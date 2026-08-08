#!/usr/bin/env bash
# Verifies the package rename left nothing behind and that the MethodChannel
# name matches on both sides of the platform boundary.
set -euo pipefail

FAIL=0

echo "== checking for stale identifiers =="
# docs/ is excluded deliberately: the spec and plan discuss the old package
# name at length, and that is not a leak. This script also excludes itself,
# because it contains the search string.
# .gradle/ holds a binary build cache that records the old namespace and is
# not rewritten by a rename, so it would fail this gate forever.
if grep -rn "com\.example\|dont_touch_2" \
     --exclude-dir=build --exclude-dir=.git --exclude-dir=.dart_tool \
     --exclude-dir=.gradle --exclude-dir=docs --exclude=verify_naming.sh . ; then
  echo "FAIL: stale identifiers found"
  FAIL=1
else
  echo "OK: no stale identifiers"
fi

echo "== checking MethodChannel agreement =="
CHANNEL_KT="android/app/src/main/kotlin/xyz/arafatpeace/touchblock/MainActivity.kt"
# Default to 0 so a missing file reports a clean mismatch rather than tripping
# an "integer expression expected" error inside the comparison below.
DART=$(grep -c "xyz\.arafatpeace\.touchblock/overlay" lib/main.dart 2>/dev/null || echo 0)
KOTLIN=$(grep -c "xyz\.arafatpeace\.touchblock/overlay" "$CHANNEL_KT" 2>/dev/null || echo 0)

if [ "$DART" -eq 1 ] && [ "$KOTLIN" -eq 1 ]; then
  echo "OK: channel name matches on both sides"
else
  echo "FAIL: channel occurrences dart=$DART kotlin=$KOTLIN (expected 1 and 1)"
  FAIL=1
fi

exit $FAIL
