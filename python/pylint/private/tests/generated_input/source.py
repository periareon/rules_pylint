"""Represent interactions with generated."""

from python.pylint.private.tests.generated_input.generated import (  # type: ignore
    greeting,
)


def say_hello(name: str) -> None:
    """Say hello to someone

    Args:
        name: The name of the person to greet.
    """

    greeting(name)
