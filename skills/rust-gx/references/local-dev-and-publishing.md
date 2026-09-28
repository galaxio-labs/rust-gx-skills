# 多 crate 联调与发布（本地 `path` ↔ registry）

## 背景

开发时经常一次改多个 crate（例：契约库 + 依赖它的组件），这时要用**本地 `path` 依赖**，改动才能一起生效、一起测试。但**发布**要给到别人（和 crates.io），就得改成引用**远程（registry）**版本。

## 本地联调：`path` 依赖

- 在**消费方**的 `Cargo.toml` 里保留两种写法，开发期启用带 `path` 的那行：

  ```toml
  #wist-contracts = { version = "0.1" }
  wist-contracts = { version = "0.1.1", path = "../wist-contracts" }
  ```

- ⚠️ **整条依赖链必须一致**：链上只要有一个节点还走 registry、而下游走 `path`，就会出现**两份同名 crate**，跨边界类型（如 `AgentConfig`、`StringKeyValue`）对不上，报错很难查。**切 path 就整条链一起切。**
- 仓里一般留了注释开关与 `# NOTE(local-dev): …` 说明；照该仓现状用，别自创第三种写法。

## 发布：按依赖顺序逐步发

- 顺序：**被依赖者先发**（叶子 → 上层）。多 crate 工作区（如 `foo-macros` + `foo`）就是按这个序逐个 `cargo publish -p`。
- 各**组件**仓有 `.github/workflows/release.yml`：
  - 推 `v*.*.*` 标签 → 建 GitHub Release + `cargo publish --token $CRATES_IO_TOKEN`。
  - 推 `v*.*.*-dryrun` 标签 → 只跑 `cargo publish --dry-run`（演练，不发）。
  - 有的仓带**幂等守卫**：先查 `index.crates.io/<crate>` 是否已有该版本，已发布就跳过。
- 所以组件发布靠**打标签**（组件用 `gx adm v_tag`，见 [发布与分支约定](release-and-branches.md)），CI 负责 publish 到 crates.io。
- **本地只排演、不真发**：本地跑 `cargo publish --dry-run`（打包 + 校验，**不上传**）；**真正的发布一律走 `.github/workflows`**（推 `v*.*.*` 标签触发）。
- 排演若报 `warning: crate <name>@<ver> already exists on crates.io index`，说明该版本已发布 → 这一步是 **no-op**；要发新内容必须先升版。

## 切回 registry（发布后必做）

- 新版本在 crates.io 就绪后，把消费方的 `path` 依赖**切回 registry**（注释掉 path 行、启用 `version` 行），按该仓的注释开关还原。
- 不切回去，源码里就一直指本地相对路径 —— 别人克隆编不过（他们没那个同级目录）。

## 顺序速查

1. **开发**：消费方切 `path`（**整条链**）。
2. **测试**：`cargo test --all`（见 [发布与分支约定](release-and-branches.md) §3）。
3. **本地排演**：按依赖序逐个 `cargo publish --dry-run`，核对打包与依赖（**不上传**）。注意它**要求工作树干净**：升版未提交会被拒 —— 先 commit 升版，或临时加 `--allow-dirty`。
4. **发布依赖**：给每个被依赖的组件打 `v_tag` 并 push → `.github/workflows/release.yml` 发到 crates.io；`-dryrun` 标签只演练。
5. **切换**：消费方去掉 `path`，改回 registry 版本。
6. **再提交/打标签**：消费方自身按发布流程发版。

## 怎么定发布顺序（推导 + 示例）

**推导**：画出「谁依赖谁」，**被依赖者先发**（拓扑序：叶子 → 上层）。查依赖：

```bash
# 单仓内看它的 wist-* 依赖
awk '/^\[dependencies\]/{f=1;next} /^\[/{f=0} f' <crate>/Cargo.toml | grep '^wist-'
```

注意：**只有组件（lib）发 crates.io**；bin（制品）走 tarball / 镜像，等依赖都上了 registry 再发。

**示例（以 `wist-agentd` 为根）**：

```
wist-contracts ─┬─> wist-metrics ─┐
                ├─> wist-validate ─┼─> wist-agentd
                └──────────────────┘
wist-shared ───────────────────────┘
```

agentd 依赖 `contracts` / `shared` / `metrics` / `validate`；`metrics`、`validate` 依赖 `contracts`；`contracts` 与 `shared` 是叶子。逐步：

1. `wist-contracts`（叶子；也是 metrics/validate 的依赖）
2. `wist-shared`（叶子）
3. `wist-metrics`（等 contracts）
4. `wist-validate`（等 contracts）
5. `wist-agentd`（**制品**：把 `path` 依赖切回 registry 后走 tarball 发布）

每一步（组件）：需要升版就 `gx adm v_patch` / `v_feat` → `gx run lint` → `cargo test --all` → `commit` + `push` → `gx adm v_tag`（CI `cargo publish`）。最后一步（agentd）：依赖都上了 crates.io 后，去掉它的 `path` 依赖改回 registry → `gx run lint` → `cargo test --all` → `push` → `gx adm tag_stable`。

## 注意

- **`--dry-run` 抓不到 crates.io 的服务端元数据校验**：缺 `description`/`license` 时本地 dry-run 会通过，**真发**才回 `400 missing or empty metadata fields`。发布前务必确认清单有 `description` 与 `license`（组件仓按兄弟仓补齐 `repository`/`homepage`/`documentation`/`readme` 等）。
- **`cargo publish`（含 `--dry-run`）要求工作树干净**：升版后未提交会被拒（`error: N files in the working directory contain changes that were not yet committed`）；排演可临时加 `--allow-dirty`，但**别用它真发**。
- **本地不真发**：`cargo publish` 的真上传只应发生在 CI（`.github/workflows/release.yml`）；本地只用 `cargo publish --dry-run` 排演。
- **依赖必须带 `version`**：`path`-only（没有 `version`）的依赖 **publish 会被拒绝**（Cargo 要求发布时每个依赖都有版本）。
- Cargo 在**上传时会自动把 `path` 依赖规范化/重写成 registry 版本**（前提是写了 `version`）——但仓里仍约定发布后**手动切回** registry，避免源码长期指向本地。
- 组件大多发到**公开的 crates.io**。
- 替代做法：同一工作区内可用 `[patch.crates-io]` 覆盖本地路径；但跨**独立仓**时，上面的注释开关更实际。
