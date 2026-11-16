# The error for an upstream flake that the consumer locks a second time
# (FY-0017), or null. Only store paths are compared; nothing is imported from
# the consumer's input.
{
  name,
  atom,
  consumer,
}:
if consumer == null || consumer.outPath == atom.outPath then
  null
else
  ''
    atom-text: input '${name}' is locked twice; add to input atom-text:
      inputs.${name}.follows = "${name}";''
