<h1 align="center">
  Renovate configuration
</h1>

<p align="center">
  Shared Renovate configuration for hexadrop projects.
</p>

You can use this preset with the following configuration

```json
{
    "extends": [
        "github>hexadrop/renovate-config"
    ]
}
```

## What it does

- **Dependency Dashboard** enabled: updates held back by the cooldown and the ones waiting for your approval show up there, without opening PRs.
- **7-day cooldown** (`minimumReleaseAge`): a version does not get a PR until 7 days after it was published. Runtime `minor` updates wait 14 days and GitHub Actions 3. `@hexadrop/*` packages and `hexadrop/*` actions do not wait.
- **Automerge** for non-major devDependencies, GitHub Actions, node/bun/yarn and lock file maintenance. Runtime dependency updates produce a changeset, so they wait for a maintainer. **Majors** do not open a PR until you approve them from the dashboard.
- **One PR per package** (or per monorepo family) and squash on merge: the 1:1 record with the package is kept in the history.
- Rebases only when needed (`rebaseWhen: automerging`) and at most 5 open PRs at a time.

## Automerge and branch protection

The preset uses `automergeType: "pr"` with `platformAutomerge: false`: Renovate merges the pull requests it is allowed to automerge with its own token, after checking that the required checks are green.

Only the updates that do not change the published packages are merged automatically: devDependencies, GitHub Actions, node/bun/yarn and lock file maintenance. Runtime dependency updates produce a changeset, so they stay open until a maintainer approves and merges them.

So that Renovate can merge without a human approval, its app (id `2740`) is in the bypass list of the branch ruleset that protects `main` and `develop`, with the **"For pull requests only"** mode:

```bash
./scripts/apply-renovate-bypass.sh            # dry-run: shows the before and after
./scripts/apply-renovate-bypass.sh --apply    # applies it
```

It needs `gh` authenticated with admin permissions on the repositories and `jq`. It only touches branch rules that require at least one review.

`/merge` covers the rest: it approves with the `hexabot` app (a person triggers it with a comment) and merges with the method required by the policy.

### Personal accounts

The script accepts any owner, not just the organization:

```bash
OWNER=<user> ./scripts/apply-renovate-bypass.sh
OWNER=<user> ./scripts/apply-renovate-bypass.sh --apply
```

Private repositories on the Free plan have no branch rules, so they do not need the bypass: Renovate merges as soon as it sees the checks green. Any preset that extends this one (`github>hexadrop/renovate-config`) inherits the changes automatically.

> Merging as an exempt actor means GitHub no longer guarantees the required checks for that merge: Renovate's logic does, and it only merges with the branch up to date and the checks green. Hence the minimum cooldown: it gives a problematic package time to surface before it lands.
