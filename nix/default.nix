# The root module of atom-text (FY-0017). It fails when the consumer locks
# git-hooks.nix a second time, imports its module and the atom's modules. The
# atom has no formatter, so it imports no module of treefmt-nix. The atom's
# inputs and the root of the repository reach the other files only as
# function arguments.
atomInputs:
{ inputs, ... }:
let
  root = ./..;
  # The functions that atoms share, of the revision the atom pins (FY-0040).
  shared = atomInputs.lib-atom.lib;
  upstream = shared.upstream {
    atom = "atom-text";
    own = atomInputs;
    consumer = inputs;
  };
  # The warning of the next major version, with lib of the consumer's nixpkgs.
  warning =
    lib:
    shared.warning {
      inherit lib;
      atom = "atom-text";
      inherit root;
    };
in
{
  key = toString ./default.nix;
  _file = ./default.nix;
  imports = [
    (upstream "git-hooks" atomInputs.git-hooks.flakeModule)
    (import ./hooks.nix { inherit root shared; })
    (import ./checks.nix {
      inherit (atomInputs) git-hooks;
      inherit warning;
    })
    (import ./shell.nix { inherit warning; })
  ];
}
