#!/usr/bin/env bash
# ==============================================================================
# Script Name: alpine-to-linux.sh
# Alias wrapper for alpine-to-debian.sh (Supports Debian 11/12/13 & Ubuntu 24/26)
# ==============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
exec bash "$DIR/alpine-to-debian.sh" "$@"
