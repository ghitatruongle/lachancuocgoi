#!/usr/bin/env python3
"""
Retrain / continue fine-tuning MobileBERT checkpoints in this project.

Recommended starting checkpoint:
  - ghitav2_stage2/

Why stage2 by default?
  - ghitav2/ appears to be biased after the last fine-tuning stage.
  - starting from stage2 lets you re-run the final intent-classification
    stage with better settings (class weights, early stopping, validation).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import unicodedata
from collections import Counter
from pathlib import Path

os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from transformers import MobileBertTokenizer, TFMobileBertForSequenceClassification


LABELS = [
    "AUTH_POLICE_LAWSUIT",
    "TAX_GOV_APP",
    "TELECOM_LOCK",
    "TECH_SUPPORT_HIJACK",
    "HOSPITAL_EMERGENCY",
    "VIRTUAL_KIDNAPPING",
    "CEO_FRAUD_B2B",
    "SOCIAL_DEEPFAKE_LOAN",
    "ROMANCE_SCAM",
    "SEXTORTION_BLACKMAIL",
    "CHARITY_DONATION",
    "INVESTMENT_SCAM",
    "JOB_TASK_SCAM",
    "GIFT_LOTTERY",
    "GAMBLING_PREDICTION",
    "IMMIGRATION_VISA_SCAM",
    "BANK_CARD_FRAUD",
    "DELIVERY_COD",
    "FAKE_SUBSCRIPTION",
    "BLACK_CREDIT_TERROR",
    "RECOVERY_SCAM",
    "GENERIC_SCAM",
    "SAFE",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Retrain ghitav2 / MobileBERT for the 23-class intent task."
    )
    parser.add_argument(
        "--source-model",
        default="ghitav2_stage2",
        help="Checkpoint to continue from. Recommended: ghitav2_stage2",
    )
    parser.add_argument(
        "--tokenizer-model",
        default="google/mobilebert-uncased",
        help="Tokenizer source used for encoding text.",
    )
    parser.add_argument(
        "--train-file",
        default="train_intents.csv",
        help="CSV with columns: text,label",
    )
    parser.add_argument(
        "--output-dir",
        default="ghitav2_retrained",
        help="Folder to save the new Hugging Face checkpoint.",
    )
    parser.add_argument(
        "--tflite-out",
        default="ghitav2_retrained.tflite",
        help="Output path for exported TFLite model.",
    )
    parser.add_argument("--epochs", type=int, default=5, help="Max epochs.")
    parser.add_argument("--batch-size", type=int, default=8, help="Batch size.")
    parser.add_argument("--learning-rate", type=float, default=1e-5, help="Learning rate.")
    parser.add_argument("--max-length", type=int, default=256, help="Sequence length.")
    parser.add_argument("--val-size", type=float, default=0.2, help="Validation split.")
    parser.add_argument("--random-state", type=int, default=42, help="Random seed.")
    parser.add_argument(
        "--no-class-weights",
        action="store_true",
        help="Disable class weights. Not recommended because SAFE is overrepresented.",
    )
    parser.add_argument(
        "--normalize-like-app",
        action="store_true",
        help="Apply app-like normalization before tokenization.",
    )
    parser.add_argument(
        "--strip-accents",
        action="store_true",
        help="Also remove accents before tokenization.",
    )
    parser.add_argument(
        "--no-export-tflite",
        action="store_true",
        help="Skip TFLite export.",
    )
    return parser.parse_args()


def normalize_like_app(text: str, strip_accents: bool) -> str:
    text = text.lower()
    if strip_accents:
        text = "".join(
            ch for ch in unicodedata.normalize("NFD", text)
            if unicodedata.category(ch) != "Mn"
        )
    text = re.sub(r"[^\w\s]", " ", text, flags=re.UNICODE)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def load_dataset(path: Path, apply_normalization: bool, strip_accents: bool) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"Training file not found: {path}")

    df = pd.read_csv(path)
    required_columns = {"text", "label"}
    missing = required_columns - set(df.columns)
    if missing:
        raise ValueError(f"Missing required columns: {sorted(missing)}")

    df = df[["text", "label"]].dropna().copy()
    df["label"] = df["label"].astype(int)
    df["text"] = df["text"].astype(str).str.strip()
    df = df[df["text"] != ""].copy()

    if apply_normalization:
        df["text"] = df["text"].apply(lambda x: normalize_like_app(x, strip_accents))

    return df


def encode_texts(tokenizer: MobileBertTokenizer, texts: list[str], max_length: int) -> dict[str, tf.Tensor]:
    return dict(
        tokenizer(
            texts,
            padding=True,
            truncation=True,
            max_length=max_length,
            return_tensors="tf",
        )
    )


def make_class_weights(labels: list[int]) -> dict[int, float]:
    counts = Counter(labels)
    total = sum(counts.values())
    num_classes = len(counts)
    return {
        label: total / (num_classes * count)
        for label, count in sorted(counts.items())
    }


def print_distribution(name: str, labels: list[int]) -> None:
    counts = Counter(labels)
    print(f"{name}: total={len(labels)} classes={len(counts)} min={min(counts.values())} max={max(counts.values())}")
    print("counts:", dict(sorted(counts.items())))


def export_tflite(model: TFMobileBertForSequenceClassification, out_path: Path) -> None:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]
    tflite_model = converter.convert()
    out_path.write_bytes(tflite_model)


def main() -> int:
    args = parse_args()

    train_file = Path(args.train_file)
    source_model = Path(args.source_model)
    output_dir = Path(args.output_dir)
    tflite_out = Path(args.tflite_out)

    print("Loading dataset...")
    df = load_dataset(
        train_file,
        apply_normalization=args.normalize_like_app,
        strip_accents=args.strip_accents,
    )
    print_distribution("full_dataset", df["label"].tolist())

    train_texts, val_texts, train_labels, val_labels = train_test_split(
        df["text"].tolist(),
        df["label"].tolist(),
        test_size=args.val_size,
        random_state=args.random_state,
        stratify=df["label"].tolist(),
    )
    print_distribution("train_split", train_labels)
    print_distribution("val_split", val_labels)

    print(f"Loading tokenizer: {args.tokenizer_model}")
    tokenizer = MobileBertTokenizer.from_pretrained(args.tokenizer_model)

    print(f"Encoding texts with max_length={args.max_length} ...")
    train_inputs = encode_texts(tokenizer, train_texts, args.max_length)
    val_inputs = encode_texts(tokenizer, val_texts, args.max_length)
    train_labels_tf = tf.convert_to_tensor(train_labels)
    val_labels_tf = tf.convert_to_tensor(val_labels)

    print(f"Loading model checkpoint: {source_model}")
    model = TFMobileBertForSequenceClassification.from_pretrained(
        str(source_model),
        num_labels=len(LABELS),
        ignore_mismatched_sizes=False,
    )

    optimizer = tf.keras.optimizers.Adam(learning_rate=args.learning_rate)
    loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
    model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])

    class_weight = None
    if not args.no_class_weights:
        class_weight = make_class_weights(train_labels)
        print("class_weight:", class_weight)

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss",
            patience=2,
            restore_best_weights=True,
        )
    ]

    print("Training...")
    history = model.fit(
        train_inputs,
        train_labels_tf,
        validation_data=(val_inputs, val_labels_tf),
        epochs=args.epochs,
        batch_size=args.batch_size,
        class_weight=class_weight,
        callbacks=callbacks,
        verbose=1,
    )

    print("Evaluating best restored weights...")
    eval_results = model.evaluate(val_inputs, val_labels_tf, verbose=0)
    print("validation_metrics:", dict(zip(model.metrics_names, eval_results)))

    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"Saving checkpoint to: {output_dir}")
    model.save_pretrained(output_dir)

    metadata = {
        "source_model": str(source_model),
        "tokenizer_model": args.tokenizer_model,
        "train_file": str(train_file),
        "output_dir": str(output_dir),
        "tflite_out": str(tflite_out),
        "epochs": args.epochs,
        "batch_size": args.batch_size,
        "learning_rate": args.learning_rate,
        "max_length": args.max_length,
        "val_size": args.val_size,
        "normalize_like_app": args.normalize_like_app,
        "strip_accents": args.strip_accents,
        "class_weight": class_weight,
        "history": history.history,
        "label_map": {index: label for index, label in enumerate(LABELS)},
    }
    (output_dir / "retrain_metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    if not args.no_export_tflite:
        print(f"Exporting TFLite to: {tflite_out}")
        export_tflite(model, tflite_out)

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
