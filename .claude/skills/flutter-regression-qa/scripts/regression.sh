#!/usr/bin/env bash
# Bounded regression gate. Usage: regression.sh [targeted test files...]
# Runs format check, analyze, the targeted files, then the full suite.
# Every step has a hard timeout; a hang is a failure, never a reason to wait.
set -uo pipefail
[ -d /opt/fl/flutter/bin ] && export PATH=/opt/fl/flutter/bin:$PATH
cd "$(git rev-parse --show-toplevel)"
status=0
step() { local name=$1; shift; echo "== $name"; if "$@"; then echo "PASS $name"; else echo "FAIL $name (exit $?)"; status=1; fi; }
step format  timeout 120 dart format --output=none --set-exit-if-changed lib test
step analyze timeout 300 flutter analyze
if [ $# -gt 0 ]; then step targeted timeout 900 flutter test --timeout 60s "$@"; fi
step full    timeout 1800 flutter test --timeout 90s
echo "== RESULT: $([ $status = 0 ] && echo ALL PASS || echo FAILURES)"
exit $status
