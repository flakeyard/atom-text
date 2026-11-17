# The configuration of the tools (FY-0037). typos gets config/typos.toml, or
# the project's typos.toml, _typos.toml or .typos.toml, in the entry of the
# hook with --isolated, so that a _typos.toml below the root does not apply.
# editorconfig-checker gets config/editorconfig-checker.json, or the
# project's .editorconfig-checker.json, with -config. Without an
# .editorconfig, editorconfig-checker reports nothing.
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
      hooks = name: (fixture { inherit name; }).allSystems.${system}.pre-commit.settings.hooks;
      # The words of the entry of typos and the file after --config.
      words = name: lib.splitString " " (hooks name).typos.entry;
      typosConfig = name: lib.elemAt (words name) 2;
      editorconfig-checker = name: (hooks name).editorconfig-checker;
      check = name: (fixture { inherit name; }).checks.${system}.text;
      # The store path of a file as the atom makes it: comparing paths needs
      # no build, where reading the file would.
      stored =
        path: name:
        "${builtins.path {
          inherit path;
          name = lib.removePrefix "." name;
        }}";
      failure = name: pkgs.testers.testBuildFailure (check name);
    in
    {
      checks = {
        test-configs = facts pkgs "test-configs" {
          # Restated: the entry is the interface (FY-0035).
          "the entry of typos passes the chosen file and --isolated" =
            lib.take 2 (words "good") == [
              (lib.getExe' pkgs.typos "typos")
              "--config"
            ]
            &&
              lib.drop 3 (words "good") == [
                "--isolated"
                "--force-exclude"
              ];
          "the entry of typos has nothing of upstream's settings" = lib.length (words "good") == 5;
          "without a project file, typos gets config/typos.toml" =
            typosConfig "good" == stored (root + "/config/typos.toml") "typos.toml";
          "with typos.toml, typos gets it" =
            typosConfig "typos-config" == stored (root + "/dev/fixtures/typos-config/typos.toml") "typos.toml";
          "with _typos.toml, typos gets it" =
            typosConfig "typos-config-underscore"
            == stored (root + "/dev/fixtures/typos-config-underscore/_typos.toml") "_typos.toml";
          "with .typos.toml, typos gets it" =
            typosConfig "typos-config-dotted"
            == stored (root + "/dev/fixtures/typos-config-dotted/.typos.toml") ".typos.toml";
          "the file typos gets is a store path of its own" =
            lib.hasSuffix "-typos.toml" (typosConfig "good")
            && lib.hasSuffix "-typos.toml" (typosConfig "typos-config-dotted");
          "editorconfig-checker gets -config" = lib.head (editorconfig-checker "good").args == "-config";
          "without a project file, editorconfig-checker gets config/editorconfig-checker.json" =
            lib.elemAt (editorconfig-checker "good").args 1
            == stored (root + "/config/editorconfig-checker.json") "editorconfig-checker.json";
          "with .editorconfig-checker.json, editorconfig-checker gets it" =
            lib.elemAt (editorconfig-checker "editorconfig-checker-config").args 1
            == stored (
              root + "/dev/fixtures/editorconfig-checker-config/.editorconfig-checker.json"
            ) ".editorconfig-checker.json";
        };
        # The word passes only with the project's file.
        test-configs-typos = check "typos-config";
        test-configs-typos-underscore = check "typos-config-underscore";
        test-configs-typos-dotted = check "typos-config-dotted";
        # The project's file enables the indentation check, which the default
        # configuration disables.
        test-configs-editorconfig-checker = pkgs.runCommand "test-configs-editorconfig-checker" { } ''
          log=${failure "editorconfig-checker-config"}/testBuildFailure.log
          cat "$log"
          grep -iF 'wrong indent style found (tabs instead of spaces)' "$log"
          touch $out
        '';
        # With --isolated, typos does not read sub/_typos.toml, so the word
        # is reported.
        test-configs-nested = pkgs.runCommand "test-configs-nested" { } ''
          log=${failure "typos-nested"}/testBuildFailure.log
          cat "$log"
          grep -F 'sub/words.txt:1:' "$log"
          touch $out
        '';
        # Without an .editorconfig, the trailing whitespace and the missing
        # final newline pass.
        test-configs-no-editorconfig = check "no-editorconfig";
      };
    };
}
