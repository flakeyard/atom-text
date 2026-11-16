# The configuration file that each tool gets (FY-0037): the project's file at
# a standard path at its root, else the default of the atom, either one as a
# store path of its own; and the errors for project files the atom does not
# take. project is the project's source, which for a git flake holds only
# tracked files.
{
  lib,
  root,
  project,
}:
let
  exists = name: builtins.pathExists (project + "/${name}");
  # Store path names cannot start with a dot.
  stored =
    path: name:
    builtins.path {
      inherit path;
      name = lib.removePrefix "." name;
    };
  # The names of the standard paths of a tool that the project has.
  found = lib.filter exists;
  chosen =
    default: names:
    let
      project' = found names;
    in
    if project' == [ ] then
      stored (root + "/config/${default}") default
    else
      stored (project + "/${lib.head project'}") (lib.head project');
  # typos reads these names in this order, and the first it finds.
  typos = [
    "typos.toml"
    "_typos.toml"
    ".typos.toml"
  ];
  # Tables of files of other tools in which typos also finds its
  # configuration. builtins.fromTOML reads TOML without dates and times; a
  # file with them fails evaluation until Nix reads them by default.
  embedded = [
    {
      file = "pyproject.toml";
      table = [
        "tool"
        "typos"
      ];
    }
    {
      file = "Cargo.toml";
      table = [
        "package"
        "metadata"
        "typos"
      ];
    }
    {
      file = "Cargo.toml";
      table = [
        "workspace"
        "metadata"
        "typos"
      ];
    }
  ];
  configures =
    { file, table }:
    exists file
    && lib.hasAttrByPath table (builtins.fromTOML (builtins.readFile (project + "/${file}")));
in
{
  typos = chosen "typos.toml" typos;
  editorconfig-checker = chosen "editorconfig-checker.json" [ ".editorconfig-checker.json" ];
  errors =
    lib.optional (lib.length (found typos) > 1) (
      "atom-text: ${lib.concatStringsSep ", " (found typos)} configure typos at the root;"
      + " typos reads only one of them, keep one."
    )
    ++ map (
      { file, table }:
      "atom-text: ${file} configures typos in [${lib.concatStringsSep "." table}], which the atom"
      + " does not pass to typos; move its content to typos.toml at the root."
    ) (lib.filter configures embedded)
    ++ lib.optional (exists ".ecrc") (
      "atom-text: .ecrc is the old name of the configuration of editorconfig-checker, which"
      + " the atom does not pass to it; rename it to .editorconfig-checker.json."
    );
}
