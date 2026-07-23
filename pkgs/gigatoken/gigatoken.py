#!/usr/bin/env python3
import argparse
import fnmatch
import json
import os
import subprocess
import sys
from pathlib import Path

import awkward as ak
from gigatoken import Tokenizer


DEFAULT_TOKENIZER = "openai-community/gpt2"


def add_tokenizer_option(parser):
    parser.add_argument(
        "--tokenizer",
        "-t",
        "--model",
        "-m",
        default=DEFAULT_TOKENIZER,
        help="tokenizer path, directory, or Hugging Face repository",
    )


def parse_args():
    parser = argparse.ArgumentParser(
        prog="gigatoken",
        description="Count, encode, and decode text with Gigatoken.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--version", action="version", version="%(prog)s 0.9.0")
    commands = parser.add_subparsers(dest="command", required=True)

    count = commands.add_parser(
        "count", help="count tokens in files, directories, or stdin"
    )
    add_tokenizer_option(count)
    count.add_argument("paths", nargs="*", help="files or directories; use - for stdin")
    count.add_argument("--file", "-f", action="append", default=[], dest="files")
    count.add_argument("--exclude", action="append", default=[], metavar="GLOB")
    count.add_argument(
        "--no-gitignore", action="store_true", help="include files ignored by Git"
    )
    count.add_argument(
        "--verbose",
        "-v",
        "--list",
        action="store_true",
        help="list each file and the total",
    )
    sorting = count.add_mutually_exclusive_group()
    sorting.add_argument(
        "--sort",
        choices=("path", "size"),
        default="path",
        help="sort verbose output by path or token count",
    )
    sorting.add_argument(
        "-s",
        "--sort-size",
        action="store_const",
        const="size",
        dest="sort",
        help="sort verbose output by token count",
    )
    count.add_argument(
        "-r", "--reverse", action="store_true", help="reverse the output sort order"
    )

    encode = commands.add_parser("encode", help="encode text as token IDs")
    add_tokenizer_option(encode)
    encode.add_argument("text", nargs="?", help="text; use - or omit it for stdin")
    encode.add_argument("--file", "-f", type=Path)
    encode.add_argument("--json", action="store_true", help="output a JSON array")

    decode = commands.add_parser("decode", help="decode token IDs")
    add_tokenizer_option(decode)
    decode.add_argument("tokens", nargs="*", type=int)
    decode.add_argument("--file", "-f", type=Path)

    commands.add_parser("bench", help="run the upstream Gigatoken benchmark")

    if len(sys.argv) == 1:
        parser.print_help()
        raise SystemExit(0)
    return parser.parse_args()


def load_tokenizer(spec):
    if spec.endswith(".tiktoken"):
        return Tokenizer.from_tiktoken(spec)
    if spec.endswith(".model"):
        return Tokenizer.from_sentencepiece(spec)
    return Tokenizer(spec)


def excluded(path, patterns):
    return any(
        fnmatch.fnmatch(str(path), pattern)
        or fnmatch.fnmatch(path.name, pattern)
        or any(fnmatch.fnmatch(part, pattern) for part in path.parts)
        for pattern in patterns
    )


def warn(message):
    print(f"gigatoken: {message}", file=sys.stderr)


def git_ignored(path):
    git = os.environ.get("GIGATOKEN_GIT", "@git@")
    result = subprocess.run(
        [git, "-C", path.parent, "check-ignore", "--quiet", "--", path.resolve()],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def read_text_file(path):
    data = path.read_bytes()
    if b"\0" in data:
        return None
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return None
    controls = sum(byte < 32 and byte not in (9, 10, 12, 13) for byte in data)
    if data and controls / len(data) > 0.01:
        return None
    return text


def read_file(path):
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise SystemExit(f"gigatoken: {path}: {error}") from error


def parse_tokens(source):
    try:
        value = json.loads(source)
        return value if isinstance(value, list) else [int(value)]
    except json.JSONDecodeError:
        return [int(token) for token in source.replace(",", " ").split()]


def count_tokens(args, tokenizer):
    paths = args.paths + args.files
    if not paths:
        paths = ["-"]

    failed = False
    texts = []
    names = []
    for value in paths:
        if value == "-":
            texts.append(sys.stdin.read())
            names.append("-")
            continue

        path = Path(value)
        if not path.exists():
            warn(f"{path}: no such file or directory")
            failed = True
            continue
        files = sorted(path.rglob("*")) if path.is_dir() else [path]
        for file in files:
            if (
                not file.is_file()
                or excluded(file, [".git", *args.exclude])
                or (not args.no_gitignore and git_ignored(file))
            ):
                continue
            try:
                text = read_text_file(file)
            except OSError as error:
                warn(f"{file}: {error}")
                failed = True
                continue
            if text is None:
                continue
            texts.append(text)
            names.append(str(file))

    amounts = ak.to_list(ak.num(tokenizer.encode_batch(texts), axis=1)) if texts else []
    results = list(zip(amounts, names))
    total = sum(amounts)

    if args.verbose:
        if args.sort == "size":
            results.sort(key=lambda result: result[1])
            results.sort(key=lambda result: result[0], reverse=args.reverse)
        else:
            results.sort(key=lambda result: result[1], reverse=args.reverse)
        for amount, name in results:
            print(f"{amount:>8}  {name}")
        print(f"{'--------'}\n{total:>8}  total")
    else:
        print(total)
    return not failed


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "bench":
        from gigatoken._cli import app

        app()
        return

    args = parse_args()
    tokenizer = load_tokenizer(args.tokenizer)
    if args.command == "count":
        if not count_tokens(args, tokenizer):
            raise SystemExit(1)
    elif args.command == "encode":
        if args.file and args.text is not None:
            raise SystemExit("gigatoken: use either TEXT or --file, not both")
        text = read_file(args.file) if args.file else args.text
        text = sys.stdin.read() if text in (None, "-") else text
        tokens = tokenizer.encode(text).tolist()
        print(json.dumps(tokens) if args.json else "\n".join(map(str, tokens)))
    else:
        if args.file and args.tokens:
            raise SystemExit("gigatoken: use either TOKENS or --file, not both")
        if args.tokens:
            tokens = args.tokens
        else:
            source = read_file(args.file) if args.file else sys.stdin.read()
            tokens = parse_tokens(source)
        sys.stdout.buffer.write(bytes(tokenizer.decode(tokens)))


if __name__ == "__main__":
    main()
