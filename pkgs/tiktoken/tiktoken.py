#!/usr/bin/env python3
import argparse
import fnmatch
import json
import os
import subprocess
import sys
from pathlib import Path

import tiktoken
from tiktoken.model import MODEL_PREFIX_TO_ENCODING, MODEL_TO_ENCODING


def add_tokenizer_options(parser):
    tokenizer = parser.add_mutually_exclusive_group()
    tokenizer.add_argument(
        "--model", "-m", default="gpt-5", help="select an OpenAI model"
    )
    tokenizer.add_argument("--encoding", help="select an encoding directly")


def parse_args():
    parser = argparse.ArgumentParser(
        prog="tiktoken",
        description="Count, encode, and decode text with OpenAI tiktoken encodings.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--version", action="version", version="%(prog)s 0.13.0")
    commands = parser.add_subparsers(dest="command", required=True)

    count = commands.add_parser(
        "count", help="count tokens in files, directories, or stdin"
    )
    add_tokenizer_options(count)
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
    add_tokenizer_options(encode)
    encode.add_argument("text", nargs="?", help="text; use - or omit it for stdin")
    encode.add_argument("--file", "-f", type=Path)
    encode.add_argument("--json", action="store_true", help="output a JSON array")

    decode = commands.add_parser("decode", help="decode token IDs")
    add_tokenizer_options(decode)
    decode.add_argument("tokens", nargs="*", type=int)
    decode.add_argument("--file", "-f", type=Path)
    commands.add_parser("models", help="list supported models and encodings")

    if len(sys.argv) == 1:
        parser.print_help()
        raise SystemExit(0)
    return parser.parse_args()


def codec(args):
    if args.encoding:
        return tiktoken.get_encoding(args.encoding)
    return tiktoken.encoding_for_model(args.model)


def excluded(path, patterns):
    return any(
        fnmatch.fnmatch(str(path), pattern)
        or fnmatch.fnmatch(path.name, pattern)
        or any(fnmatch.fnmatch(part, pattern) for part in path.parts)
        for pattern in patterns
    )


def warn(message):
    print(f"tiktoken: {message}", file=sys.stderr)


def git_ignored(path):
    git = os.environ.get("TIKTOKEN_GIT", "git")
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


def count(args, encoding):
    paths = args.paths + args.files
    if not paths:
        paths = ["-"]

    total = 0
    failed = False
    results = []
    for value in paths:
        if value == "-":
            amount = len(encoding.encode(sys.stdin.read()))
            total += amount
            results.append((amount, "-"))
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
            amount = len(encoding.encode(text))
            total += amount
            results.append((amount, str(file)))

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


def list_models():
    for model, encoding in sorted(MODEL_TO_ENCODING.items()):
        print(f"{model:<40} {encoding}")
    for prefix, encoding in sorted(MODEL_PREFIX_TO_ENCODING.items()):
        print(f"{prefix + '*':<40} {encoding}")


def read_file(path):
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise SystemExit(f"tiktoken: {path}: {error}") from error


def parse_tokens(source):
    try:
        value = json.loads(source)
        return value if isinstance(value, list) else [int(value)]
    except json.JSONDecodeError:
        return [int(token) for token in source.replace(",", " ").split()]


def main():
    args = parse_args()
    if args.command == "models":
        list_models()
        return

    encoding = codec(args)
    if args.command == "count":
        if not count(args, encoding):
            raise SystemExit(1)
    elif args.command == "encode":
        if args.file and args.text is not None:
            raise SystemExit("tiktoken: use either TEXT or --file, not both")
        text = read_file(args.file) if args.file else args.text
        text = sys.stdin.read() if text in (None, "-") else text
        tokens = encoding.encode(text)
        print(json.dumps(tokens) if args.json else "\n".join(map(str, tokens)))
    else:
        if args.file and args.tokens:
            raise SystemExit("tiktoken: use either TOKENS or --file, not both")
        source = read_file(args.file) if args.file else sys.stdin.read()
        tokens = args.tokens or parse_tokens(source)
        print(encoding.decode(tokens), end="")


if __name__ == "__main__":
    main()
