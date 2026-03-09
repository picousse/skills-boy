#!/usr/bin/env bash
# update.sh — Pull all upstream skill repos and sync symlinks into this hub.
#
# Usage:  ./update.sh
#
# After running, ~/.copilot/skills and ~/.gemini/skills should both point to
# the skills/ directory in this repo so that all tools stay in sync automatically.
#
# Initial setup (run once):
#   ln -sfn "$(pwd)/skills" ~/.copilot/skills
#   ln -sfn "$(pwd)/skills" ~/.gemini/skills

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_HUB="$SCRIPT_DIR/skills"

# ---------------------------------------------------------------------------
# Upstream repos: add/remove entries here as needed.
# Each entry is "repo_path:skills_subdir"
# ---------------------------------------------------------------------------
REPOS=(
  "$HOME/Software/biolizard-genai-skills:skills"
  "$HOME/Software/ai-labs-claude-skills:packages/skills"
)

# ---------------------------------------------------------------------------
# 1. Pull each upstream repo
# ---------------------------------------------------------------------------
echo "==> Pulling upstream repos..."
for entry in "${REPOS[@]}"; do
  repo="${entry%%:*}"
  if [[ -d "$repo/.git" ]]; then
    echo "    git pull  $repo"
    git -C "$repo" pull --ff-only 2>&1 | sed 's/^/        /'
  else
    echo "    [skip] not a git repo: $repo"
  fi
done

# ---------------------------------------------------------------------------
# 2. Add symlinks for any new skill directories found in upstream repos
# ---------------------------------------------------------------------------
echo ""
echo "==> Syncing skill symlinks..."
for entry in "${REPOS[@]}"; do
  repo="${entry%%:*}"
  subdir="${entry##*:}"
  src="$repo/$subdir"

  if [[ ! -d "$src" ]]; then
    echo "    [skip] skills dir not found: $src"
    continue
  fi

  while IFS= read -r -d '' skill_dir; do
    skill_name="$(basename "$skill_dir")"
    target="$SKILLS_HUB/$skill_name"
    if [[ ! -e "$target" && ! -L "$target" ]]; then
      ln -s "$skill_dir" "$target"
      echo "    + $skill_name"
    fi
  done < <(find "$src" -mindepth 1 -maxdepth 1 -type d -print0)
done

# ---------------------------------------------------------------------------
# 3. Remove dangling symlinks (skill was removed from an upstream repo)
# ---------------------------------------------------------------------------
echo ""
echo "==> Removing dangling symlinks..."
while IFS= read -r -d '' link; do
  if [[ ! -e "$link" ]]; then
    echo "    - $(basename "$link") (target gone)"
    rm "$link"
  fi
done < <(find "$SKILLS_HUB" -maxdepth 1 -type l -print0)

# ---------------------------------------------------------------------------
# 4. Verify tool config symlinks exist
# ---------------------------------------------------------------------------
echo ""
echo "==> Checking tool config symlinks..."
for config_link in "$HOME/.copilot/skills" "$HOME/.gemini/skills"; do
  if [[ -L "$config_link" ]]; then
    target="$(readlink "$config_link")"
    if [[ "$target" == "$SKILLS_HUB" ]]; then
      echo "    OK  $config_link -> $target"
    else
      echo "    WARN  $config_link points to $target (expected $SKILLS_HUB)"
    fi
  else
    echo "    MISSING  $config_link is not a symlink — run setup once:"
    echo "             ln -sfn \"$SKILLS_HUB\" \"$config_link\""
  fi
done

echo ""
echo "Done."
