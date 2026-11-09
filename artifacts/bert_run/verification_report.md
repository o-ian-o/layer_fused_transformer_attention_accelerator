# BERT Q/K/V verification report

- Model: `google-bert/bert-base-uncased`
- Text: `The cat sat on the mat.`
- Tokens: `['[CLS]', 'the', 'cat', '[SEP]']`
- Shape per tensor: `(4, 64)`; scale: `128`
- Rounding: nearest, ties-to-even; overflow policy: fail, never clip

## Quantization error (maximum absolute, in original float units)
- Q: `0.003889560699`
- K: `0.003884315491`
- V: `0.003899693489`

## Attention output comparison
- Max absolute error: `0.0344415307`
- Mean absolute error: `0.005109287822`

**RTL status:** not claimed compatible. See `docs/RTL_CHANGE_PLAN.md`; the Python fixed-point model is a behavioral target for the specified arithmetic, not proof of RTL simulation equivalence.
