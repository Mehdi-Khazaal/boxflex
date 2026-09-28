# boxflex_adi2

adi2 resolves each flex container through one procedure,
`Adi.Layout_Util.Compute_Flex_Layout`. This crate provides a procedure
with the same signature that converts to `Boxflex.Flex.Item`, calls
`Boxflex.Flex.Resolve`, and converts back.

Not built by CI: it depends on adi2, which is not a stable release yet.
Pin a commit in `alire.toml` before building.

Milestone 3 stretch goal: adi2 built with this adapter in place of its
own flex code, with adi2's own test suite passing. That gives boxflex a
browser-validated conformance oracle for free.

Two things adi2 has that the seed engine does not yet:
- `Align_Content` (how wrapped lines share cross space): typed, not
  implemented.
- per-item baseline: the adapter passes 0; extend `Flex_Child_Info` or
  measure it in adi2 if Baseline alignment matters.
