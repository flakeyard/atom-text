# Project files the atom does not take fail evaluation with a message that
# names them (FY-0037): more than one configuration file of typos at the
# root, a configuration of typos in pyproject.toml or Cargo.toml, and .ecrc.
# Other tables of pyproject.toml and Cargo.toml are fine.
{
  facts,
  fixture,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      errors =
        name:
        (import (root + "/nix/configs.nix") {
          inherit lib root;
          project = root + "/dev/fixtures/${name}";
        }).errors;
      evaluates =
        name: (builtins.tryEval (fixture { inherit name; }).checks.${system}.text.drvPath).success;
    in
    {
      checks.test-errors = facts pkgs "test-errors" {
        # Restated: the text is the interface (FY-0035).
        "two configurations of typos fail with their names" =
          errors "typos-configs" == [
            "atom-text: typos.toml, .typos.toml configure typos at the root; typos reads only one of them, keep one."
          ];
        "pyproject.toml fails with its table" =
          errors "pyproject" == [
            "atom-text: pyproject.toml configures typos in [tool.typos], which the atom does not pass to typos; move its content to typos.toml at the root."
          ];
        "Cargo.toml fails with the table of the package" =
          errors "cargo" == [
            "atom-text: Cargo.toml configures typos in [package.metadata.typos], which the atom does not pass to typos; move its content to typos.toml at the root."
          ];
        "Cargo.toml fails with the table of the workspace" =
          errors "cargo-workspace" == [
            "atom-text: Cargo.toml configures typos in [workspace.metadata.typos], which the atom does not pass to typos; move its content to typos.toml at the root."
          ];
        ".ecrc fails" =
          errors "ecrc" == [
            "atom-text: .ecrc is the old name of the configuration of editorconfig-checker, which the atom does not pass to it; rename it to .editorconfig-checker.json."
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
