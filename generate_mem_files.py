import numpy as np
from pathlib import Path

# Load BERT Q, K, V vectors
data = np.load("artifacts/bert_run/bert_qkv_int.npz")

output_dir = Path(".")

for name in ["Q", "K", "V"]:

    matrix = data[name]

    print(f"{name} shape: {matrix.shape}")

    # Flatten in row-major order
    values = matrix.flatten()

    if len(values) != 256:
        raise ValueError(f"{name} must contain 256 values")

    # Convert signed integers to 16-bit hexadecimal
    hex_values = [
        f"{int(value) & 0xFFFF:04X}"
        for value in values
    ]

    filename = output_dir / f"{name.lower()}_mem.hex"

    with open(filename, "w") as file:
        file.write("\n".join(hex_values) + "\n")

    print(f"Generated: {filename}")

print("\nAll memory files generated successfully!")