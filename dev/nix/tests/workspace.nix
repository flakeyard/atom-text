# The atom in a project with atom-workspace: the hooks are enabled with the
# packages of the project's nixpkgs, the files that tools write are excluded,
# checks.pre-commit is off, and devShells.default holds typos and
# editorconfig-checker.
{ facts, fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      flake = fixture { name = "good"; };
      inherit (flake.allSystems.${system}.pre-commit.settings) hooks excludes;
      checks = flake.checks.${system};
      shell = flake.devShells.${system}.default;
      # The shell holds the output out of a package, not its first output.
      holds = package: lib.elem package.out shell.nativeBuildInputs;
    in
    {
      checks.test-workspace = facts pkgs "test-workspace" {
        "the hook typos is enabled" = hooks.typos.enable;
        "the hook editorconfig-checker is enabled" = hooks.editorconfig-checker.enable;
        "typos is the project's" = hooks.typos.package == pkgs.typos;
        "editorconfig-checker is the project's" =
          hooks.editorconfig-checker.package == pkgs.editorconfig-checker;
        "CHANGELOG.md is excluded" = lib.elem ''^CHANGELOG\.md$'' excludes;
        "checks.pre-commit is off" = !(checks ? pre-commit);
        "the shell holds typos" = holds pkgs.typos;
        "the shell holds editorconfig-checker" = holds pkgs.editorconfig-checker;
      };
    };
}
