# 版本管理（`version.txt` 为权威 + gx ver 同步）

## 1. 权威来源：仓库根的 `version.txt`

- 仓库根 `version.txt` 保存当前版本（纯文本，如 `0.1.3`），是**最权威**的版本信息。
- 其它文件里的版本（如 `Cargo.toml`）都是它的**派生**，不单独手改。

## 2. 升级入口：`gx adm v_patch` / `v_feat`

- `gx adm` 读 `_gal/adm.gxl`：**进入**自动 `ver.use`（读 `version.txt`），**退出**自动 `ver.syn_file`（把版本回写文件）。
- 所以**任何 `gx adm` 跑完都会做一次同步**。变更版本用：
  - `gx adm v_patch` —— 补丁位 +1（bugfix）；
  - `gx adm v_feat` —— 次版本位 +1（feature）。
- `gx.ver` 的 `inc` 语义：`null` 只读不改 / `build` 只动 build 号 / `bugfix` 补丁 +1 / `feature` 次版本 +1。

## 3. 同步到文件：`#@gxl:set(version)` 标记

- 模板的退出流把 `SYN_FILE` 指到 `Cargo.toml`，由 `ver.gxl` 调用：

  ```
  gx.patch_file(file: "${SYN_FILE}", action: "set", marker: "version", value: r#""${VERSION}""#);
  ```

- 目标文件里对应那一行必须带 marker：

  ```toml
  version = "0.1.3" #@gxl:set(version)
  ```

  `gx.patch_file` 靠 marker 定位，**不要删或改写**。
- 常见落点：`Cargo.toml` 的 `[package].version`，或工作区的 `[workspace.package].version`。
- 要同步**多个**文件：为每个文件各配一个退出流，或把 `SYN_FILE` 指向该文件（同样带 `#@gxl:set(version)`）。

## 4. 组件 vs 制品：`adm.gxl` 选哪个 `ver_adm`

`vfm.gxl` 提供两个变体，`adm.gxl` 用 `mod main : <变体>` 选一个，菜单随之不同：

| 用途 | `adm.gxl` | 可用管理流 | 稳定标签 |
| --- | --- | --- | --- |
| **组件**（library） | `mod main : lib_ver_adm` | `v_patch` / `v_feat` / `v_tag` | `v_tag` → `vX.Y.Z` |
| **制品**（bin / docker） | `mod main : sys_ver_adm` | `v_patch` / `v_feat` / `tag_stable` / `tag_beta` / `tag_alpha` | `tag_stable` → `vX.Y.Z`（另有 beta/alpha） |

> 注：**组件仓的标签流不一定叫 `v_tag`** —— 有的仓 `lib_ver_adm` 里仍叫 `tag_stable`。以该仓 `gx adm` 列出的菜单为准。

这与「发布通道」一致：组件只到 `main`，制品才走 `alpha → beta → main`。见 [发布与分支约定](release-and-branches.md)。

> **锁文件归属**：**组件**（library）**不**入库 `Cargo.lock`；**制品**（bin / docker）**要**入库 `Cargo.lock`，且版本变更时锁里的本包版本必须与 `Cargo.toml` 同步（见 §6）。

## 5. 参考实现

本机一份**组件**示例：`x-topology/wist/wist-contracts`

- `version.txt` 保存版本；`Cargo.toml` 的版本行带 `#@gxl:set(version)`；
- `_gal/adm.gxl` 用 `mod main : lib_ver_adm`，菜单是 `v_patch` / `v_feat` / `v_tag`。

## 6. 注意

- **别手改** `version.txt` 或带 marker 的版本行来“升版本” —— 走 `gx adm`，否则 `version.txt` 与文件会分叉。
- 打标签前先定版本（`v_patch` / `v_feat`），否则 `tag_*` / `v_tag` 用的是旧号。
- marker 只认 `@gxl:set(...)` 这类注释形式；不要把 marker 写进被同步行以外的位置。
- **制品升版本后要同步并提交 `Cargo.lock`**：`gx adm v_patch` / `v_feat` **只改 `Cargo.toml` 与 `version.txt`，不动 `Cargo.lock`**，锁里的本包版本会落后。补一次 `cargo update -p <本包名>`（或 `cargo check` / `cargo build`）让锁版本跟上，再连同 `Cargo.toml` + `version.txt` + `Cargo.lock` 一起提交。打 tag 前工作区必须干净、三者版本一致。
  - **组件**：锁不入库，无需上述步骤；
  - **制品**：锁入库，**必须**同步，否则入库的锁与 `Cargo.toml` 分叉（构建未必报错，但历史的可复现性被破坏）。
