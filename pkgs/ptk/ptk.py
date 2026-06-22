#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

import ptk


CONTENT_TYPES = ("dict", "list", "code", "log", "diff", "text")


def add_input_options(parser):
    parser.add_argument("text", nargs="?", help="text; use - or omit it for stdin")
    parser.add_argument("--file", "-f", type=Path)
    parser.add_argument("--raw", action="store_true", help="do not parse JSON input")


def add_minimizer_options(parser):
    parser.add_argument("--type", choices=CONTENT_TYPES, help="force the content type")
    parser.add_argument(
        "--aggressive", "-a", action="store_true", help="maximize compression"
    )
    parser.add_argument(
        "--keep-nulls", action="store_true", help="preserve null and empty values"
    )
    parser.add_argument(
        "--format", choices=("json", "kv", "tabular"), help="dict output format"
    )
    parser.add_argument(
        "--mode", choices=("clean", "signatures"), help="code output mode"
    )
    parser.add_argument(
        "--errors-only", action="store_true", help="retain only errors in logs"
    )


def parse_args():
    parser = argparse.ArgumentParser(
        prog="ptk",
        description="Minimize LLM tokens in JSON, code, logs, diffs, and text.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {ptk.__version__}"
    )
    commands = parser.add_subparsers(dest="command", required=True)

    minimize = commands.add_parser("minimize", help="minimize text, a file, or stdin")
    add_input_options(minimize)
    add_minimizer_options(minimize)

    stats = commands.add_parser("stats", help="show minimized output and statistics")
    add_input_options(stats)
    add_minimizer_options(stats)

    detect = commands.add_parser("detect", help="detect the input content type")
    add_input_options(detect)

    commands.add_parser("types", help="list supported content types")

    if len(sys.argv) == 1:
        parser.print_help()
        raise SystemExit(0)
    return parser.parse_args()


def read_input(args):
    if args.file and args.text is not None:
        raise SystemExit("ptk: use either TEXT or --file, not both")
    if args.file:
        try:
            return args.file.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as error:
            raise SystemExit(f"ptk: {args.file}: {error}") from error
    return sys.stdin.read() if args.text in (None, "-") else args.text


def parse_input(args):
    source = read_input(args)
    if args.raw:
        return source
    try:
        return json.loads(source)
    except json.JSONDecodeError:
        return source


def minimizer_options(args):
    options = {
        "aggressive": args.aggressive,
        "strip_nulls": not args.keep_nulls,
        "content_type": args.type,
    }
    if args.format:
        options["format"] = args.format
    if args.mode:
        options["mode"] = args.mode
    if args.errors_only:
        options["errors_only"] = True
    return options


def main():
    args = parse_args()
    if args.command == "types":
        print("\n".join(CONTENT_TYPES))
        return

    value = parse_input(args)
    if args.command == "detect":
        print(ptk.detect_type(value))
    elif args.command == "stats":
        result = ptk.stats(value, **minimizer_options(args))
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(ptk.minimize(value, **minimizer_options(args)))


if __name__ == "__main__":
    main()
