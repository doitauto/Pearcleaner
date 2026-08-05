#!/bin/zsh

# Keep Xcode Cloud builds deterministic for the AppRinse macOS release.
set -euo pipefail

echo "Using Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "Repository: ${CI_PRIMARY_REPOSITORY_DIR:-$PWD}"

# Resolve Swift packages when the project contains package dependencies.
xcodebuild -resolvePackageDependencies \
  -project "Pearcleaner.xcodeproj" \
  -scheme "Pearcleaner Release"
