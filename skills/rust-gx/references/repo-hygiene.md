# 仓库卫生：`_gal` 入库、生成物不入库

## `_gal/` 要入库

`_gal/` 里的**工作流定义必须入库**（它是项目定义的一部分，团队共享同一套）：

```
_gal/work.gxl       # gx run 入口
_gal/adm.gxl        # gx adm 入口
_gal/rust.gxl       # rust_flow / rust_env
_gal/ver.gxl        # mod ver
_gal/vfm.gxl        # ver_adm
_gal/project.toml   # 占位
```

## 生成物不入库

- **`_gal/.report/`** —— 每次任务运行生成的报告（`task_<时间>.yaml`）。**不入库。**
- **`.run.gxl`**（及 `.run*`）—— 运行期状态 / 临时产物。**不入库。**
- 其它常规生成物：`/target`。
- **`Cargo.lock` 按仓型**：**制品（bin / 可执行）要入库**（锁住交付时用的确切依赖）；**组件（lib）不入库**（写进 `.gitignore`，交由消费方自行解析）。

## 推荐 `.gitignore`

```gitignore
/target
.report
.run*
```

- `.report` **不带前导斜杠** → 匹配任意层级，所以正好覆盖 `_gal/.report/`。
- `.run*` 覆盖 `.run.gxl` 这类运行期文件。

## 反例（别这么做）

- ❌ 把**整个 `_gal/`** 写进 `.gitignore`（例如一行 `_gal/`）：会把工作流定义也一起排除。结果别人克隆下来没有 `_gal/`，`gx run` / `gx adm` 直接跑不起来。
- ✅ 只忽略 `_gal/` 下的**生成子目录**（`.report`），保留 gxl 与 `project.toml`。

## 自检

```bash
git ls-files _gal                        # 期望：列出 6 个文件（work/adm/rust/ver/vfm.gxl + project.toml）
git check-ignore _gal/work.gxl           # 期望：无输出（= 未被忽略）
git check-ignore _gal/.report            # 期望：命中 .report 规则
git ls-files Cargo.lock                  # 制品：应列出；组件：应为空
git check-ignore Cargo.lock              # 制品：不忽略；组件：命中 Cargo.lock 规则
```
