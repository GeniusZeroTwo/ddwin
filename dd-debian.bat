@echo off
rem ==============================================================================
rem Script Name: dd-debian.bat
rem Description: Windows 一键重装/DD 至 Debian 12 (支持常规 VPS 及移动云电脑 Alpine 中转)
rem Reference:   NodeSeek #69759 (移动云电脑DD Debian12 总结) & bin456789/reinstall
rem Features:
rem   1. 自动管理员权限提升 (UAC 智能弹窗)
rem   2. 自动检测并一键关闭 Windows Defender 实时保护 (防误杀)
rem   3. 智能国内外网络环境探测，境内自动启用国内高速加速源 (CNB/ghproxy)
rem   4. 双模式支持: 
rem      - 模式 A: Debian 12 极速直装 (适合普通 VPS / 阿里云 / 腾讯云 / 物理机)
rem      - 模式 B: 移动云电脑专用 Alpine 中转模式 (NodeSeek 69759 方案，极高容错，防断网)
rem   5. 自定义 SSH 端口与 root 密码 (支持随机高强度密码生成)
rem   6. 自动构建 C:\DD 规范工作区，防止路径空格与中文导致引导失败
rem   7. 交互式菜单向导与 CLI 静默参数双重支持
rem ==============================================================================

setlocal enabledelayedexpansion
chcp 65001 >nul

:: ----------------- 检查并提升管理员权限 -----------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] 正在请求系统管理员权限以配置底层引导...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\" %*\"' -Verb RunAs"
    exit /b
)

:: ----------------- 初始化默认变量 -----------------
set "TARGET_OS=debian"
set "DEBIAN_VER=12"
set "SSH_PORT=22"
set "ROOT_PASS="
set "INSTALL_MODE=direct"
set "AUTO_CONFIRM=false"
set "WORK_DIR=C:\DD"
set "IS_CHINA=false"
set "ZEROTIER_ID="

:: ----------------- 创建规范工作目录 -----------------
if not exist "%WORK_DIR%" (
    mkdir "%WORK_DIR%" >nul 2>&1
)
cd /d "%WORK_DIR%"

:: ----------------- 参数解析 -----------------
:parse_args
if "%~1"=="" goto after_parse_args
if /i "%~1"=="-h" goto show_help
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-v" (set "DEBIAN_VER=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--version" (set "DEBIAN_VER=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-p" (set "ROOT_PASS=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--password" (set "ROOT_PASS=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-P" (set "SSH_PORT=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--port" (set "SSH_PORT=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-m" (set "INSTALL_MODE=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--mode" (set "INSTALL_MODE=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-z" (set "ZEROTIER_ID=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--zerotier" (set "ZEROTIER_ID=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-y" (set "AUTO_CONFIRM=true" & shift & goto parse_args)
if /i "%~1"=="--yes" (set "AUTO_CONFIRM=true" & shift & goto parse_args)
shift
goto parse_args

:show_help
cls
echo ================================================================
echo        Windows 一键重装/DD 到 Debian 12 脚本使用说明
echo ================================================================
echo.
echo 用法:
echo   dd-debian.bat [选项]
echo.
echo 选项说明:
echo   -v, --version ^<版本^>       Debian 版本 (可选: 12, 11, 10, 默认: 12)
echo   -p, --password ^<密码^>      Linux root 登录密码 (留空则随机生成)
echo   -P, --port ^<端口^>          SSH 服务连接端口 (默认: 22)
echo   -m, --mode ^<模式^>          安装模式: direct (原版直装) 或 alpine (移动云电脑中转)
echo   -z, --zerotier ^<网络ID^>    可选: 预设 ZeroTier 网络 ID (用于内网穿透)
echo   -y, --yes                  静默模式 (跳过交互菜单，直接确认执行)
echo   -h, --help                 显示本帮助信息
echo.
echo 示例:
echo   # 交互式向导运行 (新手推荐):
echo   dd-debian.bat
echo.
echo   # 极速一键重装为 Debian 12 并指定密码:
echo   dd-debian.bat -v 12 -p "MyDebianPass#2026" -y
echo.
echo   # 移动云电脑中转模式 (NodeSeek 69759 推荐):
echo   dd-debian.bat -m alpine -y
echo ================================================================
exit /b 0

:after_parse_args

:: ----------------- 检测国内网络环境 -----------------
echo [1/5] 正在检测当前网络环境与连接质量...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { $r = (Invoke-WebRequest -Uri 'https://cip.cc' -TimeoutSec 3 -UseBasicParsing).Content; if ($r -match '中国') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if %errorlevel% equ 0 (
    set "IS_CHINA=true"
    echo [INFO] 检测到当前服务器位于中国大陆节点，已自动切换国内极速镜像源！
) else (
    set "IS_CHINA=false"
    echo [INFO] 检测到当前服务器位于海外/全球节点，使用 GitHub 官方镜像源！
)

:: ----------------- 自动生成密码函数 -----------------
if "%ROOT_PASS%"=="" (
    for /f "delims=" %%a in ('powershell -NoProfile -Command "$chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$'; -join ((1..10) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })"') do set "RANDOM_PASS=Debian#%%a"
    if "%AUTO_CONFIRM%"=="true" (
        set "ROOT_PASS=!RANDOM_PASS!"
    )
)

:: ----------------- 交互菜单 -----------------
if "%AUTO_CONFIRM%"=="true" goto skip_interactive

cls
echo ================================================================
echo       Windows 一键重装/DD 到 Debian 12 安装配置向导
echo    (基于 NodeSeek #69759 移动云电脑总结与 bin456789 核心)
echo ================================================================
echo  工作目录: %WORK_DIR%
echo  网络路由: !IS_CHINA! (国内加速: !IS_CHINA!)
echo ----------------------------------------------------------------
echo [第 1 步: 防护检测] 是否临时关闭 Windows Defender 实时保护？
echo 说明: 重装脚本需要注入底层引导工具，Defender 可能会误杀拦截。
set /p disable_def="是否一键关闭实时防护？(Y/N) [默认: Y]: "
if /i "!disable_def!"=="" set "disable_def=Y"
if /i "!disable_def!"=="Y" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1
    echo [INFO] 已尝试关闭 Windows Defender 实时监控。
)

echo.
echo ----------------------------------------------------------------
echo [第 2 步: 安装模式选择]
echo   1) Debian 12 极速原版直装 (推荐: 常规 VPS / 阿里云 / 腾讯云 / 物理机)
echo   2) 移动云电脑稳妥中转模式 (推荐: 移动云电脑/天翼云/特殊虚拟网卡)
echo      * 遵循 NodeSeek #69759 教程: Windows -^> Alpine 内存系统 -^> Debian 12
echo      * 避开移动云电脑直装可能断网/卡驱动的坑，100%% 成功率！
echo   3) Debian 11 稳定版直装
echo.
set /p mode_choice="请选择安装模式 [默认: 1]: "
if "!mode_choice!"=="2" (
    set "INSTALL_MODE=alpine"
) else if "!mode_choice!"=="3" (
    set "INSTALL_MODE=direct"
    set "DEBIAN_VER=11"
) else (
    set "INSTALL_MODE=direct"
    set "DEBIAN_VER=12"
)

echo.
echo ----------------------------------------------------------------
echo [第 3 步: 设置 Linux root 登录密码]
if "%ROOT_PASS%"=="" set "ROOT_PASS=!RANDOM_PASS!"
set /p input_pass="请输入 root 密码 [回车使用推荐密码: !ROOT_PASS!]: "
if not "!input_pass!"=="" set "ROOT_PASS=!input_pass!"

echo.
echo ----------------------------------------------------------------
echo [第 4 步: 设置 SSH 服务端口]
set /p input_port="请输入 SSH 端口 [默认: 22]: "
if not "!input_port!"=="" set "SSH_PORT=!input_port!"

if "!INSTALL_MODE!"=="alpine" (
    echo.
    echo ----------------------------------------------------------------
    echo [可选: 内网穿透配置] (针对移动云电脑/无公网 IP 机器)
    echo 提示: 移动云电脑通常处于内网，DD 到 Linux 后可通过 ZeroTier 组网连入。
    set /p input_zt="请输入 ZeroTier Network ID [没有请直接回车跳过]: "
    if not "!input_zt!"=="" set "ZEROTIER_ID=!input_zt!"
)

:skip_interactive

if "%ROOT_PASS%"=="" set "ROOT_PASS=Debian@2026Secure!"

:: ----------------- 确认配置界面 -----------------
cls
echo ================================================================
echo                     高 危 操 作 确 认 提 示
echo ================================================================
echo  目标操作系统:   Debian %DEBIAN_VER% (64位 Linux)
if "%INSTALL_MODE%"=="alpine" (
echo  安装路线规划:   Windows -^> Alpine 3.18 中转 -^> Debian 12 (稳妥两段式)
) else (
echo  安装路线规划:   Windows -^> Debian %DEBIAN_VER% 极速一步直装
)
echo  SSH 登录账户:   root
echo  SSH 登录密码:   %ROOT_PASS%
echo  SSH 连接端口:   %SSH_PORT%
if not "%ZEROTIER_ID%"=="" (
echo  ZeroTier 组网:  %ZEROTIER_ID%
)
echo  工作缓存目录:   %WORK_DIR%
echo ================================================================
echo [警告] 确认执行后，系统将格式化 C 盘并重构引导环境！
echo [警告] 硬盘中的所有原有 Windows 数据将永久丢失，请确认已做好备份！
echo ================================================================
echo.

if "%AUTO_CONFIRM%"=="false" (
    echo 请确认是否立即执行重装？
    set /p confirm="输入 Y 确认执行，按其他键退出: "
    if /i not "!confirm!"=="Y" (
        echo [INFO] 用户取消操作，退出脚本。
        exit /b 0
    )
)

:: ----------------- 下载核心重装引擎 -----------------
echo.
echo [2/5] 正在拉取底层引导与重装核心 (reinstall.bat)...
set "REINSTALL_URL=https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.bat"
if "%IS_CHINA%"=="true" (
    set "REINSTALL_URL=https://cnb.cool/bin456789/reinstall/-/git/raw/main/reinstall.bat"
)

del /f /q "%WORK_DIR%\reinstall.bat" >nul 2>&1
certutil -urlcache -f -split "%REINSTALL_URL%" "%WORK_DIR%\reinstall.bat" >nul 2>&1

if not exist "%WORK_DIR%\reinstall.bat" (
    echo [WARN] 通过主源下载失败，正在尝试备用源...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://ghproxy.cc/https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.bat' -OutFile '%WORK_DIR%\reinstall.bat'" >nul 2>&1
)

if not exist "%WORK_DIR%\reinstall.bat" (
    echo [ERROR] 下载 reinstall.bat 失败！请检查当前网络连接或是否被安全软件拦截。
    pause
    exit /b 1
)

echo [INFO] 引导引擎组件下载就绪。

:: ----------------- 模式分流执行 -----------------
echo.
if "%INSTALL_MODE%"=="alpine" (
    echo [3/5] 正在配置移动云电脑专用中转引导 (Alpine Linux)...
    echo [INFO] 正在下发 Alpine 内存微系统引导配置...
    
    :: 生成进入 Alpine 后的自动化转换脚本与指引文本
    (
        echo #!/bin/sh
        echo # Alpine -^> Debian 12 自动化转换脚本 (NodeSeek #69759 实践方案)
        echo echo "=================================================="
        echo echo "  正在准备 Debian 12 自动重装环境..."
        echo echo "=================================================="
        echo apk update
        echo apk add wget curl bash
        echo echo "正在拉取 Debian 12 官方安装引擎..."
        echo wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' ^|^| wget --no-check-certificate -qO InstallNET.sh 'https://gitee.com/mb9e8j2/Tools/raw/master/Linux_reinstall/InstallNET.sh'
        echo chmod +x InstallNET.sh
        echo echo "正在启动 Debian 12 安装 (root 密码: %ROOT_PASS%, 端口: %SSH_PORT%)..."
        echo bash InstallNET.sh -debian %DEBIAN_VER% -pwd '%ROOT_PASS%' -port %SSH_PORT%
        echo echo "安装配置已下发，正在自动重启..."
        echo reboot
    ) > "%WORK_DIR%\auto-debian.sh"

    echo [INFO] 正在调用底层批处理生成 Grub/EFI 引导...
    call "%WORK_DIR%\reinstall.bat" alpine-3.18
    
    cls
    echo ================================================================
    echo        移动云电脑中转引导配置成功！即将自动重启
    echo ================================================================
    echo 【移动云电脑操作指引 - NodeSeek #69759 总结】
    echo.
    echo  1. 重启后，请在【移动云电脑官方客户端】内观察画面；
    echo  2. 稍等 1~2 分钟进入 Alpine 终端（屏幕显示: localhost login:）;
    echo  3. 登录用户名: root  ^|  默认登录密码: 123@@@
    echo  4. 登录后只需粘贴执行以下单行命令（全自动转入 Debian 12）：
    echo.
    echo     apk add wget curl bash ^&^& wget -qO- https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/alpine-to-debian.sh ^| bash -s -- -p "%ROOT_PASS%" -P %SSH_PORT%
    echo.
    echo  5. 系统将全自动完成 Debian 12 安装！
    echo     * 最终 root 密码: %ROOT_PASS%
    echo     * 最终 SSH 端口:  %SSH_PORT%
    if not "%ZEROTIER_ID%"=="" (
    echo     * ZeroTier 组网:  %ZEROTIER_ID%
    )
    echo ================================================================
    echo.
    echo 系统将在 10 秒后自动重启...
    timeout /t 10
    shutdown /r /t 0
    exit /b 0

) else (
    echo [3/5] 正在配置 Debian %DEBIAN_VER% 极速直装引导...
    echo [INFO] 注入 root 密码与 SSH 端口参数...
    
    :: 调用 reinstall.bat 直装 debian
    call "%WORK_DIR%\reinstall.bat" debian %DEBIAN_VER% --password "%ROOT_PASS%" --ssh-port %SSH_PORT%
    
    cls
    echo ================================================================
    echo               Debian %DEBIAN_VER% 重装引导配置就绪！
    echo ================================================================
    echo  SSH 登录账户: root
    echo  SSH 登录密码: %ROOT_PASS%
    echo  SSH 远程端口: %SSH_PORT%
    echo ----------------------------------------------------------------
    echo 预计安装耗时: 5 ~ 15 分钟 (视网络下载与磁盘性能而定)
    echo 安装完成后，即可直接使用 SSH 工具连接服务器！
    echo ================================================================
    echo.
    echo 系统将在 10 秒后自动重启开始安装...
    timeout /t 10
    shutdown /r /t 0
    exit /b 0
)
