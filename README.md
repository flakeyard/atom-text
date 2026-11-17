# atom-text

A flake-parts module that checks the spelling of every file with typos, and its
charset, line endings, final newline and trailing whitespace with
editorconfig-checker, as git hooks and as the check `checks.text`
([FY-0017][fy-0017], [ADR-0001][adr-0001]).

## Inputs

The atom has one input, `git-hooks`, which the project makes it share with
`follows` ([FY-0017][fy-0017]). It has no formatter, so it needs no
`treefmt-nix`. It also pins [lib-atom][lib-atom], the functions that atoms
share, in its own `flake.lock`; the project neither declares nor follows it
([FY-0040][fy-0040]). While the atom is `0.y.z`, only flakeyard's own
repositories use it, in the form of [FY-0016][fy-0016]:

```nix
{
  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&rev=<commit>&shallow=1";
    flake-parts = {
      url = "git+https://github.com/hercules-ci/flake-parts?ref=main&rev=<commit>&shallow=1";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    git-hooks = {
      url = "git+https://github.com/cachix/git-hooks.nix?ref=master&rev=<commit>&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    atom-text = {
      url = "git+https://github.com/flakeyard/atom-text?ref=v0&rev=<commit>&shallow=1";
      inputs.git-hooks.follows = "git-hooks";
    };
    atom-workspace.url = "git+https://github.com/flakeyard/atom-workspace?ref=v0&rev=<commit>&shallow=1";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        inputs.atom-text.flakeModules.default
        inputs.atom-workspace.flakeModules.default
      ];
    };
}
```

Without the `follows` line, evaluation fails with:

```text
atom-text: input 'git-hooks' is locked twice; add to input atom-text:
  inputs.git-hooks.follows = "git-hooks";
```

[atom-workspace][atom-workspace] joins the shell of the atom into
`devShells.default`, installs its hooks, excludes the files that tools write,
such as `CHANGELOG.md`, `flake.lock` and `LICENSES/`, and switches off the
aggregated `checks.pre-commit` of git-hooks.nix.

## Files it reads

From the project's source, which for a git flake holds only tracked files:

- every file: typos checks the files that pre-commit selects as text,
  editorconfig-checker every file, both except the project's global excludes;
- `typos.toml`, `_typos.toml` and `.typos.toml` at the root, whose presence
  decides the configuration of typos;
- `pyproject.toml` and `Cargo.toml` at the root, read at evaluation for a
  configuration of typos in them, which fails evaluation;
- `.editorconfig-checker.json` at the root, whose presence decides the
  configuration of editorconfig-checker, and `.ecrc` at the root, which fails
  evaluation;
- the `.editorconfig` files that editorconfig-checker reads: in the directory of
  each file and above it, up to one with `root = true`.

editorconfig-checker takes its rules from `.editorconfig`: in a project without
one it reports nothing. Start the project's `.editorconfig` with `root = true`;
otherwise a `.editorconfig` above the project applies in the working tree but
not in the check. flakeyard's repositories carry this one
([ADR-0001][adr-0001]):

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2
switch_case_indent = true
binary_next_line = true
```

## Tools and configuration

Both tools get a configuration file by flag, as a store path of its own
([FY-0037][fy-0037]):

- typos: standard paths `typos.toml`, `_typos.toml` and `.typos.toml`; default
  [`config/typos.toml`][typos], passed with `--config`.
- editorconfig-checker: standard path `.editorconfig-checker.json`; default
  [`config/editorconfig-checker.json`][ec-cfg], passed with `-config`; it also
  reads `.editorconfig`.

A project's file at the standard path replaces the default wholly.

- typos gets `--config` with the chosen file, `--isolated`, so that it reads no
  other configuration file, also none below the root, and `--force-exclude`, so
  that `files.extend-exclude` of a project's file applies to the files
  pre-commit passes. The default writes out the values of `[default]` with the
  defaults of typos and ignores nothing. More than one of `typos.toml`,
  `_typos.toml` and `.typos.toml` at the root fails evaluation, since typos
  reads only one.
- A configuration of typos in `[tool.typos]` of `pyproject.toml`, or in
  `[package.metadata.typos]` or `[workspace.metadata.typos]` of `Cargo.toml`,
  fails evaluation: move its content to one of the standard paths.
- editorconfig-checker gets `-config` with the chosen file and then reads no
  other configuration file. The default lists every key of the tool except
  `Version`, which it fails on when it differs from its own version, and
  disables `Indentation`, `IndentSize` and `MaxLineLength`: the check covers
  charset, line endings, final newline and trailing whitespace.
- `.ecrc`, the old name of the configuration of editorconfig-checker, fails
  evaluation: rename it to `.editorconfig-checker.json`.

The messages of these errors are those of lib-atom ([FY-0040][fy-0040]), such
as:

```text
atom-text: the project has more than one configuration of typos: typos.toml,
.typos.toml; keep one.
atom-text: the atom cannot pass these configurations of typos to it:
pyproject.toml [tool.typos]; write the configuration in one of typos.toml,
_typos.toml, .typos.toml instead.
```

(one line each, wrapped here).

To replace a default, commit the file at the root. Since the atom reads only
tracked files, an untracked file is seen by the tools in the working tree but
not by the atom.

## Options

The atom sets the hooks `typos` and `editorconfig-checker` of git-hooks.nix with
`lib.mkOverride 900`, so a plain definition of the project, such as
`perSystem.pre-commit.settings.hooks.editorconfig-checker.args = [ ... ];`,
replaces a value of the atom without `mkForce`. The check runs the hooks'
`entry` and `args`, so such a definition changes it too, and honours the hooks'
other options and the project's global `perSystem.pre-commit.settings.excludes`:
pre-commit selects the files in the check as the installed hook does.

The atom sets the whole `entry` of `typos`, since upstream's ignores
`settings.configPath`. The `settings.*` options of the hook `typos` therefore
have no effect: change the configuration file, or override `entry`.

## Outputs

- `flakeModules.default`: the module. It adds to every system:
  - the hooks `typos` and `editorconfig-checker`, enabled, with the packages of
    the project's nixpkgs;
  - `checks.text`: the hooks, run by pre-commit through `lib.<system>.run` of
    git-hooks.nix with the project's global excludes, over the whole source of
    the project, without network access. Any change of the project rebuilds it;
  - `devShells.flakeyard-text`: typos and editorconfig-checker, which
    atom-workspace joins into `devShells.default`.

Supported systems are `x86_64-linux` and `aarch64-linux`.

## Supported upstream revisions

The oldest supported revisions are those the tests run with: git-hooks.nix
`204b6977e00caac19e2313015a598543ca7be150`, flake-parts
`ea2630b7470978622c7689a1ff75d2b389175399` and nixpkgs `nixos-26.05` at
`ac588ef1c914865dad517b337ea0eb9694a4021c`, with typos 1.46.3 and
editorconfig-checker 3.6.1.

## Public API

Releases follow [semantic versioning][versioning] ([FY-0024][fy-0024]). The
public API is the input `git-hooks`, `flakeModules.default`, the hooks `typos`
and `editorconfig-checker`, the values the atom sets whose change fails a
project that passed before (the default configurations and the flags of both
tools), the files it reads and the ones that fail evaluation, the outputs
`checks.text` and `devShells.flakeyard-text`, the supported systems and the
oldest supported upstream revisions. Versions of typos and editorconfig-checker
come from the project's nixpkgs and are not part of it.

The last minor release before a major one contains `nix/next-major.nix`; while
it exists, the check and the shell warn at evaluation that the next major
version is coming and where its migration guide is ([FY-0038][fy-0038]).

## Develop in the container

Open the repository in the flakeyard dev container: the editor reads
[`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json), and
`direnv` loads the shell of [`dev/flake.nix`](dev/flake.nix) through
[`.envrc`](.envrc) ([FY-0012][fy-0012]). [atom-workspace][atom-workspace] builds
the shell and installs the git hooks each time it starts. The container runs
`direnv allow` when it is created; run it once in every other worktree, and run
`direnv block` before you check out a branch you do not trust, since entering
the directory runs that branch's shell hook. Commit inside the container, whose
Nix store has the tools of the hooks. With Nix on the host, `direnv allow` or
`nix develop ./dev` gives the same shell.

The public [`flake.nix`](flake.nix) holds only the input and the module
([FY-0017][fy-0017]). [`dev/flake.nix`](dev/flake.nix), with its own lock,
imports the atom as consumers do, with [atom-nix][atom-nix],
[atom-shell][atom-shell], [atom-workflows][atom-workflows] and atom-workspace,
and holds the tests:

- `text`: the atom's check of this repository;
- `nix`, `shell`, `workflows`, `treefmt`: the checks of the other atoms of this
  repository;
- `test-good`: a fixture project in [`dev/fixtures`](dev/fixtures) that passes,
  with indentation and a line length that the default does not check;
- `test-bad`: a fixture project with a misspelled word, CRLF, a missing final
  newline, trailing whitespace and a byte order mark;
- `test-configs`, `test-configs-typos`, `test-configs-typos-underscore`,
  `test-configs-typos-dotted`, `test-configs-editorconfig-checker`: the entry of
  typos and the arguments of editorconfig-checker, and the project's
  `typos.toml`, `_typos.toml`, `.typos.toml` and `.editorconfig-checker.json`;
- `test-configs-nested`: a `_typos.toml` below the root does not apply;
- `test-configs-no-editorconfig`: without `.editorconfig`, editorconfig-checker
  reports nothing;
- `test-errors`: the evaluation errors and their messages;
- `test-config-keys`: the default configurations list every key of the installed
  tools;
- `test-excluded`, `test-not-excluded`, `test-generated`: the project's global
  excludes skip the failing files in the check, other excludes do not, and the
  files that tools write pass;
- `test-workspace`: the hooks, the check and the shell with atom-workspace;
- `test-follows`: the error for a missing `follows`;
- `test-next-major`: the warning of the next major version.

The dev flake has no input for lib-atom: it fetches the revision that the root
[`flake.lock`](flake.lock) pins, gives it to the atom and takes the fixture
projects and the tests `test-follows`, `test-next-major` and `test-workspace`
from `internal/testing` of that revision ([FY-0040][fy-0040]).

Run the same commands as CI:

```sh
nix flake check --no-update-lock-file ./dev
nix flake check --no-update-lock-file --no-build --all-systems ./dev
```

CI runs [`test.yaml`](.github/workflows/test.yaml), which calls
[workflow-check][workflow-check] with `./dev`: it checks `dev/flake.lock`,
builds every check on x86_64 and arm64 runners, checks the pull request title
and `renovate.json`, fails on configuration files of atom tools at their
standard root paths ([FY-0037][fy-0037]), and reports `check / required`
([FY-0034][fy-0034]). Its weekly run builds the checks against the current
branches of nixpkgs, treefmt-nix, git-hooks.nix and flake-parts instead of the
locked revisions ([FY-0038][fy-0038]).
[`scorecard.yaml`](.github/workflows/scorecard.yaml) runs OpenSSF Scorecard, and
[`release.yaml`](.github/workflows/release.yaml) releases the repository with
[workflow-release][workflow-release].

Before a pull request, also run prettier, markdownlint and `reuse lint`; the
atoms that will provide them in this repository are not released yet
([FY-0038][fy-0038]).

## License

[MIT](LICENSE).

[adr-0001]:
  docs/adr/records/0001-check-spelling-with-typos-and-basic-file-hygiene-with-editorconfig-checker.md
[atom-nix]: https://github.com/flakeyard/atom-nix
[atom-shell]: https://github.com/flakeyard/atom-shell
[atom-workflows]: https://github.com/flakeyard/atom-workflows
[atom-workspace]: https://github.com/flakeyard/atom-workspace
[ec-cfg]: config/editorconfig-checker.json
[fy-0012]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0012-develop-in-container.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0034]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md
[fy-0037]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0037-atoms-ship-default-configs-that-projects-replace.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
[fy-0040]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0040-share-code-through-lib-repositories.md
[lib-atom]: https://github.com/flakeyard/lib-atom
[typos]: config/typos.toml
[versioning]: https://github.com/flakeyard/.github/blob/main/VERSIONING.md
[workflow-check]: https://github.com/flakeyard/workflow-check
[workflow-release]: https://github.com/flakeyard/workflow-release
