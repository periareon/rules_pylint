"""# rules_pylint

## Overview

Rules for the Python linter [pylint][pl]

### Setup

To setup the rules for `pylint`, define a [py_pylint_toolchain](#py_pylint_toolchain) within your
project and register it within your workspace. For example say you have the following `BUILD.bazel`
file in the root of your workspace:

```python
load("@rules_pylint//python/pylint:defs.bzl", "py_pylint_toolchain")

py_pylint_toolchain(
    name = "py_pylint_toolchain",
    pylint = "@pip_deps//:pylint",
)

toolchain(
    name = "toolchain",
    toolchain = ":py_pylint_toolchain",
    toolchain_type = "@rules_pylint//python/pylint:toolchain_type",
    visibility = ["//visibility:public"],
)
```

You would then add the following to your `WORKSPACE.bazel` file.

```python
register_toolchains("//tools/pylint:toolchain")
```

In addition to this formatter, a check can be added to your build phase using the [py_pylint_aspect](#py_pylint_aspect)
aspect. Simply add the following to a `.bazelrc` file to enable this check.

```text
build --aspects=@rules_pylint//python/pylint:defs.bzl%py_pylint_aspect
build --output_groups=+py_pylint_checks
```

These rules use a global flag to determine the location of the configuration file to use with pylint. To wire up a custom
config file, simply add the following to your `.bazelrc` file

```text
build --@rules_pylint//python/pylint:config=//:pylintrc
```

Note the flag above assumes you have a `pylintrc` in the root of your repository.

It's recommended to only enable this aspect in your CI environment so formatting issues do not
impact user's ability to rapidly iterate on changes.


[pl]: https://pylint.pycqa.org/en/latest/

## Rules

- [py_pylint_aspect](#py_pylint_aspect)
- [py_pylint_test](#py_pylint_test)
- [py_pylint_toolchain](#py_pylint_toolchain)

---

---
"""

load(
    "//python/pylint/private:pylint.bzl",
    _py_pylint_aspect = "py_pylint_aspect",
    _py_pylint_test = "py_pylint_test",
)
load(
    "//python/pylint/private:pylint_toolchain.bzl",
    _py_pylint_toolchain = "py_pylint_toolchain",
)

py_pylint_aspect = _py_pylint_aspect
py_pylint_test = _py_pylint_test
py_pylint_toolchain = _py_pylint_toolchain
