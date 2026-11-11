#!/usr/bin/env python3
"""
Extract BERT-base layer-0/head-0 Q/K/V and build RTL-oriented references.

Run from repository root:
  python reference_model/bert_rtl_verifier.py
Optional:
  python reference_model/bert_rtl_verifier.py --scale 128 --seed 42

Artifacts are written to artifacts/bert_run/. The SV include is also copied
to Simulation Sources/bert_qkv_test_vectors.svh.
"""
from __future__ import annotations
import argparse, json, math, shutil
from pathlib import Path
import numpy as np
import torch
from transformers import AutoModel, AutoTokenizer

MODEL_NAME = "google-bert/bert-base-uncased"
TEXT = "The cat sat on the mat."
N = 4
HEAD = 0
SEED = 42
# This table is copied value-for-value from Design Sources/exp_lut.sv.
EXP_LUT_Q15 = np.array([
    32768,28918,25520,22521,19875,17539,15479,13660,12055,10638,
    9388,8285,7312,6452,5694,5025,4435,3914,3454,3048,
    2690,2374,2095,1849,1631,1440,1271,1121,990,873,
    771,680,600,530,467,412,364,321,283,250,
    221,195,172,152,134,118,104,92,81,72,
    63,56,49,43,38,34,30,26,23,21,
    18,16,14,12,11
], dtype=np.int64)

def round_half_to_even(x: np.ndarray) -> np.ndarray:
    """NumPy rint: nearest integer, ties to even (explicit project convention)."""
    return np.rint(x)

def quantize_int16(x: np.ndarray, scale: int, label: str):
    if not np.all(np.isfinite(x)):
        raise ValueError(f"{label}: non-finite input")
    scaled = x.astype(np.float64) * scale
    rounded = round_half_to_even(scaled)
    lo, hi = int(rounded.min()), int(rounded.max())
    print(f"{label}: float range [{x.min():.8f}, {x.max():.8f}], "
          f"rounded integer range [{lo}, {hi}]")
    if lo < -32768 or hi > 32767:
        raise OverflowError(f"{label}: signed int16 overflow [{lo}, {hi}]; no clipping performed")
    qi = rounded.astype(np.int16)
    err = np.abs(x.astype(np.float64) - qi.astype(np.float64) / scale)
    return qi, float(err.max())

def sv_assignments(path: Path, arrays: dict[str, np.ndarray]):
    """Emit assignment statements intended inside a testbench initial/task block."""
    with path.open("w", encoding="utf-8") as f:
        f.write("// Generated from google-bert/bert-base-uncased; do not hand-edit.\n")
        f.write("// Declare logic signed [15:0] q[0:3][0:63], k[0:3][0:63], v[0:3][0:63].\n")
        f.write("// Include this file inside an initial block after those declarations.\n")
        for name, arr in arrays.items():
            assert arr.shape == (4, 64)
            f.write(f"// {name.upper()} assignments\n")
            for i in range(4):
                for j in range(64): 
                    value = int(arr[i, j])
                    if value < 0:
                     literal = f"-16'sd{-value}"
                    else:
                     literal = f"16'sd{value}"
                    f.write(f"{name}[{i}][{j}] = {literal};\n")

def trunc_div_signed(n: np.ndarray, d: int) -> np.ndarray:
    """SV signed integer division truncates toward zero (not floor)."""
    n = np.asarray(n, dtype=np.int64)
    return np.where(n >= 0, n // d, -((-n) // d))

def rtl_fixed_attention(qi, ki, vi):
    """
    Bit-accurate behavioral model of current RTL arithmetic AFTER parameter
    updates documented in docs/RTL_CHANGE_PLAN.md:
      QK: signed integer dot products
      scale: (score <<< 8) / 131072 == trunc(score / 512), Q8 score
      LUT: round delta to nearest 1/8 (Q8 step 32), saturate index at 64
      softmax: (exp_q15 << 15) / row_sum, unsigned integer truncation
      weighted sum: signed products, sum, arithmetic >>> 15
    """
    q64, k64, v64 = [np.asarray(x, dtype=np.int64) for x in (qi,ki,vi)]
    raw_scores = q64 @ k64.T
    # Q/K are quantized with S=128. Real scaled dot product is raw/(128^2*8).
    # Express that real value in Q8: raw*256/(128^2*8) = raw/512.
    score_q8 = trunc_div_signed(raw_scores, 512)
    row_max = score_q8.max(axis=1, keepdims=True)
    delta = row_max - score_q8
    lut_index = np.minimum((delta + 16) >> 5, 64).astype(np.int64)
    exp_q15 = EXP_LUT_Q15[lut_index]
    row_sum = exp_q15.sum(axis=1, keepdims=True)
    weights_q15 = (exp_q15 << 15) // row_sum
    weighted_acc = weights_q15 @ v64
    out_int = weighted_acc >> 15  # arithmetic right shift, matching signed SV >>>.
    return {
        "qk_raw": raw_scores, "scores_q8": score_q8, "delta_q8": delta,
        "lut_index": lut_index, "exp_q15": exp_q15,
        "row_sum": row_sum, "weights_q15": weights_q15,
        "weighted_acc": weighted_acc, "output_int": out_int
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scale", type=int, default=128)
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--model", default=MODEL_NAME)
    ap.add_argument("--text", default=TEXT)
    ap.add_argument("--output-dir", default="artifacts/bert_run")
    args = ap.parse_args()
    if args.scale != 128:
        raise ValueError("This checked-in RTL configuration is calibrated for --scale 128 only. "
                         "Re-derive SCALE_DENOM = scale^2 * sqrt(64) and update RTL/reference together.")
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    torch.set_grad_enabled(False)

    outdir = Path(args.output_dir)
    outdir.mkdir(parents=True, exist_ok=True)
    repo = Path(__file__).resolve().parents[1]
    print(f"Loading {args.model} ...")
    tokenizer = AutoTokenizer.from_pretrained(args.model)
    model = AutoModel.from_pretrained(args.model)
    model.eval()
    # Tokenize with special tokens; require exactly four tokens after truncation.
    encoded = tokenizer(args.text, return_tensors="pt", add_special_tokens=True,
                        truncation=True, max_length=N, padding="max_length")
    input_ids = encoded["input_ids"]
    attention_mask = encoded["attention_mask"]
    if input_ids.shape != (1, N) or int(attention_mask.sum()) != N:
        raise ValueError("Expected exactly four non-padding tokens including special tokens.")
    token_ids = input_ids[0].tolist()
    token_strings = tokenizer.convert_ids_to_tokens(token_ids)

    captured = {}
    attention = model.encoder.layer[0].attention.self
    handles = []
    for name in ("query", "key", "value"):
        def hook(_module, _inputs, output, key=name):
            captured[key] = output.detach().clone()
        handles.append(getattr(attention, name).register_forward_hook(hook))
    try:
        with torch.no_grad():
            _ = model(input_ids=input_ids, attention_mask=attention_mask)
    finally:
        for h in handles:
            h.remove()
    heads = int(model.config.num_attention_heads)
    hidden = int(model.config.hidden_size)
    head_dim = hidden // heads
    if head_dim != 64 or heads != 12:
        raise ValueError(f"Unexpected BERT-base dimensions: heads={heads}, head_dim={head_dim}")
    def head0(name):
        t = captured[name].reshape(1, N, heads, head_dim).permute(0,2,1,3)
        a = t[0, HEAD].cpu().numpy().copy()
        if a.shape != (N,64) or not np.isfinite(a).all():
            raise AssertionError(f"Invalid {name} tensor")
        return a
    qf, kf, vf = head0("query"), head0("key"), head0("value")
    print("Token IDs:", token_ids)
    print("Tokens:", token_strings)
    for name, a in (("Q",qf),("K",kf),("V",vf)):
        print(f"{name}: shape={a.shape}, dtype={a.dtype}, samples={a[0,:8]}")
    np.savez_compressed(outdir/"bert_qkv_float.npz", Q=qf, K=kf, V=vf,
                        token_ids=np.asarray(token_ids,dtype=np.int64),
                        token_strings=np.asarray(token_strings))
    metadata = {
        "model_name": args.model, "text": args.text, "token_ids": token_ids,
        "tokens": token_strings, "sequence_length": N, "num_heads": heads,
        "selected_head": HEAD, "head_dimension": head_dim,
        "torch_dtype": str(captured["query"].dtype), "numpy_dtype": str(qf.dtype),
        "quantization_scale": args.scale, "rounding": "round-to-nearest, ties-to-even (numpy.rint)",
        "seed": args.seed, "attention_formula": "softmax(Q @ K.T / sqrt(64)) @ V"
    }
    (outdir/"bert_metadata.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")

    qi, qe = quantize_int16(qf,args.scale,"Q")
    ki, ke = quantize_int16(kf,args.scale,"K")
    vi, ve = quantize_int16(vf,args.scale,"V")
    np.savez_compressed(outdir/"bert_qkv_int.npz",Q=qi,K=ki,V=vi,
                        scale=np.asarray(args.scale,dtype=np.int32))
    svpath = outdir/"bert_qkv_test_vectors.svh"
    sv_assignments(svpath, {"q":qi,"k":ki,"v":vi})
    sim_copy = repo/"Simulation Sources"/"bert_qkv_test_vectors.svh"
    shutil.copy2(svpath,sim_copy)

    def softmax(x):
        x = x - np.max(x,axis=-1,keepdims=True)
        e = np.exp(x)
        return e/e.sum(axis=-1,keepdims=True)
    scores_float = (qf @ kf.T)/math.sqrt(64.0)
    weights_float = softmax(scores_float)
    of = weights_float @ vf
    fx = rtl_fixed_attention(qi,ki,vi)
    ofx = fx["output_int"].astype(np.float64)/args.scale
    maxerr = float(np.max(np.abs(of-ofx)))
    meanerr = float(np.mean(np.abs(of-ofx)))
    np.savez_compressed(outdir/"attention_reference_results.npz",
        scores_float=scores_float, weights_float=weights_float, output_float=of,
        **fx, output_fixed_dequantized=ofx)
    np.savetxt(outdir/"attention_output_float.csv",of,delimiter=",",fmt="%.10g")
    np.savetxt(outdir/"attention_output_fixed.csv",ofx,delimiter=",",fmt="%.10g")
    report = {
        "quantization": {"scale":args.scale,"rounding":"nearest ties-to-even",
          "Q_max_abs_error":qe,"K_max_abs_error":ke,"V_max_abs_error":ve},
        "attention": {"max_abs_error_float_vs_fixed":maxerr,
          "mean_abs_error_float_vs_fixed":meanerr},
        "ranges": {"Q_int":[int(qi.min()),int(qi.max())],
          "K_int":[int(ki.min()),int(ki.max())],"V_int":[int(vi.min()),int(vi.max())]},
        "rtl_compatibility": "NOT CLAIMED: apply and simulate the documented RTL changes first.",
        "fixed_point_model": "Current exp_lut.sv LUT and integer truncation semantics; scale denominator 131072 with FRAC_BITS=8."
    }
    (outdir/"verification_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    (outdir/"verification_report.md").write_text(
      "# BERT Q/K/V verification report\n\n"
      f"- Model: `{args.model}`\n- Text: `{args.text}`\n- Tokens: `{token_strings}`\n"
      f"- Shape per tensor: `(4, 64)`; scale: `{args.scale}`\n"
      f"- Rounding: nearest, ties-to-even; overflow policy: fail, never clip\n\n"
      "## Quantization error (maximum absolute, in original float units)\n"
      f"- Q: `{qe:.10g}`\n- K: `{ke:.10g}`\n- V: `{ve:.10g}`\n\n"
      "## Attention output comparison\n"
      f"- Max absolute error: `{maxerr:.10g}`\n- Mean absolute error: `{meanerr:.10g}`\n\n"
      "**RTL status:** not claimed compatible. See `docs/RTL_CHANGE_PLAN.md`; the Python fixed-point model is a behavioral target for the specified arithmetic, not proof of RTL simulation equivalence.\n",
      encoding="utf-8")
    print("\nQK raw scores:\n",fx["qk_raw"])
    print("\nScaled scores Q8:\n",fx["scores_q8"])
    print("\nLUT indices:\n",fx["lut_index"])
    print("\nQ15 weights:\n",fx["weights_q15"])
    print("\nFloat output (first row, first 8):",of[0,:8])
    print("\nFixed output / scale (first row, first 8):",ofx[0,:8])
    print(f"\nOutput error: max={maxerr:.8g}, mean={meanerr:.8g}")
    print("Wrote artifacts to",outdir.resolve())
    print("Wrote SV include to",sim_copy.resolve())

if __name__ == "__main__":
    main()
