# -*- python -*-

load(
    "@drake//tools/skylark:drake_cc.bzl",
    "drake_cc_library",
)
load("//tools/workspace:generate_file.bzl", "generate_file")

def _combine_relative_labels(arg_list, arg_map):
    # Merge the relative_labels= and relative_labels_map= arguments as seen in
    # the public macros below.  The result is a map where the arg_list items
    # are twinned into matching key:key pairs, union'd with the arg_map.  (Also
    # double-checks that the keys and values are all relative labels.)
    result = dict([(x, x) for x in arg_list]) + arg_map
    for x in result.keys() + result.values():
        if not x.startswith(":"):
            fail("Expected relative_label, got " + x)
    return result

def drake_cc_hdrs_forwarding_library(
        name,
        relative_labels = [],
        relative_labels_map = {},
        actual_subdir = "",
        loud = False,
        tags = [],
        **kwargs):
    """Generates a drake_cc_library filled with generated header files that
    merely include other header files, optionally with a deprecation warning.
    This automates the chore of adding compatibility headers when packages
    move.

    The relative_labels + relative_labels_map.keys() specify the header
    filenames to generate.  For each label name ':foo', this macro generates a
    header named 'foo.h' that includes 'drake/{actual_subdir}/{new_foo}.h'
    where new_foo for relative_labels is the same as foo, and new_foo for
    relative_labels_map is the value for the foo key (without the leading
    colon).

    When loud is true, the generated header will have a #warning directive
    explaining the new location.
    """

    actual_subdir or fail("Missing required actual_subdir")

    # Generate one header file for each mapped label.
    hdrs = []
    mapping = _combine_relative_labels(relative_labels, relative_labels_map)
    for stub_relative_label, actual_relative_label in mapping.items():
        actual_include = "drake/{}/{}.h".format(
            actual_subdir,
            actual_relative_label[1:],
        )
        warning = "#warning This header is deprecated; use {} instead".format(
            actual_include,
        ) if loud else ""
        basename = stub_relative_label[1:] + ".h"
        generate_file(
            name = basename,
            content = "\n".join([
                "#pragma once",
                "{warning}",
                "#include \"{actual_include}\"",
            ]).format(
                warning = warning,
                actual_include = actual_include,
            ),
        )
        hdrs.append(basename)

    # Place all of the header files into a library.
    drake_cc_library(
        name = name,
        hdrs = hdrs,
        tags = tags + ["nolint"],
        **kwargs
    )

def drake_cc_library_aliases(
        relative_labels = [],
        relative_labels_map = {},
        actual_subdir = "",
        loud = False,
        tags = [],
        deps = [],
        **kwargs):
    """Generates aliases for drake_cc_library labels that have moved into a new
    package.  This is superior to native.alias() both for its brevity (it can
    generate many aliases at once), and because the deprecation message
    actually works (see https://github.com/bazelbuild/bazel/issues/5802).

    The relative_labels + relative_labels_map specify the correspondence.  For
    each label name foo in the relative_labels and relative_labels_map.keys(),
    this macro generates an alias to '//{actual_subdir}:{new_foo}' where
    new_foo for relative_labels is the same as foo, and new_foo for
    relative_labels_map is the value for the foo key.

    When loud is true, the generated label in this package will have a
    deprecation warning explaining the new location.  When using this mode, the
    caller should probably set 'tags = ["manual"]' to avoid spurious warnings
    during 'bazel build //...'.
    """

    actual_subdir or fail("Missing required actual_subdir")

    mapping = _combine_relative_labels(relative_labels, relative_labels_map)
    for stub_relative_label, actual_relative_label in mapping.items():
        actual_full_label = "//" + actual_subdir + actual_relative_label
        deprecation = ("Use the label " + actual_full_label) if loud else None
        native.cc_library(
            name = stub_relative_label[1:],
            deps = deps + [actual_full_label],
            tags = tags + ["nolint"],
            deprecation = deprecation,
            **kwargs
        )
        native.alias(
            name = stub_relative_label[1:] + ".installed_headers",
            actual = actual_full_label + ".installed_headers",
        )