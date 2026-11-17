---
id: ADR-0001
title:
  Check spelling with typos and basic file hygiene with editorconfig-checker
status: accepted
date: 2026-11-16
supersedes: []
superseded_by: []
related: []
affects:
  ["flake.nix", "flake.lock", "nix/**", "config/**", "dev/**", "README.md"]
review_by:
---

## Context

atom-text is an atom of step 4 of [FY-0038][fy-0038]. It owns all files of a
project, with typos for spelling and editorconfig-checker limited to charset,
line endings, final newline and trailing whitespace ([FY-0017][fy-0017]).
Decisions of flakeyard require of it:

- [FY-0017][fy-0017]: inputs are exactly the upstream flakes whose modules the
  atom imports, each checked against the consumer's input of the same name
  before the import. Upstream options are set with `lib.mkOverride 900`, and
  tool packages come from the consumer's `pkgs`. The domain has one check, built
  with `lib.<system>.run` of git-hooks.nix from only the domain's hooks and the
  project's global excludes. Developer tools are `devShells.flakeyard-<atom>`.
  Tests live in `dev/` with their own lock and import the atom as consumers do.
- [FY-0037][fy-0037]: typos and editorconfig-checker are tools of the kind "a
  file by flag". The atom ships flakeyard's configuration of each in `config/`,
  a project's file at the tool's standard path at the root replaces it wholly,
  the chosen file reaches the tool by its flag as a store path of its own, and a
  project file at a standard path in a form the atom does not pass fails
  evaluation with a message that names it. Atoms do not ship `.editorconfig`; it
  belongs to the project.
- [FY-0015][fy-0015]: every repository passes typos, lines do not end with
  whitespace, also in Markdown, and the files that tools write, such as
  `CHANGELOG.md`, are excluded from text linters, which atom-workspace does with
  `workspace.generated`.
- [FY-0024][fy-0024] and [FY-0038][fy-0038]: releases start at `v0.1.0` with the
  moving tag `v0`, a stricter default ships first as an opt-in under
  `config/next/`, and the warning of the next major version lives in
  `nix/next-major.nix`.
- [FY-0040][fy-0040]: the check of `follows`, the warning of the next major
  version and the choice of configuration files are functions of lib-atom, which
  the atom declares as an input and pins in its own `flake.lock`, and the
  helpers of the tests come from its `internal/testing`. Logic that only this
  atom needs, such as the tables of `pyproject.toml` and `Cargo.toml`, stays in
  the atom.

Reading git-hooks.nix at `204b6977` and the tools of `nixos-26.05` (typos
1.46.3, editorconfig-checker 3.6.1), with those of `nixos-unstable` (typos
1.52.0, editorconfig-checker 4.0.2) for comparison, and running them, showed:

- git-hooks.nix defines the hooks `typos`, with `types = [ "text" ]`, and
  `editorconfig-checker`, with `types = [ "file" ]`, and gives every value of a
  hook with `mkDefault`. The entry of `typos` passes `--config` with a file
  generated from `settings.config` whenever that is not `{ }`, and
  `settings.configPath` only when it is. Upstream itself defines
  `settings.config.default.extend-words` under a `lib.mkIf` on
  `settings.ignored-words`, so `settings.config` is `{ default = { }; }` and
  `settings.configPath` is ignored; the same holds on its current `master`. The
  entry also passes `--force-exclude`.
- typos takes one `--config` and fails when it gets two. Without `--isolated` it
  also reads `typos.toml`, `_typos.toml` or `.typos.toml`, the first of them in
  this order, in the directory of each file and above it, and the tables
  `[tool.typos]` of `pyproject.toml` and `[package.metadata.typos]` and
  `[workspace.metadata.typos]` of `Cargo.toml`. With `--isolated` it reads none
  of them, also not a `_typos.toml` below the root. Given `pyproject.toml` or
  `Cargo.toml` by `--config`, it reads their table, by the name of the file.
- typos checks every file passed by name: hidden files and the ignore files
  `.ignore` and `.gitignore` drop none of them. `--force-exclude` applies
  `files.extend-exclude` of the configuration to them.
- editorconfig-checker reads its rules from the project's `.editorconfig` files;
  without one it reports nothing. A `.editorconfig` in a directory above the
  project applies unless the project's file says `root = true`, so the hook in a
  working tree inside such a directory and the check in the sandbox would
  differ.
- editorconfig-checker 3.6.1 reads `.editorconfig-checker.json` and, deprecated,
  `.ecrc`; 4.0.2 reads only `.editorconfig-checker.json`. With `-config` both
  read no other file. Both write the same keys with `-init`: `Version`,
  `Verbose`, `Format`, `Debug`, `IgnoreDefaults`, `SpacesAfterTabs`, `NoColor`,
  `Exclude`, `AllowedContentTypes`, `PassedFiles` and `Disable` with `Charset`,
  `EndOfLine`, `Indentation`, `InsertFinalNewline`, `TrimTrailingWhitespace`,
  `IndentSize` and `MaxLineLength`. Both fail when `Version` is set and differs
  from their own version.
- editorconfig-checker reports a UTF-8 byte order mark against
  `charset = utf-8`; 3.6.1 does not report a Latin-1 file, 4.0.2 does. Its
  default excludes, such as lock files of package managers and minified scripts,
  also skip files passed by name.

## Decision

### Inputs

The public flake has one input, `git-hooks` (cachix/git-hooks.nix). The atom has
no formatter and imports no module of treefmt-nix, so it does not declare
`treefmt-nix` ([FY-0017][fy-0017]). Before importing the module of
git-hooks.nix, the atom fails evaluation with the line
`inputs.git-hooks.follows = "git-hooks";` when the consumer's input of that name
has another store path, through the function `upstream` of lib-atom.

The public flake also declares `lib-atom`, which the atom pins in its own
`flake.lock` and consumers neither declare nor follow ([FY-0040][fy-0040]).

### typos

The atom enables the upstream hook `typos` with `pkgs.typos` of the consumer and
owns it. It sets the hook's `entry`, with `lib.mkOverride 900`, to typos with
`--config <file>`, `--isolated` and `--force-exclude`, since the upstream entry
ignores `settings.configPath`. `--force-exclude` keeps `files.extend-exclude` of
a project's file working for the files that pre-commit passes by name. The file
is `config/typos.toml`, or the project's `typos.toml`, `_typos.toml` or
`.typos.toml` at the root, as a store path of its own made with `builtins.path`.
More than one of them fails evaluation with their names, since typos reads only
one. The function `config` of lib-atom chooses the file of each tool and makes
the messages of the errors ([FY-0040][fy-0040]).

`config/typos.toml` writes out the values of `[default]` that typos has, each
with its default, and ignores no word, identifier or file. It leaves out
`[files]`, whose values decide which files typos finds when it walks
directories.

A configuration of typos in `pyproject.toml` (`[tool.typos]`) or `Cargo.toml`
(`[package.metadata.typos]`, `[workspace.metadata.typos]`) at the root fails
evaluation with a message that names the file and the table: the atom passes
them to `config` as `unsupported` entries whose condition reads the table with
`builtins.fromTOML`.

### editorconfig-checker

The atom enables the upstream hook `editorconfig-checker` with
`pkgs.editorconfig-checker` of the consumer and owns it. The hook gets
`-config <file>`, the file being `config/editorconfig-checker.json` or the
project's `.editorconfig-checker.json` at the root, as a store path of its own.
The default lists every key that `-init` writes except `Version`, with the
defaults of the tool, and disables `Indentation`, `IndentSize` and
`MaxLineLength`, so that it checks charset, line endings, final newline and
trailing whitespace ([FY-0017][fy-0017]). An `.ecrc` at the root, the old name
of the file, is an `unsupported` entry and fails evaluation with a message that
names `.editorconfig-checker.json` instead.

### Check and shell

`checks.text` is built with `lib.<system>.run` of git-hooks.nix from only the
two hooks, with every option the project's configuration holds for them, the
project's global `pre-commit.settings.excludes` and the project's `pre-commit`
and `git` packages. Its source is the whole project, since the hooks check every
file. pre-commit selects the files, as the installed hook does.

`devShells.flakeyard-text` holds typos and editorconfig-checker.

### Project files of flakeyard's repositories

Atoms do not ship `.editorconfig` ([FY-0037][fy-0037]). The templates will
generate two files for every flakeyard repository, and until they exist the
files are copied into each repository by hand. `.editorconfig`:

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

`root = true` keeps `.editorconfig` files above the repository out. The first
four properties are the rules of editorconfig-checker; trailing whitespace is
trimmed in Markdown too, so Markdown has no hard line breaks made of trailing
spaces ([FY-0015][fy-0015]). The last four keep the style of shfmt, which
atom-shell switches to `.editorconfig` when the file exists, at `-i 2 -ci -bn`.

`.gitattributes`:

```text
* text=auto eol=lf
**/flake.lock linguist-generated
.release-please-manifest.json linguist-generated
```

Line endings are normalized to LF. Lock files and the manifest of release-please
are collapsed in diffs; `CHANGELOG.md` is not, since release pull requests are
read through it.

### Next major version

While `nix/next-major.nix` exists, `checks.text` and `devShells.flakeyard-text`
warn with `lib.warn` of the consumer's nixpkgs, through the function `warning`
of lib-atom: the version, the end of support 6 months after it, and the link to
the migration guide the file names ([FY-0016][fy-0016], [FY-0038][fy-0038]).

### Tests

`dev/flake.nix` imports the atom from the flake's own outputs called with the
dev flake's `git-hooks`, which is what `follows` gives a consumer, together with
atom-workspace, atom-nix, atom-shell and atom-workflows, and checks this
repository with them. The dev flake has no input for lib-atom: it fetches the
revision that the root `flake.lock` pins, gives it to the atom and takes the
fixture projects and the tests of `follows`, the warning and the glue of
atom-workspace from its `internal/testing`, with the messages restated in the
tests. Fixture projects import the atom and atom-workspace the same way. Its
checks evaluate on x86_64-linux and aarch64-linux: a project that passes, with
indentation and a line length that the default does not check; a project with a
misspelled word, CRLF, a missing final newline, trailing whitespace and a byte
order mark; each accepted name of the configuration of typos; a
`.editorconfig-checker.json` that enables indentation; the entry of typos; a
`_typos.toml` below the root that does not apply; a project without
`.editorconfig`; the evaluation errors; the global excludes and the files that
tools write; the keys of both default configurations against the installed
tools; the glue of atom-workspace; the follows error; and the next-major
warning.

## Constraints

- The public flake MUST declare only the inputs `git-hooks` and `lib-atom`
  ([FY-0040][fy-0040]), and MUST fail evaluation with the exact follows line
  when the consumer's `git-hooks` has another store path.
- The entry of the hook `typos` MUST pass exactly the chosen file with
  `--config`, and `--isolated`.
- editorconfig-checker MUST get the chosen file with `-config`.
- The chosen file MUST be the project's file at a standard path at the root when
  one exists, else the default of `config/`, as a store path of its own.
- More than one configuration file of typos at the root, a configuration of
  typos in `pyproject.toml` or `Cargo.toml`, and `.ecrc` at the root MUST fail
  evaluation with a message that names them.
- The default configuration of editorconfig-checker MUST disable `Indentation`,
  `IndentSize` and `MaxLineLength`, and MUST NOT set `Version`.
- `checks.text` MUST be built with `lib.<system>.run` of git-hooks.nix from only
  the two hooks and the project's global excludes, and the atom MUST NOT select
  its files.
- Everything listed in the "Public API" of the README is the public API
  ([FY-0017][fy-0017], [FY-0024][fy-0024]).

## Consequences

- (+) A project gets the same findings in the git hook, in `nix flake check` and
  in CI, with flakeyard's configuration or its own file.
- (+) A configuration file of typos below the root cannot switch off a finding
  that the root's configuration reports.
- (−) `checks.text` depends on the whole source, so any change rebuilds it.
- (−) The `settings.*` options of the upstream hook `typos` have no effect; a
  project changes its configuration file, or overrides the hook's `entry`.
- (−) editorconfig-checker checks nothing in a project without `.editorconfig`,
  and a `.editorconfig` without `root = true` lets a file above the project
  apply in the working tree but not in the check.
- (−) A project that configures typos in `pyproject.toml` or `Cargo.toml`, or
  editorconfig-checker in `.ecrc`, moves the configuration before it adopts the
  atom.
- (−) `builtins.fromTOML` fails on a `pyproject.toml` or `Cargo.toml` with dates
  or times, which fails evaluation.
- (±) `.editorconfig` and `.gitattributes` are copied by hand into flakeyard's
  repositories until the templates generate them.

## Alternatives considered

- **`settings.configPath` of the upstream hook.** Ignored while
  `settings.config` is not `{ }`, which upstream's own definition makes it.
- **`--config` in `args` next to upstream's entry.** typos fails on a second
  `--config`.
- **Overriding `settings.config` to make `settings.configPath` work.** It would
  turn off another option of the upstream hook to reach a third one; the entry
  states the whole command in one place.
- **`settings.config` with the content of the chosen file.** typos would get a
  file generated from the parsed content instead of the file itself.
- **Passing `pyproject.toml` or `Cargo.toml` by `--config`.** typos reads their
  table, but the check would depend on files that mostly configure other tools,
  and the order among them and the dedicated files would be a rule of the atom.
- **`.ecrc` as a second standard path.** Version 4 of editorconfig-checker does
  not read it.
- **Indentation and line length in the default.** Formatters own indentation,
  and lines that cannot be broken, such as URLs, are allowed
  ([FY-0015][fy-0015]).
- **Ignoring the links of release-please in the changelog with
  `extend-ignore-re`.** `CHANGELOG.md` is excluded from text linters
  ([FY-0015][fy-0015]).

[fy-0015]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0015-documentation-rules.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0037]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0037-atoms-ship-default-configs-that-projects-replace.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
[fy-0040]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0040-share-code-through-lib-repositories.md
