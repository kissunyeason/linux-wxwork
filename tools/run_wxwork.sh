#!/bin/bash

# Wine Docker 兼容性脚本
# 此脚本仅作为向后兼容性保护，实际功能已迁移到 ./tools/run.sh
# 直接调用 ./tools/run.sh wxwork

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" wxwork "$@" 