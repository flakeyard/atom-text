# The project's global excludes, pre-commit.settings.excludes, apply to the
# check as to the hooks: the failing files of dev/fixtures/bad pass once
# excluded, and still fail when the excludes name other files. The files
# that tools write, which atom-workspace excludes, pass with a misspelled
# word and trailing whitespace.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      excluding =
        excludes:
        (fixture {
          name = "bad";
          module.perSystem.pre-commit.settings = { inherit excludes; };
        }).checks.${system}.text;
      failure = pkgs.testers.testBuildFailure (excluding [ ''^other\.txt$'' ]);
    in
    {
      checks = {
        test-excluded = excluding [ ''\.txt$'' ];
        test-not-excluded = pkgs.runCommand "test-not-excluded" { } ''
          log=${failure}/testBuildFailure.log
          cat "$log"
          grep -F 'spelling.txt:1:' "$log"
          grep -F 'trailing.txt:' "$log"
          touch $out
        '';
        test-generated = (fixture { name = "generated"; }).checks.${system}.text;
      };
    };
}
