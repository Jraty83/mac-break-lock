#!/bin/zsh
set -euo pipefail

# Back-compat wrapper — prefer Scripts/install.sh
exec "$(cd "$(dirname "$0")" && pwd)/install.sh"
