#!/usr/bin/env bash
# Updates this fork to upstream's newest release when the tower is fully down, as FORK.md's update steps do by hand.
# The Windows launcher runs it before `tower up`: a cold start (after Shut down Ubuntu or a reboot) is the one moment
# a host change ends no session.
#
#   scripts/fork-update.sh due   exits 0 when an update is due: every daemon is down, the checkout is clean on
#                                wsl-linux, and upstream has a newer release tag. Fetches upstream's tags.
#   scripts/fork-update.sh run   updates if still due: rebases the fork's commits onto the new tag, then npm ci,
#                                typecheck and npm test, then force-pushes to origin. On any failure it puts the
#                                branch and node_modules back, starts the tower and keeps a draft saying what to do.
#
# Its output goes to ~/.tower/fork-update.log. Two runs at once wait on each other.
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ROOT="$HOME/.tower"
LOG="$ROOT/fork-update.log"
BRANCH=wsl-linux
cd "$REPO"

say() { printf '%s  %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
tower() { node --import tsx "$REPO/src/cli.ts" "$@"; }

# A daemon of this checkout whose pid file names a live process.
anyDaemonUp() {
  local f pid
  for f in "$ROOT"/{host,terms,jobs,tower}.pid; do
    [[ -f $f ]] || continue
    pid=$(<"$f")
    [[ -r /proc/$pid/cmdline ]] && tr '\0' ' ' <"/proc/$pid/cmdline" | grep -qF "$REPO/src/" && return 0
  done
  return 1
}

base() { git describe --tags --abbrev=0 --match 'v*' HEAD; }
newest() { git tag --list 'v*' --sort=-v:refname | head -1; }

# Prints the release to update to when one is due; fails otherwise.
due() {
  anyDaemonUp && return 1
  [[ $(git symbolic-ref --short -q HEAD) == "$BRANCH" ]] || return 1
  [[ -z $(git status --porcelain) ]] || return 1
  timeout 30 git fetch --quiet --tags upstream || return 1
  local from to
  from=$(base) && to=$(newest) || return 1
  [[ $to != "$from" ]] && git merge-base --is-ancestor "$from" "$to" || return 1
  echo "$to"
}

# Keeps stdin as a draft on the floor whose hub is this checkout, a prompt a worker can take: title on the first line.
# Through the API, since `tower keep` is a worker's verb and this runs outside any session.
KEEP_DRAFT='
const fs = require("fs")
const config = JSON.parse(fs.readFileSync(`${process.env.HOME}/.tower/config.json`, "utf8"))
const project = Object.keys(config.projects).find((k) => config.projects[k].hub === process.argv[1])
const url = `http://127.0.0.1:${config.port}`
const body = JSON.stringify({ project, collection: "drafts", ext: "md", name: "fork update", content: fs.readFileSync(0, "utf8") })
fetch(`${url}/collection/create`, { method: "POST", headers: { origin: url, "content-type": "application/json" }, body })
  .then(async (r) => (console.log(await r.text()), r.ok || process.exit(1)))'
keepDraft() { node -e "$KEEP_DRAFT" "$REPO" >>"$LOG" 2>&1 || say "could not keep the draft"; }

# The CHANGELOG lines between two releases that ask for a config change.
configAsks() { git show "$2:CHANGELOG.md" | awk -v stop="## $1" '$0 == stop {exit} /^## v/ {v=$2} v != "" && /\*\*config:?\*\*/ {print v ": " $0}'; }

run() {
  exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tower-fork-update.lock"
  flock 9
  local from to backup step=""
  to=$(due) || exit 0
  from=$(base)
  backup="backup/$BRANCH-$from"
  printf '\e]0;Updating the Tower to %s\a' "$to"
  say "updating $from -> $to (backup branch $backup)"
  git branch -f "$backup" "$BRANCH"

  if ! git rebase --onto "$to" "$from" "$BRANCH" >>"$LOG" 2>&1; then
    step="the rebase: $(git diff --name-only --diff-filter=U | paste -sd, - | sed 's/,/, /g') conflict"
    git rebase --abort
  fi
  for check in "npm ci" "npm run -s typecheck" "npm test"; do
    [[ -z $step ]] || break
    say "$check"
    $check >>"$LOG" 2>&1 || step="\`$check\`"
  done

  if [[ -n $step ]]; then
    say "failed at $step; back to $from"
    git reset --quiet --hard "$backup"
    npm ci >>"$LOG" 2>&1 || say "npm ci on $from failed too"
    tower up >>"$LOG" 2>&1
    keepDraft <<EOF
Update the tower to $to (the automatic update failed)

The fork's automatic update from $from to $to stopped at $step, so the tower still runs $from: nothing changed.
Update it by hand as FORK.md says (\`git rebase --onto $to $from $BRANCH\`, then the checks), resolving what stopped it.
The details are at the end of ~/.tower/fork-update.log. The branch before the attempt is \`$backup\`.
EOF
    exit 1
  fi

  git push --quiet --force-with-lease origin "$BRANCH" >>"$LOG" 2>&1 || say "push to origin failed: push $BRANCH by hand"
  say "updated to $to"
  tower up >>"$LOG" 2>&1
  local asks
  asks=$(configAsks "$from" "$to")
  [[ -z $asks ]] || keepDraft <<EOF
Check the config changes $to asks for

The tower updated itself from $from to $to. These CHANGELOG entries ask for a change to ~/.tower/config.json: read
each one in CHANGELOG.md, make the change with the user if it applies here, and \`tower config check\` after.

$asks
EOF
}

case "${1:-}" in
  due) due >/dev/null ;;
  run) run ;;
  *) echo "usage: $0 due|run" >&2; exit 2 ;;
esac
