# A project whose files pass both tools: checks.text succeeds, also over a
# file that is indented with a tab and has a line longer than
# max_line_length, which the default configuration does not check.
{ fixture, ... }:
{
  perSystem =
    { system, ... }:
    {
      checks.test-good = (fixture { name = "good"; }).checks.${system}.text;
    };
}
