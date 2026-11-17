# A consumer that locks git-hooks.nix a second time fails at evaluation with
# the follows line to add (FY-0017).
{ testing, ... }:
{
  perSystem = testing.follows {
    output = [
      "checks"
      "text"
    ];
    # Restated: the text is the interface (FY-0035).
    messages.git-hooks = ''
      atom-text: input 'git-hooks' is locked twice; add to input atom-text:
        inputs.git-hooks.follows = "git-hooks";'';
  };
}
