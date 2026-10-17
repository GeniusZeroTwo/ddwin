<#
.SYNOPSIS
    Windows 一键重装/DD 到 Debian 12 (PowerShell 引导器)
.DESCRIPTION
    自动以管理员权限下载并启动 dd-debian.bat 核心安装套件，支持移动云电脑 Alpine 中转与常规 VPS 直装。
#>

[CmdletBinding()]
param (
    [string]$Version = "12",
    [string]$Password = "",
    [string]$Port = "22",
    [string]$Mode = "direct",
    [string]$ZeroTier = "",
    [switch]$Yes
)

# 强制 UTF-8 输出
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[提示] 正在请求管理员权限以配置系统引导..." -ForegroundColor Yellow
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    exit
}

$workDir = "C:\DD"
if (-not (Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
}
Set-Location $workDir

# 智能探测国内网络
$isChina = $false
try {
    $test = (Invoke-WebRequest -Uri "https://cip.cc" -TimeoutSec 3 -UseBasicParsing).Content
    if ($test -match "中国") { $isChina = $true }
} catch {}

$batUrl = if ($isChina) {
    "https://ghproxy.cc/https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-debian.bat"
} else {
    "https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-debian.bat"
}

$batPath = Join-Path $workDir "dd-debian.bat"
Write-Host "[1/3] 正在拉取 dd-debian 核心脚本..." -ForegroundColor Green
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $batUrl -OutFile $batPath -UseBasicParsing
} catch {
    # 备用源
    $fallbackUrl = "https://raw.githubusercontent.com/GeniusZeroTwo/ddwin/main/dd-debian.bat"
    Invoke-WebRequest -Uri $fallbackUrl -OutFile $batPath -UseBasicParsing
}

Write-Host "[2/3] 正在启动安装向导..." -ForegroundColor Green

# 组装参数并调用批处理
$cmdArgs = @()
if ($Version) { $cmdArgs += "-v `"$Version`"" }
if ($Password) { $cmdArgs += "-p `"$Password`"" }
if ($Port) { $cmdArgs += "-P `"$Port`"" }
if ($Mode) { $cmdArgs += "-m `"$Mode`"" }
if ($ZeroTier) { $cmdArgs += "-z `"$ZeroTier`"" }
if ($Yes) { $cmdArgs += "-y" }

$procArgs = "/c `"`"$batPath`" $($cmdArgs -join ' ')`""
Start-Process -FilePath "cmd.exe" -ArgumentList $procArgs -Wait -NoNewWindow
