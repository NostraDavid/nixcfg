#!/usr/bin/env python3
import argparse
import fnmatch
import json
import sys
from pathlib import Path

import tiktoken


def parse_args():
    parser = argparse.ArgumentParser(
        prog="tiktoken",
        description="Count, encode, and decode text with OpenAI tiktoken encodings.",
    )
    parser.add_argument("--version", action="version", version="%(prog)s 0.13.0")
    parser.add_argument("--model", "-m", help="select an OpenAI model")
    parser.add_argument("--encoding", default="o200k_base")
    parser.add_argument("--exclude", action="append", default=[], metavar="GLOB")

    commands = parser.add_subparsers(dest="command")
    count = commands.add_parser("count", help="count tokens (default command)")
    count.add_argument("paths", nargs="*")
    encode = commands.add_parser("encode", help="encode text as token IDs")
    encode.add_argument("text", nargs="?")
    decode = commands.add_parser("decode", help="decode token IDs")
    decode.add_argument("tokens", nargs="*", type=int)

    args = parser.parse_args()
    if args.command is None:
        args.command = "count"
        args.paths = []
    return args


def codec(args):
    if args.model:
        return tiktoken.encoding_for_model(args.model)
    return tiktoken.get_encoding(args.encoding)


def excluded(path, patterns):
    return any(fnmatch.fnmatch(str(path), pattern) or fnmatch.fnmatch(path.name, pattern) for pattern in patterns)


def count(args, encoding):
    if not args.paths:
        print(len(encoding.encode(sys.stdin.read())))
        return

    total = 0
    for value in args.paths:
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
            print(f"{amount:>8}  {file}")
    if len(args.paths) > 1 or any(Path(value).is_dir() for value in args.paths):
        print(f"{'--------'}\n{total:>8}  total")


def main():
    args = parse_args()
    encoding = codec(args)
    if args.command == "count":
        count(args, encoding)
    elif args.command == "encode":
        text = args.text if args.text is not None else sys.stdin.read()
        print(json.dumps(encoding.encode(text)))
    else:
        tokens = args.tokens or json.loads(sys.stdin.read())
        print(encoding.decode(tokens), end="")


if __name__ == "__main__":
    main()
