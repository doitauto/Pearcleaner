//
//  PearcleanerApp.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI
import AppKit
import AlinFoundation

@main
struct PearcleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    //MARK: ObservedObjects
    @ObservedObject var appState = AppState.shared
    @ObservedObject private var permissionManager = PermissionManagerLocal.shared
    //MARK: StateObjects
    @StateObject var locations = Locations()
    @StateObject var fsm = FolderSettingsManager.shared

    init() {
        //MARK: GUI or CLI launch mode.
        handleLaunchMode()

        // The App Store build must never install a password-request listener at launch.
        // The standalone CLI build may still use SUDO_ASKPASS when explicitly invoked.
        #if !APP_STORE_SANDBOX
        _ = PasswordRequestHandler.shared
        #endif

        //MARK: Pre-load apps data during app initialization (use streaming for fast initial load)
        let folderPaths = FolderSettingsManager.shared.folderPaths
        loadApps(folderPaths: folderPaths, useStreaming: true)

        //MARK: Pre-load volume information
        AppState.shared.loadVolumeInfo()

    }

    var body: some Scene {

        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .environmentObject(locations)
                .environmentObject(fsm)
                .environmentObject(permissionManager)

        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(appState: appState, locations: locations, fsm: fsm)
        }
    }
}



// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

        // Register as services provider (required for NSServices to work)
        NSApp.servicesProvider = self

        // Permission status is checked only after the user opens the Permissions view.
        // This keeps launch free of permission or administration prompts.

        // Load and cleanup undo history
        Task { @MainActor in
            UndoHistoryManager.shared.cleanupStaleEntries()
        }

        ensureApplicationSupportFolderExists()

        cleanupPearcleanerTempDirs()

    }

    func applicationWillTerminate(_ notification: Notification) {}

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        return false
    }

    // MARK: - Service Handler
    @objc func handleServiceRequest(_ pasteboard: NSPasteboard, userData: NSString, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        // Get file URLs from pasteboard
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !fileURLs.isEmpty else {
            printOS("Service: No valid file URLs found in pasteboard")
            return
        }

        // Process all selected .app files
        let appURLs = fileURLs.filter { $0.pathExtension == "app" }

        guard !appURLs.isEmpty else {
            printOS("Service: No .app bundles found in selection")
            return
        }

        // Open deep link for each app - DeeplinkManager will queue and process them sequentially
        for appURL in appURLs {
            if let deepLinkURL = URL(string: "apprinse://com.doitauto.AppRinse?path=\(appURL.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appURL.path)") {
                NSWorkspace.shared.open(deepLinkURL)
            }
        }
    }

}
