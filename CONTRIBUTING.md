# Contributing

## Who owns what

This repository (`GNAT-Academic-Program/boxflex`) is the upstream. It is
maintained by AdaCore's GAP coordinator, who decides what gets merged.

Each capstone team works in its own **fork**. Your fork is yours: branch,
experiment, break things. Upstream only receives what is finished.

## Workflow

1. Fork this repository. One fork per team.
2. Work on a branch in your fork. Keep `main` in your fork equal to
   upstream `main` so rebasing stays painless.
3. When a milestone is done (see README), open a pull request to
   upstream `main`. One milestone, one PR. Small PRs get merged;
   thousand-line PRs get sent back.
4. After anything is merged upstream, every team rebases. Conflicts
   between teams on the same package are design questions; bring them
   to the weekly meeting rather than resolving them silently.

Pull requests are reviewed in batches, roughly every two weeks. A PR
opened the day before review day will not be looked at until the next
one.

## What a mergeable PR looks like

- CI is green: builds with warnings-as-errors, tests pass, SPARK flow
  analysis is clean.
- It adds a test, or a proof, or both, for what it changes.
- It does not weaken a contract or an invariant to make something pass.
  If a contract is wrong, the PR says why and fixes the contract on its
  own, with the reasoning in the description.
- Commits have a one-line summary in the imperative ("Resolve flex
  basis against parent content box"), and a body when the summary is
  not enough.
- No floating point, access types or heap in `src/`.

## Style

GNAT style (`-gnatyg`), 100 columns. Names follow the CSS flexbox spec
where one exists. Every public subprogram has a comment saying what it
guarantees, not how it does it.
