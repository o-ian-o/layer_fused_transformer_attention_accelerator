# BERT Q/K/V extraction for RTL attention verification

This workflow extracts the first BERT encoder layer's query, key, and value
projection outputs for attention head 0, quantizes them to signed int16, and
generates a SystemVerilog include file and independent reference results.

## Repository placement

- `reference_model/bert_rtl_verifier.py`: extraction, quantization, test-vector,
  floating reference, and fixed-point behavioral reference.
- `Design Sources/*.sv`: revised RTL parameter defaults and arithmetic fixes.
- `Simulation Sources/tb_bert_layer_fused_attention.sv`: N=4, D=64 end-to-end TB.
- `Simulation Sources/bert_qkv_test_vectors.svh`: generated on script execution.
- `artifacts/bert_run/`: generated NPZ, JSON, CSV, and report outputs.
- `docs/RTL_CHANGE_PLAN.md`: rationale and verification sequence.

## Run locally

From the repository root (the directory containing the `.xpr` file):

```bash
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate
python -m pip install -r requirements-bert.txt
python reference_model/bert_rtl_verifier.py
```

The first run downloads `google-bert/bert-base-uncased` from Hugging Face.
It needs internet access. Re-running with the same model revision, input,
software versions, and seed gives deterministic preprocessing and inference
in normal CPU execution. For strict archival reproducibility, record/pin the
resolved model commit and package versions in your experiment log.

## Run in Google Colab

1. Upload/extract the repository ZIP in the Colab session.
2. `cd` into `layer_fused_attention_accelerator`.
3. Run `!pip install -r requirements-bert.txt`.
4. Run `!python reference_model/bert_rtl_verifier.py`.
5. Download `artifacts/bert_run/` and the generated include file if needed.

## What the generated files mean

- `bert_qkv_float.npz`: original floating point Q/K/V and token information.
- `bert_metadata.json`: model, input, token, shape, head and quantization metadata.
- `bert_qkv_int.npz`: signed int16 Q/K/V plus quantization scale.
- `bert_qkv_test_vectors.svh`: explicit signed decimal assignments. Include it
  inside a testbench procedural block after declaring q/k/v arrays.
- `attention_reference_results.npz`: float and fixed-point intermediate arrays.
- `attention_output_float.csv`, `attention_output_fixed.csv`: output matrices.
- `verification_report.json/.md`: quantization and output error summary.

The NPZ files containing real pretrained-model values are created when you run
the script. They are intentionally not fabricated or pre-populated with sample
numbers in this source package.

## Important comparison convention

BERT Q/K/V are projection outputs before attention score calculation.
For head dimension 64, the float reference is
`softmax(Q @ K.T / 8) @ V`.

With input quantization scale S=128, integer dot products represent
`S^2 * (Q @ K.T)`. To represent the scaled score in Q8, the RTL arithmetic is
`(raw_score << 8) / (128*128*8)`, i.e. `(raw_score << 8)/131072`.
The script models the same signed truncation, the exact 65-entry exp LUT,
nearest LUT-step rounding, Q15 normalization by integer division, and signed
arithmetic right shift in the weighted sum.

The fixed-point reference models the documented target arithmetic. It does
not by itself prove that the RTL compiles, simulates, or matches bit-for-bit.
