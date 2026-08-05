#!/bin/zsh

# Keep Xcode Cloud builds deterministic for the AppRinse macOS release.
set -euo pipefail

repo_path="${CI_PRIMARY_REPOSITORY_PATH:-${CI_PRIMARY_REPOSITORY_DIR:-$(cd -- "$(dirname -- "$0")/.." && pwd)}}"
project_path="$repo_path/Pearcleaner.xcodeproj"

if [[ ! -d "$project_path" ]]; then
  echo "error: Xcode project not found at $project_path" >&2
  exit 1
fi

echo "Using Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "Repository: $repo_path"

# Resolve Swift packages when the project contains package dependencies.
cd "$repo_path"
xcodebuild -resolvePackageDependencies \
  -project "$project_path"
