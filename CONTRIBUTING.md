# Contributing

Thanks for your interest in contributing to `gdashlint-action`.

## Prerequisites

- A GitHub Actions workflow editor/test environment.
- Docker, only needed when changing `distribution: docker` behavior.
- [`actionlint`](https://github.com/rhysd/actionlint), optional but recommended for local workflow validation.

## Development workflow

1. Fork the repository and create a feature branch.
2. Keep changes focused and update examples for user-facing behavior changes.
3. Run the narrowest relevant local checks before opening a pull request.
4. Open a pull request using the provided template.

Useful local checks:

```sh
actionlint
bash -n scripts/run-gdashlint.sh
```

If you have ShellCheck installed, also run:

```sh
shellcheck scripts/run-gdashlint.sh
```

## Testing the action

GitHub Actions are usually tested at three levels:

1. **Static validation**: run `actionlint` to validate workflow syntax and common GitHub Actions mistakes.
2. **Script validation**: run `bash -n` and, optionally, `shellcheck` against scripts used by composite actions.
3. **Integration validation**: create a temporary workflow in a branch that checks out the repository and uses the local action with `uses: ./`.

Example local-action workflow:

```yaml
name: Action integration test

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  rules:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout action repository
        uses: actions/checkout@9f698171ed81b15d1823a05fc7211befd50c8ae0 # v6.0.3

      - name: Run local action
        uses: ./
        with:
          command: rules
          version: v0.2.0
          format: text
```

For fix behavior, use a fixture dashboard committed to the test branch, run `command: fix`, then verify the working tree changed as expected with `git diff --exit-code` or inspect the diff in the workflow logs.

Tools such as [`act`](https://github.com/nektos/act) can run some workflows locally, but they are not a perfect replacement for GitHub-hosted runners. Use a real GitHub Actions workflow before publishing a release.

If a check is not relevant to your change or cannot run locally, note that in the pull request.

## Commit and pull request expectations

- Use clear, descriptive commit messages.
- Explain the motivation and user impact of the change.
- Keep unrelated refactors out of feature or bug-fix pull requests.
- Update documentation for action input, output, or workflow behavior changes.

## Reporting issues

Please use the GitHub issue templates when reporting bugs or proposing features. Include enough detail for maintainers to reproduce or evaluate the request.

For security issues, follow [`SECURITY.md`](SECURITY.md) instead of opening a public issue.
