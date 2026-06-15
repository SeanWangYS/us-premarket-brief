#!/usr/bin/env bash
# US Premarket Brief — launchd entry point
# Triggered by ~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist
# at 20:30 Asia/Taipei, Mon-Fri.

set -uo pipefail

# Keep the Mac awake for the WHOLE run. launchd often fires this in the evening
# while the laptop sits idle (lid open); without this, macOS idle-sleeps mid-run
# and FREEZES the process for hours. Real incidents from the log:
#   - 2026-06-04: claude started 22:23 but didn't finish/push until 10:02 next
#     morning (frozen ~11.5h while asleep).
#   - the git-fetch "sleep 30" backoff stretched to 55 min as the system
#     suspended between attempts.
# Re-exec ONCE under caffeinate so a single power assertion covers git + claude
# + push end-to-end:  -i no idle system sleep, -m no disk idle sleep,
# -s no system sleep on AC.  NOTE: caffeinate does NOT prevent lid-close
# (clamshell) sleep, and can't help if the Mac is ALREADY asleep at 20:30 —
# that half is handled by the pmset wake schedule (scripts/setup-wake-schedule.sh),
# which wakes the Mac at 20:28 so launchd fires on time. Degrades gracefully if
# caffeinate is missing.
if [[ -z "${BRIEF_CAFFEINATED:-}" ]] && command -v caffeinate >/dev/null 2>&1; then
  export BRIEF_CAFFEINATED=1
  # Re-run via `bash "$0"` (not `caffeinate "$0"` directly) so this works
  # whether launchd execs the file or someone runs `bash run-brief.sh`, and
  # regardless of the file's +x bit. Shebang is env bash, so this is equivalent.
  exec caffeinate -ims bash "$0" "$@"
fi

REPO="$HOME/us-premarket-brief"
LOG="$HOME/Library/Logs/us-premarket-brief.log"
SLACK_URL_FILE="$HOME/.config/us-premarket-brief/slack_webhook"
DATE="$(date '+%Y-%m-%d')"
RUN_TIME="$(date '+%H:%M')"

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

notify_success() {
  osascript -e "display notification \"$DATE brief published\" with title \"Premarket Brief\"" 2>/dev/null || true
  if [[ -f "$SLACK_URL_FILE" ]]; then
    local url
    url="$(cat "$SLACK_URL_FILE")"
    local landing="https://seanwangys.github.io/us-premarket-brief/"
    local archive="https://seanwangys.github.io/us-premarket-brief/archive/${DATE}.html"
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\":white_check_mark: 美股盤前情報已更新 — ${DATE}\\n網頁：${landing}\\n本日存檔：${archive}\"}" \
      "$url" >/dev/null || true
  fi
}

mkdir -p "$(dirname "$LOG")"
log "=== run-brief.sh start (date=$DATE) ==="

cd "$REPO" || { notify_fail "cannot cd $REPO"; exit 1; }

# 1. Sync with origin, make report-data branch follow main.
#    launchd often fires this the instant the Mac wakes, before Wi-Fi / SSH is
#    ready, so the first fetch can fail with "ssh: connect to host ... port 22".
#    We must NOT proceed on a stale origin/main: building report-data on an old
#    base diverges it from main, and the ff-only merge action then fails
#    silently (incident 2026-05-26/27 — two days of briefs never reached main).
#    So retry with backoff, and ABORT HARD if fetch never succeeds. Never `|| true`.
log "git fetch origin (with retry; network may be cold right after wake)"
fetch_ok=0
for attempt in 1 2 3 4 5; do
  if git fetch origin main report-data >>"$LOG" 2>&1; then
    fetch_ok=1
    log "git fetch succeeded on attempt $attempt"
    break
  fi
  log "git fetch attempt $attempt failed (network/SSH not ready?); retrying in 30s"
  sleep 30
done
if [[ $fetch_ok -eq 0 ]]; then
  notify_fail "git fetch origin failed after 5 attempts — aborting so we never build on a stale base"
  exit 1
fi

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

# Inject today's date AND the shell-side run-start time into the prompt header.
# - DATE pins file names to a single day even if the run crosses midnight.
# - RUN_TIME pins the "generation time" the brief publishes; otherwise Claude
#   guesses (and the previous prompt let it default to the scheduled 20:30,
#   which lies about when the snapshot actually happened).
PROMPT_HEADER="# Runtime context (injected by run-brief.sh)

- Today's brief date: ${DATE}
- Run start time: ${RUN_TIME} Asia/Taipei
- Use this exact date for all file names (data/${DATE}.md, docs/archive/${DATE}.html)
- Use this exact run-start time as the brief's generation timestamp (the
  '生成時間' / '產生時間' fields). It reflects when the data was fetched,
  not when the file was written.
- Do NOT compute the date or time yourself; trust the shell.

---

"
FULL_PROMPT="${PROMPT_HEADER}$(cat routine-prompt.md)"

# Explicit tool allowlist (narrower than bypassPermissions): in headless mode
# any tool not on this list is auto-denied. We keep --add-dir for filesystem
# scope. Bash is required because skills internally shell out to curl.
#
# --settings disables the `dotagents-skills` plugin for this run ONLY. That
# plugin's marketplace is a `directory` source living under ~/Documents (a
# macOS TCC-protected folder), so on startup claude loads its skills from
# Documents and triggers a "claude wants to access Documents" GUI prompt. The
# grant is keyed to the exact binary path (~/.local/share/claude/versions/X),
# so EVERY auto-update lands at a new path and re-prompts — which silently
# blocks the unattended run until someone clicks Allow. The brief needs none of
# dotagents' skills (they're for CVE work); disabling it keeps the headless run
# clear of ~/Documents entirely, so no version bump can ever re-trigger the
# popup. We override only this one plugin (not --setting-sources, which would
# also drop the user-scope moomoo skills the brief depends on).
claude -p "$FULL_PROMPT" \
  --add-dir "$REPO" \
  --allowedTools "Skill WebSearch Write Edit Read Bash" \
  --settings '{"enabledPlugins":{"dotagents-skills@dotagents":false}}' \
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

# 5. Success notification (macOS + Slack; Slack only fires if webhook file exists)
notify_success
log "=== run-brief.sh done OK ==="
