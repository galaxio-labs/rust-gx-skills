# 发布与分支约定

按**用途**把仓库分两类，发布通道不同。分类看的是「这东西怎么被消费」：被别的代码依赖的走**组件**通道，被直接运行/部署的走**制品**通道。

## 1. 组件（被依赖的库 / component）

- **只在 `main` 上开发与发布**；不设 `alpha` / `beta` 分支。
- **已发布的版本出现问题**：从 `main` 切出 **`hotfix/x.y`** 分支进行修复（`x.y` = 出问题的版本线），修完回到发布流程。
- 对应 gx（`_gal/adm.gxl` 用 `mod main : lib_ver_adm`）：
  - 发版：`gx adm v_tag` → 打 `vX.Y.Z` 并 `push --tags`。
  - 补丁：先 `gx adm v_patch`（版本补丁位 +1），再 `gx adm v_tag`。

## 2. 制品（二进制 / docker 等直接使用物）

- 设 **三个分支：`main`、`beta`、`alpha`**，成熟度递增：**`alpha` → `beta` → `main`**。
- 通道 ↔ 分支 ↔ 标签 ↔ gx：

| 成熟度 | 分支 | 标签 | gx |
| --- | --- | --- | --- |
| 最低 | `alpha` | `vX.Y.Z-alpha` | `gx adm tag_alpha` |
| 中间 | `beta` | `vX.Y.Z-beta` | `gx adm tag_beta` |
| 最高 | `main` | `vX.Y.Z` | `gx adm tag_stable` |

## 3. 提交与发布流程（按顺序）

1. **提交前**：跑该仓支持的检查命令，至少 `gx run lint`（必要时再 `gx run test`）。
2. **版本变更后**：确认所有版本号都已更新（`gx adm v_patch` / `v_feat` 改 `version.txt` 并同步 `Cargo.toml`），再跑 **`cargo test --all`**（工作区全量测试）。
   - **制品**还需**同步 `Cargo.lock`**：`gx adm v_patch` / `v_feat` 不动锁，需跑一次 `cargo update -p <本包名>`（或 `cargo check`）让锁里的版本跟上，并把 `Cargo.lock` 连同 `Cargo.toml` + `version.txt` 一起提交；**组件**锁不入库，无需此步。详见 [版本管理](version-management.md) §6。
3. **更新 changelog**（发布前必做）：写仓库根 `CHANGELOG.md`，标题读 `version.txt` 的版本 + 当天日期 —— 见 §4。
4. **提交**：`git commit` + `git push`。
5. **打标签**（在 commit / push **之后**）：
   - **组件**（在 `main`）：`gx adm v_tag`。
   - **制品**（在**对应分支**上）：`alpha` 分支 → `gx adm tag_alpha`；`beta` 分支 → `gx adm tag_beta`；`main` 分支 → `gx adm tag_stable`。
   - 这些流程会 `git tag vX.Y.Z[-beta|-alpha]` 并 `git push --tags`。

## 4. 更新 changelog（发布前必做）

发布前更新仓库根的 `CHANGELOG.md`。它是写给**使用者**看的，不是维护者的实现记录。

- **节标题 = 版本号 + 日期**：版本号取仓库根 `version.txt`（即刚 `v_patch` / `v_feat` 出来的号），日期取当天，
  形如 `## [0.1.11] - 2026-09-29`；**最新版本放最上面**（倒序）。
  - 因标题要读 `version.txt`，changelog 在**升版本之后、`commit` 之前**写。
  - 制品按通道发版时，标题里的版本带**与 tag 一致**的通道后缀，如 `## [0.1.6-alpha] - 2026-09-29`。
- **一条改动用一行**，说**给使用者带来的价值**，不写内部实现：
  - ✅ 「状态上报带上最近一次续签判定，运维可在页面上看到证书续签情况」
  - ❌ 「把 `last_renewal_json` 改成 `CASE WHEN excluded…` 保留上一次」（字段名 / SQL / 迁移号这类实现细节）
- **只列对外可见的变化**：新能力、行为变化、修复、破坏性变更。纯内部重构、测试、注释、CI 调整**不逐条写**（除非影响使用者）。
- **破坏性变更显式标出**（如 `**破坏性**：…`）。
- 小节沿用本仓既有风格（`### 新增 / 变更 / 修复 / 移除`）；没有内容的小节直接省掉。
- 文件不存在就新建：首行 `# 更新日志`，加一句「遵循 [Keep a Changelog] + [语义化版本]」的说明（参 `wist-agentd` / `wist-control` 的 `CHANGELOG.md`）。

> 顺序回顾：`gx adm v_patch|v_feat`（定版本）→ 同步 `Cargo.lock` + `cargo test --all` → 写 `CHANGELOG.md`（标题读 `version.txt`）→
> `commit`（changelog 与版本一并提交）→ `push` → 打标签。

## 5. 注意

- 打标签放在 `commit` / `push` **之后**；制品必须切到**对应分支**再打，别在 `main` 上打 `tag_alpha`。
- gx 的 `v_tag` / `tag_*` 只**打标签 + push**，**不建分支**；`alpha` / `beta` / `hotfix/x.y` 这些分支按本文约定自行切。
- 组件不要发到 `alpha` / `beta` 通道；制品的成熟度沿 `alpha → beta → main` 推进。
- 以上是通道口径，**具体走哪条以目标仓库现状与团队约定为准**；本仓改动前先看该仓库既有分支与标签。
