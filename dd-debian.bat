@echo off
rem ==============================================================================
rem Script Name: dd-debian.bat
rem Description: Windows 一键重装/DD 至 Debian (11/12/13) 与 Ubuntu (24.04/26.04)
rem Reference:   NodeSeek #69759 (移动云电脑DD Linux 总结) & bin456789/reinstall
rem Features:
rem   1. 自动管理员权限提升 (UAC 智能弹窗，/k 保活防闪退)
rem   2. 自动检测并一键关闭 Windows Defender 实时保护 (防误杀)
rem   3. 智能国内外网络环境探测，境内自动启用国内高速加速源
rem   4. 多系统与双模式支持:
rem      - Debian 12 (稳定推荐) / Debian 13 [Trixie] / Debian 11 [Bullseye]
rem      - Ubuntu 24.04 LTS (Noble) / Ubuntu 26.04 LTS (Resolute)
rem      - 模式 A: 极速原版直装 (适合普通 VPS / 阿里云 / 腾讯云 / 物理机)
rem      - 模式 B: 移动云电脑专用 Alpine 中转模式 (NodeSeek 69759 方案，极高容错，防断网)
rem   5. 自定义 SSH 端口与 root 密码 (支持随机高强度密码生成)
rem   6. 自动构建 C:\DD 规范工作区，防止路径空格与中文导致引导失败
rem   7. 交互式菜单向导与 CLI 静默参数双重支持
rem ==============================================================================

setlocal enabledelayedexpansion
chcp 65001 >nul

rem ----------------- 检查并提升管理员权限 -----------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] 正在请求系统管理员权限以配置底层引导...
powershell -NoProfile -ExecutionPolicy Bypass -Command "='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = 3072; [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {}; try { (New-Object System.Net.WebClient).DownloadFile('%SRC1%', '%WORK_DIR%
einstall.bat') } catch { (New-Object System.Net.WebClient).DownloadFile('%SRC2%', '%WORK_DIR%
einstall.bat') }" >nul 2>&1
einstall.bat\') } catch { (New-Object System.Net.WebClient).DownloadFile(\'%SRC2%\', \'%WORK_DIR%
einstall.bat\') }" >nul 2>&1
    if !errorlevel! neq 0 (
        echo.
        echo ================================================================
        echo [错误] 自动申请管理员权限失败！
        echo 请直接右键点击本批处理文件，选择【以管理员身份运行】！
        echo ================================================================
        pause
    )
    exit /b
)

rem ----------------- 初始化默认变量 -----------------
set "TARGET_OS=debian"
set "OS_VER=12"
set "OS_DISPLAY=Debian 12"
set "SSH_PORT=22"
set "ROOT_PASS="
set "INSTALL_MODE=direct"
set "AUTO_CONFIRM=false"
set "WORK_DIR=C:\DD"
set "IS_CHINA=false"
set "ZEROTIER_ID="

rem ----------------- 创建规范工作目录 -----------------
if not exist "%WORK_DIR%" (
    mkdir "%WORK_DIR%" >nul 2>&1
)
cd /d "%WORK_DIR%"

rem ----------------- 参数解析 -----------------
:parse_args
if "%~1"=="" goto after_parse_args
if /i "%~1"=="-h" goto show_help
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-o" (set "TARGET_OS=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--os" (set "TARGET_OS=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-v" (set "OS_VER=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="--version" (set "OS_VER=%~2" & shift & shift & goto parse_args)
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
echo        Windows 一键重装/DD 到 Debian / Ubuntu 脚本使用说明
echo ================================================================
echo.
echo 用法:
echo   dd-debian.bat [选项]
echo.
echo 选项说明:
echo   -o, --os ^<系统^>           目标操作系统 (可选: debian, ubuntu, 默认: debian)
echo   -v, --version ^<版本^>       系统版本:
echo                                Debian: 12 (默认), 13 [Trixie], 11 [Bullseye]
echo                                Ubuntu: 24.04 (或 24), 26.04 (或 26), 22.04
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
echo   # 极速一键重装为 Debian 13 并指定密码:
echo   dd-debian.bat -v 13 -p "MyDebian13Pass#2026" -y
echo.
echo   # 极速一键重装为 Ubuntu 24.04 LTS:
echo   dd-debian.bat -o ubuntu -v 24 -p "MyUbuntuPass#2026" -y
echo.
echo   # 移动云电脑中转模式 (转入 Debian 13):
echo   dd-debian.bat -m alpine -v 13 -y
echo ================================================================
pause
exit /b 0

:after_parse_args

rem ----------------- 版本与操作系统智能自适应 -----------------
if "!OS_VER!"=="24" set "TARGET_OS=ubuntu"
if "!OS_VER!"=="24.04" set "TARGET_OS=ubuntu"
if "!OS_VER!"=="26" set "TARGET_OS=ubuntu"
if "!OS_VER!"=="26.04" set "TARGET_OS=ubuntu"
if "!OS_VER!"=="22" set "TARGET_OS=ubuntu"
if "!OS_VER!"=="22.04" set "TARGET_OS=ubuntu"

rem 规范化系统与版本
if /i "!TARGET_OS!"=="ubuntu" (
    set "TARGET_OS=ubuntu"
    if "!OS_VER!"=="24" set "OS_VER=24.04"
    if "!OS_VER!"=="26" set "OS_VER=26.04"
    if "!OS_VER!"=="22" set "OS_VER=22.04"
    if "!OS_VER!"=="" set "OS_VER=24.04"
    if "!OS_VER!"=="12" set "OS_VER=24.04"
    set "OS_DISPLAY=Ubuntu !OS_VER! LTS"
) else (
    set "TARGET_OS=debian"
    if "!OS_VER!"=="" set "OS_VER=12"
    if "!OS_VER!"=="13" (
        set "OS_DISPLAY=Debian 13 [Trixie]"
    ) else if "!OS_VER!"=="11" (
        set "OS_DISPLAY=Debian 11 [Bullseye]"
    ) else (
        set "OS_DISPLAY=Debian !OS_VER!"
    )
)

rem ----------------- 检测国内网络环境 -----------------
echo [1/5] 正在检测当前网络环境与连接质量...
powershell -NoProfile -ExecutionPolicy Bypass -Command "='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = 3072; [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {}; try { (New-Object System.Net.WebClient).DownloadFile('%SRC1%', '%WORK_DIR%
einstall.bat') } catch { (New-Object System.Net.WebClient).DownloadFile('%SRC2%', '%WORK_DIR%
einstall.bat') }" >nul 2>&1
einstall.bat\') } catch { (New-Object System.Net.WebClient).DownloadFile(\'%SRC2%\', \'%WORK_DIR%
einstall.bat\') }" >nul 2>&1
if %errorlevel% equ 0 (
    set "IS_CHINA=true"
    echo [INFO] 检测到当前服务器位于中国大陆节点，已自动切换国内极速镜像源！
) else (
    set "IS_CHINA=false"
    echo [INFO] 检测到当前服务器位于海外/全球节点，使用 GitHub 官方镜像源！
)

rem ----------------- 自动生成密码函数 -----------------
if "%ROOT_PASS%"=="" (
    for /f "delims=" %%a in ('powershell -NoProfile -Command "$chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789@#'; -join ((1..10) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })"') do (
        if "!TARGET_OS!"=="ubuntu" (
            set "RANDOM_PASS=Ubuntu#%%a"
        ) else (
            set "RANDOM_PASS=Debian#%%a"
        )
    )
    if "%AUTO_CONFIRM%"=="true" (
        set "ROOT_PASS=!RANDOM_PASS!"
    )
)

rem ----------------- 交互菜单 -----------------
if "%AUTO_CONFIRM%"=="true" goto skip_interactive

cls
echo ================================================================
echo    Windows 一键重装/DD 到 Linux 安装配置向导 (Debian / Ubuntu)
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
powershell -NoProfile -ExecutionPolicy Bypass -Command "='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = 3072; [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {}; try { (New-Object System.Net.WebClient).DownloadFile('%SRC1%', '%WORK_DIR%
einstall.bat') } catch { (New-Object System.Net.WebClient).DownloadFile('%SRC2%', '%WORK_DIR%
einstall.bat') }" >nul 2>&1
einstall.bat\') } catch { (New-Object System.Net.WebClient).DownloadFile(\'%SRC2%\', \'%WORK_DIR%
einstall.bat\') }" >nul 2>&1
    echo [INFO] 已尝试关闭 Windows Defender 实时监控。
)

echo.
echo ----------------------------------------------------------------
echo [第 2 步: 目标系统与重装模式选择]
echo.
echo   【Debian 官方极速直装 (推荐: 常规 VPS / 阿里云 / 腾讯云 / 物理机)】
echo     1) Debian 12 (Bookworm - 官方推荐稳定版) [默认]
echo     2) Debian 13 (Trixie - 最新预发布版)
echo     3) Debian 11 (Bullseye - 经典旧稳定版)
echo.
echo   【Ubuntu 官方极速直装 (推荐: 常规 VPS / 阿里云 / 腾讯云 / 物理机)】
echo     4) Ubuntu 24.04 LTS (Noble Numbat - 长期支持版)
echo     5) Ubuntu 26.04 LTS (Resolute - 最新长期支持版)
echo.
echo   【移动云电脑稳妥中转模式 (NodeSeek #69759 推荐方案，100%% 成功率)】
echo     6) Alpine 中转 -^> Debian 12 (移动云电脑推荐首选)
echo     7) Alpine 中转 -^> Debian 13 [Trixie]
echo     8) Alpine 中转 -^> Ubuntu 24.04 LTS
echo     9) Alpine 中转 -^> Ubuntu 26.04 LTS
echo.
set /p mode_choice="请选择安装模式与目标系统 [默认: 1]: "
if "!mode_choice!"=="2" (
    set "INSTALL_MODE=direct"
    set "TARGET_OS=debian"
    set "OS_VER=13"
    set "OS_DISPLAY=Debian 13 [Trixie]"
) else if "!mode_choice!"=="3" (
    set "INSTALL_MODE=direct"
    set "TARGET_OS=debian"
    set "OS_VER=11"
    set "OS_DISPLAY=Debian 11 [Bullseye]"
) else if "!mode_choice!"=="4" (
    set "INSTALL_MODE=direct"
    set "TARGET_OS=ubuntu"
    set "OS_VER=24.04"
    set "OS_DISPLAY=Ubuntu 24.04 LTS"
) else if "!mode_choice!"=="5" (
    set "INSTALL_MODE=direct"
    set "TARGET_OS=ubuntu"
    set "OS_VER=26.04"
    set "OS_DISPLAY=Ubuntu 26.04 LTS"
) else if "!mode_choice!"=="6" (
    set "INSTALL_MODE=alpine"
    set "TARGET_OS=debian"
    set "OS_VER=12"
    set "OS_DISPLAY=Debian 12"
) else if "!mode_choice!"=="7" (
    set "INSTALL_MODE=alpine"
    set "TARGET_OS=debian"
    set "OS_VER=13"
    set "OS_DISPLAY=Debian 13 [Trixie]"
) else if "!mode_choice!"=="8" (
    set "INSTALL_MODE=alpine"
    set "TARGET_OS=ubuntu"
    set "OS_VER=24.04"
    set "OS_DISPLAY=Ubuntu 24.04 LTS"
) else if "!mode_choice!"=="9" (
    set "INSTALL_MODE=alpine"
    set "TARGET_OS=ubuntu"
    set "OS_VER=26.04"
    set "OS_DISPLAY=Ubuntu 26.04 LTS"
) else (
    set "INSTALL_MODE=direct"
    set "TARGET_OS=debian"
    set "OS_VER=12"
    set "OS_DISPLAY=Debian 12"
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

if not "!INSTALL_MODE!"=="alpine" goto skip_zerotier_prompt
echo.
echo ----------------------------------------------------------------
echo [可选: 内网穿透配置] [针对移动云电脑/无公网 IP 机器]
echo 提示: 移动云电脑通常处于内网，DD 到 Linux 后可通过 ZeroTier 组网连入。
set /p input_zt="请输入 ZeroTier Network ID [没有请直接回车跳过]: "
if not "!input_zt!"=="" set "ZEROTIER_ID=!input_zt!"
:skip_zerotier_prompt

:skip_interactive

if "%ROOT_PASS%"=="" (
    if "!TARGET_OS!"=="ubuntu" (
        set "ROOT_PASS=Ubuntu@2026Secure"
    ) else (
        set "ROOT_PASS=Debian@2026Secure"
    )
)

rem ----------------- 确认配置界面 -----------------
cls
echo ================================================================
echo                     高 危 操 作 确 认 提 示
echo ================================================================
echo  目标操作系统:   !OS_DISPLAY! [64位 Linux]
if "%INSTALL_MODE%"=="alpine" echo  安装路线规划:   Windows -^> Alpine 3.18 中转 -^> !OS_DISPLAY! [稳妥两段式]
if not "%INSTALL_MODE%"=="alpine" echo  安装路线规划:   Windows -^> !OS_DISPLAY! 极速一步直装
echo  SSH 登录账户:   root
echo  SSH 登录密码:   %ROOT_PASS%
echo  SSH 连接端口:   %SSH_PORT%
if not "%ZEROTIER_ID%"=="" echo  ZeroTier 组网:  %ZEROTIER_ID%
echo  工作缓存目录:   %WORK_DIR%
echo ================================================================
echo [警告] 确认执行后，系统将格式化 C 盘并重构引导环境！
echo [警告] 硬盘中的所有原有 Windows 数据将永久丢失，请确认已做好备份！
echo ================================================================
echo.

if /i "%AUTO_CONFIRM%"=="true" goto do_install_confirm

echo 请确认是否立即执行重装？
set "confirm="
set /p confirm="输入 Y 确认执行，按其他键退出: "
if /i "!confirm!"=="Y" goto do_install_confirm
if /i "!confirm!"=="YES" goto do_install_confirm
if /i "!confirm!"=="y" goto do_install_confirm

echo.
echo [INFO] 用户取消操作，退出脚本。
pause
exit /b 0

:do_install_confirm
rem ----------------- 下载或获取核心重装引擎 -----------------
echo.
echo [2/5] 正在准备底层引导与重装核心 [reinstall.bat]...

rem 预生成 geoip 避免 reinstall.bat 内置 certutil 出现 0x80072f8f 证书错误
if "%IS_CHINA%"=="true" (
    echo loc=CN> "%WORK_DIR%\geoip"
) else (
    echo loc=US> "%WORK_DIR%\geoip"
)

rem 1. 优先使用当前目录已有的 reinstall.bat
if exist "%~dp0reinstall.bat" (
    echo [INFO] 检测到本地目录存在 reinstall.bat，正在直接同步到工作区...
    copy /y "%~dp0reinstall.bat" "%WORK_DIR%\reinstall.bat" >nul 2>&1
)

rem 2. 若工作区已存在且有效，直接复用（切勿重复下载或删除）
if exist "%WORK_DIR%\reinstall.bat" (
    echo [INFO] 底层重装核心 [reinstall.bat] 已就绪，直接使用。
    goto skip_download_reinstall
)

rem 3. 尝试从国内腾讯云 CNB / GitMirror / 官方源高速拉取
set "SRC1=http://cnb.cool/bin456789/reinstall/-/git/raw/main/reinstall.bat"
set "SRC2=https://cnb.cool/bin456789/reinstall/-/git/raw/main/reinstall.bat"
set "SRC3=https://raw.gitmirror.com/bin456789/reinstall/main/reinstall.bat"
set "SRC4=https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.bat"

where curl >nul 2>&1
if !errorlevel! equ 0 (
    curl -k -s -L -f -o "%WORK_DIR%\reinstall.bat" "%SRC1%" >nul 2>&1
    if not exist "%WORK_DIR%\reinstall.bat" curl -k -s -L -f -o "%WORK_DIR%\reinstall.bat" "%SRC2%" >nul 2>&1
    if not exist "%WORK_DIR%\reinstall.bat" curl -k -s -L -f -o "%WORK_DIR%\reinstall.bat" "%SRC3%" >nul 2>&1
    if not exist "%WORK_DIR%\reinstall.bat" curl -k -s -L -f -o "%WORK_DIR%\reinstall.bat" "%SRC4%" >nul 2>&1
)

if not exist "%WORK_DIR%\reinstall.bat" certutil -urlcache -f -split "%SRC1%" "%WORK_DIR%\reinstall.bat" >nul 2>&1
if not exist "%WORK_DIR%\reinstall.bat" certutil -urlcache -f -split "%SRC2%" "%WORK_DIR%\reinstall.bat" >nul 2>&1
if not exist "%WORK_DIR%\reinstall.bat" certutil -urlcache -f -split "%SRC3%" "%WORK_DIR%\reinstall.bat" >nul 2>&1

if exist "%WORK_DIR%\reinstall.bat" goto skip_ps_download
echo [WARN] 正在启用 PowerShell 安全通道拉取组件...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = 3072; [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}; try { (New-Object System.Net.WebClient).DownloadFile('%SRC1%', '%WORK_DIR%\reinstall.bat') } catch { (New-Object System.Net.WebClient).DownloadFile('%SRC2%', '%WORK_DIR%\reinstall.bat') }" >nul 2>&1
:skip_ps_download

rem 4. 若所有网络下载均受阻，直接从内置模块自解包（零网络依赖兜底）
if not exist "%WORK_DIR%\reinstall.bat" call :extract_embedded_reinstall

if exist "%WORK_DIR%\reinstall.bat" goto skip_download_reinstall
echo.
echo ================================================================
echo [ERROR] 获取 reinstall.bat 失败！
echo 请检查当前网络连接，或手动下载 reinstall.bat 放入 C:\DD 目录。
echo ================================================================
pause
exit /b 1

:skip_download_reinstall
echo [INFO] 引导引擎组件下载就绪。

rem ----------------- 模式分流执行 -----------------
echo.
if /i "%INSTALL_MODE%"=="alpine" goto do_alpine_mode
goto do_direct_mode

:do_alpine_mode
echo [3/5] 正在配置移动云电脑专用中转引导 [Alpine Linux]...
echo [INFO] 正在下发 Alpine 内存微系统引导配置...

echo #!/bin/sh> "%WORK_DIR%\auto-linux.sh"
echo # Alpine to !OS_DISPLAY! auto install>> "%WORK_DIR%\auto-linux.sh"
echo echo "==================================================">> "%WORK_DIR%\auto-linux.sh"
echo echo "  正在准备 !OS_DISPLAY! 自动重装环境...">> "%WORK_DIR%\auto-linux.sh"
echo echo "==================================================">> "%WORK_DIR%\auto-linux.sh"
echo apk update>> "%WORK_DIR%\auto-linux.sh"
echo apk add wget curl bash>> "%WORK_DIR%\auto-linux.sh"
echo echo "正在拉取官方安装引擎...">> "%WORK_DIR%\auto-linux.sh"
echo wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' ^|^| wget --no-check-certificate -qO InstallNET.sh 'https://gitee.com/mb9e8j2/Tools/raw/master/Linux_reinstall/InstallNET.sh'>> "%WORK_DIR%\auto-linux.sh"
echo chmod +x InstallNET.sh>> "%WORK_DIR%\auto-linux.sh"
echo echo "正在启动 !OS_DISPLAY! 安装 [root 密码: %ROOT_PASS%, 端口: %SSH_PORT%]...">> "%WORK_DIR%\auto-linux.sh"
echo bash InstallNET.sh -%TARGET_OS% %OS_VER% -pwd '%ROOT_PASS%' -port %SSH_PORT%>> "%WORK_DIR%\auto-linux.sh"
echo echo "安装配置已下发，正在自动重启...">> "%WORK_DIR%\auto-linux.sh"
echo reboot>> "%WORK_DIR%\auto-linux.sh"

copy /y "%WORK_DIR%\auto-linux.sh" "%WORK_DIR%\auto-debian.sh" >nul 2>&1

echo [INFO] 正在调用底层批处理生成 Grub/EFI 引导...
call "%WORK_DIR%\reinstall.bat" alpine-3.18
if !errorlevel! equ 0 goto alpine_success
echo.
echo ================================================================
echo [ERROR] 引导工具执行失败，退出代码: !errorlevel!
echo 请检查上方执行日志，按任意键退出...
echo ================================================================
pause
exit /b !errorlevel!

:alpine_success
cls
echo ================================================================
echo        移动云电脑中转引导配置成功！即将自动重启
echo ================================================================
echo 【移动云电脑操作指引 - NodeSeek #69759 总结】
echo.
echo  1. 重启后，请在【移动云电脑官方客户端】内观察画面；
echo  2. 稍等 1~2 分钟进入 Alpine 终端 [屏幕显示: localhost login:]；
echo  3. 登录用户名: root  ^|  默认登录密码: 123@@@
echo  4. 登录后只需粘贴执行以下单行命令（全自动转入 !OS_DISPLAY!）：
echo.
if "%IS_CHINA%"=="true" (
    echo     apk add wget curl bash ^&^& wget -qO- https://ghproxy.cc/https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/alpine-to-debian.sh ^| bash -s -- -o %TARGET_OS% -v %OS_VER% -p "%ROOT_PASS%" -P %SSH_PORT%
) else (
    echo     apk add wget curl bash ^&^& wget -qO- https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/alpine-to-debian.sh ^| bash -s -- -o %TARGET_OS% -v %OS_VER% -p "%ROOT_PASS%" -P %SSH_PORT%
)
echo.
echo  5. 系统将全自动完成 !OS_DISPLAY! 安装！
echo     * 最终 root 密码: %ROOT_PASS%
echo     * 最终 SSH 端口:  %SSH_PORT%
if not "%ZEROTIER_ID%"=="" echo     * ZeroTier 组网:  %ZEROTIER_ID%
echo ================================================================
echo.
echo 系统将在 10 秒后自动重启...
timeout /t 10
shutdown /r /t 0
exit /b 0

:do_direct_mode
echo [3/5] 正在配置 !OS_DISPLAY! 极速直装引导...
echo [INFO] 注入 root 密码与 SSH 端口参数...

call "%WORK_DIR%\reinstall.bat" %TARGET_OS% %OS_VER% --password "%ROOT_PASS%" --ssh-port %SSH_PORT%
if !errorlevel! equ 0 goto direct_success
echo.
echo ================================================================
echo [ERROR] 直装引导配置失败，退出代码: !errorlevel!
echo 请检查上方执行日志，按任意键退出...
echo ================================================================
pause
exit /b !errorlevel!

:direct_success
cls
echo ================================================================
echo               !OS_DISPLAY! 重装引导配置就绪！
echo ================================================================
echo  目标系统:   !OS_DISPLAY!
echo  SSH 登录账户: root
echo  SSH 登录密码: %ROOT_PASS%
echo  SSH 远程端口: %SSH_PORT%
echo ----------------------------------------------------------------
echo 预计安装耗时: 5 ~ 15 分钟 [视网络下载与磁盘性能而定]
echo 安装完成后，即可直接使用 SSH 工具连接服务器！
echo ================================================================
echo.
echo 系统将在 10 秒后自动重启开始安装...
timeout /t 10
shutdown /r /t 0
exit /b 0

:extract_embedded_reinstall
echo [INFO] 正在从内置数据包自解包释放 reinstall.bat 核心...
(
echo -----BEGIN CERTIFICATE-----
echo QGVjaG8gb2ZmDQptb2RlIGNvbiBjcCBzZWxlY3Q9NDM3ID5udWwNCnNldGxvY2FsIEVuYWJsZURl
echo bGF5ZWRFeHBhbnNpb24NCg0Kc2V0IGNvbmZob21lPWh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250
echo ZW50LmNvbS9iaW40NTY3ODkvcmVpbnN0YWxsL21haW4NCnNldCBjb25maG9tZV9jbj1odHRwczov
echo L2NuYi5jb29sL2JpbjQ1Njc4OS9yZWluc3RhbGwvLS9naXQvcmF3L21haW4NCnJlbSBzZXQgY29u
echo ZmhvbWVfY249aHR0cHM6Ly93d3cuZ2hwcm94eS5jYy9odHRwczovL3Jhdy5naXRodWJ1c2VyY29u
echo dGVudC5jb20vYmluNDU2Nzg5L3JlaW5zdGFsbC9tYWluDQoNCnNldCBwa2dzPWN1cmwsY3Bpbyxw
echo N3ppcCxkb3MydW5peCxqcSx4eixnemlwLHpzdGQsb3BlbnNzbCxiaW5kLXV0aWxzLGxpYmljb252
echo LGJpbnV0aWxzDQpzZXQgY21kcz1jdXJsLGNwaW8scDd6aXAsZG9zMnVuaXgsanEseHosZ3ppcCx6
echo c3RkLG9wZW5zc2wsbnNsb29rdXAsaWNvbnYsYXINCg0KcmVtIDY1MDAxIOS7o+eggemhteS8muS5
echo seeggQ0KDQpyZW0g5LiN6KaB55SoIDo6IOazqOmHig0KcmVtIOWQpuWImeWPr+iDveS8muWHuueO
echo sCDns7vnu5/mib7kuI3liLDmjIflrprnmoTpqbHliqjlmagNCg0KcmVtIFdpbmRvd3MgNyBTUDEg
echo d2luaHR0cCDpu5jorqTkuI3mlK/mjIEgdGxzIDEuMg0KcmVtIGh0dHBzOi8vc3VwcG9ydC5taWNy
echo b3NvZnQuY29tL2VuLXVzL3RvcGljL3VwZGF0ZS10by1lbmFibGUtdGxzLTEtMS1hbmQtdGxzLTEt
echo Mi1hcy1kZWZhdWx0LXNlY3VyZS1wcm90b2NvbHMtaW4td2luaHR0cC1pbi13aW5kb3dzLWM0YmQ3
echo M2QyLTMxZDctNzYxZS0wMTc4LTExMjY4YmIxMDM5Mg0KcmVtIOacieS6m+ezu+e7n+agueivgeS5
echo puayoeabtOaWsA0KcmVtIOaJgOS7peS4jeimgeeUqGh0dHBzDQpyZW0g6L+b5YWl6ISa5pys55uu
echo 5b2VDQpjZCAvZCAlfmRwMA0KDQpyZW0g5qOA5p+l5piv5ZCm5pyJ566h55CG5ZGY5p2D6ZmQDQpm
echo bHRtYyA+bnVsIDI+JjENCmlmIGVycm9ybGV2ZWwgMSAoDQogICAgZWNobyBQbGVhc2UgcnVuIGFz
echo IGFkbWluaXN0cmF0b3JeXiENCiAgICBleGl0IC9iDQopDQoNCnJlbSDmnInml7YgJXRtcCUg5bim
echo 5Lya6K+dIGlk77yM5LiU5paH5Lu25aS55LiN5a2Y5ZyoDQpyZW0gaHR0cHM6Ly9sZWFybi5taWNy
echo b3NvZnQuY29tL3Ryb3VibGVzaG9vdC93aW5kb3dzLXNlcnZlci9zaGVsbC1leHBlcmllbmNlL3Rl
echo bXAtZm9sZGVyLXdpdGgtbG9nb24tc2Vzc2lvbi1pZC1kZWxldGVkDQpyZW0gaWYgbm90IGV4aXN0
echo ICV0bXAlICgNCnJlbSAgICAgbWQgJXRtcCUNCnJlbSApDQoNCnJlbSDkuIvovb0gZ2VvaXANCmlm
echo IG5vdCBleGlzdCBnZW9pcCAoDQogICAgcmVtIHd3dy5jbG91ZGZsYXJlLmNvbS9kYXNoLmNsb3Vk
echo ZmxhcmUuY29tIOWbveWGheiuv+mXrueahOaYr+e+juWbveacjeWKoeWZqO+8jOiAjOS4lOmDqOWI
echo huWcsOWMuuiiq+WimQ0KICAgIGNhbGwgOmRvd25sb2FkIGh0dHA6Ly93d3cucXVhbGNvbW0uY24v
echo Y2RuLWNnaS90cmFjZSAlfmRwMGdlb2lwIHx8IGdvdG8gOmRvd25sb2FkX2ZhaWxlZA0KKQ0KDQpy
echo ZW0g5Yik5pat5piv5ZCm5pyJIGxvYz0NCmZpbmRzdHIgL2M6ImxvYz0iIGdlb2lwID5udWwNCmlm
echo IGVycm9ybGV2ZWwgMSAoDQogICAgZWNobyBJbnZhbGlkIGdlb2lwIGZpbGUNCiAgICBkZWwgZ2Vv
echo aXANCiAgICBleGl0IC9iIDENCikNCg0KcmVtIOajgOafpeaYr+WQpuWbveWGhQ0KZmluZHN0ciAv
echo YzoibG9jPUNOIiBnZW9pcCA+bnVsDQppZiBub3QgZXJyb3JsZXZlbCAxICgNCiAgICByZW0gbWly
echo cm9ycy50dW5hLnRzaW5naHVhLmVkdS5jbiDkvJrlvLrliLbot7PovawgaHR0cHMNCiAgICBzZXQg
echo bWlycm9yPWh0dHA6Ly9taXJyb3Iubmp1LmVkdS5jbg0KICAgIGlmIGRlZmluZWQgY29uZmhvbWVf
echo Y24gKA0KICAgICAgICBzZXQgY29uZmhvbWU9IWNvbmZob21lX2NuIQ0KICAgICkgZWxzZSBpZiBk
echo ZWZpbmVkIGdpdGh1Yl9wcm94eSAoDQogICAgICAgIGVjaG8gIWNvbmZob21lISB8IGZpbmRzdHIg
echo L2M6IjovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20vIiA+bnVsDQogICAgICAgIGlmIG5vdCBl
echo cnJvcmxldmVsIDEgKA0KICAgICAgICAgICAgc2V0IGNvbmZob21lPSFjb25maG9tZTpodHRwOi8v
echo PWh0dHBzOi8vIQ0KICAgICAgICAgICAgc2V0IGNvbmZob21lPSFjb25maG9tZTpodHRwczovL3Jh
echo dy5naXRodWJ1c2VyY29udGVudC5jb209JWdpdGh1Yl9wcm94eSUhDQogICAgICAgICkNCiAgICAp
echo DQopIGVsc2UgKA0KICAgIHJlbSDmnI3liqHlmajlnKjnvo7lm70gZXF1aW5peCDmnLrmiL/vvIzk
echo uI3mmK8gY2RuDQogICAgc2V0IG1pcnJvcj1odHRwOi8vbWlycm9ycy5rZXJuZWwub3JnDQopDQoN
echo CmNhbGwgOmNoZWNrX2N5Z3dpbl9pbnN0YWxsZWQgfHwgKA0KICAgIHJlbSB3aW4xMCBhcm0g5pSv
echo 5oyB6L+Q6KGMIHg4NiDova/ku7YNCiAgICByZW0gd2luMTEgYXJtIOaUr+aMgei/kOihjCB4ODYg
echo 5ZKMIHg4Nl82NCDova/ku7YNCg0KICAgIHJlbSB3aW5kb3dzIDExIDI0aDIg5rKh5pyJIHdtaWMN
echo CiAgICByZW0gd21pYyBvcyBnZXQgb3NhcmNoaXRlY3R1cmUg5pi+56S65Lit5paH77yM5Y2z5L2/
echo 6K6+572u5LqGIG1vZGUgY29uIGNwIHNlbGVjdD00MzcNCiAgICByZW0gd21pYyBDb21wdXRlclN5
echo c3RlbSBnZXQgU3lzdGVtVHlwZSDmmL7npLroi7HmlocNCiAgICByZW0gZm9yIC9mICJ0b2tlbnM9
echo KiIgJSVhIGluICgnd21pYyBDb21wdXRlclN5c3RlbSBnZXQgU3lzdGVtVHlwZSBefCBmaW5kIC9p
echo ICJiYXNlZCInKSBkbyAoDQogICAgcmVtICAgICBzZXQgIlN5c3RlbVR5cGU9JSVhIg0KICAgIHJl
echo bSApDQoNCiAgICByZW0g5pyJ55qE57O757uf57K+566A5LqGIHBvd2Vyc2hlbGwNCiAgICByZW0g
echo Zm9yIC9mICJkZWxpbXM9IiAlJWEgaW4gKCdwb3dlcnNoZWxsIC1Ob0xvZ28gLU5vUHJvZmlsZSAt
echo Tm9uSW50ZXJhY3RpdmUgLUNvbW1hbmQgIihHZXQtV21pT2JqZWN0IHdpbjMyX2NvbXB1dGVyc3lz
echo dGVtKS5TeXN0ZW1UeXBlIicpIGRvICgNCiAgICByZW0gICAgIHNldCAiU3lzdGVtVHlwZT0lJWEi
echo DQogICAgcmVtICkNCg0KICAgIHJlbSBTeXN0ZW1BcmNoDQogICAgZm9yIC9mICJ0b2tlbnM9MyIg
echo JSVhIGluICgncmVnIHF1ZXJ5ICJIS0xNXFNZU1RFTVxDdXJyZW50Q29udHJvbFNldFxDb250cm9s
echo XFNlc3Npb24gTWFuYWdlclxFbnZpcm9ubWVudCIgL3YgUFJPQ0VTU09SX0FSQ0hJVEVDVFVSRScp
echo IGRvICgNCiAgICAgICAgc2V0IFN5c3RlbUFyY2g9JSVhDQogICAgKQ0KDQogICAgcmVtIOS5n+WP
echo r+S7peeUqCBQUk9DRVNTT1JfQVJDSElURVc2NDMyIOWSjCBQUk9DRVNTT1JfQVJDSElURUNUVVJF
echo IOWIpOaWrQ0KICAgIHJlbSBBUk02NCB3aW4xMSAgUFJPQ0VTU09SX0FSQ0hJVEVXNjQzMiAgIFBS
echo T0NFU1NPUl9BUkNISVRFQ1RVUkUNCiAgICByZW0g5Y6f55SfY21kICAgICAgICAgIOacquWumuS5
echo iSAgICAgICAgICAgICAgICAgICAgICBBUk02NA0KICAgIHJlbSAzMuS9jWNtZCAgICAgICAgICBB
echo Uk02NCAgICAgICAgICAgICAgICAgICAgICAgeDg2DQoNCiAgICByZW0gaWYgZGVmaW5lZCBQUk9D
echo RVNTT1JfQVJDSElURVc2NDMyICgNCiAgICByZW0gICAgIHNldCAiU3lzdGVtQXJjaD0lUFJPQ0VT
echo U09SX0FSQ0hJVEVXNjQzMiUiDQogICAgcmVtICkgZWxzZSAoDQogICAgcmVtICAgICBzZXQgIlN5
echo c3RlbUFyY2g9JVBST0NFU1NPUl9BUkNISVRFQ1RVUkUlIg0KICAgIHJlbSApDQoNCiAgICByZW0g
echo QnVpbGROdW1iZXINCiAgICBmb3IgL2YgInRva2Vucz0zIiAlJWEgaW4gKCdyZWcgcXVlcnkgIkhL
echo TE1cU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRcQ3VycmVudFZlcnNpb24iIC92IEN1cnJl
echo bnRCdWlsZE51bWJlcicpIGRvICgNCiAgICAgICAgc2V0IC9hIEJ1aWxkTnVtYmVyPSUlYQ0KICAg
echo ICkNCg0KICAgIHNldCBDeWd3aW5FT0w9MQ0KDQogICAgZWNobyAhU3lzdGVtQXJjaCEgfCBmaW5k
echo ICJBUk0iID4gbnVsDQogICAgaWYgbm90IGVycm9ybGV2ZWwgMSAoDQogICAgICAgIGlmICFCdWls
echo ZE51bWJlciEgR0VRIDIyMDAwICgNCiAgICAgICAgICAgIHNldCBDeWd3aW5FT0w9MA0KICAgICAg
echo ICApDQogICAgKSBlbHNlICgNCiAgICAgICAgZWNobyAhU3lzdGVtQXJjaCEgfCBmaW5kICJBTUQ2
echo NCIgPiBudWwNCiAgICAgICAgaWYgbm90IGVycm9ybGV2ZWwgMSAoDQogICAgICAgICAgICBpZiAh
echo QnVpbGROdW1iZXIhIEdFUSA5NjAwICgNCiAgICAgICAgICAgICAgICBzZXQgQ3lnd2luRU9MPTAN
echo CiAgICAgICAgICAgICkNCiAgICAgICAgKQ0KICAgICkNCg0KICAgIHJlbSB3aW43LzggY3lnd2lu
echo IOW3siBFT0zvvIzkuI3og73nlKjmnIDmlrAgY3lnd2luIOa6kO+8jOiAjOimgeeUqCBDeWd3aW4g
echo VGltZSBNYWNoaW5lIOa6kA0KICAgIHJlbSDkvYYgQ3lnd2luIFRpbWUgTWFjaGluZSDmsqHmnInl
echo m73lhoXmupANCiAgICByZW0g5Li65LqG5L+d6K+B5Zu95YaF5LiL6L296YCf5bqmLCBjeWd3aW4g
echo RU9MIOe7n+S4gOS9v+eUqCBjeWd3aW4tYXJjaGl2ZSB4ODYg5rqQDQogICAgaWYgIUN5Z3dpbkVP
echo TCEgPT0gMSAoDQogICAgICAgIHNldCBDeWd3aW5BcmNoPXg4Ng0KICAgICAgICBzZXQgZGlyPS9z
echo b3VyY2V3YXJlL2N5Z3dpbi1hcmNoaXZlLzIwMjIxMTIzDQogICAgKSBlbHNlICgNCiAgICAgICAg
echo c2V0IEN5Z3dpbkFyY2g9eDg2XzY0DQogICAgICAgIHNldCBkaXI9L3NvdXJjZXdhcmUvY3lnd2lu
echo DQogICAgKQ0KDQogICAgcmVtIGRhb2Nsb3VkIOWKoOmAn+aciSA5MCDlpKnnvJPlrZjvvIzkuJTk
echo uI3mlK/mjIEgSVB2Ng0KICAgIHJlbSBodHRwczovL2dpdGh1Yi5jb20vRGFvQ2xvdWQvcHVibGlj
echo LWJpbmFyeS1maWxlcy1taXJyb3INCiAgICByZW0g5peg5rOV55So5p+l6K+i5a2X56ym5Liy5by6
echo 5Yi25Yi35paw57yT5a2YDQogICAgcmVtIGh0dHBzOi8vZmlsZXMubS5kYW9jbG91ZC5pby93d3cu
echo Y2xvdWRmbGFyZS5jb20vY2RuLWNnaS90cmFjZT9hPTENCiAgICByZW0gaHR0cHM6Ly9maWxlcy5t
echo LmRhb2Nsb3VkLmlvL3d3dy5jbG91ZGZsYXJlLmNvbS9jZG4tY2dpL3RyYWNlP2I9Mg0KICAgIHJl
echo bSDkuZ/lsLHml6Dms5XnlKggaHR0cHM6Ly93d3cuY3lnd2luLmNvbS9zZXR1cC14ODZfNjQuZXhl
echo P3h4eD0yMDI1MDEwMSDlvLrliLbmr4/lpKnliLfmlrDnvJPlrZgNCg0KICAgIHJlbSDkuIvovb0g
echo Q3lnd2luDQogICAgaWYgbm90IGV4aXN0IHNldHVwLSFDeWd3aW5BcmNoIS5leGUgKA0KICAgICAg
echo ICBjYWxsIDpkb3dubG9hZCBodHRwOi8vd3d3LmN5Z3dpbi5jb20vc2V0dXAtIUN5Z3dpbkFyY2gh
echo LmV4ZSAlfmRwMHNldHVwLSFDeWd3aW5BcmNoIS5leGUgfHwgZ290byA6ZG93bmxvYWRfZmFpbGVk
echo DQogICAgKQ0KDQogICAgcmVtIOWwkeS6jiAxTSDop4bkuLrml6DmlYgNCiAgICByZW0g5pyJ55qE
echo IElQIOiiq+WumOe9keaLiem7ke+8jOaXoOazleS4i+i9vSBleGXvvIzkuIvovb3lvpfliLAgaHRt
echo bA0KICAgIGZvciAlJUEgaW4gKHNldHVwLSFDeWd3aW5BcmNoIS5leGUpIGRvIGlmICUlfnpBIExT
echo UyAxMDQ4NTc2ICgNCiAgICAgICAgZWNobyBJbnZhbGlkIENneXdpbiBpbnN0YWxsZXINCiAgICAg
echo ICAgZGVsIHNldHVwLSFDeWd3aW5BcmNoIS5leGUNCiAgICAgICAgZXhpdCAvYiAxDQogICAgKQ0K
echo DQogICAgcmVtIOWuieijhSBDeWd3aW4NCiAgICBzZXQgc2l0ZT0hbWlycm9yISFkaXIhDQogICAg
echo c3RhcnQgL3dhaXQgc2V0dXAtIUN5Z3dpbkFyY2ghLmV4ZSBeDQogICAgICAgIC0tYWxsb3ctdW5z
echo dXBwb3J0ZWQtd2luZG93cyBeDQogICAgICAgIC0tcXVpZXQtbW9kZSBeDQogICAgICAgIC0tb25s
echo eS1zaXRlIF4NCiAgICAgICAgLS1zaXRlICFzaXRlISBeDQogICAgICAgIC0tcm9vdCAlU3lzdGVt
echo RHJpdmUlXGN5Z3dpbiBeDQogICAgICAgIC0tbG9jYWwtcGFja2FnZS1kaXIgJX5kcDBjeWd3aW4t
echo bG9jYWwtcGFja2FnZS1kaXIgXg0KICAgICAgICAtLXBhY2thZ2VzICVwa2dzJQ0KDQogICAgcmVt
echo IOajgOafpSBDeWd3aW4g5piv5ZCm5oiQ5Yqf5a6J6KOFDQogICAgaWYgZXJyb3JsZXZlbCAxIGdv
echo dG8gOmluc3RhbGxfY3lnd2luX2ZhaWxlZA0KICAgIGNhbGwgOmNoZWNrX2N5Z3dpbl9pbnN0YWxs
echo ZWQgfHwgZ290byA6aW5zdGFsbF9jeWd3aW5fZmFpbGVkDQopDQoNCnJlbSDlnKhj55uY5qC555uu
echo 5b2V5LiL5omn6KGMIGN5Z3BhdGggLXVhIC4g5Lya5b6X5YiwIC9jeWdkcml2ZS9j77yM5Zug5q2k
echo 5pyr5bC+6KaB5pyJIC8NCmZvciAvZiAlJWEgaW4gKCclU3lzdGVtRHJpdmUlXGN5Z3dpblxiaW5c
echo Y3lncGF0aCAtdWEgLi8nKSBkbyBzZXQgdGhpc2Rpcj0lJWENCg0KcmVtIOS4i+i9vSByZWluc3Rh
echo bGwuc2gNCmlmIG5vdCBleGlzdCByZWluc3RhbGwuc2ggKA0KICAgIGNhbGwgOmRvd25sb2FkX3dp
echo dGhfY3VybCAlY29uZmhvbWUlL3JlaW5zdGFsbC5zaCAldGhpc2RpciVyZWluc3RhbGwuc2ggfHwg
echo Z290byA6ZG93bmxvYWRfZmFpbGVkDQogICAgY2FsbCA6Y2htb2QgYSt4ICV0aGlzZGlyJXJlaW5z
echo dGFsbC5zaA0KKQ0KDQpyZW0gJSog5peg5rOV5aSE55CGIC0taXNvIGh0dHBzOi8veC5jb20vP3l5
echo eT0xMjMNCnJlbSDkuLrmr4/kuKrlj4LmlbDmt7vliqDlvJXlj7fvvIzkvb/lj4LmlbDmraPnoa7k
echo vKDpgJLliLAgYmFzaA0KcmVtIGZvciAlJWEgaW4gKCUqKSBkbyAoDQpyZW0gICAgIHNldCAicGFy
echo YW09IXBhcmFtISAiJSV+YSIiDQpyZW0gKQ0KDQpyZW0g6L2s5oiQIHVuaXgg5qC85byP77yM6YG/
echo 5YWN55So5oi355SoIHdpbmRvd3Mg6K6w5LqL5pys57yW6L6R5ZCO5o2i6KGM56ym5LiN5a+5DQol
echo U3lzdGVtRHJpdmUlXGN5Z3dpblxiaW5cZG9zMnVuaXggLXEgJyV0aGlzZGlyJXJlaW5zdGFsbC5z
echo aCcNCg0KcmVtIOeUqCBiYXNoIOi/kOihjA0KcmVtICVTeXN0ZW1Ecml2ZSVcY3lnd2luXGJpblxi
echo YXNoIC1sICV0aGlzZGlyJXJlaW5zdGFsbC5zaCAlKiDov5DooYzlkI7kvJrmuIXlsY8NCnJlbSDl
echo m6DmraTkuI3og73nlKggLWwNCnJlbSDov5nlsLHpnIDopoHlnKggcmVpbnN0YWxsLnNoIOmHjOi/
echo kOihjCBzb3VyY2UgL2V0Yy9wcm9maWxlDQpyZW0g5oiW6ICF5re75YqgIGV4cG9ydCBQQVRIPS91
echo c3IvbG9jYWwvc2JpbjovdXNyL2xvY2FsL2JpbjovdXNyL3NiaW46L3Vzci9iaW46L3NiaW46L2Jp
echo bjokUEFUSA0KJVN5c3RlbURyaXZlJVxjeWd3aW5cYmluXGJhc2ggJXRoaXNkaXIlcmVpbnN0YWxs
echo LnNoICUqDQpleGl0IC9iDQoNCnJlbSBiaXRzIOimgeaxguaciSBDb250ZW50LUxlbmd0aCDmiY3o
echo g73kuIvovb0NCnJlbSBjbG91ZGZsYXJlIOeahCBjZG4tY2dpL3RyYWNlIOayoeaciSBDb250ZW50
echo LUxlbmd0aA0KcmVtIOaNruivtOWmguaenOe9kee7nOiuvuS4uuKAnOaMiea1gemHj+iuoei0ueKA
echo nSBiaXRzIOS5n+aXoOazleS4i+i9vQ0KcmVtIGh0dHBzOi8vbGVhcm4ubWljcm9zb2Z0LmNvbS9l
echo bi11cy93aW5kb3dzL3dpbjMyL2JpdHMvaHR0cC1yZXF1aXJlbWVudHMtZm9yLWJpdHMtZG93bmxv
echo YWRzDQpyZW0gYml0c2FkbWluIC90cmFuc2ZlciAiJX4zIiAvcHJpb3JpdHkgZm9yZWdyb3VuZCAl
echo fjEgJX4yDQoNCjpkb3dubG9hZA0KcmVtIGNlcnR1dGlsIOS8muiiqyB3aW5kb3dzIERlZmVuZGVy
echo IOaKpeavkg0KcmVtIHdpbmRvd3Mgc2VydmVyIDIwMTkg6KaB55So56ys5LqM5p2hIGNlcnR1dGls
echo IOWRveS7pA0KZWNobyBEb3dubG9hZGluZzogJX4xICV+Mg0KZGVsIC9xICIlfjIiIDI+bnVsDQpp
echo ZiBleGlzdCAiJX4yIiAoZWNobyBDYW5ub3QgZGVsZXRlICV+MiAmIGV4aXQgL2IgMSkNCg0Kd2hl
echo cmUgY3VybCA+bnVsIDI+JjENCmlmIG5vdCBlcnJvcmxldmVsIDEgKA0KICAgIGN1cmwgLWsgLXMg
echo LUwgLWYgLW8gIiV+MiIgIiV+MSIgPm51bCAyPiYxDQogICAgaWYgbm90IGVycm9ybGV2ZWwgMSBp
echo ZiBleGlzdCAiJX4yIiBleGl0IC9iIDANCikNCg0KY2VydHV0aWwgLXVybGNhY2hlIC1mIC1zcGxp
echo dCAiJX4xIiAiJX4yIiA+bnVsIDI+JjENCmlmIG5vdCBlcnJvcmxldmVsIDEgaWYgZXhpc3QgIiV+
echo MiIgZXhpdCAvYiAwDQoNCmNlcnR1dGlsIC11cmxjYWNoZSAtc3BsaXQgIiV+MSIgIiV+MiIgPm51
echo bCAyPiYxDQppZiBub3QgZXJyb3JsZXZlbCAxIGlmIGV4aXN0ICIlfjIiIGV4aXQgL2IgMA0KDQpw
echo b3dlcnNoZWxsIC1Ob1Byb2ZpbGUgLUV4ZWN1dGlvblBvbGljeSBCeXBhc3MgLUNvbW1hbmQgIiRQ
echo cm9ncmVzc1ByZWZlcmVuY2U9J1NpbGVudGx5Q29udGludWUnOyBbTmV0LlNlcnZpY2VQb2ludE1h
echo bmFnZXJdOjpTZWN1cml0eVByb3RvY29sID0gMzA3MjsgW1N5c3RlbS5OZXQuU2VydmljZVBvaW50
echo TWFuYWdlcl06OlNlcnZlckNlcnRpZmljYXRlVmFsaWRhdGlvbkNhbGxiYWNrID0geyR0cnVlfTsg
echo KE5ldy1PYmplY3QgU3lzdGVtLk5ldC5XZWJDbGllbnQpLkRvd25sb2FkRmlsZSgnJX4xJywgJyV+
echo MicpIiA+bnVsIDI+JjENCmlmIG5vdCBlcnJvcmxldmVsIDEgaWYgZXhpc3QgIiV+MiIgZXhpdCAv
echo YiAwDQoNCnJlbSDkuIvovb3lpLHotKXml7bliKDpmaTmlofku7bvvIzpmLLmraLkuIvovb3kuobk
echo uIDpg6jliIblr7zoh7TkuIvmrKHov5DooYzml7bot7Pov4fkuobkuIvovb0NCmRlbCAvcSAiJX4y
echo IiAyPm51bA0KZXhpdCAvYiAxDQoNCjpkb3dubG9hZF93aXRoX2N1cmwNCnJlbSDliqAgLS1pbnNl
echo Y3VyZSDpmLLmraLku6XkuIvplJnor68NCnJlbSBjdXJsOiAoNzcpIGVycm9yIHNldHRpbmcgY2Vy
echo dGlmaWNhdGUgdmVyaWZ5IGxvY2F0aW9uczoNCnJlbSAgIENBZmlsZTogL2V0Yy9zc2wvY2VydHMv
echo Y2EtY2VydGlmaWNhdGVzLmNydA0KcmVtICAgQ0FwYXRoOiBub25lDQplY2hvIERvd25sb2FkOiAl
echo fjEgJX4yDQolU3lzdGVtRHJpdmUlXGN5Z3dpblxiaW5cY3VybCAtTCAtLWluc2VjdXJlICIlfjEi
echo IC1vICIlfjIiDQpleGl0IC9iDQoNCjpjaG1vZA0KJVN5c3RlbURyaXZlJVxjeWd3aW5cYmluXGNo
echo bW9kICIlfjEiICIlfjIiDQpleGl0IC9iDQoNCjpkb3dubG9hZF9mYWlsZWQNCmVjaG8gRG93bmxv
echo YWQgZmFpbGVkLg0KZXhpdCAvYiAxDQoNCjppbnN0YWxsX2N5Z3dpbl9mYWlsZWQNCmVjaG8gRmFp
echo bGVkIHRvIGluc3RhbGwgQ3lnd2luLg0KZXhpdCAvYiAxDQoNCjpjaGVja19jeWd3aW5faW5zdGFs
echo bGVkDQpzZXQgImNtZHNfc3BhY2U9JWNtZHM6LD0gJSINCmZvciAlJWMgaW4gKCVjbWRzX3NwYWNl
echo JSkgZG8gKA0KICAgIGlmIG5vdCBleGlzdCAiJVN5c3RlbURyaXZlJVxjeWd3aW5cYmluXCUlYyIg
echo aWYgbm90IGV4aXN0ICIlU3lzdGVtRHJpdmUlXGN5Z3dpblxiaW5cJSVjLmV4ZSIgKA0KICAgICAg
echo ICBleGl0IC9iIDENCiAgICApDQopDQpleGl0IC9iIDANCg==
echo -----END CERTIFICATE-----
) > "%WORK_DIR%\reinstall.b64"
certutil -decode "%WORK_DIR%\reinstall.b64" "%WORK_DIR%\reinstall.bat" >nul 2>&1
del /f /q "%WORK_DIR%\reinstall.b64" >nul 2>&1
exit /b 0
