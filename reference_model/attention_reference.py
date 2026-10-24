import numpy as np

def run_attention_reference(Q, K, V):
    print("--- Inputs ---")
    print("Q:\n", Q)
    print("K:\n", K)
    print("V:\n", V)

    # ---------------------------------------------------------
    # Stage 1: QK^T Matrix Multiplication (Matches qk_matmul.sv)
    # ---------------------------------------------------------
    scores = Q @ K.T
    print("\n--- Stage 1: QK Scores (Integer) ---")
    print(scores)

    # ---------------------------------------------------------
    # Stage 2: Scale Attention Scores (Matches scale_unit.sv)
    # (scores <<< 8) / 2
    # ---------------------------------------------------------
    scaled_scores = (scores * 256) // 2
    print("\n--- Stage 2: Scaled Scores (Q8 format) ---")
    print(scaled_scores)

    # ---------------------------------------------------------
    # Stage 3: Softmax (Matches softmax.sv & exp_lut.sv)
    # ---------------------------------------------------------
    row_max = scaled_scores.max(axis=1, keepdims=True)
    delta_q8 = row_max - scaled_scores
    
    # LUT indexing: round to nearest multiple of 32 (delta_q8 + 16) >> 5
    lut_index = (delta_q8 + 16) >> 5
    lut_index = np.clip(lut_index, 0, 64) # Saturate max index at 64
    
    # Hardware LUT exactly extracted from exp_lut.sv
    LUT = np.array([
        32768, 28918, 25520, 22521, 19875, 17539, 15479, 13660, 12055, 10638,
        9388, 8285, 7312, 6452, 5694, 5025, 4435, 3914, 3454, 3048,
        2690, 2374, 2095, 1849, 1631, 1440, 1271, 1121, 990, 873,
        771, 680, 600, 530, 467, 412, 364, 321, 283, 250,
        221, 195, 172, 152, 134, 118, 104, 92, 81, 72,
        63, 56, 49, 43, 38, 34, 30, 26, 23, 21,
        18, 16, 14, 12, 11
    ])
    
    exp_q15 = LUT[lut_index]
    sum_exp = exp_q15.sum(axis=1, keepdims=True)
    
    # Normalization: (exp_q15 << 15) / sum_exp
    weights = (np.left_shift(exp_q15.astype(np.int64), 15)) // sum_exp
    print("\n--- Stage 3: Attention Weights (Q15 format) ---")
    print(weights)

    # ---------------------------------------------------------
    # Stage 4: Weighted Sum (Matches attention_weighted_sum.sv)
    # ---------------------------------------------------------
    accumulator = weights @ V
    
    # Arithmetic right shift by 15 (accumulator >>> 15 in SV)
    # Using floor_divide or right_shift in numpy matches Verilog arithmetic shift
    output_matrix = np.right_shift(accumulator.astype(np.int64), 15)
    
    print("\n--- Stage 4: Final Output Matrix (Integer) ---")
    print(output_matrix)
    
    return output_matrix

# Example usage with random 4x4 matrices
np.random.seed(42)
Q_test = np.random.randint(-5, 5, size=(4, 4))
K_test = np.random.randint(-5, 5, size=(4, 4))
V_test = np.random.randint(-5, 5, size=(4, 4))

run_attention_reference(Q_test, K_test, V_test)