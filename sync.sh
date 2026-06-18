#!/bin/sh
# Sync: keep the local copy current AND publish local work.
# Run from anywhere inside the repo, any time: `./sync.sh` (git-bash on Windows is fine).
#
# What it does, in order:
#   1. PULL  - rebase onto origin/master (autostash carries uncommitted edits across the pull)
#   2. COMMIT - if anything local is uncommitted, commit it with a dated sync message
#   3. PUSH  - publish (the .githooks/post-commit hook also pushes on every normal commit)
#
# New clone setup (once): git config core.hooksPath .githooks

set -e
cd "$(git rev-parse --show-toplevel)"

echo "[sync] pulling origin/master (rebase, autostash)..."
git pull --rebase --autostash origin master

if [ -n "$(git status --porcelain)" ]; then
  files=$(git status --porcelain | wc -l | tr -d ' ')
  echo "[sync] committing $files local change(s)..."
  git add -A
  git commit -m "sync $(date +%Y-%m-%d): $files file(s) updated locally"
else
  echo "[sync] no local changes to commit."
fi

# push anything ahead of origin (covers commits made while offline)
if [ -n "$(git log origin/master..HEAD --oneline 2>/dev/null)" ]; then
  echo "[sync] pushing..."
  git push origin master
else
  echo "[sync] nothing to push."
fi

echo "[sync] done. local and origin are current."
