# A project with one finding of each kind: checks.text reports the
# misspelled word of typos, and the line endings, the missing final newline,
# the trailing whitespace and the byte order mark of editorconfig-checker.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      failure = pkgs.testers.testBuildFailure (fixture { name = "bad"; }).checks.${system}.text;
    in
    {
      checks.test-bad = pkgs.runCommand "test-bad" { } ''
        log=${failure}/testBuildFailure.log
        cat "$log"
        # The findings of editorconfig-checker under the line of a file,
        # without colours; their case differs between its versions.
        findings() {
          sed 's/\x1b\[[0-9;]*m//g' "$log" \
            | awk -v file="$1:" '$0 == file { on = 1; next } on && /^\t/ { print; next } { on = 0 }'
        }
        grep -F 'spelling.txt:1:' "$log"
        grep -F 'should be' "$log"
        findings crlf.txt | grep -iF 'not all lines have the correct end of line character'
        findings final-newline.txt | grep -iF 'wrong line endings or no final newline'
        findings trailing.txt | grep -iF '1: trailing whitespace'
        findings charset.txt | grep -iF 'wrong character encoding ("UTF-8-SIG" instead of "utf-8")'
        touch $out
      '';
    };
}
