# rust-gx-skills

面向 Rust 项目的 Agent 技能集，围绕 **gx（Galaxy Flow CLI）** 与标准 `_gal/` 工作区。

## 安装

```sh
./install.sh                 # 装全部技能到 ~/.agents/skills（Zed / agent）
./install.sh rust-gx         # 只装指定技能
./install.sh --codex         # 装到 Codex CLI（~/.codex/skills）
./install.sh --claude        # 装到 Claude Code（~/.claude/skills）
./install.sh --dir ~/my-skills
./install.sh --dry-run
```

可用 `AGENT_SKILLS_DIR` 覆盖 `--agents` 的默认目标目录。

## 技能

| 技能 | 说明 |
|---|---|
| [`rust-gx`](./skills/rust-gx/SKILL.md) | 用 gx 开发/构建/检查/测试/发版 Rust 项目：`gx init project --path rust` 初始化 `_gal/`，`gx run build\|lint\|test`，`gx adm v_patch/v_feat/v_tag/tag_*` 管版本与发布，多 crate 的 `path` 联调与按依赖序发 crates.io，`.github` 工作流模板。 |

## 结构

```text
skills/<skill-name>/SKILL.md      技能入口（frontmatter: name/description）
skills/<skill-name>/references/   按需加载的参考文档
install.sh                        复制技能到目标技能目录
```

## 添加新技能

1. 新建 `skills/<name>/SKILL.md`，frontmatter 的 `name` 须与目录名一致。
2. 细节放进 `skills/<name>/references/*.md`，在 `SKILL.md` 里链接。
3. `./install.sh` 会自动发现并安装。
