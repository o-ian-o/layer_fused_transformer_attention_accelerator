# RTL change plan: 4x64 BERT head-0 vectors

## Baseline findings from the supplied project

The original top-level and QK testbench default to `D=4`. The QK engine
performs one multiply-accumulate per clock and computes N*N*D products.
At N=4,D=64 this is 1,024 MAC cycles. The original top-level testbench waits
only 200 clocks, which is insufficient.

The original `scale_unit` uses `(scores <<< 8)/2`. That is a legacy test
convention and is not scaled dot-product attention for Q/K inputs quantized
at 128. The original scale expression also shifts a 40-bit value without
explicitly widening the intermediate.

The existing exponential LUT has 65 entries, 0..64, with a Q8 input step of
32 (1/8) and Q15 output. Its original rounding-offset addition occurs before
saturation; an extremely large unsigned delta could wrap during that addition.

## Required numerical convention

Let `S=128`, `D=64`, and `raw = Q_int @ K_int.T`.

- `Q_int ~= round(Q_float*S)` and similarly for K/V.
- `raw ~= Q_float @ K_float.T * S^2`.
- Desired real score is `(Q_float @ K_float.T)/sqrt(64)`.
- Convert desired score to Q8: `score_q8 = raw*256/(S^2*8)`.
- With S=128, denominator after the shift is `128^2*8 = 131072`.
- Thus the RTL scale stage is `(raw <<< 8)/131072`, with signed division
  truncating toward zero. It is equivalent to `trunc(raw/512)`.

The LUT input is the nonnegative Q8 difference between row maximum and score.
The LUT rounds to the nearest 1/8 step: `(delta_q8+16)>>5`, saturating at index 64. Softmax computes `(exp_q15<<15)/sum(exp_q15)` using integer division.
Weighted sum computes the signed sum of `weight_q15 * V_int`, then arithmetic
right-shifts by 15.

## Changes applied in this package

1. `qk_matmul.sv`: default D changed to 64. Keep `DATA_WIDTH=16` and
   `ACC_WIDTH=40`. For signed int16 inputs, one product magnitude can reach
   2^30; summing 64 terms requires 38 signed bits. 40 bits provides margin.
2. `scale_unit.sv`: default denominator changed to 131072 and the left-shift
   intermediate is explicitly widened to `ACC_WIDTH+FRAC_BITS+1` bits.
3. `exp_lut.sv`: saturation is checked before adding the rounding offset,
   preventing unsigned wrap for extreme deltas.
4. `layer_fused_attention.sv`: default D changed to 64 and scale denominator
   changed from 2 to 131072.
5. New `tb_bert_layer_fused_attention.sv`: declares N=4,D=64, includes the
   generated assignments, and allows 5,000 clocks (far above the 1,024 MAC
   cycles plus controller margin).

## Modules that should be checked, not blindly rewritten

- `softmax.sv`: `SUM_WIDTH=20` can hold four 16-bit LUT outputs (maximum
  131072, requiring 18 bits). `numerator` is 32 bits and the maximum
  `32768<<15` is 2^30, which fits. Confirm simulator signedness and row-sum
  assertions in the actual simulator.
- `attention_weighted_sum.sv`: 17-bit unsigned weight extended to signed,
  multiplied by signed int16 V, then accumulated. ACC_WIDTH=40 is ample for
  four products. Output is signed int16; a convex weighted average of int16
  values should remain in range, subject to Q15 normalization truncation.
- `qk_matmul.sv`: 40-bit accumulator is adequate. Confirm multiplication is
  treated as signed by the simulator; the operands are declared signed and
  the product is signed. If tool warnings suggest ambiguity, use explicit
  `$signed(q[i][d]) * $signed(k[j][d])`.

## Critical integration caveat: softmax precision

Q15 weights are stored in 16-bit unsigned values, where 32768 represents
1.0. This is valid as an unsigned 16-bit encoding. Do not change them to
signed 16-bit, because 32768 would become negative. `attention_weighted_sum`
must continue to extend weights with a leading zero before signed multiply.

## Vivado procedure

1. Make a copy/branch before editing. Open the `.xpr` project.
2. Add `Simulation Sources/tb_bert_layer_fused_attention.sv` as a simulation
   source (Add Sources -> Add or Create Simulation Sources).
3. Add `Simulation Sources` to Verilog include directories if Vivado cannot
   resolve `` `include "bert_qkv_test_vectors.svh" ``.
4. Run the Python generator from repository root. It creates the include file
   under `Simulation Sources`.
5. Set `tb_bert_layer_fused_attention` as simulation top.
6. Run behavioral simulation. Check `done`, no timeout, and inspect the output.
7. Compare the printed RTL output matrix against
   `artifacts/bert_run/attention_reference_results.npz` key `output_int`.
   A mismatch means the RTL and Python behavioral arithmetic disagree.
8. Only after this comparison passes should the report be updated to say
   bit-accurate RTL verification passed. The generated report deliberately
   says compatibility is not claimed.

## Existing legacy tests

Keep the original D=4 unit testbenches as regression tests. Their `scale_unit`
test instantiates denominator 2 and remains a legacy module-level check.
The top-level's scale denominator is now the BERT-specific 131072 convention.
Run both legacy unit tests and the new BERT end-to-end test after any RTL edit.
