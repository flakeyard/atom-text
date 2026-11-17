# The default configurations write out every value (FY-0037): the test fails
# when editorconfig-checker -init of the project's nixpkgs writes a key that
# config/editorconfig-checker.json does not list, or typos reports a value of
# [default] that config/typos.toml does not set, so that a new version of a
# tool shows what to add. Version is left out of the configuration, since
# editorconfig-checker fails when it differs from its own.
{ root, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.test-config-keys =
        pkgs.runCommand "test-config-keys"
          {
            nativeBuildInputs = [
              pkgs.editorconfig-checker
              pkgs.typos
              pkgs.python3
            ];
          }
          ''
            cd "$(mktemp -d)"
            editorconfig-checker -init
            typos --isolated --dump-config typos.toml
            python3 - ${root + "/config/editorconfig-checker.json"} ${root + "/config/typos.toml"} <<'EOF'
            import json, sys, tomllib

            def keys(value, prefix=""):
                if not isinstance(value, dict):
                    return {prefix}
                return set().union(*(keys(v, f"{prefix}.{k}".lstrip(".")) for k, v in value.items()))

            tool = json.load(open(".editorconfig-checker.json"))
            del tool["Version"]
            missing = keys(tool) - keys(json.load(open(sys.argv[1])))
            scalars = {k for k, v in tomllib.load(open("typos.toml", "rb"))["default"].items()
                       if not isinstance(v, (dict, list))}
            missing |= {f"default.{k}" for k in scalars - set(tomllib.load(open(sys.argv[2], "rb"))["default"])}
            for key in sorted(missing):
                print(f"not in the default configuration: {key}", file=sys.stderr)
            sys.exit(1 if missing else 0)
            EOF
            touch $out
          '';
    };
}
