"""A module for calculating fibonacci sequences"""


def fibonacci_of(number: int) -> int:
    """Return the fibonacci sequence for a given number of steps in.

    Args:
        number: The steps of a fibonacci sequence.

    Returns:
        The fibonacci value `number` steps in.
    """

    if number in {0, 1}:
        return number
    return fibonacci_of(number - 1) + fibonacci_of(number - 2)
