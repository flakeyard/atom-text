# The atom in a project with atom-workspace: the hooks are enabled with the
# packages of the project's nixpkgs, the files that tools write are excluded,
# checks.pre-commit is off, and devShells.default holds typos and
# editorconfig-checker.
{ testing, ... }:
{
  perSystem = testing.workspace (
    {
      pkgs,
      flake,
      system,
    }:
    let
      inherit (flake.allSystems.${system}.pre-commit.settings) hooks excludes;
    in
    {
      packages = {
        inherit (pkgs) typos editorconfig-checker;
      };
      facts = {
        "the hook typos is enabled" = hooks.typos.enable;
        "the hook editorconfig-checker is enabled" = hooks.editorconfig-checker.enable;
        "typos is the project's" = hooks.typos.package == pkgs.typos;
        "editorconfig-checker is the project's" =
          hooks.editorconfig-checker.package == pkgs.editorconfig-checker;
        "CHANGELOG.md is excluded" = pkgs.lib.elem ''^CHANGELOG\.md$'' excludes;
      };
    }
  );
}
