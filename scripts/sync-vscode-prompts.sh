#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SOURCE_TARBALL="$TMP_DIR/godot-studio-skills.tar.gz"
SOURCE_URL="https://codeload.github.com/Joelnicolass/godot-studio-skills/tar.gz/refs/heads/main"

ROOT_SKILLS_DIR="$REPO_ROOT/skills"
ROOT_COMMANDS_DIR="$REPO_ROOT/commands"
GH_SKILLS_DIR="$REPO_ROOT/.github/skills"
GH_PROMPTS_DIR="$REPO_ROOT/.github/prompts"
VSCODE_PROMPTS_DIR="$REPO_ROOT/.vscode/prompts"

echo "Downloading godot-studio-skills..."
curl -fsSL "$SOURCE_URL" -o "$SOURCE_TARBALL"
tar -xzf "$SOURCE_TARBALL" -C "$TMP_DIR"
SOURCE_ROOT="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'godot-studio-skills-*' | head -n 1)"
if [[ -z "${SOURCE_ROOT:-}" ]]; then
  echo "Could not find extracted godot-studio-skills root." >&2
  exit 1
fi

SKILLS_SRC="$SOURCE_ROOT/skills"
COMMANDS_SRC="$SOURCE_ROOT/commands"

rm -rf "$ROOT_SKILLS_DIR" "$ROOT_COMMANDS_DIR" "$GH_SKILLS_DIR" "$GH_PROMPTS_DIR" "$VSCODE_PROMPTS_DIR"
mkdir -p "$ROOT_SKILLS_DIR" "$ROOT_COMMANDS_DIR" \
  "$GH_SKILLS_DIR" \
  "$GH_PROMPTS_DIR/skills" "$GH_PROMPTS_DIR/commands" \
  "$VSCODE_PROMPTS_DIR/skills" "$VSCODE_PROMPTS_DIR/commands"

echo "Copying base skills to root and GitHub metadata..."
while IFS= read -r skill_dir; do
  skill_name="$(basename "$skill_dir")"
  mkdir -p "$ROOT_SKILLS_DIR/$skill_name" "$GH_SKILLS_DIR/$skill_name"
  cp "$skill_dir/SKILL.md" "$ROOT_SKILLS_DIR/$skill_name/SKILL.md"
  cp "$skill_dir/SKILL.md" "$GH_SKILLS_DIR/$skill_name/SKILL.md"

  cp "$skill_dir/SKILL.md" "$GH_PROMPTS_DIR/skills/$skill_name.md"
  cp "$skill_dir/SKILL.md" "$VSCODE_PROMPTS_DIR/skills/$skill_name.md"
done < <(find "$SKILLS_SRC" -mindepth 1 -maxdepth 1 -type d | sort)

echo "Copying command metadata..."
while IFS= read -r command_file; do
  command_name="$(basename "$command_file" .md)"
  cp "$command_file" "$ROOT_COMMANDS_DIR/$command_name.md"

  title_line="$(grep -m1 -E '^[[:space:]]*#' "$command_file" | sed -E 's/^[[:space:]]*#+[[:space:]]*//' || true)"
  description="${title_line:-Slash command /$command_name imported from godot-studio-skills.}"

  command_skill_dir="$GH_SKILLS_DIR/$command_name"
  mkdir -p "$command_skill_dir"
  {
    echo "---"
    echo "name: $command_name"
    echo "description: $description"
    echo "user-invocable: true"
    echo "disable-model-invocation: true"
    echo "---"
    echo
    cat "$command_file"
  } > "$command_skill_dir/SKILL.md"

  cp "$command_file" "$GH_PROMPTS_DIR/commands/$command_name.md"
  cp "$command_file" "$VSCODE_PROMPTS_DIR/commands/$command_name.md"
done < <(find "$COMMANDS_SRC" -mindepth 1 -maxdepth 1 -type f -name '*.md' | sort)

base_skill_count="$(find "$SKILLS_SRC" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
command_count="$(find "$COMMANDS_SRC" -mindepth 1 -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
total_skill_count="$(find "$GH_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
root_skill_count="$(find "$ROOT_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
root_command_count="$(find "$ROOT_COMMANDS_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"

echo "Done."
echo "Base skills: $base_skill_count"
echo "Command-skills: $command_count"
echo "Root skills: $root_skill_count"
echo "Root commands: $root_command_count"
echo "Total .github/skills dirs: $total_skill_count"
