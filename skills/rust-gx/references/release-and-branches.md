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
3. **提交**：`git commit` + `git push`。
4. **打标签**（在 commit / push **之后**）：
   - **组件**（在 `main`）：`gx adm v_tag`。
   - **制品**（在**对应分支**上）：`alpha` 分支 → `gx adm tag_alpha`；`beta` 分支 → `gx adm tag_beta`；`main` 分支 → `gx adm tag_stable`。
   - 这些流程会 `git tag vX.Y.Z[-beta|-alpha]` 并 `git push --tags`。

## 4. 注意

- 打标签放在 `commit` / `push` **之后**；制品必须切到**对应分支**再打，别在 `main` 上打 `tag_alpha`。
- gx 的 `v_tag` / `tag_*` 只**打标签 + push**，**不建分支**；`alpha` / `beta` / `hotfix/x.y` 这些分支按本文约定自行切。
- 组件不要发到 `alpha` / `beta` 通道；制品的成熟度沿 `alpha → beta → main` 推进。
- 以上是通道口径，**具体走哪条以目标仓库现状与团队约定为准**；本仓改动前先看该仓库既有分支与标签。
