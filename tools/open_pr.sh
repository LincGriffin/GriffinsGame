#!/usr/bin/env bash
# Open (or find) a GitHub pull request for the current branch — without `gh`.
#
# Usage:
#   tools/open_pr.sh "<title>" <body_markdown_file> [base_branch]
#
# Why this exists: `gh` isn't installed here, and hand-rolling the REST call has
# two footguns that produced an empty PR body once already. Both are handled:
#   1. The body is JSON-escaped with tools/escape_json.pl (a *file*, never an
#      inline `perl -e`, which the shell/MSYS mangles into an empty string).
#   2. MSYS path-conversion (which rewrites `owner:branch` and `ref:path`) is
#      disabled for the whole script.
#
# Auth: reuses the git-cached GitHub credential (git credential fill). The token
# is kept in a local variable and never printed.

set -euo pipefail
export MSYS_NO_PATHCONV=1   # stop Git-Bash from mangling ':' in URLs/args

TITLE="${1:-}"
BODY_FILE="${2:-}"
BASE="${3:-main}"

if [[ -z "$TITLE" || -z "$BODY_FILE" ]]; then
	echo "usage: tools/open_pr.sh \"<title>\" <body_markdown_file> [base_branch]" >&2
	exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(git rev-parse --show-toplevel)"

[[ -f "$BODY_FILE" ]] || { echo "body file not found: $BODY_FILE" >&2; exit 1; }

# owner/repo from the origin URL (handles https and ssh remotes).
ORIGIN="$(git remote get-url origin)"
SLUG="$(printf '%s' "$ORIGIN" | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')"
[[ "$SLUG" == */* ]] || { echo "could not parse owner/repo from origin: $ORIGIN" >&2; exit 1; }
OWNER="${SLUG%%/*}"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "$BASE" ]]; then
	echo "refusing to open a PR from '$BASE' into itself — create a feature branch first." >&2
	exit 1
fi
if [[ "$BASE" != "main" ]]; then
	echo "WARNING: base is '$BASE', not 'main' — this is a STACKED PR." >&2
	echo "         Merging it lands the changes in '$BASE', NOT in main. Prefer basing" >&2
	echo "         feature branches on origin/main so every PR targets main directly." >&2
fi

echo "Pushing $BRANCH ..."
git push -u origin "$BRANCH"

# JSON-escape title + body via the script file (NOT an inline perl -e).
TITLE_ESC="$(printf '%s' "$TITLE" | perl "$SCRIPT_DIR/escape_json.pl")"
BODY_ESC="$(perl "$SCRIPT_DIR/escape_json.pl" "$BODY_FILE")"
if [[ "${#BODY_ESC}" -lt 20 ]]; then
	echo "escaped body is suspiciously short (${#BODY_ESC} chars) — aborting to avoid an empty PR body." >&2
	exit 1
fi
PAYLOAD="$(printf '{"title":"%s","head":"%s","base":"%s","body":"%s"}' \
	"$TITLE_ESC" "$BRANCH" "$BASE" "$BODY_ESC")"

# Cached GitHub token (used only here; never echoed).
TOKEN="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p')"
[[ -n "$TOKEN" ]] || { echo "no cached GitHub credential (git credential fill returned nothing)." >&2; exit 1; }

API="https://api.github.com/repos/$SLUG"

pr_url() { printf '%s' "$1" | { grep -oE '"html_url": *"[^"]*/pull/[0-9]+"' || true; } | head -1 | sed -E 's/.*"(https[^"]+)"/\1/'; }

# Send the body from a FILE via `--data-binary @file` — a relative path curl.exe
# can read with MSYS path-conversion off. Passing the JSON inline as `-d "$PAYLOAD"`
# gets mangled when native curl.exe rebuilds its command line (all the embedded
# quotes), yielding HTTP 400. Likewise the response is read from stdout, not `-o`,
# because mingw curl can't write to a POSIX temp path here. A marker separates the
# JSON body from the trailing status code.
PAYLOAD_FILE=".open_pr_payload.json"
printf '%s' "$PAYLOAD" > "$PAYLOAD_FILE"
trap 'rm -f "$PAYLOAD_FILE"' EXIT

RESPONSE="$(curl -sS -X POST \
	-H "Authorization: Bearer $TOKEN" \
	-H "Accept: application/vnd.github+json" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	"$API/pulls" --data-binary @"$PAYLOAD_FILE" -w '__HTTP__%{http_code}')"
CODE="${RESPONSE##*__HTTP__}"
BODY="${RESPONSE%__HTTP__*}"

if [[ "$CODE" == "201" ]]; then
	echo "PR created: $(pr_url "$BODY")"
elif [[ "$CODE" == "422" ]]; then
	# Usually: a PR already exists for this branch. Look it up.
	EXIST="$(curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
		"$API/pulls?head=$OWNER:$BRANCH&state=open")"
	URL="$(pr_url "$EXIST")"
	if [[ -n "$URL" ]]; then
		echo "PR already exists: $URL"
	else
		echo "create failed (HTTP 422) and no open PR found for $BRANCH:" >&2
		printf '%s\n' "$BODY" >&2
		exit 1
	fi
else
	echo "PR creation failed (HTTP $CODE):" >&2
	printf '%s\n' "$BODY" >&2
	exit 1
fi
