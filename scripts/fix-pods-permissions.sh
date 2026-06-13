#!/bin/bash
# Run from the iOS project root after clone/copy (especially from Windows).
# Fixes: Pods-AnokiXDistributor-frameworks.sh: Permission denied

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -d "Pods/Target Support Files" ]; then
  echo "Pods/ not found. Run: pod install"
  exit 1
fi

find "Pods/Target Support Files" -name "*.sh" -print -exec chmod +x {} \;
echo "Done. Rebuild in Xcode (AnokiXDistributor.xcworkspace)."
