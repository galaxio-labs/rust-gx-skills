# 标准 `_gal` 模板（Rust）

`gx init project --path rust` 从默认模板仓 `https://github.com/galaxio-labs/prj-tpl.git` 的 `rust` 子目录生成下面前 6 个文件。模板在各项目里**内容一致**，唯一随项目变的是 `work.gxl` 里的 `prj_key` 与 `_pub_local` 里的产物名。离线或模板仓库不可达时，按本文手工重建。

## 目录

```
_gal/
  work.gxl        # gx run 入口：envs + conf/build/lint/test
  adm.gxl         # gx adm 入口：版本与打标签
  rust.gxl        # 复用模块：rust_flow(lint/build) + rust_env
  ver.gxl         # 复用模块：mod ver（use/build/patch/feature/syn_file）
  vfm.gxl         # 复用模块：ver_adm（v_patch/v_feat/tag_*）
  project.toml    # 占位（0 字节）
version.txt       # 版本唯一来源，如 0.1.0
Cargo.toml        # 版本行带 marker：version = "0.1.0" #@gxl:set(version)
```

说明：

- `extern mod <name> { path = "@{PATH}"; }` 引入的是**同目录**（`_gal/`）的兄弟 `.gxl`。
- `gx run` 默认读 `./_gal/work.gxl`，`gx adm` 默认读 `./_gal/adm.gxl`。
- 把 `<prj-key>` 替换为项目名；`<bin-name>` 替换为实际产物名（可有多个 `cp` 行）。

## `_gal/work.gxl`

```gxl
extern mod rust,ver { path = "@{PATH}"; }

mod envs  {
   env _common  : rust_env.init   {
    root      = ".";
    prj_key   = "<prj-key>" ;

  }

  #[usage(desp="use debug ",color="blue")]
  env debug :  _common,rust_env.debug {
  }
  #[usage(desp="use debug ",color="blue")]
  env release :  _common,rust_env.release{
  }

  #[usage(desp="default mamcos", color="green")]
  env default    : envs._common,debug;
}

mod main  {
      bld_bins = "target/${ENV_BUILD_NAME}" ;
      HOME_BIN = "${HOME}/bin" ;

    #[auto_load(entry)]
    flow __into | conf {
    }
    #[task(name="config")]
    flow conf  {
    }

  #[task(name="${ENV_PRJ_KEY}@build")]
  flow ver.use | conf | rust_flow.build | @build | _pub_local {
      gx.echo(  "${MAIN_HOME_BIN}" );
  }
  #[usage(desp="lint code")]
  flow lint | rust_flow.lint {} ;

  #[task(name="test")]
  flow build  |   @test  {
    gx.cmd ( "cargo test --all ${ENV_BUILD_FLAG}", log : "1" , out:"true"  );
  }

  #[task(name="pub to local")]
  flow _pub_local   {
    gx.cmd (  "mkdir -p ${MAIN_HOME_BIN}" );
    gx.cmd (  "cp ${MAIN_BLD_BINS}/<bin-name> ${MAIN_HOME_BIN}/"  );
  }
}
```

菜单（`gx run`）：`conf`、`build`、`lint`、`test`；env：`debug`、`release`、`default`。

## `_gal/rust.gxl`

```gxl
mod rust_flow  {
  flow lint        {
    gx.cmd ( "cargo fmt ", log : "1" , out:"true"  );
    gx.cmd ( "cargo fix --allow-dirty", log : "1" , out:"true"  );
    gx.cmd ( "cargo clippy --all-targets --all-features -- -D warnings"  );
  }
   #[usage(desp="rust build")]
   flow build {
    gx.cmd ( cmd: "cargo build  ${ENV_BUILD_FLAG} ${ENV_TARGET_FLAG} "  );
  }
}

mod rust_env {
  env init     { build_flag  ="" ; build_name = "debug"; target_flag  = "" ; target_name = "" ; }
  env debug    {}  ;
  env release  { build_flag   =" --release" ; build_name = "release" ;  }
}
```

## `_gal/ver.gxl`

```gxl
mod ver {

  flow use   {
      gx.ver ( file : "${GXL_START_ROOT}/version.txt" ,  inc : "null" );
    }
  flow build   {
      gx.ver ( file : "${GXL_START_ROOT}/version.txt" ,  inc : "build"  );
      gx.echo ( "current version : ${VERSION}" );
    }
  flow patch {
      gx.ver ( file : "${GXL_START_ROOT}/version.txt" ,  inc : "bugfix" );
      gx.echo (  "current version : ${VERSION}"  );
    }
  flow feature {
      gx.ver ( file : "${GXL_START_ROOT}/version.txt" ,  inc : "feature"  );
      gx.echo ( "current version : ${VERSION}"  );
    }
  flow syn_file {
        gx.patch_file(
        file   : "${SYN_FILE}",
        action : "set",
        marker : "version",
        value  : r#""${VERSION}""#
        );
    }
}
```

`inc` 语义：`null`=只读不改；`build`=只加 build 号；`bugfix`=补丁位 +1；`feature`=次版本位 +1。

## `_gal/vfm.gxl`

```gxl
extern mod ver { path = "@{PATH}"; }
mod sys_ver_adm {
  #[auto_load(entry)]
  flow __into_sys_ver_adm | ver.use {
  }
  #[usage(desp="update version of patch ")]
  flow v_patch   | ver.patch  { }
  #[usage(desp="update version of feature ")]
  flow v_feat |  ver.feature   { }
  #[usage(desp="add tag by version ")]
  flow tag_stable {
    gx.ver ( file : "${GXL_START_ROOT}/version.txt" ,  inc : "null"  );
    gx.cmd (  "git tag v${VERSION}" );
    gx.cmd (  "git push --tags" );
  }

  flow tag_beta{
    gx.ver ( file : "${GXL_START_ROOT}/version.txt" ,  inc : "null"  );
    gx.cmd (  "git tag v${VERSION}-beta" );
    gx.cmd (  "git push --tags" );
  }
  flow tag_alpha{
    gx.ver ( file : "${GXL_START_ROOT}/version.txt" ,  inc : "null"  );
    gx.cmd (  "git tag v${VERSION}-alpha" );
    gx.cmd (  "git push --tags" );
  }
}
mod lib_ver_adm {
  #[auto_load(entry)]
  flow __into_lib_ver_adm | ver.use {
  }
  #[usage(desp="update version of patch ")]
  flow v_patch   | ver.patch  { }
  #[usage(desp="update version of feature ")]
  flow v_feat |  ver.feature   { }
  #[usage(desp="add tag by version ")]
  flow tag_stable{
    gx.ver ( file : "${GXL_START_ROOT}/version.txt" ,  inc : "null"  );
    gx.cmd (  "git tag v${VERSION}" );
    gx.cmd (  "git push --tags" );
  }
}

mod ver_adm : sys_ver_adm {
}
```

菜单（`gx adm`）：`v_patch`、`v_feat`、`tag_stable`、`tag_beta`、`tag_alpha`。

## `_gal/adm.gxl`

```gxl
extern mod vfm { path = "@{PATH}"; }

mod  envs {
  env default {
     ROOT= "./";
  }
}
mod main   : ver_adm {

#[auto_load(entry)]
  flow _entry : ver.use {
  }

#[auto_load(exit)]
  flow _set_ver | ver.syn_file {
    SYN_FILE= "${ENV_ROOT}/Cargo.toml";
  }
}
```

**关键行为**：`gx adm` 进入时自动跑 `ver.use`（读 `version.txt`），退出时自动跑 `_set_ver | ver.syn_file`（把版本写回 `Cargo.toml`）。所以**任何** `gx adm` 跑完，`Cargo.toml` 的版本都会与 `version.txt` 对齐。

## `_gal/project.toml`

占位文件，0 字节。保留即可。

## `Cargo.toml` 版本 marker

```toml
[package]
name = "<crate-name>"
version = "0.1.0" #@gxl:set(version)
edition = "2024"
```

`#@gxl:set(version)` 是 `gx.patch_file` 的定位 marker，**不要删除或改写**，否则版本同步会失败。

## 变体提示

- 部分仓库的 `adm.gxl` 引用**远程模块**（例如 `extern mod cfm { git = "https://github.com/.../...git", channel = "${GXL_CHANNEL:develop}" }`），而不是本地 `vfm.gxl`。改动这类仓库时不要用本模板覆盖。
- 纯库 crate 可能没有 `_pub_local` / 无二进制；`prj_key` 仍应设置。
