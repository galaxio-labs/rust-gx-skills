# `.github` 工作流（按仓型的通用模板）

`.github/workflows` 与 `_gal/` 一样，是**随仓入库的通用模板**：先按仓型选一套，拷贝即用，只替换与**产物名**相关的地方。

| 仓型 | 工作流 | 用途 |
| --- | --- | --- |
| **组件（lib）** | `ci.yml` + `release.yml` | CI 检查；发布 `cargo publish` 到 crates.io |
| **制品（bin / docker）** | `build-and-test.yml` + `release.yml` | CI 检查；发布多平台产物（tarball / docker） |

另各仓有 `.github/dependabot.yml`（cargo + github-actions 依赖更新）。触发时机与打标签的关系见 [发布与分支约定](release-and-branches.md)、[多 crate 联调与发布](local-dev-and-publishing.md)。

---

## A. 组件（lib）

> 来源：`wist-contracts/.github`（**组件**；其余 lib 仓逐字一致）。

### `ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main, develop, release/*]
  pull_request:
    branches: [main, develop, release/*]

env:
  CARGO_TERM_COLOR: always

jobs:
  test:
    name: Test
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        rust: [stable, beta]
    steps:
      - uses: actions/checkout@v7
      - uses: dtolnay/rust-toolchain@master
        with:
          toolchain: ${{ matrix.rust }}
      - uses: Swatinem/rust-cache@v2
      - run: cargo test --all-features -- --test-threads=1

  fmt:
    name: Rustfmt
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt
      - run: cargo fmt --all -- --check

  clippy:
    name: Clippy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy
      - uses: Swatinem/rust-cache@v2
      - run: cargo clippy --all-targets --all-features -- -D warnings

  security:
    name: Security Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: cargo generate-lockfile
      - uses: rustsec/audit-check@v2.0.0
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

  coverage:
    name: Code Coverage
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: llvm-tools-preview
      - uses: Swatinem/rust-cache@v2
      - uses: taiki-e/install-action@cargo-llvm-cov

      - name: Generate coverage report
        run: |
          cargo llvm-cov --all-features --workspace --lcov --output-path lcov.info -- --test-threads=1
          echo "Coverage file generated:"
          ls -la lcov.info
          echo "File size: $(wc -c < lcov.info) bytes"

      - name: Upload to Codecov
        uses: codecov/codecov-action@v7
        with:
          files: ./lcov.info
          flags: unittests
          name: coverage-${{ github.ref_name }}
          token: ${{ secrets.CODECOV_TOKEN }}
          fail_ci_if_error: ${{ github.event_name == 'push' }}
          verbose: true
```

### `release.yml`

推 `v*.*.*`（或 `v*.*.*-dryrun`）标签触发，`cargo publish` 到 crates.io。

```yaml
name: Release

on:
  push:
    tags:
      - "v*.*.*"
      - "v*.*.*-dryrun"

jobs:
  create-release:
    name: Create GitHub Release
    if: ${{ startsWith(github.ref, 'refs/tags/v') }}
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v7
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v3
        with:
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  publish-crate:
    name: Publish to crates.io
    runs-on: ubuntu-latest
    if: ${{ startsWith(github.ref, 'refs/tags/v') }}
    needs: create-release
    steps:
      - uses: actions/checkout@v7
      - uses: dtolnay/rust-toolchain@stable
      - name: Cargo publish (dry run)
        if: ${{ endsWith(github.ref, '-dryrun') }}
        run: cargo publish --dry-run
      - name: Cargo publish
        if: ${{ !endsWith(github.ref, '-dryrun') }}
        run: cargo publish --token ${{ secrets.CRATES_IO_TOKEN }}
```

> 多 crate 工作区要**按依赖序**逐个 `cargo publish -p <crate>`，并可用「查 `index.crates.io` 已发布就跳过」的幂等守卫。

---

## B. 制品（bin / docker）

> 来源：`wist-agentd/.github`（**制品**）。其 `build-and-test.yml` 与 `wist-gateway` / `wist-center` 逐字一致；`release.yml` 各仓只差**产物名**。

### `build-and-test.yml`

```yaml
name: Build & Test

on:
  push:
    branches:
      - "*"
  pull_request:
    types: [opened, reopened]
    branches:
      - "*"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-24.04, macos-14]
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Install Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          toolchain: stable

      - name: Cargo fmt
        run: cargo fmt --check

      - name: Cargo build (release)
        run: cargo build --release --all

      - name: Cargo test (release)
        run: cargo test --release --all

  coverage:
    name: Code Coverage
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Install Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          toolchain: stable
          components: llvm-tools-preview

      - uses: Swatinem/rust-cache@v2

      - name: Install cargo-llvm-cov
        uses: taiki-e/install-action@cargo-llvm-cov

      - name: Generate coverage report
        run: |
          cargo llvm-cov --all-features --workspace --lcov --output-path lcov.info -- --test-threads=1
          echo "Coverage file generated:"
          ls -la lcov.info
          echo "File size: $(wc -c < lcov.info) bytes"

      - name: Upload to Codecov
        uses: codecov/codecov-action@v7
        with:
          files: ./lcov.info
          flags: unittests
          name: coverage-${{ github.ref_name }}
          token: ${{ secrets.CODECOV_TOKEN }}
          fail_ci_if_error: ${{ github.event_name == 'push' }}
          verbose: true
```

### `release.yml`

推 `v*.*.*` 标签触发，多平台原生编译 → 打 tarball → 建 GitHub Release。**把 `<bin-name>` / artifact 名替换成本仓的产物**。

```yaml
name: Release

on:
  push:
    tags: ["v*.*.*"]

permissions:
  contents: read

jobs:
  build-matrix:
    name: Build ${{ matrix.target }}
    runs-on: ${{ matrix.os }}
    permissions:
      contents: read
      attestations: write
      id-token: write
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: ubuntu-24.04
            target: x86_64-unknown-linux-gnu
          - os: ubuntu-24.04-arm
            target: aarch64-unknown-linux-gnu
          - os: macos-14
            target: aarch64-apple-darwin
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Install Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          toolchain: stable
          targets: ${{ matrix.target }}

      - name: Cargo build
        run: cargo build --release --target ${{ matrix.target }}

      - name: Package artifacts
        run: |
          set -euo pipefail
          ARTIFACT="<bin-name>-${{ github.ref_name }}-${{ matrix.target }}"
          mkdir -p artifacts
          cp -av "target/${{ matrix.target }}/release/<bin-name>" artifacts/
          tar -czf "${ARTIFACT}.tar.gz" artifacts

      - uses: actions/upload-artifact@v7
        with:
          name: <bin-name>-${{ github.ref_name }}-${{ matrix.target }}
          path: <bin-name>-${{ github.ref_name }}-${{ matrix.target }}.tar.gz
          if-no-files-found: error
          retention-days: 7

  release:
    needs: [build-matrix]
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Download artifacts
        uses: actions/download-artifact@v8
        with:
          path: artifacts
          pattern: <bin-name>-*
          merge-multiple: true

      - name: Release
        uses: softprops/action-gh-release@v3
        with:
          name: ${{ github.ref_name }}
          tag_name: ${{ github.ref_name }}
          generate_release_notes: true
          files: artifacts/*.tar.gz
```

> **docker 制品**（如某仓的 gateway）会在这套基础上**再加一个 `docker` 任务**：多平台镜像推到 `ghcr.io` 与国内镜像源（TCR）。要点：
> - 预发布 tag（`vX.Y.Z-alpha` / `-beta` / `-rc`）**只推该 tag，不覆盖 `:latest`**（`v*.*.*` 的触发也会匹配这些 tag）。
> - 需要 `packages: write` 与镜像仓库登录 secrets。

---

## `dependabot.yml`（各仓一份）

```yaml
version: 2

updates:
  - package-ecosystem: cargo
    directory: "/"
    schedule:
      interval: weekly
      day: monday
      time: "09:00"
      timezone: Asia/Shanghai
    open-pull-requests-limit: 10
    labels:
      - "📦 dependencies"

  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: monthly
    open-pull-requests-limit: 5
    labels:
      - "📦 dependencies"
      - "ci"
```

---

## 注意

- **模板按仓型选一套**：lib 用 `ci.yml` + crates.io 版 `release.yml`；bin 用 `build-and-test.yml` + tarball 版 `release.yml`。别混用。
- **只改产物名**：bin 的 `release.yml` 里 `<bin-name>` / artifact 名是唯一需要按仓替换的东西。
- 需要的 secrets：`CODECOV_TOKEN`（覆盖）、`CRATES_IO_TOKEN`（publish）、镜像仓库凭据（docker）。
- **真发布只走这里**：`cargo publish` / tarball / 镜像都由 workflow 在推标签时执行；**本地只 `cargo publish --dry-run` 排演，不在本地真发**。
- 触发是**标签驱动**：发布 = 打 `vX.Y.Z`（见 [发布与分支约定](release-and-branches.md)）；多 crate 的依赖序与排演见 [多 crate 联调与发布](local-dev-and-publishing.md)。
