#!/usr/bin/env python3
"""
Run the ghitav2 MobileBERT TFLite classifier on a desktop machine.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
GHITAV1_DIR = ROOT_DIR / "model_ghitav1"
if str(GHITAV1_DIR) not in sys.path:
    sys.path.insert(0, str(GHITAV1_DIR))

from run_ghitav1_on_pc import (
    DEFAULT_MAX_SEQ_LEN,
    Ghitav1DesktopRunner,
    find_asset_path,
    print_human_readable,
    read_input_text,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run ghitav2.tflite directly on a desktop machine."
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

    script_dir = Path(__file__).resolve().parent
    model_path = find_asset_path(
        args.model,
        str(script_dir / "ghitav2.tflite"),
        "ghitav2.tflite",
        "app/src/main/assets/ghitav2.tflite",
    )
    vocab_path = find_asset_path(
        args.vocab,
        str(script_dir / "vocab.txt"),
        "vocab.txt",
        "app/src/main/assets/vocab.txt",
    )
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
