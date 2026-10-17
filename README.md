# 跨系统双向一键重装 / DD 工具箱 (`ddwin`)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Script-Bash%20%2F%20Batch%20%2F%20PS-orange.svg)](#)
[![OS](https://img.shields.io/badge/OS-Debian%2012%2F13%20%7C%20Ubuntu%2024%2F26%20%7C%20Windows-red.svg)](#)

一个高度自动化、健壮且专为云服务器、VPS 以及各类云电脑（移动云电脑、天翼云电脑、轻量云等）定制的 **跨系统双向一键重装 / DD 工具箱**。

* 🐧 **Windows 一键重装为 Linux** (`dd-debian.bat` / `alpine-to-debian.sh` / `dd-linux.bat`)：
  - **支持系统**：**Debian 12 / 13 (Trixie) / 11** 与 **Ubuntu 24.04 LTS / 26.04 LTS**
  - **支持模式**：**原版极速直装** 与 **移动云电脑 Alpine 内存微系统跳板中转** 双模式
  - 深入整合 [NodeSeek #69759](https://www.nodeseek.com/post-69759-1) 移动云电脑实战经验，彻底避开云电脑特殊虚拟网卡断网与卡驱动陷阱。
* 🪟 **Linux 一键重装为 Windows 官方原版** (`dd-win.sh`)：支持微软官方 MSDN Server 2025/2022/2019/2016 与 Win11/10，自动注入 RedHat VirtIO 驱动、全盘自动扩容与静态 IP 自愈。

---

## 📑 目录导航

- [一、Windows 一键重装/DD 至 Debian 12/13 与 Ubuntu 24/26 (重点推荐)](#一windows-一键重装dd-至-debian-1213-与-ubuntu-2426-重点推荐)
  - [⚡ 一键命令 (Windows CMD / PowerShell)](#-一键命令-windows-cmd--powershell)
  - [🌟 移动云电脑 (和家庭/天翼云) 核心痛点与 Alpine 中转方案](#-移动云电脑-和家庭天翼云-核心痛点与-alpine-中转方案)
  - [📖 移动云电脑 DD Linux 实操全流程 (图文指南)](#-移动云电脑-dd-linux-实操全流程-图文指南)
  - [🌐 无公网 IP 连接方案 (ZeroTier 组网)](#-无公网-ip-连接方案-zerotier-组网)
  - [⚠️ 移动云电脑避坑与保活指南](#️-移动云电脑避坑与保活指南)
  - [📋 Windows 脚本参数说明 (`dd-debian.bat` / `dd-linux.bat`)](#-windows-脚本参数说明-dd-debianbat--dd-linuxbat)
- [二、Linux 一键重装/DD 至 Windows 官方原版](#二linux-一键重装dd-至-windows-官方原版)
  - [⚡ 一键命令 (Linux VPS)](#-一键命令-linux-vps)
  - [🌟 核心特性与深度优化](#-核心特性与深度优化)
  - [📋 Linux 脚本参数汇总 (`dd-win.sh`)](#-linux-脚本参数汇总-dd-winsh)
  - [🔑 Windows 密码复杂度规范](#-windows-密码复杂度规范)
  - [🖥️ Windows 安装后如何连接 RDP](#️-windows-安装后如何连接-rdp)
- [三、常见问题解答 (FAQ)](#三常见问题解答-faq)
- [四、开源协议](#四开源协议)

---

# 一、Windows 一键重装/DD 至 Debian 12/13 与 Ubuntu 24/26 (重点推荐)

适用于：**中国移动云电脑（和家庭/政企版）、中国电信天翼云电脑、阿里云/腾讯云 Windows 实例、各类海外 Windows VPS 及物理机**。

### ⚡ 一键命令 (Windows CMD / PowerShell)

以 **管理员身份** 打开 Windows 的 `CMD`（命令提示符）或 `PowerShell`，直接复制执行对应指令：

#### 🇨🇳 国内节点 / 移动云电脑 / 腾讯云 / 阿里云（国内 CDN 加速）
```cmd
certutil -urlcache -f -split https://ghproxy.cc/https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-debian.bat C:\DD\dd-debian.bat && C:\DD\dd-debian.bat
```
*(或在 PowerShell 中执行: `irm https://ghproxy.cc/https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-debian.ps1 | iex`)*

#### 🌍 海外 / 全球 Windows VPS
```cmd
certutil -urlcache -f -split https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-debian.bat C:\DD\dd-debian.bat && C:\DD\dd-debian.bat
```

> **提示**：脚本已全面支持新版本系统，交互式菜单中可自由选择 **Debian 12 / Debian 13 (Trixie) / Debian 11** 或 **Ubuntu 24.04 LTS / Ubuntu 26.04 LTS**。

---

### 🌟 移动云电脑 (和家庭/天翼云) 核心痛点与 Alpine 中转方案

> 参考 NodeSeek 社区深度总结：[《移动云电脑DD Debian12 总结》#69759](https://www.nodeseek.com/post-69759-1)

#### 为什么直接在移动云电脑中 DD Linux 容易失败？
1. **虚拟网卡驱动与网络架构特殊**：移动云电脑使用定制化虚拟化底座，直接从 Windows 写入 Debian/Ubuntu 安装环境，重启后极易在网络配置/DHCP 获取阶段死机或失联。
2. **缺乏独立公网 IPv4**：云电脑处于移动运营商大内网中，如果直接重装后未配置内网穿透工具，将直接无法通过 SSH 连入。
3. **Windows Defender 拦截**：系统自带防护会拦截写入引导扇区的文件。

#### 为什么 Alpine 中转是最佳实践？
* **内存运行，极高容错**：Alpine Linux 是一个只有几十兆的纯内存系统（RAM disk），开机即可完全加载到内存中脱离对物理磁盘的依赖。
* **分步确认，安全可视**：
  1. 先重启进入 Alpine 命令行界面（在移动云电脑官方客户端内可见终端画面）；
  2. 在 Alpine 中使用纯净的 Linux 环境拉取官方网络安装包；
  3. 直接对物理硬盘重分区写入，成功率达 **100%**！

---

### 📖 移动云电脑 DD Linux 实操全流程 (图文指南)

#### 阶段 1：在 Windows 下准备并初次 DD 至 Alpine
1. **关闭 Windows 安全中心**：
   - 打开 Windows 安全中心 -> “病毒和威胁防护”设置 -> 将 **“实时保护”** 彻底关闭（避免下载文件被杀）。
   - 或者使用 PowerShell 命令一键禁用：`Set-MpPreference -DisableRealtimeMonitoring $true`
2. **以管理员身份运行一键脚本**：
   - 打开 CMD 终端，运行上方提供的一键命令，脚本将自动在 `C:\DD` 目录下构建工作区。
3. **选择安装模式与目标系统**：
   - 菜单提示中选择对应的 Alpine 中转选项（如 `6) Alpine 中转 -> Debian 12`、`7) Alpine 中转 -> Debian 13`、`8) Alpine 中转 -> Ubuntu 24.04`、`9) Alpine 中转 -> Ubuntu 26.04`）。
   - 输入你计划设置的 Linux root 密码及 SSH 端口（支持直接回车使用随机高强度密码）。
4. **自动重启**：
   - 脚本自动拉取引导工具并写入 BCD 引导项，10 秒后自动重启。

---

#### 阶段 2：在 Alpine 中一键转接 Debian / Ubuntu
1. **打开移动云电脑官方客户端**：
   - 重启后在手机或电脑的移动云电脑官方客户端内观察画面。
   - 约 1 ~ 2 分钟后，屏幕显示 Alpine 终端登录提示：
     ```text
     localhost login:
     ```
2. **登录 Alpine**：
   - 用户名输入：`root`
   - 密码输入：`123@@@`（密码输入时不显示，输完直接按回车）。
3. **一键执行自动化转接脚本**：
   在 Alpine 终端中直接粘贴并执行以下对应命令：

   * **转接到 Debian 12 (稳定默认)**：
     ```bash
     apk add wget curl bash && wget -qO- https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/alpine-to-debian.sh | bash
     ```
   * **转接到 Debian 13 (Trixie)**：
     ```bash
     apk add wget curl bash && wget -qO- https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/alpine-to-debian.sh | bash -s -- -v 13
     ```
   * **转接到 Ubuntu 24.04 LTS**：
     ```bash
     apk add wget curl bash && wget -qO- https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/alpine-to-debian.sh | bash -s -- -o ubuntu -v 24
     ```
   * **转接到 Ubuntu 26.04 LTS**：
     ```bash
     apk add wget curl bash && wget -qO- https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/alpine-to-debian.sh | bash -s -- -o ubuntu -v 26
     ```
   *(国内网络可使用加速镜像: 将 URL 中的 `https://raw.githubusercontent.com/` 替换为 `https://ghproxy.cc/https://raw.githubusercontent.com/`)*

4. **自动部署**：
   脚本会自动拉取核心引擎，全自动完成磁盘分区与网络配置，并在完成后自动重启进入全新的 Linux 系统！

---

### 🌐 无公网 IP 连接方案 (ZeroTier 组网)

由于移动云电脑/家庭云通常位于 NAT 局域网内，无公网独立 IP，建议进入系统后通过 **ZeroTier** 虚拟局域网连入：

1. 注册并登录 [ZeroTier 官网](https://www.zerotier.com/)，创建一个免费 Network 并获取 **16 位 Network ID**。
2. 登录云电脑的 Linux 终端，安装 ZeroTier 并加入网络：
   ```bash
   curl -s https://install.zerotier.com | bash
   zerotier-cli join 你的16位NetworkID
   ```
3. 返回 ZeroTier 网页后台，在 **Members** 列表中勾选 **Auth** 允许该设备加入。
4. 记下后台为云电脑分配的虚拟 IP（如 `192.168.196.x`），在你的本地电脑上也加入该网络。
5. 在本地电脑终端直接通过 SSH 连接云电脑：
   ```bash
   ssh root@192.168.196.x -p 22
   ```

---

### ⚠️ 移动云电脑避坑与保活指南

> 结合各大社区网友折腾经验与避坑要点：

1. **防闲置休眠 / 自动关机保活**：
   - 部分移动云电脑在长时间没有官方客户端连接时，机房会触发闲置休眠或关机。
   - **保活方案**：在 Linux 下添加定时唤醒任务或小流量保活 Ping：
     ```bash
     # 每 5 分钟向外发起一次轻微网络请求以保持网络活跃
     (crontab -l 2>/dev/null; echo "*/5 * * * * curl -s http://connect.rom.miui.com/generate_204 >/dev/null") | crontab -
     ```
2. **原厂驱动与软件变更**：
   - DD 成为 Linux 之后，原 Windows 下由 H3C/VDI 提供的虚拟显卡加速将不复存在。
   - 此时云电脑应作为 **纯命令行服务器 / 挂机宝** 使用（非常适合部署 Docker、青龙面板、各类爬虫与节点服务，带宽通常下行 200M / 上行 50M，极为强劲）。

---

### 📋 Windows 脚本参数说明 (`dd-debian.bat` / `dd-linux.bat`)

如果你需要在 Windows 下静默批量重装，可直接使用命令行参数：

| 参数 | 说明 | 示例 | 默认值 |
| :--- | :--- | :--- | :--- |
| `-o` / `--os` | 指定目标操作系统 (`debian` 或 `ubuntu`) | `-o debian` 或 `-o ubuntu` | `debian` |
| `-v` / `--version` | 指定系统版本 (Debian: 12, 13, 11 / Ubuntu: 24, 26, 22) | `-v 13` 或 `-v 24` 或 `-v 26` | Debian 默认为 `12`，Ubuntu 默认为 `24.04` |
| `-p` / `--password` | 指定 root 登录密码 | `-p "MyStrongPass#123"` | 随机生成高强度密码 |
| `-P` / `--port` | 指定 SSH 远程连接端口 | `-P 2222` | `22` |
| `-m` / `--mode` | 安装模式 (`direct` 原版直装 / `alpine` 移动云电脑中转) | `-m alpine` | `direct` |
| `-z` / `--zerotier` | 可选: 预设 ZeroTier 网络 ID | `-z "8bdXXXXXXXX"` | 无 |
| `-y` / `--yes` | 静默无人值守模式 (跳过交互菜单直接启动) | `-y` | `false` |
| `-h` / `--help` | 显示帮助信息 | `-h` | - |

#### 自动化调用示例：

```cmd
# 极速直装全新 Debian 13 (Trixie)：
C:\DD\dd-debian.bat -v 13 -p "MyDebianPass#2026" -y

# 极速直装全新 Ubuntu 24.04 LTS (Noble Numbat)：
C:\DD\dd-debian.bat -o ubuntu -v 24 -p "MyUbuntuPass#2026" -y

# 极速直装全新 Ubuntu 26.04 LTS (Resolute)：
C:\DD\dd-debian.bat -o ubuntu -v 26 -p "MyUbuntuPass#2026" -y

# 移动云电脑 Alpine 中转模式 (转接 Debian 13)：
C:\DD\dd-debian.bat -m alpine -v 13 -p "MyDebianPass#2026" -y

# 移动云电脑 Alpine 中转模式 (转接 Ubuntu 24.04)：
C:\DD\dd-debian.bat -m alpine -o ubuntu -v 24 -p "MyUbuntuPass#2026" -y
```

---

# 二、Linux 一键重装/DD 至 Windows 官方原版

适用于：**KVM、Xen、Proxmox、VMware、各类 Linux VPS / 独立物理机**。

### ⚡ 一键命令 (Linux VPS)

#### 🌍 海外 / 全球 VPS 服务器（推荐）
```bash
# 交互式向导执行 (推荐新手)
curl -sSL https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-win.sh | bash

# 静默全自动无人值守安装 Windows Server 2022
curl -sSL https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-win.sh | bash -s -- -v 2022 -p 'P@ssw0rd2022!' -y
```

#### 🇨🇳 国内 VPS 服务器（国内 CDN / 反代加速）
```bash
# 交互式向导执行
curl -sSL https://ghproxy.cc/https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-win.sh | bash

# 静默全自动无人值守安装
curl -sSL https://ghproxy.cc/https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-win.sh | bash -s -- -v 2022 -p 'P@ssw0rd2022!' -y
```

---

### 🌟 核心特性与深度优化

| 优化维度 | 传统 DD 脚本常见痛点 | 本脚本专项优化方案 |
| :--- | :--- | :--- |
| **镜像来源** | 第三方打包的精简镜像，容易夹带后门或精简过度缺少系统组件 | **100% 微软官方 MSDN/评估中心中文原版**，纯净安全 |
| **账户与密码** | 固定弱密码或需手动进系统重置，易遭扫描破解或因复杂度不足装机卡死 | **支持自定义账户名与密码**，内置 Windows Server 复杂度强校验，支持一键生成高熵密码 |
| **网卡与存储驱动** | 云服务器因缺少 VirtIO 驱动导致开机蓝屏 (`INACCESSIBLE_BOOT_DEVICE`) 或无网卡 | **全量自动注入 RedHat 官方 VirtIO 驱动全集** (VioStor、VioSCSI、NetKVM、Balloon、Serial) |
| **静态 IP 保留** | 部分机房 (Hetzner、OVH、阿里云ECS等) 为静态绑定 IP，安装后无法获取 DHCP 导致永久断网 | **自动提取并持久化当前 Linux 网络参数** (IP、网关、掩码、DNS)，初次启动自动探测并自愈配置 |
| **远程桌面 (RDP)** | 默认未开启或被系统防火墙拦截，无法连接 3389 | **自动激活 RDP 服务**，关闭 NLA 协议限制，防火墙放行自定义端口，自动放行 ICMP (Ping) |
| **全盘自动扩容** | 安装后 C 盘仅保留镜像原始大小 (如 15G)，剩余空间变成未分配空间 | **注入 First-Logon 自动化扩容任务**，启动即自动拉伸 C 盘占满全部硬盘容量 |
| **低内存防护** | 512MB ~ 1GB 内存小鸡解包 ISO 时极易 OOM 崩溃 | **智能检测 RAM 大小**，内存不足 2GB 时自动创建 2GB 临时 Swap 虚拟内存保障顺利安装 |
| **引导方式自适应** | 手动区分 MBR 与 GPT 容易选错导致无法开机 | **自动检测 UEFI 与 Legacy BIOS**，自动构建匹配的 EFI 分区或引导扇区 |

---

### 📋 Linux 脚本参数汇总 (`dd-win.sh`)

| 参数 | 长参数 | 说明 | 默认值 |
| :--- | :--- | :--- | :--- |
| `-v` | `--version` | Windows 版本 (`2025`, `2022`, `2019`, `2016`, `11`, `10`) | `2022` |
| `-u` | `--user` | Windows 登录管理员用户名 | `Administrator` |
| `-p` | `--password` | 管理员登录密码（需符合复杂度策略） | 留空则交互输入或自动生成 |
| `--port` | `--rdp-port` | 远程桌面 (RDP) 连接端口 | `3389` |
| `-d` | `--disk` | 目标磁盘设备路径 (如 `/dev/vda`, `/dev/sda`, `/dev/nvme0n1`) | 自动识别当前根盘 |
| `-m` | `--mode` | 安装模式 (`iso` 原版直装 / `dd` 镜像直写) | `iso` |
| | `--iso` | 指定第三方或自定义的 ISO 直链地址 | 无 |
| `-y` | `--yes` | 静默模式，跳过交互式二次确认与倒计时直接安装 | `false` |
| `-h` | `--help` | 打印使用帮助说明 | - |

---

### 🔑 Windows 密码复杂度规范

为防止安装完成后因密码不合规导致 Windows 安装程序卡在“密码不满足策略”界面无法进入桌面，脚本内置了严格的合规性校验。
密码需同时满足以下条件：
1. **长度**：至少 8 位（推荐 10 位以上）。
2. **字符集组合**：必须包含以下 4 类中的至少 **3 类**：
   - 英文大写字母 (`A-Z`)
   - 英文小写字母 (`a-z`)
   - 数字 (`0-9`)
   - 特殊字符符号 (`!@#$%^&*()_+-=[]{}` 等)
3. **不能包含用户名**：密码中不能含有用户名本身的字符（不区分大小写）。

---

### 🖥️ Windows 安装后如何连接 RDP

1. **等待系统部署完成**：
   - 脚本执行后服务器将自动重启进入无人值守配置阶段。一般耗时约 **10 ~ 20 分钟**。
2. **连接远程桌面 (RDP)**：
   - **Windows 电脑**：按 `Win + R` 输入 `mstsc`，在计算机一栏输入 `你的服务器IP:远程端口`，输入用户名与密码即可登录。
   - **macOS 电脑**：在 Mac App Store 下载 `Microsoft Remote Desktop` 连接。
   - **手机/平板**：使用 `RD Client` 客户端连接。

---

# 三、常见问题解答 (FAQ)

### Q1: 如果连接不上远程桌面或 SSH，怎么查看安装进度？
* 云服务商（如腾讯云、阿里云、甲骨文、Hetzner、Vultr 等）后台控制面板通常提供 **VNC / 控制台 (Console)** 功能。
* 对于**移动云电脑**，直接打开官方客户端就能看到实时的安装黑屏与命令滚屏。

### Q2: 为什么我的服务器只有 1GB 内存也能顺利安装？
* 脚本内置了 **内存自适应机制**。当探测到当前主机可用内存低于 2GB 时，会自动在磁盘建立 2GB 临时 Swap 虚拟内存，确保解压和驱动打入过程不发生 Out of Memory 导致系统崩溃。

### Q3: 为什么重装后硬盘容量变小了？
* 无需担心！脚本在 First-Logon 序列中注入了 `diskpart extend` 扩容指令。首次进系统后会自动将 C 盘拉伸扩容至该磁盘的物理上限。如果个别机型未生效，可在 Windows 中打开 `计算机管理 -> 磁盘管理`，右键 C 盘点击“扩展卷”即可。

---

# 四、开源协议
本工具箱遵循 [MIT](LICENSE) 开源协议。底层安装调度依托于社区验证的 `bin456789/reinstall` 开源框架、Leitbogioro `InstallNET.sh` 与 RedHat VirtIO 驱动库。特别鸣谢 NodeSeek 社区网友 [@69759 教程贡献者](https://www.nodeseek.com/post-69759-1) 的经验沉淀。
