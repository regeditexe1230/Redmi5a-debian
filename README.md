## 硬件信息

- 设备：Xiaomi Redmi 5A (riva)
- SoC：Qualcomm MSM8917 (Snapdragon 425)
- 架构：ARM64 (aarch64)
- 内核版本：Linux 6.6.0
- 后摄：OV13850 (13MP) / 前摄：OV5648 (5MP)

## 前置依赖

### 交叉编译工具链 (x86_64 宿主)
```bash
# Ubuntu/Debian
sudo apt install gcc-aarch64-linux-gnu python3

# Arch
sudo pacman -S aarch64-linux-gnu-gcc python3
```

### ARM64 设备本地编译
直接编译无需交叉工具链，`make` 会自动检测。

## 快速开始

```bash
# 一键编译：内核 + 外置模块 + boot.img
make all

# 或分步编译
make kernel      # 编译内核
make modules     # 编译外置模块
make image       # 生成 boot_new.img
```

编译产物：
- `linux-6.6/arch/arm64/boot/Image.gz` — 压缩内核镜像
- `modules/*/xxx.ko` — 外置内核模块
- `boot_new.img` — Android boot image（可直接刷入）

## 目录结构

```
Redmi5A-Kernel/
├── linux-6.6/                    # Linux 6.6 完整源码树（含编译产物）
│   ├── .config                    # 当前内核配置 (CONFIG_LOCALVERSION="umeko-compile")
│   └── arch/arm64/boot/dts/qcom/  # MSM8916/8917/8937 设备树
├── modules/                       # 外置内核模块源码
│   ├── camss_overlay/             # CAMSS 摄像头子系统 overlay
│   ├── dapm_fix/                  # DAPM 音频电源管理修复
│   ├── mclk_fix/                  # MCLK 主时钟修复
│   ├── msm8916-qdsp6/             # QDSP6 音频 DSP 驱动（基于 msm8916/apq8016）
│   └── test_i2c/                  # I2C 总线调试模块
├── pmOS/                          # postmarketOS 设备包（APKBUILD）
├── boot/                          # Debian 镜像启动文件
│   ├── vmlinuz                    # 内核可执行文件
│   ├── initramfs / initramfs-extra # initramfs
│   └── dtbs/                      # 设备树 blob
│       └── msm8917-xiaomi-riva.dtb
├── config.gz                      # 备选内核配置（实为当前编译使用的 .config 压缩包）
├── ramdisk.gz                     # Android boot.img 使用的 ramdisk
├── dt.img                         # 预编译设备树镜像
├── mkimg.py                       # boot.img 打包脚本
├── build.sh                       # Debian 系统镜像构建脚本（需 root）
├── Makefile                       # 顶层 Makefile
└── README.md
```

### 设备树 DTS 源码缺失
- `boot/dtbs/msm8917-xiaomi-riva.dtb` 已编译可用，但对应的 `.dts` 源文件不在内核树中
- 内核树中唯一的完整 DTS 是 `msm8916-wingtech-wt88047.dts`（红米2），包含 OV8865/OV2680 配置，与 Redmi 5A 不匹配
- 如需修改 Redmi 5A 设备树，需要找到原始 `msm8917-xiaomi-riva.dts` 源文件后重新编译

### msm8916-qdsp6 模块
该模块基于 APQ8016 (DragonBoard 410c) 的 QDSP6 音频 DSP 代码，msm8917 与 msm8916 在同系列中兼容性较好，但未经 msm8917 专项适配验证。

## 自定义修改

### 修改内核配置
```bash
cd linux-6.6
make ARCH=arm64 menuconfig    # 图形化配置界面
# 或直接编辑 .config
make ARCH=arm64 savedefconfig # 保存为 defconfig
```

### 添加新的外置模块
1. 在 `modules/` 下创建目录，放入 `.c` 文件和 `Makefile`（内容：`obj-m := 模块名.o`）
2. 在顶层 `Makefile` 的 `MODULES` 变量中添加目录名
3. `make modules` 即会自动编译

### 替换内核 QDSP6 音频驱动
`modules/msm8916-qdsp6/` 是 QDSP6 音频 DSP 驱动的修改版：

```bash
# 备份原驱动
cp -r linux-6.6/sound/soc/qcom/qdsp6 linux-6.6/sound/soc/qcom/qdsp6.bak

# 替换文件
cp modules/msm8916-qdsp6/qdsp6/*.c linux-6.6/sound/soc/qcom/qdsp6/
cp modules/msm8916-qdsp6/apq8016_sbc.c linux-6.6/sound/soc/qcom/
cp modules/msm8916-qdsp6/common.c linux-6.6/sound/soc/qcom/

# 重新编译
make kernel
```

### Debian 系统镜像构建
`build.sh` 使用 `rootfs/` 目录构建 Debian 系统镜像（`debian-riva.img`），需 root 权限。

```bash
sudo bash build.sh
```

### 修改 boot.img 内核命令行
编辑 `mkimg.py` 中的 `cmdline` 变量。

## 刷入设备

```bash
# 使用 fastboot 刷入
fastboot flash boot boot_new.img

# 或通过 lk2nd
fastboot flash boot boot_new.img
```

## 许可证

Linux 内核使用 GPL-2.0。本工程中的自定义模块和脚本使用相同许可证。
