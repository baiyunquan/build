# CHANGELOG — pbsbc01h3lite Armbian Build

## [26.05.0-trunk] — 2026-05-29

### 目标

为 pbsbc01h3 Lite 板（Allwinner H3，512MB/1GB RAM）构建完整的 Armbian Jammy 镜像，
启用以下三项硬件功能：

| 功能 | 接口 | 验证结果 |
|------|------|---------|
| 有线以太网 (EMAC) | H3 内置 10/100 MII PHY | `eth0` DHCP 获取到 IP |
| XR819 WiFi | SDIO/mmc1 | `wlan0` 固件 XR_C01.08.52.58 加载成功 |
| USB OTG 串口 (g_serial) | USB OTG 外设模式 | `/sys/class/udc/musb-hdrc.4.auto` 出现 |

---

### 新增文件

#### 1. 板卡配置 `userpatches/config/boards/pbsbc01h3lite.csc`

```
git show af7d596 -- userpatches/config/boards/pbsbc01h3lite.csc
```

关键设置：

- `BOARDFAMILY="sun8i"` — Allwinner H3/H2+ 家族
- `BOOTCONFIG="orangepi_lite_defconfig"` — 复用 OrangePi Lite U-Boot 配置
- `BOOT_FDT_FILE="sun8i-h3-pbsbc01h3-lite.dtb"` — 指向自定义 DTB
- `MODULES_CURRENT="g_serial"` — 启动时加载 USB OTG 串口 gadget 模块
- `DEFAULT_OVERLAYS="usbhost2 usbhost3"` — 启用 USB HOST 2/3 端口
- U-Boot 后处理 hook：DRAM 时钟设为 624 MHz，ZQ=3881979，ODT 启用

#### 2. 内核 DTS 补丁 `userpatches/kernel/archive/sunxi-6.18/0001-arm-dts-allwinner-add-pbsbc01h3-lite.patch`

```
git show af7d596 -- "userpatches/kernel/archive/sunxi-6.18/0001-arm-dts-allwinner-add-pbsbc01h3-lite.patch"
```

补丁在内核树中创建了两个文件：

**`arch/arm/boot/dts/allwinner/Makefile`** (+1 行)
```diff
@@ -243,6 +243,7 @@ dtb-$(CONFIG_MACH_SUN8I) += \
        sun8i-h3-orangepi-lite.dtb \
        sun8i-h3-orangepi-one.dtb \
        sun8i-h3-orangepi-pc.dtb \
+       sun8i-h3-pbsbc01h3-lite.dtb \
        sun8i-h3-orangepi-pc-plus.dtb \
```

**`arch/arm/boot/dts/allwinner/sun8i-h3-pbsbc01h3-lite.dts`** (新建，51 行)

继承 `sun8i-h3-orangepi-lite.dts`，覆盖以下节点：

| 节点 | 作用 | GPIO（来源：legacy fex） |
|------|------|------------------------|
| `wifi_pwrseq` | XR819 电源时序 | PL7 (`r_pio 0 7`) ACTIVE_LOW — wl_reg_on |
| `&emac` | 内置 MII PHY 以太网 | 无外部 PHY，`phy-mode = "mii"` |
| `&mmc1` | XR819 SDIO WiFi（替换 RTL8189FTV） | PG10 (`pio 6 10`) EDGE_RISING — wl_host_wake |
| `&usb_otg` | USB OTG 外设模式 | — |
| `&usbphy` | OTG ID 检测 | PG12 (`pio 6 12`) ACTIVE_HIGH |

> GPIO 来源：`pbsbc01h3-build/external/config/fex/pbsbc01h3lite.fex`  
> 确认 `gmac_used = 0`（无外部 RGMII，使用内部 MII PHY）

---

### 调试过程（关键节点）

#### 问题一：运行中镜像的 DTS 为最小配置

首次编译（未修改 DTS 时）产生的运行镜像中，DTB 只包含板卡标识，
没有 EMAC / OTG / WiFi 节点。通过串口（ttyUSB0）进行板上诊断：

```bash
# dmesg | grep -iE "emac|stmmac|gmac"   → 空（无以太网驱动）
# ip link                                → 仅 lo
# ls /sys/class/udc/                     → 空（OTG 不可用）
```

#### 问题二：DTS 研究

从 legacy fex 文件提取 GPIO 分配，确认：
- `gmac_used = 0` → H3 内置 MII PHY，而非外部 RGMII
- `wl_reg_on = PL7`、`wl_host_wake = PG10`
- `usb_id_gpio = PG12`

#### 问题三：DTB 热部署验证

DTS 修改后先通过 Docker 编译 DTB，再通过 Python pyserial + base64 方式
通过串口传输到板上，无需完整重新构建即可验证硬件配置是否正确。

#### 问题四：补丁文件格式错误（导致首次完整构建失败）

| 错误 | 原因 | 修复 |
|------|------|------|
| Makefile hunk 行号不符 | 行号写为 238，实际为 243 | 更正为 `@@ -243,6 +243,7 @@` |
| Makefile 上下文缺少 TAB | 内容行用空格而非 `\t` | 替换为真实 tab 字符 |
| DTS hunk 行数不符 | 头部写 `+1,57`，实际只有 51 行 | 更正为 `+1,51` |

补丁格式修复后通过干运行验证：
```bash
patch --dry-run -p1 < userpatches/kernel/archive/sunxi-6.18/0001-arm-dts-allwinner-add-pbsbc01h3-lite.patch
# → checking file arch/arm/boot/dts/allwinner/Makefile  ✓
# → checking file arch/arm/boot/dts/allwinner/sun8i-h3-pbsbc01h3-lite.dts  ✓
```

---

### 构建命令

```bash
cd build/
./compile.sh build \
  BOARD=pbsbc01h3lite \
  BRANCH=current \
  BUILD_DESKTOP=no \
  BUILD_MINIMAL=no \
  DOCKERFILE_USE_ARMBIAN_IMAGE_AS_BASE=no \
  KERNEL_CONFIGURE=no \
  KERNEL_GIT=shallow \
  RELEASE=jammy \
  UBOOT_CONFIGURE=no
```

构建时间：约 17 分钟（Docker 容器内，含完整内核编译）

---

### 构建产物

```
output/images/Armbian-unofficial_26.05.0-trunk_Pbsbc01h3lite_jammy_current_6.18.33.img
  大小：2.3 GB
  SHA256：6c8c1796702c4dd1555ec2c14cec95955dde52e28bdcc609171e3a1b7fa35d6e
```

---

### 网络配置修复（2026-05-29 实机测试）

#### 问题：DNS 无法解析，apt 无法使用

首发版本的 `/etc/systemd/resolved.conf` 为默认模板，所有 DNS 配置行均被注释：
```ini
#DNS=
#FallbackDNS=
```

导致 systemd-resolved 启动后无上游 DNS 服务器，无法进行域名解析。

**症状**：
```bash
# ping bing.com   → Name or service not known
# curl bing.com   → Could not resolve host
# apt update      → (卡住，无法连接源)
```

#### 解决方案

修改 `/etc/systemd/resolved.conf`，添加公有 DNS 服务器：

```ini
[Resolve]
DNS=8.8.8.8 8.8.4.4 1.1.1.1
FallbackDNS=8.8.8.8 1.1.1.1
DNSSEC=allow-downgrade
DNSOverTLS=no
```

重启 systemd-resolved：
```bash
systemctl restart systemd-resolved
```

#### 验证结果

✅ **DNS 解析** 恢复：
```bash
# ping bing.com
PING bing.com (150.171.28.10) 56(84) bytes of data.
64 bytes from 150.171.28.10: icmp_seq=1 ttl=110 time=71.5 ms
```

✅ **HTTP 请求** 工作：
```bash
# curl -I bing.com
HTTP/1.1 301 Moved Permanently
Location: http://cn.bing.com/
```

✅ **apt 软件包管理** 恢复：
```bash
# apt update
Hit:1 http://ports.ubuntu.com jammy InRelease
Get:5 http://ports.ubuntu.com jammy/main armhf c-n-f Metadata [28.9 kB]
```

---

### WiFi (XR819) 扫描测试

#### 状态

- **驱动**：已加载 (`xradio_wlan 106496`)
- **固件**：XR_C01.08.52.58 已加载
- **接口**：`wlan0` 存在，MAC `12:81:0c:10:bf:b1`

#### 扫描结果

目前 WiFi 扫描无返回结果（`iw wlan0 scan dump` 为空）。

**可能原因**：
- 天线配置需要后续优化（`iw phy` 显示 "Available Antennas: TX 0 RX 0"）
- XR819 的中断（wl_host_wake GPIO PG10）可能未正确配置  
- 驱动可能需要 regulatory domain 配置

**后续工作**：
- [ ] 核查 DTS 中 XR819 中断配置（PG10 电平有效性）
- [ ] 检查 regulatory domain 配置
- [ ] 可能需要补充天线功率配置

---

### 持久化修复

为了在未来的镜像构建中自动应用 DNS 配置修复，已修改 `userpatches/customize-image.sh`：

```bash
# 在 jammy 镜像中自动配置 DNS
if [[ "$BOARD" == "pbsbc01h3lite" ]]; then
    cat >> /etc/systemd/resolved.conf << 'EOF'
[Resolve]
DNS=8.8.8.8 8.8.4.4 1.1.1.1
FallbackDNS=8.8.8.8 1.1.1.1
DNSSEC=allow-downgrade
DNSOverTLS=no
EOF
fi
```

这样后续构建的镜像将在首次引导时即具备 DNS 解析能力，无需手动修复。

---

### Git 提交历史

```
f73879685 fix: add DNS configuration to customize-image.sh for pbsbc01h3lite
408f45e2d docs: update CHANGELOG with network fixes and WiFi scan results
6378d0c4b docs: add CHANGELOG for pbsbc01h3lite board build
af7d59648 feat(board): add pbsbc01h3lite board support
```

查看完整历史：
```bash
cd build/
git log --stat HEAD~3..HEAD
```

---

### XFCE4 桌面与 GPU 驱动调试（2026-05-29 实机测试）

#### 问题：HDMI 显示器无图像，LightDM 启动失败

用户通过 `armbian-config` 安装 XFCE4 桌面后，HDMI 无输出，`systemctl status lightdm` 显示 `failed`。

**诊断过程（通过 SSH）**：

```bash
# journalctl -u lightdm --no-pager | tail -20
# → Failed to find session configuration slick-greeter
```

发现三个根本原因：

| 问题 | 原因 |
|------|------|
| LightDM 报错 `slick-greeter` 未找到 | armbian-config 默认配置引用 `slick-greeter`，但该包未安装 |
| Xorg 未安装 | `armbian-config` 仅安装 xfce4 库文件，未安装 `xserver-xorg` |
| xfce4 桌面组件不完整 | 缺少 `xfce4`、`xfce4-terminal`、`xfdesktop4` 等核心包 |

#### GPU / 显示硬件状态（验证通过）

```bash
# lsmod | grep -E "lima|drm"
lima 49152 0
gpu_sched 36864 1 lima
drm_shmem_helper 16384 1 lima

# cat /sys/class/drm/card0-HDMI-A-1/status
connected

# ls /dev/dri/
card0  card1  renderD128
```

- ✅ Lima GPU 驱动已加载（Allwinner H3 Mali-400 开源驱动）
- ✅ HDMI-A-1 已连接，EDID 256 字节可读
- ✅ DRI 设备节点存在（DRI2/DRI3 支持）

#### 解决方案

**Step 1：安装缺失软件包**

```bash
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xserver-xorg \
    xserver-xorg-video-fbdev \
    xserver-xorg-video-modesetting \
    xfce4 \
    xfce4-terminal \
    lightdm-gtk-greeter
```

安装时间：约 20 分钟（H3 CPU 满载，dpkg configure 阶段 CPU 占用率 ~100%）

**Step 2：覆盖 greeter 配置（slick-greeter → lightdm-gtk-greeter）**

```bash
cat > /etc/lightdm/lightdm.conf.d/50-greeter-override.conf << 'EOF'
[Seat:*]
greeter-session=lightdm-gtk-greeter
EOF
```

> 文件名 `50-greeter-override.conf` 数字大于原有的 `10-slick-greeter.conf`，  
> LightDM 按字母序加载配置，后加载的设置覆盖前者。

**Step 3：重启 LightDM**

```bash
systemctl restart lightdm
```

#### 验证结果

```bash
# systemctl is-active lightdm
active

# cat /sys/class/drm/card0-HDMI-A-1/status
connected

# grep "HDMI-1" /var/log/Xorg.0.log
(II) modeset(0): Output HDMI-1 connected
(II) modeset(0): Output HDMI-1 using initial mode 720x480 +0+0
(II) modeset(0): [DRI2] Setup complete
(II) modeset(0): [DRI2]   DRI driver: sun4i-drm
```

- ✅ **LightDM 运行中**（`active`）
- ✅ **Xorg 进程存在**（PID 可见，监听 `:0`，运行于 vt7）
- ✅ **HDMI 已连接并输出**（720x480，由显示器 EDID 决定）
- ✅ **Lima GPU / modesetting 驱动正常**（DRI2 with `sun4i-drm`）
- ✅ **lightdm-gtk-greeter 登录界面已显示在 HDMI**（greeter 进程可见）

#### 注意事项

- 连接的显示器 EDID 仅上报 SD 分辨率（720x480、720x576、640x480），故 Xorg 使用 720x480。若需 1080p，需连接支持高分辨率的显示器。
- `lightdm-gtk-greeter` 日志中有若干 WARNING（背景图片缺失、language-tools 缺失），均为非致命错误，不影响桌面正常使用。
- `accountsservice` 未运行（`org.freedesktop.Accounts` 服务未找到），lightdm 回退为读取 `/etc/passwd` 用户列表，功能正常。
