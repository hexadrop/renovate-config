#!/usr/bin/env bash
#
# Adds or removes the bypass entry of the Renovate GitHub App in the branch
# rulesets. The preset used it while platformAutomerge was false, so Renovate
# merged by itself. With native auto-merge the hexabot app approves the pull
# requests and no app needs to bypass the required reviews anymore.
#
# Usage:
#   scripts/apply-renovate-bypass.sh [--remove] [--apply] [repository ...]
#
# Without --apply it only shows what would change. Without repositories it
# applies to every repository of the owner that has a renovate.json.
#
# Only rulesets that require at least one approving review are touched. If you
# later raise the review requirement on a repository, run this again.
#
# Environment:
#   OWNER            organization or user to scan (default: hexadrop)
#   RENOVATE_APP_ID  GitHub App id of Renovate (default: 2740)
#   BYPASS_MODE      always | pull_request (default: pull_request)
set -euo pipefail

OWNER="${OWNER:-${ORG:-hexadrop}}"
RENOVATE_APP_ID="${RENOVATE_APP_ID:-2740}"
BYPASS_MODE="${BYPASS_MODE:-pull_request}"

MODE="dry-run"
ACTION="add"
REPOS=()

usage() {
	sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
	case "$arg" in
		--apply) MODE="apply" ;;
		--remove) ACTION="remove" ;;
		--dry-run) MODE="dry-run" ;;
		-h | --help)
			usage
			exit 0
			;;
		-*)
			echo "unknown option: $arg" >&2
			exit 1
			;;
		*) REPOS+=("$arg") ;;
	esac
done

for bin in gh jq; do
	command -v "$bin" > /dev/null || {
		echo "missing dependency: $bin" >&2
		exit 1
	}
done

if [ "${#REPOS[@]}" -eq 0 ]; then
	while IFS= read -r repo; do
		if gh api "repos/$OWNER/$repo/contents/renovate.json" > /dev/null 2>&1; then
			REPOS+=("$repo")
		fi
	done < <(gh repo list "$OWNER" --limit 200 --json name --jq '.[].name')
fi

if [ "${#REPOS[@]}" -eq 0 ]; then
	echo "no repositories to process" >&2
	exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

for repo in "${REPOS[@]}"; do
	raw_rulesets="$(gh api "repos/$OWNER/$repo/rulesets" 2> /dev/null || true)"
	if ! printf '%s' "$raw_rulesets" | jq -e 'type == "array"' > /dev/null 2>&1; then
		raw_rulesets="[]"
	fi

	ruleset_ids="$(
		printf '%s' "$raw_rulesets" \
			| jq -r '.[] | select(.target == "branch" and .source_type == "Repository") | .id'
	)"

	if [ -z "$ruleset_ids" ]; then
		default_branch="$(gh api "repos/$OWNER/$repo" --jq '.default_branch' 2> /dev/null || echo main)"
		protection="$(gh api "repos/$OWNER/$repo/branches/$default_branch/protection" 2> /dev/null || true)"
		classic_reviews="$(
			printf '%s' "$protection" \
				| jq -r '.required_pull_request_reviews.required_approving_review_count // 0' 2> /dev/null || echo 0
		)"
		if [ "${classic_reviews:-0}" -gt 0 ] 2> /dev/null; then
			echo "$repo: classic branch protection requires $classic_reviews review(s), add the bypass by hand"
		else
			echo "$repo: no required reviews, skipped"
		fi
		continue
	fi

	for ruleset_id in $ruleset_ids; do
		current="$WORKDIR/$repo-$ruleset_id.json"
		desired="$WORKDIR/$repo-$ruleset_id.desired.json"

		gh api "repos/$OWNER/$repo/rulesets/$ruleset_id" > "$current" 2> /dev/null || {
			echo "$repo: cannot read ruleset $ruleset_id, skipped" >&2
			continue
		}

		name="$(jq -r '.name' "$current")"
		branches="$(jq -r '[.conditions.ref_name.include[]?] | join(", ")' "$current")"
		reviews="$(
			jq -r '[.rules[] | select(.type == "pull_request" and (.enforcement // "active") == "active") | .parameters.required_approving_review_count] | add // 0' "$current"
		)"
		before="$(jq -c '.bypass_actors // []' "$current")"

		echo "$repo: $name ($branches)"
		if [ "$reviews" -lt 1 ]; then
			echo "  no required reviews, skipped"
			continue
		fi

		jq --argjson app "$RENOVATE_APP_ID" --arg mode "$BYPASS_MODE" --arg action "$ACTION" '
			.bypass_actors = (
				[((.bypass_actors // [])[]) | select(.actor_type != "Integration" or .actor_id != $app)]
				+ (if $action == "add" then [{ actor_id: $app, actor_type: "Integration", bypass_mode: $mode }] else [] end)
			)
			| { name, target, enforcement, conditions, rules, bypass_actors }
		' "$current" > "$desired"

		after="$(jq -c '.bypass_actors' "$desired")"

		if [ "$before" = "$after" ]; then
			echo "  already up to date"
			continue
		fi

		echo "  before: $before"
		echo "  after:  $after"

		if [ "$MODE" = "apply" ]; then
			gh api -X PUT "repos/$OWNER/$repo/rulesets/$ruleset_id" --input "$desired" > /dev/null
			echo "  applied"
		else
			echo "  dry-run, not applied"
		fi
	done
done

if [ "$MODE" != "apply" ]; then
	echo
	echo "run again with --apply to write the changes"
fi
