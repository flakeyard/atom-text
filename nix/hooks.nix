# The hooks typos and editorconfig-checker of git-hooks.nix, with the
# configuration files of nix/configs.nix (FY-0037). Both tools take a file by
# flag; typos also gets --isolated, so that it reads no configuration file it
# finds itself, and editorconfig-checker reads none once it gets -config. The
# check runs the same entry and arguments.
{ root }:
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
      configs = import ./configs.nix {
        inherit lib root;
        project = self.outPath;
      };
      # A project file the atom does not take fails evaluation, instead of
      # being ignored.
      chosen =
        name:
        if configs.errors == [ ] then "${configs.${name}}" else throw (lib.concatLines configs.errors);
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
              (chosen "typos")
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
            (chosen "editorconfig-checker")
          ];
        };
      };
    };
}
