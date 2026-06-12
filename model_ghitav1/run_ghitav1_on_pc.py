#!/usr/bin/env python3
"""
Run the ghitav1 MobileBERT TFLite classifier on a desktop machine.

This project ships a TensorFlow Lite model (`ghitav1.tflite`). The current
GGUF / llama.cpp conversion path does not support MobileBERT sequence
classification, so this script runs the original TFLite model directly.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import unicodedata
import warnings
from pathlib import Path

import numpy as np

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")
warnings.filterwarnings("ignore", message=".*tf.lite.Interpreter is deprecated.*")

import tensorflow as tf


DEFAULT_MAX_SEQ_LEN = 256
CLS_TOKEN = "[CLS]"
SEP_TOKEN = "[SEP]"
PAD_TOKEN = "[PAD]"
UNK_TOKEN = "[UNK]"

LABELS: list[tuple[str, str]] = [
    ("AUTH_POLICE_LAWSUIT", "Gia danh cong an, toa an, vien kiem sat"),
    ("TAX_GOV_APP", "Thue, VNeID gia, dich vu cong"),
    ("TELECOM_LOCK", "Doa khoa SIM, nha mang"),
    ("TECH_SUPPORT_HIJACK", "Ho tro ky thuat gia"),
    ("HOSPITAL_EMERGENCY", "Benh vien, vien phi gap"),
    ("VIRTUAL_KIDNAPPING", "Bat coc ao, doa tinh mang"),
    ("CEO_FRAUD_B2B", "Deepvoice sep muon tien"),
    ("SOCIAL_DEEPFAKE_LOAN", "Deepfake ban be muon tien"),
    ("ROMANCE_SCAM", "Lua tinh, buu kien kep hai quan"),
    ("SEXTORTION_BLACKMAIL", "Tong tien anh clip nhay cam"),
    ("CHARITY_DONATION", "Tu thien ao, quyen gop"),
    ("INVESTMENT_SCAM", "Dau tu coin, Forex"),
    ("JOB_TASK_SCAM", "Cong tac vien, viec lam online"),
    ("GIFT_LOTTERY", "Trung thuong, tri an"),
    ("GAMBLING_PREDICTION", "Lo de, du doan so"),
    ("IMMIGRATION_VISA_SCAM", "Visa, xuat khau lao dong"),
    ("BANK_CARD_FRAUD", "Ngan hang gia, the khoa"),
    ("DELIVERY_COD", "Shipper no tien, COD"),
    ("FAKE_SUBSCRIPTION", "Tru tien tu dong, goi VIP"),
    ("BLACK_CREDIT_TERROR", "Tin dung den, doi no"),
    ("RECOVERY_SCAM", "Dich vu lay lai tien da bi lua"),
    ("GENERIC_SCAM", "Lua dao chung chung"),
    ("SAFE", "Hoi thoai an toan"),
]


def find_asset_path(explicit_path: Path | None, *candidates: str) -> Path:
    if explicit_path is not None:
        if explicit_path.exists():
            return explicit_path
        raise FileNotFoundError(f"File not found: {explicit_path}")

    base_dir = Path(__file__).resolve().parent
    search_roots = [
        base_dir,
        base_dir.parent,
        Path.cwd(),
    ]
    search_paths: list[Path] = []
    for root in search_roots:
        for candidate in candidates:
            candidate_path = Path(candidate)
            if candidate_path.is_absolute():
                path = candidate_path
            else:
                path = root / candidate_path
            if path not in search_paths:
                search_paths.append(path)
    for path in search_paths:
        if path.exists():
            return path

    searched = ", ".join(str(path) for path in search_paths)
    raise FileNotFoundError(f"Could not locate required file. Searched: {searched}")


def load_vocab(vocab_path: Path) -> dict[str, int]:
    vocab: dict[str, int] = {}
    with vocab_path.open("r", encoding="utf-8") as handle:
        for index, token in enumerate(handle):
            vocab[token.strip()] = index
    return vocab


def normalize_vietnamese(text: str) -> str:
    cleaned_chars: list[str] = []
    for ch in text.lower():
        category = unicodedata.category(ch)
        if ch.isspace() or category.startswith(("L", "N")):
            cleaned_chars.append(ch)
        else:
            cleaned_chars.append(" ")
    return " ".join("".join(cleaned_chars).split())


def wordpiece_tokenize(word: str, vocab: dict[str, int]) -> list[str]:
    sub_tokens: list[str] = []
    start = 0

    while start < len(word):
        end = len(word)
        current_substring: str | None = None

        while start < end:
            piece = word[start:end]
            if start > 0:
                piece = f"##{piece}"
            if piece in vocab:
                current_substring = piece
                break
            end -= 1

        if current_substring is None:
            return [UNK_TOKEN]

        sub_tokens.append(current_substring)
        start = end

    return sub_tokens


def tokenize(text: str, vocab: dict[str, int]) -> list[str]:
    tokens: list[str] = []
    for word in text.split():
        if word in vocab:
            tokens.append(word)
            continue
        tokens.extend(wordpiece_tokenize(word, vocab))
    return tokens


def build_bert_inputs(tokens: list[str], vocab: dict[str, int], max_seq_len: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    cls_id = vocab.get(CLS_TOKEN, 101)
    sep_id = vocab.get(SEP_TOKEN, 102)
    pad_id = vocab.get(PAD_TOKEN, 0)
    unk_id = vocab.get(UNK_TOKEN, 100)

    truncated_tokens = tokens[-(max_seq_len - 2):]

    input_ids = np.full((1, max_seq_len), pad_id, dtype=np.int32)
    attention_mask = np.zeros((1, max_seq_len), dtype=np.int32)
    token_type_ids = np.zeros((1, max_seq_len), dtype=np.int32)

    input_ids[0, 0] = cls_id
    attention_mask[0, 0] = 1

    for idx, token in enumerate(truncated_tokens, start=1):
        input_ids[0, idx] = vocab.get(token, unk_id)
        attention_mask[0, idx] = 1

    sep_position = len(truncated_tokens) + 1
    input_ids[0, sep_position] = sep_id
    attention_mask[0, sep_position] = 1

    return input_ids, attention_mask, token_type_ids


def softmax(logits: np.ndarray) -> np.ndarray:
    shifted = logits - np.max(logits)
    exp_values = np.exp(shifted)
    return exp_values / np.sum(exp_values)


class Ghitav1DesktopRunner:
    def __init__(self, model_path: Path, vocab_path: Path, max_seq_len: int = DEFAULT_MAX_SEQ_LEN) -> None:
        self.model_path = model_path
        self.vocab_path = vocab_path
        self.max_seq_len = max_seq_len
        self.vocab = load_vocab(vocab_path)
        # Windows + TensorFlow Lite can choke on non-ASCII filesystem paths.
        self.interpreter = tf.lite.Interpreter(model_content=model_path.read_bytes())
        self.runner = self.interpreter.get_signature_runner("serving_default")

    def predict(self, text: str, top_k: int = 5) -> dict[str, object]:
        if not text or not text.strip():
            raise ValueError("Input text is empty.")

        normalized = normalize_vietnamese(text)
        tokens = tokenize(normalized, self.vocab)
        input_ids, attention_mask, token_type_ids = build_bert_inputs(tokens, self.vocab, self.max_seq_len)

        outputs = self.runner(
            attention_mask=attention_mask,
            input_ids=input_ids,
            token_type_ids=token_type_ids,
        )
        logits = outputs["logits"][0].astype(np.float64)
        probabilities = softmax(logits)

        predictions = []
        for index, (label_id, label_name) in enumerate(LABELS):
            predictions.append(
                {
                    "rank": 0,
                    "label_id": label_id,
                    "label_name": label_name,
                    "confidence": float(probabilities[index]),
                    "logit": float(logits[index]),
                }
            )

        predictions.sort(key=lambda item: item["confidence"], reverse=True)
        for rank, item in enumerate(predictions, start=1):
            item["rank"] = rank

        return {
            "model_path": str(self.model_path),
            "vocab_path": str(self.vocab_path),
            "max_seq_len": self.max_seq_len,
            "input_text": text,
            "normalized_text": normalized,
            "token_count": len(tokens),
            "top_prediction": predictions[0],
            "predictions": predictions[:top_k],
        }


def print_human_readable(result: dict[str, object]) -> None:
    top_prediction = result["top_prediction"]
    predictions = result["predictions"]

    print(f"Model       : {result['model_path']}")
    print(f"Vocab       : {result['vocab_path']}")
    print(f"Max seq len : {result['max_seq_len']}")
    print(f"Tokens      : {result['token_count']}")
    print(f"Input       : {result['input_text']}")
    print(f"Normalized  : {result['normalized_text']}")
    print()
    print(
        "Top result  : "
        f"{top_prediction['label_id']} | {top_prediction['label_name']} | "
        f"{top_prediction['confidence']:.4%}"
    )
    print()
    print("Top predictions:")
    for item in predictions:
        print(
            f"  {item['rank']:>2}. "
            f"{item['label_id']:<24} "
            f"{item['confidence']:.4%} "
            f"({item['label_name']})"
        )


def read_input_text(args: argparse.Namespace) -> str | None:
    if args.text:
        return args.text
    if args.file:
        return Path(args.file).read_text(encoding="utf-8")
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run ghitav1.tflite directly on a desktop machine."
    )
    parser.add_argument("--text", help="Vietnamese transcript to classify.")
    parser.add_argument("--file", help="Read transcript text from a UTF-8 file.")
    parser.add_argument("--top-k", type=int, default=5, help="Number of predictions to show.")
    parser.add_argument("--max-seq-len", type=int, default=DEFAULT_MAX_SEQ_LEN, help="Sequence length used for inference.")
    parser.add_argument("--json", action="store_true", help="Print JSON instead of human-readable text.")
    parser.add_argument("--model", type=Path, help="Optional path to a .tflite model file.")
    parser.add_argument("--vocab", type=Path, help="Optional path to vocab.txt.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.top_k < 1:
        print("--top-k must be >= 1", file=sys.stderr)
        return 2
    if args.max_seq_len < 4:
        print("--max-seq-len must be >= 4", file=sys.stderr)
        return 2

    model_path = find_asset_path(args.model, "ghitav1.tflite", "app/src/main/assets/ghitav1.tflite")
    vocab_path = find_asset_path(args.vocab, "vocab.txt", "app/src/main/assets/vocab.txt")
    runner = Ghitav1DesktopRunner(model_path, vocab_path, max_seq_len=args.max_seq_len)

    text = read_input_text(args)
    if text is None:
        print("Interactive mode. Press Enter on an empty line to exit.")
        while True:
            try:
                text = input("Nhap transcript: ").strip()
            except EOFError:
                print()
                return 0

            if not text:
                return 0

            result = runner.predict(text, top_k=args.top_k)
            if args.json:
                print(json.dumps(result, ensure_ascii=False, indent=2))
            else:
                print_human_readable(result)
            print()

    result = runner.predict(text, top_k=args.top_k)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print_human_readable(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
