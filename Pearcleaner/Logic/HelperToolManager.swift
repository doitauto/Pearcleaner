//
//  HelperToolManager.swift
//  Pearcleaner
//
//  App Store builds cannot ship the privileged launch daemon used by the
//  standalone distribution. This compatibility implementation keeps existing
//  call sites safe while ensuring no privileged service is registered or used.
//

import Foundation
import SwiftUI

extension Notification.Name {
    static let helperRequired = Notification.Name("helperRequired")
}

enum HelperToolAction {
    case none
    case install
    case uninstall
    case reinstall
}

final class HelperToolManager: ObservableObject {
    static let shared = HelperToolManager()

    @Published private(set) var isHelperToolInstalled = false
    @Published private(set) var message = String(localized: "Privileged helper is unavailable in the App Store version.")
    @Published private(set) var isInitialCheckComplete = true

    var status: String {
        String(localized: "Unavailable")
    }

    var shouldShowHelperBadge: Bool {
        false
    }

    private init() {}

    func triggerHelperRequiredAlert() {
        // Privileged operations are intentionally unavailable in this build.
    }

    func manageHelperTool(action: HelperToolAction = .none) async {
        isHelperToolInstalled = false
        isInitialCheckComplete = true
        message = String(localized: "Privileged helper is unavailable in the App Store version.")
    }

    func openSMSettings() {
        // No background service is registered by the App Store build.
    }

    func runCommand(_ command: String, skipHelperCheck: Bool = false) async -> (Bool, String) {
        (false, "Privileged helper is unavailable in the App Store version.")
    }

    func runThinning(atPath path: String) async -> (Bool, String) {
        (false, "Privileged helper is unavailable in the App Store version.")
    }

    func runBundleThinning(bundlePath path: String) async -> (Bool, String, [String: UInt64]) {
        (false, "Privileged helper is unavailable in the App Store version.", [:])
    }

    func nuclearResetHelper() async -> Bool {
        false
    }
}
