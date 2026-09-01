"""
Stage 3: fine-tune a small model to reproduce the labels.

This is the actual "training". In plain terms:
  * The base model (DistilBERT / MobileBERT) already knows English from Google's
    pre-training. It does NOT know what a "drug name" is.
  * We show it our labelled examples over and over. For each word it guesses a
    tag; we measure how wrong the whole guess is (one number, the "loss"); an
    optimiser nudges the model's millions of internal numbers ("weights") a hair
    in the direction that reduces the loss.
  * Repeat for every example, a few passes through the data ("epochs"). Loss
    drops, predictions improve. You never set a weight by hand.
  * After each epoch we check the held-out val set so we can see it learning
    (and stop if it starts memorising instead of generalising).

    python train_ner.py --data data/ --base-model distilbert-base-uncased --epochs 4
    python train_ner.py --data data/ --base-model google/mobilebert-uncased --epochs 5 --lr 5e-5

Runs on CPU (slow) or a GPU (Colab: set runtime to GPU, it just works).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np


def build_tokenize_fn(tokenizer, label2id):
    def fn(batch):
        enc = tokenizer(
            batch["text"], truncation=True, max_length=256,
            return_offsets_mapping=True, padding=False,
        )
        all_labels = []
        for i, offsets in enumerate(enc["offset_mapping"]):
            ents = batch["entities"][i]
            labels = []
            for (a, b) in offsets:
                if a == b:                       # special token -> ignored by loss
                    labels.append(-100)
                    continue
                hit = next(((s, e, lab) for s, e, lab in ents if s <= a < e), None)
                if hit is None:
                    labels.append(label2id["O"])
                else:
                    s, e, lab = hit
                    labels.append(label2id[f"{'B' if a == s else 'I'}-{lab}"])
            all_labels.append(labels)
        enc["labels"] = all_labels
        enc.pop("offset_mapping")
        return enc
    return fn


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data")
    ap.add_argument("--base-model", default="distilbert-base-uncased")
    ap.add_argument("--out", default="ner-model")
    ap.add_argument("--epochs", type=float, default=4)
    ap.add_argument("--lr", type=float, default=3e-5)
    ap.add_argument("--batch-size", type=int, default=16)
    args = ap.parse_args()

    from datasets import load_dataset
    from transformers import (
        AutoModelForTokenClassification, AutoTokenizer,
        DataCollatorForTokenClassification, Trainer, TrainingArguments,
    )
    from seqeval.metrics import f1_score, precision_score, recall_score

    data = Path(args.data)
    meta = json.loads((data / "labels.json").read_text())
    bio, label2id = meta["bio"], meta["label2id"]
    id2label = {i: t for t, i in label2id.items()}

    tokenizer = AutoTokenizer.from_pretrained(args.base_model)
    model = AutoModelForTokenClassification.from_pretrained(
        args.base_model, num_labels=len(bio), id2label=id2label, label2id=label2id,
    )

    ds = load_dataset("json", data_files={
        "train": str(data / "train.jsonl"),
        "val": str(data / "val.jsonl"),
    })
    tok_fn = build_tokenize_fn(tokenizer, label2id)
    ds = ds.map(tok_fn, batched=True, remove_columns=ds["train"].column_names)

    def compute_metrics(eval_pred):
        preds, labels = eval_pred
        preds = np.argmax(preds, axis=-1)
        true, pred = [], []
        for p_row, l_row in zip(preds, labels):
            t, pr = [], []
            for p, l in zip(p_row, l_row):
                if l == -100:
                    continue
                t.append(bio[l])
                pr.append(bio[p])
            true.append(t)
            pred.append(pr)
        return {
            "precision": precision_score(true, pred, zero_division=0),
            "recall": recall_score(true, pred, zero_division=0),
            "f1": f1_score(true, pred, zero_division=0),
        }

    targs = TrainingArguments(
        output_dir=args.out,
        learning_rate=args.lr,
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.batch_size,
        weight_decay=0.01,
        logging_steps=25,
        report_to="none",
        **_eval_save_kwargs(),
    )
    trainer = Trainer(
        model=model, args=targs,
        train_dataset=ds["train"], eval_dataset=ds["val"],
        data_collator=DataCollatorForTokenClassification(tokenizer),
        compute_metrics=compute_metrics,
    )
    trainer.train()
    trainer.save_model(args.out)
    tokenizer.save_pretrained(args.out)
    (Path(args.out) / "labels.json").write_text(json.dumps(meta, indent=2))
    print(f"\nSaved fine-tuned model -> {args.out}")
    print("Next: python evaluate.py --model", args.out, "--data", args.data)


def _eval_save_kwargs() -> dict:
    """TrainingArguments renamed evaluation_strategy -> eval_strategy across versions."""
    from transformers import TrainingArguments
    import inspect
    params = inspect.signature(TrainingArguments.__init__).parameters
    key = "eval_strategy" if "eval_strategy" in params else "evaluation_strategy"
    return {key: "epoch", "save_strategy": "epoch", "load_best_model_at_end": True,
            "metric_for_best_model": "f1", "save_total_limit": 1}


if __name__ == "__main__":
    main()
