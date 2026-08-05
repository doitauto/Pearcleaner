#!/bin/zsh

# Re-sign Sparkle's nested executables after Xcode Cloud has produced the archive.
# Xcode's distribution export can replace the signatures created by the target
# build phase, so this runs against the archive/exported app as the last signing
# step visible to the Xcode Cloud action.
set -euo pipefail

if [[ "${CI_XCODEBUILD_ACTION:-}" != "archive" || "${CI_XCODEBUILD_EXIT_CODE:-1}" != "0" ]]; then
    exit 0
fi

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
entitlements_path="$script_dir/SparkleSandbox.entitlements"

if [[ ! -f "$entitlements_path" ]]; then
    echo "error: Sparkle sandbox entitlements are missing at $entitlements_path" >&2
    exit 1
fi

signing_identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [[ -z "$signing_identity" || "$signing_identity" == "-" ]]; then
    signing_identity="${CODE_SIGN_IDENTITY:-}"
fi
if [[ -z "$signing_identity" || "$signing_identity" == "-" ]]; then
    signing_identity="$(security find-identity -v -p codesigning | awk -F '"' '/Apple Distribution:/ { print $2; exit }')"
fi

if [[ -z "$signing_identity" ]]; then
    echo "error: no Apple Distribution signing identity is available" >&2
    exit 1
fi

typeset -a app_candidates
app_candidates=()

if [[ -n "${CI_APP_STORE_SIGNED_APP_PATH:-}" ]]; then
    app_candidates+=("${CI_APP_STORE_SIGNED_APP_PATH}")
fi
if [[ -n "${CI_ARCHIVE_PATH:-}" ]]; then
    app_candidates+=("${CI_ARCHIVE_PATH}/Products/Applications/AppRinse.app")
fi

typeset -a apps_to_sign
apps_to_sign=()
for candidate in "${app_candidates[@]}"; do
    if [[ -d "$candidate/Contents/Frameworks/Sparkle.framework" ]]; then
        apps_to_sign+=("$candidate")
    fi
done

if (( ${#apps_to_sign[@]} == 0 )); then
    echo "error: no exported AppRinse.app with Sparkle.framework was found" >&2
    exit 1
fi

for app_path in "${apps_to_sign[@]}"; do
    sparkle_framework="$app_path/Contents/Frameworks/Sparkle.framework/Versions/B"
    echo "Re-signing Sparkle helpers in $app_path"

    codesign --force --sign "$signing_identity" --options runtime \
        --entitlements "$entitlements_path" \
        "$sparkle_framework/XPCServices/Installer.xpc"
    codesign --force --sign "$signing_identity" --options runtime \
        --entitlements "$entitlements_path" \
        "$sparkle_framework/XPCServices/Downloader.xpc"
    codesign --force --sign "$signing_identity" --options runtime \
        --entitlements "$entitlements_path" \
        "$sparkle_framework/Autoupdate"
    codesign --force --sign "$signing_identity" --options runtime \
        --entitlements "$entitlements_path" \
        "$sparkle_framework/Updater.app"
    codesign --force --sign "$signing_identity" --options runtime \
        "$app_path/Contents/Frameworks/Sparkle.framework"

    codesign --verify --strict "$app_path/Contents/Frameworks/Sparkle.framework"
done
