# checks.text: the hooks typos and editorconfig-checker, as the project's
# configuration holds them (FY-0017). Built with lib.<system>.run of
# git-hooks.nix from only these hooks and the project's global excludes, so
# pre-commit selects the files by `files`, `types` and `excludes` as the
# installed hook does. Its source is the whole project: the hooks check every
# file, so any change rebuilds the check.
{ git-hooks, warning }:
{ self, ... }:
{
  _file = ./checks.nix;

  config.perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      inherit (pkgs) lib;
      inherit (config.pre-commit) settings;
      # Every option of the project's hook; raw is computed from the others.
      hook = name: removeAttrs settings.hooks.${name} [ "raw" ];
    in
    {
      checks.text = warning lib (
        git-hooks.lib.${system}.run {
          src = self.outPath;
          hooks = lib.genAttrs [ "typos" "editorconfig-checker" ] hook;
          inherit (settings) excludes package gitPackage;
        }
      );
    };
}
