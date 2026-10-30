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
- **Automerge** for non-major devDependencies, runtime patches and minors, GitHub Actions and lock file maintenance. **Majors** do not open a PR until you approve them from the dashboard.
- **One PR per package** (or per monorepo family) and squash on merge: the 1:1 record with the package is kept in the history.
- Rebases only when needed (`rebaseWhen: automerging`) and at most 5 open PRs at a time.

## Automerge and branch protection

The preset uses `automergeType: "pr"` with `platformAutomerge: true`: Renovate enables GitHub native auto-merge with a squash merge, and GitHub merges when the required checks pass and the pull request has the required approval.

The approval comes from the `hexabot` app through the reusable `renovate-approve.yml` workflow: it approves dependency pull requests and approves them again on every push, because `dismiss_stale_reviews_on_push` dismisses the previous approval. The review requirement stays in place for humans, and no app needs to bypass the branch rules.

Repositories that still have the Renovate app in the ruleset bypass list (the previous `platformAutomerge: false` setup) can remove it with:

```bash
./scripts/apply-renovate-bypass.sh --remove            # dry-run: shows the before and after
./scripts/apply-renovate-bypass.sh --remove --apply    # removes it
```

It needs `gh` authenticated with admin permissions on the repositories and `jq`. It only touches branch rules that require at least one review.

### Personal accounts

The script accepts any owner, not just the organization:

```bash
OWNER=<user> ./scripts/apply-renovate-bypass.sh
OWNER=<user> ./scripts/apply-renovate-bypass.sh --apply
```

Private repositories on the Free plan have no branch rules, so they do not need the bypass: Renovate merges as soon as it sees the checks green. Any preset that extends this one (`github>hexadrop/renovate-config`) inherits the changes automatically.

> Merging as an exempt actor means GitHub no longer guarantees the required checks for that merge: Renovate's logic does, and it only merges with the branch up to date and the checks green. Hence the minimum cooldown: it gives a problematic package time to surface before it lands.
