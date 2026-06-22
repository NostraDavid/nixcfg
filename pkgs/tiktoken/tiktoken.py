#!/usr/bin/env python3
import argparse
import fnmatch
import json
import sys
from pathlib import Path

import tiktoken
from tiktoken.model import MODEL_PREFIX_TO_ENCODING, MODEL_TO_ENCODING


def parse_args():
    parser = argparse.ArgumentParser(
        prog="tiktoken",
        description="Count, encode, and decode text with OpenAI tiktoken encodings.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--version", action="version", version="%(prog)s 0.13.0")
    tokenizer = parser.add_mutually_exclusive_group()
    tokenizer.add_argument("--model", "-m", default="gpt-5", help="select an OpenAI model")
    tokenizer.add_argument("--encoding", default=argparse.SUPPRESS, help="select an encoding directly")
    parser.add_argument("--exclude", action="append", default=[], metavar="GLOB")

    commands = parser.add_subparsers(dest="command", required=True)
    count = commands.add_parser("count", help="count tokens (default command)")
    count.add_argument("paths", nargs="*", help="files or directories to count; reads stdin when omitted")
    count.add_argument("--file", "-f", action="append", default=[], dest="files")
    count.add_argument("--list", action="store_true", help="list token counts per file and the total")
    encode = commands.add_parser("encode", help="encode text as token IDs")
    encode.add_argument("text", nargs="?")
    encode.add_argument("--file", "-f", type=Path)
    decode = commands.add_parser("decode", help="decode token IDs")
    decode.add_argument("tokens", nargs="*", type=int)
    decode.add_argument("--file", "-f", type=Path)
    commands.add_parser("models", help="list supported models and encodings")

    if len(sys.argv) == 1:
        parser.print_help()
        raise SystemExit(0)

    args = parser.parse_args()
    return args


def codec(args):
    if encoding_name := getattr(args, "encoding", None):
        return tiktoken.get_encoding(encoding_name)
    return tiktoken.encoding_for_model(args.model)


def excluded(path, patterns):
    return any(fnmatch.fnmatch(str(path), pattern) or fnmatch.fnmatch(path.name, pattern) for pattern in patterns)


def count(args, encoding):
    paths = args.paths + args.files
    if not paths:
        print(len(encoding.encode(sys.stdin.read())))
        return

    total = 0
    for value in paths:
        path = Path(value)
        files = path.rglob("*") if path.is_dir() else [path]
        for file in files:
            if not file.is_file() or excluded(file, args.exclude):
                continue
            try:
                amount = len(encoding.encode(file.read_text(encoding="utf-8")))
            except (OSError, UnicodeDecodeError):
                continue
            total += amount
            if args.list:
                print(f"{amount:>8}  {file}")
    if args.list:
        print(f"{'--------'}\n{total:>8}  total")
    else:
        print(total)


def list_models():
    for model, encoding in sorted(MODEL_TO_ENCODING.items()):
        print(f"{model:<40} {encoding}")
    for prefix, encoding in sorted(MODEL_PREFIX_TO_ENCODING.items()):
        print(f"{prefix + '*':<40} {encoding}")


def main():
    args = parse_args()
    if args.command == "models":
        list_models()
        return
    encoding = codec(args)
    if args.command == "count":
        count(args, encoding)
    elif args.command == "encode":
        if args.file and args.text is not None:
            raise SystemExit("use either TEXT or --file, not both")
        text = args.file.read_text(encoding="utf-8") if args.file else args.text
        text = text if text is not None else sys.stdin.read()
        print(json.dumps(encoding.encode(text)))
    else:
        if args.file and args.tokens:
            raise SystemExit("use either TOKENS or --file, not both")
        source = args.file.read_text(encoding="utf-8") if args.file else sys.stdin.read()
        tokens = args.tokens or json.loads(source)
        print(encoding.decode(tokens), end="")


if __name__ == "__main__":
    main()
