# The configuration file that each tool gets (FY-0037), chosen by config of
# lib-atom (FY-0040): the project's file at a standard path at its root, else
# the default of the atom, either one as a store path of its own. Project
# files that configure a tool in a form the atom does not pass to it fail
# evaluation with a message that names them. project is the project's
# source, which for a git flake holds only tracked files.
{
  lib,
  root,
  shared,
  project,
}:
let
  chosen = shared.config {
    inherit lib project;
    atom = "atom-text";
  };
  # A table of a TOML file of another tool in which typos also finds its
  # configuration. builtins.fromTOML reads TOML without dates and times; a
  # file with them fails evaluation until Nix reads them by default.
  table = file: path: {
    name = file;
    label = "${file} [${lib.concatStringsSep "." path}]";
    when = source: lib.hasAttrByPath path (builtins.fromTOML (builtins.readFile source));
  };
in
{
  typos = chosen {
    tool = "typos";
    default = root + "/config/typos.toml";
    # typos reads these names in this order, and the first it finds.
    names = [
      "typos.toml"
      "_typos.toml"
      ".typos.toml"
    ];
    unsupported = [
      (table "pyproject.toml" [
        "tool"
        "typos"
      ])
      (table "Cargo.toml" [
        "package"
        "metadata"
        "typos"
      ])
      (table "Cargo.toml" [
        "workspace"
        "metadata"
        "typos"
      ])
    ];
  };
  editorconfig-checker = chosen {
    tool = "editorconfig-checker";
    default = root + "/config/editorconfig-checker.json";
    names = [ ".editorconfig-checker.json" ];
    # The old name of the file of editorconfig-checker, which the atom does
    # not pass to it.
    unsupported = [ ".ecrc" ];
  };
}
