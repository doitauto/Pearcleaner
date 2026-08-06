//
//  HomebrewDebugLogger.swift
//  Pearcleaner
//

import Foundation
import SwiftUI

enum UpdaterDebugSource {
    case homebrew
}

final class UpdaterDebugLogger: ObservableObject {
    static let shared = UpdaterDebugLogger()

    @Published private(set) var homebrewLogs: [String] = []

    private init() {}

    func log(_ source: UpdaterDebugSource, _ message: String) {
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        )
        let line = "[\(timestamp)] \(message)"

        DispatchQueue.main.async { [weak self] in
            self?.homebrewLogs.append(line)
        }
    }

    func generateDebugReport() -> String {
        let header = "HOMEBREW DEBUG LOG\n"
        guard !homebrewLogs.isEmpty else {
            return header + "  (No logs recorded)\n"
        }

        return header + homebrewLogs.map { "  \($0)" }.joined(separator: "\n") + "\n"
    }
}
