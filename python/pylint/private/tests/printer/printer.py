#!/usr/bin/env python3
"""An example source file to test pylint against."""

import argparse

from greeting import greeting  # type: ignore

from python.pylint.private.tests.fibonacci import fibonacci_of


def parse_args() -> argparse.Namespace:
    """Parse command line arguments

    Returns:
        A struct of parsed arguments.
    """
    parser = argparse.ArgumentParser("Fibonacci")

    parser.add_argument(
        "--fibonacci", type=int, help="The number of Fibonacci numbers to print."
    )
    parser.add_argument(
        "--greeting", type=str, help="The name of some character to greet."
    )

    args = parser.parse_args()
    if not args.fibonacci and not args.greeting:
        parser.error("Either `--fibonacci` or `--greeting` must be passed.")

    return parser.parse_args()


def main() -> None:
    """The main entrypoint."""
    args = parse_args()

    if args.fibonacci:
        print([fibonacci_of(n) for n in range(args.num)])

    if args.greeting:
        print(greeting(args.greeting))


if __name__ == "__main__":
    main()
