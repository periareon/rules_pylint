"""Bazel rules for Pylint"""

load("@rules_venv//python:defs.bzl", "PyInfo")
load("@rules_venv//python/venv:defs.bzl", "py_venv_common")

PySourcesInfo = provider(
    doc = "A provider containing information needed for running a venv tool.",
    fields = {
        "srcs": "depset[File]: All direct source files.",
    },
)

def _find_srcs(target, aspect_ctx = None):
    """Parse a target for it's sources to run on.

    Args:
        target (Target): The target the aspect is running on.
        aspect_ctx (ctx, optional): The aspect's context object.

    Returns:
        depset: A depset of sources (`File`).
    """
    if PyInfo not in target:
        return depset()

    # Ignore external targets
    if target.label.workspace_root.startswith("external"):
        return depset()

    # Sources are located differently based on whether or not
    # there's an aspect context object.
    if aspect_ctx:
        # Get a list of all non-generated source files.
        srcs = depset([
            src
            for src in getattr(aspect_ctx.rule.files, "srcs", [])
            if src.is_source
        ])

    elif PySourcesInfo not in target:
        srcs = depset()
    else:
        srcs = target[PySourcesInfo].srcs

    return srcs

def _target_sources_impl(target, ctx):
    srcs = _find_srcs(target, aspect_ctx = ctx)

    return [PySourcesInfo(
        srcs = srcs,
    )]

target_sources_aspect = aspect(
    implementation = _target_sources_impl,
    doc = "An aspect for gathering additional data on a lintable target.",
    provides = [PySourcesInfo],
)

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)

def _py_pylint_test_impl(ctx):
    venv_toolchain = ctx.toolchains[py_venv_common.TOOLCHAIN_TYPE]

    dep_info = py_venv_common.create_dep_info(
        ctx = ctx,
        deps = [ctx.attr._runner, ctx.attr.target],
    )

    py_info = py_venv_common.create_py_info(
        ctx = ctx,
        imports = [],
        srcs = [ctx.file._runner_main],
        dep_info = dep_info,
    )

    executable, runfiles = py_venv_common.create_venv_entrypoint(
        ctx = ctx,
        venv_toolchain = venv_toolchain,
        py_info = py_info,
        main = ctx.file._runner_main,
        runfiles = dep_info.runfiles,
    )

    srcs = _find_srcs(ctx.attr.target)

    args_file = ctx.actions.declare_file("{}.pylint_args.txt".format(ctx.label.name))
    ctx.actions.write(
        output = args_file,
        content = "\n".join([
            "--rcfile",
            _rlocationpath(ctx.file.config, ctx.workspace_name),
        ] + [
            "--src={}".format(_rlocationpath(src, ctx.workspace_name))
            for src in srcs.to_list()
        ]),
    )

    return [
        DefaultInfo(
            files = depset([executable]),
            runfiles = runfiles.merge(
                ctx.runfiles(files = [ctx.file.config, args_file]),
            ),
            executable = executable,
        ),
        RunEnvironmentInfo(
            environment = {
                "PY_PYLINT_RUNNER_ARGS_FILE": _rlocationpath(args_file, ctx.workspace_name),
            },
        ),
    ]

py_pylint_test = rule(
    implementation = _py_pylint_test_impl,
    doc = "A rule for running pylint on a Python target.",
    attrs = {
        "config": attr.label(
            doc = "The config file (pylintrc) containing pylint settings.",
            cfg = "target",
            allow_single_file = True,
            default = Label("//python/pylint:config"),
        ),
        "target": attr.label(
            doc = "The target to run `pylint` on.",
            providers = [PyInfo],
            mandatory = True,
            aspects = [target_sources_aspect],
        ),
        "_runner": attr.label(
            doc = "The process wrapper for running pylint.",
            cfg = "exec",
            default = Label("//python/pylint/private:pylint_runner"),
        ),
        "_runner_main": attr.label(
            doc = "The main entrypoint for the pylint runner.",
            cfg = "exec",
            allow_single_file = True,
            default = Label("//python/pylint/private:pylint_runner.py"),
        ),
    },
    toolchains = [py_venv_common.TOOLCHAIN_TYPE],
    test = True,
)

def _py_pylint_aspect_impl(target, ctx):
    ignore_tags = [
        "no_pylint",
        "no_lint",
        "nolint",
        "nopylint",
    ]
    for tag in ctx.rule.attr.tags:
        sanitized = tag.replace("-", "_").lower()
        if sanitized in ignore_tags:
            return []

    srcs = _find_srcs(target, ctx)
    if not srcs:
        return []

    venv_toolchain = py_venv_common.get_toolchain(ctx, cfg = "exec")

    dep_info = py_venv_common.create_dep_info(
        ctx = ctx,
        deps = [ctx.attr._runner, target],
    )

    py_info = py_venv_common.create_py_info(
        ctx = ctx,
        imports = [],
        srcs = [ctx.file._runner_main],
        dep_info = dep_info,
    )

    marker = ctx.actions.declare_file("{}.pylint.ok".format(target.label.name))
    aspect_name = "{}.pylint".format(target.label.name)

    executable, runfiles = py_venv_common.create_venv_entrypoint(
        ctx = ctx,
        venv_toolchain = venv_toolchain,
        py_info = py_info,
        main = ctx.file._runner_main,
        name = aspect_name,
        runfiles = dep_info.runfiles,
        use_runfiles_in_entrypoint = False,
        force_runfiles = True,
    )

    args = ctx.actions.args()
    args.add("--rcfile", ctx.file._config)
    args.add("--marker", marker)
    args.add_all(srcs, format_each = "--src=%s")

    ctx.actions.run(
        mnemonic = "Pylint",
        progress_message = "Pylint %{label}",
        executable = executable,
        inputs = depset([ctx.file._config], transitive = [srcs]),
        tools = runfiles.files,
        outputs = [marker],
        arguments = [args],
        env = ctx.configuration.default_shell_env,
    )

    return [OutputGroupInfo(
        py_pylint_checks = depset([marker]),
    )]

py_pylint_aspect = aspect(
    implementation = _py_pylint_aspect_impl,
    doc = "An aspect for running pylint on targets with Python sources.",
    attrs = {
        "_config": attr.label(
            doc = "The config file (pylintrc) containing pylint settings.",
            cfg = "target",
            allow_single_file = True,
            default = Label("//python/pylint:config"),
        ),
        "_runner": attr.label(
            doc = "The process wrapper for running pylint.",
            cfg = "exec",
            default = Label("//python/pylint/private:pylint_runner"),
        ),
        "_runner_main": attr.label(
            doc = "The main entrypoint for the pylint runner.",
            cfg = "exec",
            allow_single_file = True,
            default = Label("//python/pylint/private:pylint_runner.py"),
        ),
    } | py_venv_common.create_venv_attrs(),
    required_providers = [PyInfo],
    requires = [target_sources_aspect],
)
