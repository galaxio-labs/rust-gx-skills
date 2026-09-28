---
name: rust-gx
description: 用 gx（Galaxy Flow CLI）开发与构建 Rust 项目——新项目以 `gx init project --path rust` 初始化标准 `_gal/` 工作区；日常构建、检查、测试走 `gx run`（`_gal/work.gxl` 的 `build/lint/test`，环境 `-e debug|release`）；版本以仓库根 `version.txt` 为权威，用 `gx adm` 的 `v_patch/v_feat` 升级，并经 `#@gxl:set(version)` 同步回 `Cargo.toml` 等文件，git 标签走 `gx adm`（组件用 `v_tag`，制品用 `tag_stable|tag_beta|tag_alpha`）；发布通道按用途分（组件只在 `main`、制品 `alpha→beta→main`、已发布版本出问题走 `hotfix/x.y`）；多 crate 联调用本地 `path`、发布时按依赖序切回 registry 发到 crates.io；`.github` 工作流按仓型套用通用模板（lib 发 crates.io、bin 出制品）；`_gal` 模块更新用 `gx mod update`。适用于带 `_gal/` 目录的 Rust 仓、新建 Rust 项目，以及需要构建、检查、测试、发版、版本同步、本地多 crate 联调或调整 `_gal` 工作流的任务。
---

# Rust 项目（gx / _gal）

gx 是 Galaxy Flow 的统一 CLI，把「执行工作流、执行管理流、项目初始化、模块更新、文档查看」收敛到一个命令。Rust 项目固定用 `_gal/` 目录承载工作流。

## 工作方式

1. 先读目标仓库的 `AGENTS.md`、现有 `_gal/` 与 `Cargo.toml`，沿用既有 flow 与环境名；不要用模板覆盖已定制或引用了远程模块的 `_gal/`。
2. **新建项目初始化**：
   - 首次使用先 `gx init env`（初始化本机 Galaxy 环境）。
   - `gx init project --path rust` —— 从默认模板仓 `https://github.com/galaxio-labs/prj-tpl.git` 的 `rust` 子目录拉取标准 `_gal/`。
   - ⚠️ 真实子命令是 **`project`**、真实 flag 是 **`--path`**；口语里的 `gx init proj --tpl rust` 会报 `unrecognized subcommand`。另有 `--repo` / `--branch` / `--tag`（`--branch` 与 `--tag` 互斥）。
   - 无参 `gx init project` 只建基础 `_gal/{work,adm}.gxl`（**不含** rust 模板）；离线或拉不到模板时，按 [标准 `_gal` 模板](references/rust-template.md) 手工补齐。
3. **日常构建/检查/测试走 `gx run`**（读 `_gal/work.gxl`；环境 `-e debug|release`，默认 `default`=debug）：
   - `gx run` —— 不传 flow 时列出可用 flow/env。
   - `gx run build -e debug` / `gx run build -e release` —— 版本同步 + `cargo build` + `cargo test` + 把产物拷到 `~/bin`。
   - `gx run lint` —— `cargo fmt` + `cargo fix --allow-dirty` + `cargo clippy --all-targets --all-features -- -D warnings`。
   - `gx run test` / `gx run conf`。
4. **版本与发版走 `gx adm`**（读 `_gal/adm.gxl`）：
   - `gx adm` —— 列出管理流。
   - `gx adm v_patch`（bugfix +1）/ `gx adm v_feat`（feature +1）—— 改 `version.txt`，并在退出时同步进 `Cargo.toml`。
   - `gx adm tag_stable` / `tag_beta` / `tag_alpha`（**制品**）或 `gx adm v_tag`（**组件**）—— 打 `vX.Y.Z[-beta|-alpha]` 并 `git push --tags`。**会 push 远程**，只在明确要发版时做。
   - **发布通道按用途分**：组件只在 `main` 上开发/发布；制品走 `alpha → beta → main`；已发布版本出问题从 `main` 切 `hotfix/x.y` 修复。详见 [发布与分支约定](references/release-and-branches.md)。
   - **版本以 `version.txt` 为权威**，用 `v_patch`/`v_feat` 升级、经 `#@gxl:set(version)` 同步进文件；组件/制品该选哪个 `ver_adm`——见 [版本管理](references/version-management.md)。
5. `gx mod update` —— 更新本地 `_gal` 声明的模块。
6. 需要 gx / GXL 细节时查内置文档：`gx doc` 列主题；`gx doc gx`、`gx doc gxl`、`gx doc gx.cmd`、`gx doc gx.patch_file`、`gx doc gx.ver`。
7. 需要本 Skill 的细节时读对应 reference：[标准 `_gal` 模板](references/rust-template.md)、[版本管理](references/version-management.md)、[发布与分支约定](references/release-and-branches.md)、[多 crate 联调与发布](references/local-dev-and-publishing.md)、[GitHub 工作流](references/github-workflows.md)、[仓库卫生](references/repo-hygiene.md)。

## 硬约束

- **构建/测试默认走 gx，不直接 `cargo`**：gx 会带版本同步并把产物落到 `~/bin`。
- **`version.txt` 是版本唯一来源**；`Cargo.toml` 里的 `version = "x.y.z" #@gxl:set(version)` marker **不要删**（`gx.patch_file` 靠它定位）。任何 `gx adm` 跑完都会把 `version.txt` 对齐回 `Cargo.toml`。
- `_gal/work.gxl` 的 `prj_key` 要与项目/产物名一致；`_pub_local` 负责把二进制拷到 `${HOME}/bin`，**新增二进制要改这里**。
- `gx run lint` 会执行 `cargo fmt`（**会改文件**）与 `cargo fix --allow-dirty`，注意它可能改动工作区。
- **`_gal/` 要入库**（工作流定义随仓库走）；**生成物不入库**：`_gal/.report/`、`.run*`。别把整个 `_gal/` 写进 `.gitignore`。见 [仓库卫生](references/repo-hygiene.md)。
- **发布按用途分通道**：组件只在 `main`（不到 `alpha`/`beta`）；制品沿 `alpha → beta → main` 推进；已发布版本的问题走 `hotfix/x.y` 修复。`tag_*` 只打标签，**不建分支**。
- **提交/发布顺序**：提交前跑 `gx run lint`（该仓支持的检查命令）→ 版本变更后跑 `cargo test --all` → `commit` + `push` → 最后打标签（组件 `gx adm v_tag`；制品 `gx adm tag_alpha/tag_beta/tag_stable`，**在对应分支上**）。**本地只 `cargo publish --dry-run` 排演，真发布走 `.github/workflows`。**
- **多 crate 联调 ↔ 发布**：开发时用本地 `path`（**整条链一起切**，否则会出现两份同名 crate、跨边界类型对不上）；发布时按**依赖顺序**先发被依赖者（组件打 `v_tag`，CI `cargo publish` 到 crates.io），再把消费方**切回 registry**。见 [多 crate 联调与发布](references/local-dev-and-publishing.md)。
- **`.github/` 也入库**，且按仓型套用通用模板：**组件（lib）** 用 `ci.yml` + crates.io 版 `release.yml`（参 `wist-contracts/.github`）；**制品（bin）** 用 `build-and-test.yml` + tarball 版 `release.yml`（参 `wist-agentd/.github`，只改产物名）。见 [GitHub 工作流](references/github-workflows.md)。
- 不做 `gx adm tag_*`、`gx self update` 这类改动远程或安装目录的动作，除非用户明确要求。

## 规则优先级

1. 用户当前要求与目标仓库 `AGENTS.md`。
2. 仓库现有 `_gal/` 与 `Cargo.toml` 结构。
3. gx/GXL 约定与版本同步不变量（`version.txt` → `Cargo.toml`）。
4. 仓库既有的质量门禁（以 `gx run lint` / `gx run test` 为准）。

## 输出要求

- 说明改动涉及哪些 `_gal` 文件、版本号变化，以及实际运行了哪些 gx 命令与结果。
- 手工补齐 `_gal` 或偏离模板时，说明原因与范围。
- 报错时给出原命令与 gx 的原样输出（尤其 `unrecognized subcommand`、`marker` 相关报错），不要转述成猜测。
