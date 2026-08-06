//
//  BadgeOverlay.swift
//  Pearcleaner
//

import SwiftUI

struct BadgeOverlay: View {
    @ObservedObject private var permissionManager = PermissionManagerLocal.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("settings.interface.badgeOverlaysEnabled") private var badgeOverlaysEnabled = true
    @State private var isDismissed = false
    @State private var showPermissionList = false

    var body: some View {
        if badgeOverlaysEnabled && permissionManager.shouldShowPermissionWarning && !isDismissed {
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    HStack(spacing: PearMetrics.spacingM) {
                        Image(systemName: "lock.slash.fill")
                            .font(.title3)
                            .foregroundStyle(.red)

                        VStack(alignment: .leading, spacing: PearMetrics.spacingXS) {
                            Text("Permissions Missing")
                                .font(.headline)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                            Text("Review the permissions required for file cleanup.")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }

                        Button("Review") {
                            showPermissionList = true
                        }

                        Button {
                            isDismissed = true
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss")
                    }
                    .padding(PearMetrics.spacingM)
                    .ifGlassSidebar()
                    .padding(.trailing, PearMetrics.spacingL)
                    .padding(.bottom, PearMetrics.spacingL)
                }
            }
            .sheet(isPresented: $showPermissionList) {
                PermissionsSheetView()
            }
        }
    }
}
