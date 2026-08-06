//
//  PKGManager.swift
//  Pearcleaner
//
//  Public wrapper around macOS Installer receipt tools.
//

import Foundation

struct PackageReceipt: Hashable, Sendable {
    let packageIdentifier: String
    let volume: String

    init(packageIdentifier: String, volume: String = "/") {
        self.packageIdentifier = packageIdentifier
        self.volume = volume
    }
}

enum PKGManager {
    private enum Constants {
        static let executablePath = "/usr/sbin/pkgutil"
        static let defaultVolume = "/"
        static let defaultInstallLocation = "/"
        static let successfulTerminationStatus: Int32 = 0
        static let packageIdentifierKey = "pkgid"
        static let versionKey = "pkg-version"
        static let installTimeKey = "install-time"
        static let installLocationKey = "install-location"
        static let groupsKey = "groups"
        static let pathsKey = "paths"
        static let fileSizeKey = "size"
    }

    private struct CommandResult {
        let data: Data
        let terminationStatus: Int32
    }

    static func getAllPackages(volume: String = Constants.defaultVolume) -> [PackageReceipt] {
        guard let result = run(arguments: ["--volume", volume, "--pkgs"]),
              result.terminationStatus == Constants.successfulTerminationStatus,
              let output = String(data: result.data, encoding: .utf8) else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { PackageReceipt(packageIdentifier: $0, volume: volume) }
    }

    static func getPackageInfo(from receipt: PackageReceipt) -> PackageInfo? {
        guard let dictionary = packageInfoDictionary(for: receipt) else {
            return nil
        }

        let packageIdentifier = dictionary[Constants.packageIdentifierKey] as? String
            ?? receipt.packageIdentifier
        let version = dictionary[Constants.versionKey] as? String ?? ""
        let installLocation = dictionary[Constants.installLocationKey] as? String
            ?? Constants.defaultInstallLocation
        let installDate = formatInstallDate(dictionary[Constants.installTimeKey])
        let groups = dictionary[Constants.groupsKey] as? [String] ?? []

        return PackageInfo(
            packageId: packageIdentifier,
            packageName: "",
            packageFileName: "",
            version: version,
            installDate: installDate,
            installProcessName: "",
            bomFiles: [],
            receiptPath: "",
            installLocation: installLocation,
            bomFilesLoaded: false,
            packageGroups: groups,
            additionalInfo: "",
            receiptStoragePaths: [],
            totalSizeFromBOM: 0,
            totalFilesInBOM: 0
        )
    }

    static func getBOMInfo(for receipt: PackageReceipt) -> (totalSize: Int64, fileCount: Int)? {
        guard let result = run(
            arguments: ["--volume", receipt.volume, "--export-plist", receipt.packageIdentifier]
        ), result.terminationStatus == Constants.successfulTerminationStatus,
           let propertyList = try? PropertyListSerialization.propertyList(
               from: result.data,
               options: [],
               format: nil
           ),
           let dictionary = propertyList as? [String: Any],
           let paths = dictionary[Constants.pathsKey] as? [String: [String: Any]] else {
            return nil
        }

        var totalSize: Int64 = 0
        var fileCount = 0

        for metadata in paths.values {
            guard let size = metadata[Constants.fileSizeKey] as? NSNumber else {
                continue
            }
            totalSize += size.int64Value
            fileCount += 1
        }

        return (totalSize, fileCount)
    }

    static func getPackageFiles(receipt: PackageReceipt, installLocation: String) -> [String] {
        guard let result = run(
            arguments: [
                "--volume", receipt.volume,
                "--only-files",
                "--files", receipt.packageIdentifier
            ]
        ), result.terminationStatus == Constants.successfulTerminationStatus,
           let output = String(data: result.data, encoding: .utf8) else {
            return []
        }

        let installRoot = URL(fileURLWithPath: installLocation, isDirectory: true)

        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty && !$0.contains("._") }
            .map { relativePath in
                if relativePath.hasPrefix("/") {
                    return URL(fileURLWithPath: relativePath).standardizedFileURL.path
                }
                return installRoot
                    .appendingPathComponent(relativePath)
                    .standardizedFileURL
                    .path
            }
    }

    @discardableResult
    static func forgetPackage(identifier: String, volume: String = Constants.defaultVolume) -> Bool {
        guard let result = run(arguments: ["--volume", volume, "--forget", identifier]) else {
            return false
        }
        return result.terminationStatus == Constants.successfulTerminationStatus
    }

    static func getPackageGroups(receipt: PackageReceipt) -> [String] {
        packageInfoDictionary(for: receipt)?[Constants.groupsKey] as? [String] ?? []
    }

    private static func packageInfoDictionary(for receipt: PackageReceipt) -> [String: Any]? {
        guard let result = run(
            arguments: ["--volume", receipt.volume, "--pkg-info-plist", receipt.packageIdentifier]
        ), result.terminationStatus == Constants.successfulTerminationStatus,
           let propertyList = try? PropertyListSerialization.propertyList(
               from: result.data,
               options: [],
               format: nil
           ) else {
            return nil
        }

        return propertyList as? [String: Any]
    }

    private static func formatInstallDate(_ value: Any?) -> String {
        guard let timestamp = value as? NSNumber else {
            return ""
        }
        return String(timestamp.int64Value)
    }

    private static func run(arguments: [String]) -> CommandResult? {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: Constants.executablePath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return CommandResult(data: data, terminationStatus: process.terminationStatus)
        } catch {
            return nil
        }
    }
}
