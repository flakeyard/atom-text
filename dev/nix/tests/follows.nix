# A consumer that locks git-hooks.nix a second time fails at evaluation with
# the follows line to add (FY-0017).
{
  facts,
  fixture,
  inputs,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # An input under another store path, as the atom's own lock gives it
      # without follows.
      other = inputs.git-hooks // {
        outPath = "/nix/store/00000000000000000000000000000000-source";
      };
      message = import (root + "/nix/follows.nix") {
        name = "git-hooks";
        atom = other;
        consumer = inputs.git-hooks;
      };
      evaluated =
        given: builtins.tryEval (fixture (given // { name = "good"; })).checks.${system}.text.drvPath;
    in
    {
      checks.test-follows = facts pkgs "test-follows" {
        "the same input evaluates" = (evaluated { }).success;
        "another git-hooks fails" = !(evaluated { git-hooks = other; }).success;
        # Restated: the text is the interface (FY-0035).
        "the error names the follows line of git-hooks" =
          message == ''
            atom-text: input 'git-hooks' is locked twice; add to input atom-text:
              inputs.git-hooks.follows = "git-hooks";'';
      };
    };
}
