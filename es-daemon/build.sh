#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
swift build -c release 2>&1
echo "Built: $(pwd)/.build/release/ESWatcher"
