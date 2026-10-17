@echo off
rem ==============================================================================
rem Script Name: dd-linux.bat
rem Alias wrapper for dd-debian.bat (Supports Debian 11/12/13 & Ubuntu 24/26)
rem ==============================================================================
call "%~dp0dd-debian.bat" %*
