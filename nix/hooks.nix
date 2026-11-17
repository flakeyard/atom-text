# The hooks typos and editorconfig-checker of git-hooks.nix, with the
# configuration files of nix/configs.nix (FY-0037). Both tools take a file by
# flag; typos also gets --isolated, so that it reads no configuration file it
# finds itself, and editorconfig-checker reads none once it gets -config. The
# check runs the same entry and arguments.
{ root, shared }:
{ self, ... }:
{
  _file = ./hooks.nix;

  config.perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # A project file the atom does not take fails evaluation, instead of
      # being ignored.
      configs = import ./configs.nix {
        inherit lib root shared;
        project = self.outPath;
      };
    in
    {
      pre-commit.settings.hooks = {
        typos = {
          enable = lib.mkOverride 900 true;
          package = lib.mkOverride 900 pkgs.typos;
          # The whole entry: upstream's always passes --config with a file
          # generated from settings.config, which is never empty, and
          # ignores settings.configPath. --force-exclude, upstream's default,
          # keeps files.extend-exclude of a project's file working for the
          # files that pre-commit passes by name.
          entry = lib.mkOverride 900 (
            lib.concatStringsSep " " [
              (lib.getExe' config.pre-commit.settings.hooks.typos.package "typos")
              "--config"
              "${configs.typos.file}"
              "--isolated"
              "--force-exclude"
            ]
          );
        };
        editorconfig-checker = {
          enable = lib.mkOverride 900 true;
          package = lib.mkOverride 900 pkgs.editorconfig-checker;
          args = lib.mkOverride 900 [
            "-config"
            "${configs.editorconfig-checker.file}"
          ];
        };
      };
    };
}
