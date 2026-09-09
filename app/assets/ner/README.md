# `assets/ner/` — the on-device extraction model

Bundled into the app (declared in `../../pubspec.yaml`) and loaded by the real
`OnnxExtractor` (not built yet — still `StubExtractor`).

Produced on the GPU server from a trained checkpoint:

```bash
cd ../distill
python export_onnx.py --model model-mobile --variant int8 --emit ../app/assets/ner
```

Expected contents once emitted:

| file | what |
|------|------|
| `model.quant.onnx` | int8-quantized MobileBERT token-classifier (15 BIO tags) |
| `vocab.txt` | WordPiece vocabulary for the Dart tokenizer |
| `labels.json` | `{bio, label2id}` — tag index → name |
| `config.json` | carries `id2label` |
| `tokenizer_config.json`, `special_tokens_map.json` | tokenizer settings (uncased, max_length 256) |
| `drug_names.txt` | ~10k RxNorm drug names — the DRUG validation list (`../distill/drug_vocab.py`) |

The Python reference the Dart code must match: `../distill/infer.py`.
