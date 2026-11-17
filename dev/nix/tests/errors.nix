# Project files the atom does not take fail evaluation with a message that
# names them (FY-0037): more than one configuration file of typos at the
# root, a configuration of typos in pyproject.toml or Cargo.toml, and .ecrc.
# Other tables of pyproject.toml and Cargo.toml are fine.
{
  facts,
  fixture,
  lib-atom,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      # The errors that the atom's own module makes for a fixture project:
      # the atom gets a lib-atom whose config gives the errors as the file,
      # since builtins.tryEval loses the text of a throw.
      spied.lib = lib-atom // {
        config =
          arguments: tool:
          let
            chosen = lib-atom.config arguments tool;
          in
          chosen // { file = lib.concatStringsSep "\n" chosen.errors; };
      };
      errors =
        name:
        let
          inherit
            ((fixture {
              inherit name;
              atomInputs.lib-atom = spied;
            }).allSystems.${system}.pre-commit.settings.hooks
            )
            typos
            editorconfig-checker
            ;
          # The file in the entry of typos, between --config and --isolated.
          typosFile = lib.head (
            lib.splitString " --isolated" (lib.elemAt (lib.splitString " --config " typos.entry) 1)
          );
          lines = text: lib.optionals (text != "") (lib.splitString "\n" text);
        in
        lines typosFile ++ lines (lib.elemAt editorconfig-checker.args 1);
      evaluates =
        name: (builtins.tryEval (fixture { inherit name; }).checks.${system}.text.drvPath).success;
    in
    {
      checks.test-errors = facts pkgs "test-errors" {
        # Restated: the text is the interface (FY-0035).
        "two configurations of typos fail with their names" =
          errors "typos-configs" == [
            "atom-text: the project has more than one configuration of typos: typos.toml, .typos.toml; keep one."
          ];
        "pyproject.toml fails with its table" =
          errors "pyproject" == [
            "atom-text: the atom cannot pass these configurations of typos to it: pyproject.toml [tool.typos]; write the configuration in one of typos.toml, _typos.toml, .typos.toml instead."
          ];
        "Cargo.toml fails with the table of the package" =
          errors "cargo" == [
            "atom-text: the atom cannot pass these configurations of typos to it: Cargo.toml [package.metadata.typos]; write the configuration in one of typos.toml, _typos.toml, .typos.toml instead."
          ];
        "Cargo.toml fails with the table of the workspace" =
          errors "cargo-workspace" == [
            "atom-text: the atom cannot pass these configurations of typos to it: Cargo.toml [workspace.metadata.typos]; write the configuration in one of typos.toml, _typos.toml, .typos.toml instead."
          ];
        ".ecrc fails" =
          errors "ecrc" == [
            "atom-text: the atom cannot pass these configurations of editorconfig-checker to it: .ecrc; write the configuration in .editorconfig-checker.json instead."
          ];
        "other tables are fine" = errors "other-tables" == [ ];
        "a project without such files evaluates" = evaluates "good";
        "two configurations of typos fail evaluation" = !evaluates "typos-configs";
        "pyproject.toml fails evaluation" = !evaluates "pyproject";
        "Cargo.toml fails evaluation" = !evaluates "cargo";
        ".ecrc fails evaluation" = !evaluates "ecrc";
        "other tables evaluate" = evaluates "other-tables";
      };
    };
}
