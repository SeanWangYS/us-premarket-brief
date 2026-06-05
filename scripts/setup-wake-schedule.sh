#!/usr/bin/env bash
# Schedule a daily pre-trigger wake so the premarket brief fires ON TIME.
#
# Why this exists
# ---------------
# The brief's launchd job is set for MTWRF 20:30 Asia/Taipei. But launchd's
# StartCalendarInterval does NOT wake a sleeping Mac — if the laptop is asleep
# (or idle and about to sleep) at 20:30, the job only runs whenever the Mac next
# wakes. The log has caught this repeatedly: a 20:30 job that didn't start until
# 23:23, another that limped into the next morning. For a *premarket* brief,
# running hours late means stale data.
#
# This registers a repeating power event that wakes (or powers on) the Mac at
# 20:28 — 2 min before the launchd trigger — so the job fires on schedule and
# Wi-Fi has a moment to reconnect before the first `git fetch`.
#
# This is the SYSTEM-LEVEL half of the reliability fix. The in-script half
# (caffeinate, which keeps the Mac awake THROUGH the run so it can't sleep
# mid-brief) lives in run-brief.sh and needs no setup.
#
# Notes
# -----
# - Requires sudo (pmset schedules are system-wide).
# - `pmset repeat` REPLACES any existing repeating schedule. By default there is
#   none; if you rely on other repeating power events, merge them manually.
# - Re-run after a macOS major upgrade or when moving to a new Mac (this is a
#   system setting, not stored in the repo's git history).
# - Inspect:        pmset -g sched
# - Cancel later:   sudo pmset repeat cancel
set -euo pipefail

WAKE_TIME="20:28:00"   # 2 min before the launchd 20:30 trigger
DAYS="MTWRF"           # Mon-Fri, matching the launchd StartCalendarInterval

echo "Registering repeating wake: ${DAYS} at ${WAKE_TIME} (wakeorpoweron)…"
sudo pmset repeat wakeorpoweron "${DAYS}" "${WAKE_TIME}"

echo
echo "Done. Current scheduled power events:"
pmset -g sched
