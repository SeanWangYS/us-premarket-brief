#!/usr/bin/env bash
# US Premarket Brief — launchd entry point
# Triggered by ~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist
# at 20:30 Asia/Taipei, Mon-Fri.

set -uo pipefail

REPO="$HOME/Documents/Sean/project/us-premarket-brief"
LOG="$HOME/Library/Logs/us-premarket-brief.log"
SLACK_URL_FILE="$HOME/.config/us-premarket-brief/slack_webhook"
DATE="$(date '+%Y-%m-%d')"

log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "[$ts] $*" | tee -a "$LOG"
}

notify_fail() {
  local msg="$1"
  log "FAIL: $msg"
  osascript -e "display notification \"$msg\" with title \"Premarket Brief FAILED\"" 2>/dev/null || true
  if [[ -f "$SLACK_URL_FILE" ]]; then
    local url
    url="$(cat "$SLACK_URL_FILE")"
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\":x: Premarket brief failed ($DATE): $msg\"}" \
      "$url" >/dev/null || true
  fi
}

mkdir -p "$(dirname "$LOG")"
log "=== run-brief.sh start (date=$DATE) ==="

cd "$REPO" || { notify_fail "cannot cd $REPO"; exit 1; }

# 1. Sync with origin, make report-data branch follow main
log "git fetch origin"
git fetch origin main report-data >>"$LOG" 2>&1 || true

if git show-ref --verify --quiet refs/heads/report-data; then
  git checkout report-data >>"$LOG" 2>&1
else
  git checkout -b report-data origin/main >>"$LOG" 2>&1 \
    || git checkout -b report-data >>"$LOG" 2>&1
fi

log "reset report-data to origin/main"
git reset --hard origin/main >>"$LOG" 2>&1 || {
  notify_fail "git reset --hard origin/main failed"
  exit 1
}

# 2. Run Claude in headless mode
if [[ ! -f "routine-prompt.md" ]]; then
  notify_fail "routine-prompt.md missing in $REPO"
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  notify_fail "claude CLI not in PATH ($PATH)"
  exit 1
fi

log "starting claude -p (typically 3-6 min; output is buffered until done — DO NOT KILL the process)"

# Inject today's date into the prompt header so Claude uses the exact same
# DATE the shell uses (otherwise a near-midnight run can disagree).
PROMPT_HEADER="# Runtime context (injected by run-brief.sh)

- Today's brief date: ${DATE}
- Use this exact date for all file names (data/${DATE}.md, docs/archive/${DATE}.html)
- Do NOT compute the date yourself; trust the shell.

---

"
FULL_PROMPT="${PROMPT_HEADER}$(cat routine-prompt.md)"

# Explicit tool allowlist (narrower than bypassPermissions): in headless mode
# any tool not on this list is auto-denied. We keep --add-dir for filesystem
# scope. Bash is required because skills internally shell out to curl.
claude -p "$FULL_PROMPT" \
  --add-dir "$REPO" \
  --allowedTools "Skill WebSearch Write Edit Read Bash" \
  >>"$LOG" 2>&1
CLAUDE_EXIT=$?

if [[ $CLAUDE_EXIT -ne 0 ]]; then
  notify_fail "claude exited with code $CLAUDE_EXIT"
  exit 1
fi

# 3. Sanity-check expected output files
if [[ ! -f "docs/archive/$DATE.html" ]] || [[ ! -f "data/$DATE.md" ]]; then
  notify_fail "claude finished but expected files missing (docs/archive/$DATE.html or data/$DATE.md)"
  exit 1
fi

# 4. Commit + push to report-data only
git add docs/ data/ >>"$LOG" 2>&1
if git diff --cached --quiet; then
  log "no changes to commit; skipping push"
  exit 0
fi

git -c user.name="Premarket Brief Bot" -c user.email="brief@local" \
  commit -m "brief: $DATE" >>"$LOG" 2>&1 || {
    notify_fail "git commit failed"
    exit 1
  }

log "pushing report-data"
if ! git push -f origin report-data >>"$LOG" 2>&1; then
  notify_fail "git push -f origin report-data failed"
  exit 1
fi

# 5. Success notification
osascript -e "display notification \"$DATE brief published\" with title \"Premarket Brief\"" 2>/dev/null || true
log "=== run-brief.sh done OK ==="
