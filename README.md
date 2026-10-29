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

The preset uses `automergeType: "pr"` with `platformAutomerge: false`: Renovate waits for the required checks to be green and merges by itself with its own token. So that it can skip the required review without relaxing the rule for humans, the Renovate App (id `2740`) has to be in the bypass list of the branch ruleset that protects `main` and `develop`, with the **"For pull requests only"** mode.

`platformAutomerge: true` is not used on purpose: GitHub does not apply an actor's bypass to native auto-merge or the merge queue, so the PR would stay in `REVIEW_REQUIRED` forever. `automergeType: "branch"` is not used either, as it would lose the PR record.

Apply the bypass to every repository of the organization that extends this preset:

```bash
./scripts/apply-renovate-bypass.sh            # dry-run: shows the before and after
./scripts/apply-renovate-bypass.sh --apply    # applies it
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
