# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Not a typical software project — this is an **automation** that publishes a daily US pre-market intelligence brief. There is no traditional build / test / lint pipeline. The "logic" lives in three pieces that work together:

| Layer | File | What it does |
|---|---|---|
| Scheduler | `~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist` (live; not in repo) ← copied from `launchd/com.seanwang.us-premarket-brief.plist` (repo snapshot, not auto-synced) | macOS launchd fires `scripts/run-brief.sh` at MTWRF 20:30 Asia/Taipei |
| Shell wrapper | `scripts/run-brief.sh` | Manages git ops + invokes `claude -p` headless + sends notifications |
| Behavior spec | `routine-prompt.md` | The prompt that headless Claude reads; defines watchlist, data sources (moomoo skills + WebSearch), output format, fallback rules |

See `README.md` for the full architecture diagram, tech stack table, portability flow, and troubleshooting. Read it before making non-trivial changes.

## Two-branch model — do not break it

The publishing pipeline depends on this exact flow:

1. `scripts/run-brief.sh` resets `report-data` to `origin/main`, appends 1 commit (the daily brief), then `git push -f origin report-data`.
2. `.github/workflows/merge-to-main.yml` triggers on push to `report-data` and does `git merge --ff-only` into `main`, then pushes `main`.
3. GitHub Pages serves from `main/docs/`.

**Rules this implies for any change Claude makes here**:

- Never push directly to `main`. Use feature branches + PR; the user merges. (This is also the rule in the user's global `~/.claude/CLAUDE.md` — repeated here because the routine itself is the only sanctioned `main`-writer, via Actions.)
- Never put feature work on `report-data`. That branch is owned by the routine; it gets force-reset every run.
- If you change `scripts/run-brief.sh`, preserve the invariant that `report-data` always ends up exactly `main + 1 commit`, so the Actions `--ff-only` merge keeps working.

## What is auto-generated — do not hand-edit

These files are overwritten by every successful routine run. Hand edits will be wiped (and may pollute the next brief if committed by accident):

- `data/<YYYY-MM-DD>.md` — markdown source for each day's brief
- `docs/index.html` — landing page (today's brief, always rewritten)
- `docs/archive/<YYYY-MM-DD>.html` — daily archive

If a user reports "the brief is wrong", the fix is almost never to edit these files — it's to edit `routine-prompt.md` so the next run produces something better.

## Headless Claude permissions (most common foot-gun)

`scripts/run-brief.sh` invokes:

```
claude -p "$FULL_PROMPT" --add-dir "$REPO" --allowedTools "Skill WebSearch Write Edit Read Bash"
```

Do **not** "simplify" to `--permission-mode acceptEdits` — that mode silently denies `Skill` and `WebSearch` invocations in headless mode, which produces an empty-skeleton brief while the script reports success. We hit this exact bug on the first production run; see `git log --grep="unblock Skill"` for context.

The shell also injects a `Runtime context` header in front of `routine-prompt.md` content to pin the date that Claude uses for filenames. This prevents a near-midnight run from disagreeing with itself when shell computes `$DATE` before midnight but Claude completes after.

## Common operations

| Goal | Command |
|---|---|
| Trigger a brief manually (publishes!) | `bash ~/Documents/Sean/project/us-premarket-brief/scripts/run-brief.sh` |
| Watch run progress | `tail -f ~/Library/Logs/us-premarket-brief.log` (note: `claude -p` buffers output until done; a "frozen" log at "starting claude -p" is normal for 8–10 min) |
| Edit the brief's behavior | Edit `routine-prompt.md`, commit + push via PR; next run uses it |
| Edit the trigger time | Edit `~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist` (not in repo) then `launchctl unload && launchctl load` it |
| Check if scheduler is armed | `launchctl list \| grep premarket` |

There are no tests, no lint, no build step. Validation is end-to-end: run the script, look at the log, look at the published Pages URL, look at the Slack notification.

## Files that live outside the repo but the routine depends on

If something breaks unexpectedly, check these first — they're invisible to git:

- `~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist` — scheduler (recover from `launchd/` snapshot in repo; if it's been edited locally, the snapshot may be stale)
- `~/Library/Logs/us-premarket-brief.log` — runtime log
- `~/.config/us-premarket-brief/slack_webhook` — webhook URL (mode 600); if missing, Slack notifications silently skip
- `~/.claude/skills/moomoo-news-search/`, `moomoo-stock-digest/`, `moomoo-comment-sentiment/` — the data-source skills the routine calls

`README.md` documents how to recreate each of these on a fresh Mac.
