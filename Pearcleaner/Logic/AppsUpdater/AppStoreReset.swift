//
//  AppStoreReset.swift
//  Pearcleaner
//

import AppKit
import Foundation

enum AppStoreReset {
    enum ResetResult {
        case success
        case failure(String)
    }

    private enum Constants {
        static let bundleIdentifier = "com.apple.AppStore"
        static let applicationPath = "/System/Applications/App Store.app"
    }

    /// Restarts the App Store application using public AppKit APIs.
    static func reset() async -> ResetResult {
        await MainActor.run {
            let runningApplications = NSRunningApplication.runningApplications(
                withBundleIdentifier: Constants.bundleIdentifier
            )
            runningApplications.forEach { $0.terminate() }

            let applicationURL = URL(fileURLWithPath: Constants.applicationPath)
            guard FileManager.default.fileExists(atPath: applicationURL.path) else {
                return .failure("The App Store application could not be found.")
            }

            guard NSWorkspace.shared.open(applicationURL) else {
                return .failure("The App Store application could not be opened.")
            }

            return .success
        }
    }
}
