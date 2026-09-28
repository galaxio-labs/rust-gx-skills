#!/usr/bin/env bash
# 把本仓 skills/ 下的技能复制到 Agent 技能目录（默认 ~/.agents/skills）。
#
# 用法：
#   ./install.sh                     # 装全部技能到 ~/.agents/skills（Zed / agent）
#   ./install.sh --all               # 同上（显式）
#   ./install.sh rust-gx             # 只装某个技能
#   ./install.sh --codex             # 装到 Codex CLI（~/.codex/skills）
#   ./install.sh --claude            # 装到 Claude Code（~/.claude/skills）
#   ./install.sh --dir ~/my-skills   # 装到自定义目录
#   ./install.sh --dry-run           # 只打印将要做什么，不落盘
#
# 覆盖 env：
#   AGENT_SKILLS_DIR   --agents 的默认目标目录（默认 ${HOME}/.agents/skills）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="${SCRIPT_DIR}/skills"

usage() {
  cat <<EOF
用法：$0 [skill-name ...] [--all] [--agents|--codex|--claude] [--dir <path>] [--dry-run]

把本仓 skills/ 下的技能复制到目标技能目录。默认目标：${AGENT_SKILLS_DIR:-$HOME/.agents/skills}

参数：
  skill-name       只安装指定技能（可给多个）；不给 = 安装全部
  --all            安装全部技能（默认）

选项：
  --agents         装到 Zed / agent 技能目录（默认）
  --codex          装到 Codex CLI（\$HOME/.codex/skills）
  --claude         装到 Claude Code（\$HOME/.claude/skills）
  --dir <path>     装到自定义目录
  --dry-run        只显示将要执行的操作，不落盘
  -h, --help       显示本帮助

可覆盖 env：
  AGENT_SKILLS_DIR   --agents 的目标目录（默认 \$HOME/.agents/skills）
EOF
}

# skills/ 下每个含 SKILL.md 的子目录即一个技能。
discover_skills() {
  local dir name
  for dir in "${SKILLS_SRC}"/*/; do
    [[ -f "${dir}SKILL.md" ]] || continue
    name="$(basename "${dir%/}")"
    printf '%s\n' "${name}"
  done
}

# 把发现到的技能填进 skill_names（不用 mapfile：macOS 自带 bash 3.2 没有）。
fill_all_skills() {
  local name
  skill_names=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && skill_names+=("${name}")
  done < <(discover_skills)
}

# 读 frontmatter 的 name（目录名须与之相等）。
skill_frontmatter_name() {
  sed -n 's/^name:[[:space:]]*//p' "$1/SKILL.md" | head -n 1 | tr -d '"'"'"'[:space:]'
}

skill_names=()
target_dirs=()
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --all)
      fill_all_skills
      shift
      ;;
    --agents)
      target_dirs+=("${AGENT_SKILLS_DIR:-$HOME/.agents/skills}")
      shift
      ;;
    --codex)
      target_dirs+=("$HOME/.codex/skills")
      shift
      ;;
    --claude)
      target_dirs+=("$HOME/.claude/skills")
      shift
      ;;
    --dir)
      if [[ -z "${2:-}" ]]; then
        echo "错误：--dir 需要一个路径参数" >&2
        exit 2
      fi
      target_dirs+=("$2")
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -*)
      echo "错误：未知选项 $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      skill_names+=("$1")
      shift
      ;;
  esac
done

# 默认：安装全部技能到 ~/.agents/skills。
if [[ ${#skill_names[@]} -eq 0 ]]; then
  fill_all_skills
fi
if [[ ${#target_dirs[@]} -eq 0 ]]; then
  target_dirs+=("${AGENT_SKILLS_DIR:-$HOME/.agents/skills}")
fi

if [[ ${#skill_names[@]} -eq 0 ]]; then
  echo "错误：${SKILLS_SRC} 下没有找到任何技能（含 SKILL.md 的子目录）" >&2
  exit 1
fi

echo
echo "源：${SKILLS_SRC}"
echo "目标：${target_dirs[*]}"
[[ "$dry_run" == 1 ]] && echo "（dry-run：不落盘）"
echo

installed=0
for name in "${skill_names[@]}"; do
  src="${SKILLS_SRC}/${name}"
  if [[ ! -f "${src}/SKILL.md" ]]; then
    echo "  跳过：找不到技能 ${name}（缺 ${src}/SKILL.md）" >&2
    continue
  fi

  fm_name="$(skill_frontmatter_name "${src}")"
  if [[ -n "${fm_name}" && "${fm_name}" != "${name}" ]]; then
    echo "  警告：${name} 的 frontmatter name 是 \"${fm_name}\"，与目录名不一致（应相等）" >&2
  fi

  for base in "${target_dirs[@]}"; do
    dst="${base}/${name}"
    if [[ "$dry_run" == 1 ]]; then
      echo "  [dry-run] rm -rf ${dst} && cp -R ${src} ${dst}"
    else
      mkdir -p "${base}"
      rm -rf "${dst}"
      cp -R "${src}" "${dst}"
      echo "  [installed] ${name} → ${dst}"
    fi
    installed=$((installed + 1))
  done
done

echo
if [[ "$dry_run" == 1 ]]; then
  echo "dry-run 完成，未改动文件。"
else
  echo "完成：安装 ${installed} 项。"
fi
