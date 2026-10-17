<#
.SYNOPSIS
    Windows 一键重装/DD 到 Linux (Debian 11/12/13 / Ubuntu 24/26) PowerShell 别名
#>
[CmdletBinding()]
param (
    [string]$OS = "",
    [string]$Version = "",
    [string]$Password = "",
    [string]$Port = "22",
    [string]$Mode = "direct",
    [string]$ZeroTier = "",
    [switch]$Yes
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetScript = Join-Path $scriptDir "dd-debian.ps1"
if (Test-Path $targetScript) {
    & $targetScript @PSBoundParameters
} else {
    $batPath = Join-Path $scriptDir "dd-debian.bat"
    & $batPath
}
