//
//  AppListH.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import AlinFoundation
import FinderSync
import Foundation
import SwiftUI

struct MainWindow: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var consoleManager = GlobalConsoleManager.shared
    @StateObject private var brewManager = HomebrewManager()
    @StateObject private var updateManager = UpdateManager.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var permissionManager: PermissionManagerLocal
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 265
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.tutorial.switchUtilitiesShown") private var tutorialShown: Bool = true
    @AppStorage("settings.updater.loadOnStartup") private var loadUpdatesOnStartup: Bool = true
    @AppStorage("settings.console.state") private var consoleStateData: Data = Data()

    @State private var isDraggingOver: Bool = false
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @State private var showMenu = false
    @State private var isFullscreen = false

    // Badges
    @State private var showUpdateView = false
    @State private var showFeatureView = false
    @State private var showPermissionList = false
    @State private var glowRadius = 0.0

    var body: some View {

        // Main App Window
        ZStack {

            HStack(alignment: .center, spacing: 0) {

                Group {
                    switch appState.currentPage {
                    case .applications:
                        withConsole {
                            applicationsView
                        }

                    case .orphans:
                        withConsole {
                            ZombieView()
                        }

                    case .development:
                        withConsole {
                            EnvironmentCleanerView()
                        }

                    case .lipo:
                        withConsole {
                            LipoView()
                        }

                    case .services:
                        withConsole {
                            DaemonView()
                        }

                    case .packages:
                        withConsole {
                            PackageView()
                        }

                    case .plugins:
                        withConsole {
                            PluginsView()
                        }

                    case .fileSearch:
                        withConsole {
                            FileSearchView()
                        }

                    case .homebrew:
                        HomebrewView()
                            .environmentObject(brewManager)

                    case .updater:
                        withConsole {
                            AppsUpdaterView()
                                .environmentObject(brewManager)
                                .environmentObject(updateManager)
                        }
                    }
                }

            }

            // Drop overlay
            if isDraggingOver {
                ZStack {
                    Rectangle()
                        .fill(.regularMaterial)
                        .ignoresSafeArea()

                    VStack(spacing: PearMetrics.spacingL) {
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: 46, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)

                        VStack(spacing: PearMetrics.spacingXS) {
                            Text("Drop applications to inspect")
                                .font(.title2.weight(.semibold))
                            Text("AppRinse will find the application and its related files.")
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(PearMetrics.spacingXL * 2)
                    .background(ThemeColors.shared(for: colorScheme).elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: PearMetrics.radiusXL, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PearMetrics.radiusXL, style: .continuous)
                            .strokeBorder(
                                ThemeColors.shared(for: colorScheme).accent.opacity(0.45),
                                style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                            )
                    }
                    .shadow(
                        color: ThemeColors.shared(for: colorScheme).windowShadow,
                        radius: 24,
                        y: 12
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .accessibilityElement(children: .combine)
            }

            // Badge overlay (unified overlay for all badge notifications)
            BadgeOverlay()
                .environmentObject(updater)
                .zIndex(100)

        }
        .animation(
            .easeOut(duration: canAnimate ? PearMotion.standard : 0),
            value: isDraggingOver
        )
        .background(modernWindowBackground)
        .frame(minWidth: 900, minHeight: 650)
        .handlesExternalEvents(preferring: Set(arrayLiteral: "apprinse"), allowing: Set(arrayLiteral: "*"))
        .handleFileDrop(
            updater: updater,
            fsm: fsm,
            appState: appState,
            locations: locations,
            isTargeted: $isDraggingOver
        )
        .onOpenURL(perform: { url in
            let deeplinkManager = DeeplinkManager(updater: updater, fsm: fsm)
            deeplinkManager.manage(url: url, appState: appState, locations: locations)
        })
        .sheet(isPresented: $updater.sheet, content: {
            /// This will show the update sheet based on the frequency check function only
            updater.getUpdateView()
        })
        .sheet(isPresented: $appState.showDeleteHistory, content: {
            DeleteHistoryView()
                .environmentObject(appState)
                .environmentObject(locations)
                .environmentObject(fsm)
        })
        .onReceive(
            NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)
        ) { _ in
            isFullscreen = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)
        ) { _ in
            isFullscreen = false
        }
        .task {
            // Restore console state from AppStorage
            if let decoded = try? JSONDecoder().decode(ConsoleState.self, from: consoleStateData) {
                await MainActor.run {
                    consoleManager.showConsole = decoded.isOpen
                    consoleManager.consoleHeight = decoded.height
                }
            }
        }
        .onChange(of: consoleManager.showConsole) { newValue in
            // Save console state
            let state = ConsoleState(isOpen: newValue, height: consoleManager.consoleHeight)
            if let encoded = try? JSONEncoder().encode(state) {
                consoleStateData = encoded
            }

            // When console is hidden, trim output to 300 lines max to prevent memory bloat
            if !newValue {
                Task { @MainActor in
                    consoleManager.trimOutput(toLines: 300)
                }
            }
        }
        .onChange(of: consoleManager.consoleHeight) { newValue in
            // Save console height when changed
            let state = ConsoleState(isOpen: consoleManager.showConsole, height: newValue)
            if let encoded = try? JSONEncoder().encode(state) {
                consoleStateData = encoded
            }
        }
        .toolbar {
            TahoeToolbarItem(placement: .navigation, isGroup: true) {
                utilitySwitcher

                if tutorialShown {
                    Button {
                        tutorialShown = false
                    } label: {
                        Text("Switch Utilities")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, PearMetrics.spacingS)
                            .padding(.vertical, PearMetrics.spacingXS)
                            .background(
                                ThemeColors.shared(for: colorScheme).accentSurface,
                                in: Capsule(style: .continuous)
                            )
                    }
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                    .buttonStyle(.plain)
                }

                // Notice Icons
                if updater.updateAvailable {
                    noticeButton(
                        image: "icloud.and.arrow.down.fill",
                        color: .green,
                        help: "Update Available"
                    ) {
                        showUpdateView.toggle()
                    }
                    .sheet(isPresented: $showUpdateView) {
                        updater.getUpdateView()
                    }
                } else if updater.announcementAvailable {
                    noticeButton(
                        image: "sparkles.2",
                        color: .purple,
                        help: "New Feature"
                    ) {
                        showFeatureView.toggle()
                    }
                    .sheet(isPresented: $showFeatureView) {
                        updater.getAnnouncementView()
                    }
                } else if permissionManager.shouldShowPermissionWarning {
                    noticeButton(
                        image: "lock.slash.fill",
                        color: .red,
                        help: "Permissions Missing"
                    ) {
                        showPermissionList.toggle()
                    }
                    .sheet(isPresented: $showPermissionList) {
                        PermissionsSheetView()
                    }
                } else if HelperToolManager.shared.shouldShowHelperBadge {
                    noticeButton(
                        image: "gear",
                        color: .orange,
                        help: "Helper Not Installed"
                    ) {
                        openAppSettingsWindow(tab: .helper, updater: updater)
                    }
                }

            }

        }
    }

    private var canAnimate: Bool {
        animationEnabled && !accessibilityReduceMotion
    }

    private var modernWindowBackground: some View {
        ZStack {
            ThemeColors.shared(for: colorScheme).primaryBG

            LinearGradient(
                colors: [
                    ThemeColors.shared(for: colorScheme).accent.opacity(
                        colorScheme == .dark ? 0.08 : 0.045
                    ),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }

    private var utilitySwitcher: some View {
        Menu {
            Section("Essentials") {
                utilityMenuItems([.applications, .orphans, .updater])
            }

            Section("System") {
                utilityMenuItems([.homebrew, .packages, .services, .plugins])
            }

            Section("Tools") {
                utilityMenuItems([.fileSearch, .development, .lipo])
            }
        } label: {
            HStack(spacing: PearMetrics.spacingS) {
                Image(systemName: appState.currentPage.icon)
                    .font(.system(size: PearMetrics.toolbarIconSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                    .frame(width: 24, height: 24)
                    .background(
                        ThemeColors.shared(for: colorScheme).accentSurface,
                        in: RoundedRectangle(cornerRadius: PearMetrics.radiusS, style: .continuous)
                    )

                Text(appState.currentPage.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                if updateManager.totalUpdateCount > 0 {
                    Text(updateManager.totalUpdateCount, format: .number)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 18)
                        .background(.red, in: Capsule(style: .continuous))
                        .accessibilityLabel(
                            Text("\(updateManager.totalUpdateCount) updates available")
                        )
                }

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Switch Utilities")
        .accessibilityLabel(Text("Current utility: \(appState.currentPage.title)"))
    }

    @ViewBuilder
    private func utilityMenuItems(_ pages: [CurrentPage]) -> some View {
        ForEach(pages.filter { CurrentPage.availablePages.contains($0) }) { page in
            Button {
                selectUtility(page)
            } label: {
                Label {
                    if page == .updater && (loadUpdatesOnStartup || updateManager.totalUpdateCount > 0) {
                        Text("\(page.title) (\(updateManager.totalUpdateCount))")
                    } else {
                        Text(page.title)
                    }
                } icon: {
                    Image(systemName: page.icon)
                }
            }
        }
    }

    private func selectUtility(_ page: CurrentPage) {
        guard page != appState.currentPage else {
            tutorialShown = false
            return
        }

        withAnimation(.easeInOut(duration: canAnimate ? PearMotion.standard : 0)) {
            if page == .applications {
                appState.appInfo = .empty
                appState.currentView = .empty
            }

            appState.currentPage = page
        }

        tutorialShown = false
    }

    @ViewBuilder
    private func noticeButton(
        image: String, color: Color, help: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: image)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }
            .shadow(color: Color(NSColor.windowBackgroundColor).opacity(1), radius: 1, x: 0, y: 0)
            .shadow(color: color.opacity(0.6), radius: glowRadius, x: 0, y: 0)
            .animation(
                .easeOut(duration: canAnimate ? PearMotion.standard : 0),
                value: glowRadius
            )
        }
        .buttonStyle(.plain)
        .help(help)
        .onAppear {
            glowRadius = canAnimate ? 3 : 0
        }
    }

    /// Helper to wrap view content with console at bottom
    @ViewBuilder
    private func withConsole<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()

            if consoleManager.showConsole && !(appState.currentPage == .applications && appState.currentView == .empty) {
                GlobalConsoleView(
                    output: consoleManager.consoleOutput,
                    height: $consoleManager.consoleHeight,
                    onClear: {
                        Task { @MainActor in
                            consoleManager.clearOutput()
                        }
                    }
                )
                .frame(height: consoleManager.consoleHeight)
                .transition(.move(edge: .bottom))
            }
        }
    }

    @ViewBuilder
    private var applicationsView: some View {
        HStack(alignment: .center, spacing: 0) {

            // App List
            AppSearchView()
                .frame(width: sidebarWidth)
                .transition(.opacity)
                .ifGlassMain()
                .padding([.leading, .vertical], 8)
                .ignoresSafeArea(edges: .top)

            // Details View with Console
                HStack(spacing: 0) {
                    Group {
                        switch appState.currentView {
                        case .empty:
                            MountedVolumeView()
                                .id(appState.appInfo.id)
                        case .files:
                            FilesView()
                                .id(appState.appInfo.id)
                                .environmentObject(brewManager)
                        }
                    }
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .zIndex(2)
        }
    }

}

struct MountedVolumeView: View {
    @AppStorage("settings.interface.greetingEnabled") private var greetingEnabled: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    @State private var selectedVolumeIndex: Int = 0

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 320, maximum: 560), spacing: PearMetrics.spacingL)]
    }

    private var externalVolumeCount: Int {
        appState.volumeInfos.filter(\.isExternal).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dashboardHeader
                .padding(.horizontal, PearMetrics.spacingXL)
                .padding(.top, 30)
                .padding(.bottom, PearMetrics.spacingL)

            Divider()
                .overlay(ThemeColors.shared(for: colorScheme).separator)

            if appState.volumeInfos.isEmpty {
                VStack(spacing: PearMetrics.spacingM) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Text("Loading storage")
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    Text("Storage information will appear here shortly.")
                        .font(.subheadline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    ProgressView()
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: PearMetrics.spacingL) {
                        ForEach(Array(appState.volumeInfos.enumerated()), id: \.element.id) {
                            index, volume in
                            VolumeItemView(volume: volume, onEject: ejectVolume)
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: PearMetrics.radiusL,
                                        style: .continuous
                                    )
                                    .strokeBorder(
                                        selectedVolumeIndex == index
                                            ? ThemeColors.shared(for: colorScheme).accent.opacity(0.62)
                                            : Color.clear,
                                        lineWidth: 1.5
                                    )
                                }
                                .contentShape(
                                    RoundedRectangle(
                                        cornerRadius: PearMetrics.radiusL,
                                        style: .continuous
                                    )
                                )
                                .onTapGesture {
                                    withAnimation(
                                        .easeOut(
                                            duration: animationEnabled && !reduceMotion
                                                ? PearMotion.standard : 0
                                        )
                                    ) {
                                        selectedVolumeIndex = index
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: 1160)
                    .frame(maxWidth: .infinity)
                    .padding(PearMetrics.spacingXL)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            selectedVolumeIndex = 0
        }
        .onChange(of: appState.volumeInfos.count) { volumeCount in
            if volumeCount > 0 {
                selectedVolumeIndex = min(selectedVolumeIndex, volumeCount - 1)
            }
        }
    }

    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: PearMetrics.spacingL) {
            VStack(alignment: .leading, spacing: PearMetrics.spacingXS) {
                HStack(spacing: PearMetrics.spacingS) {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)

                    Text("Storage")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }

                Text("Select an application from the sidebar to inspect and clean its files.")
                    .font(.subheadline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }

            Spacer(minLength: PearMetrics.spacingL)

            if externalVolumeCount > 0 {
                Label("\(externalVolumeCount) external", systemImage: "externaldrive.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .padding(.horizontal, PearMetrics.spacingM)
                    .frame(height: 28)
                    .background(
                        ThemeColors.shared(for: colorScheme).hoverSurface,
                        in: Capsule(style: .continuous)
                    )
            }

            if greetingEnabled {
                ProfileMenuView()
            }
        }
    }

    private func ejectVolume(_ volume: VolumeInfo) {
        let workspace = NSWorkspace.shared
        let success = workspace.unmountAndEjectDevice(atPath: volume.path)

        if !success {
            printOS("Failed to eject volume: \(volume.name)")
        } else {
            // Find the current volume's index before ejection
            if let currentIndex = appState.volumeInfos.firstIndex(where: { $0.id == volume.id }) {
                // Refresh volume list after successful ejection
                appState.loadVolumeInfo()

                // Adjust selected index after volume removal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let newCount = appState.volumeInfos.count
                    if newCount > 0 {
                        selectedVolumeIndex = min(currentIndex, newCount - 1)
                    }
                }
            }
        }
    }
}
struct ProfileMenuView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var profile: UserProfile? = nil

    var body: some View {
        HStack(spacing: PearMetrics.spacingS) {
            if let name = profile?.firstName {
                Text(name.lowercased())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }

            if let image = profile?.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(
                                ThemeColors.shared(for: colorScheme).separator,
                                lineWidth: 1
                            )
                    }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("User profile")
        .onAppear {
            Task {
                profile = await getUserProfile()
            }
        }
    }
}

struct VolumeItemView: View {
    let volume: VolumeInfo
    let onEject: (VolumeInfo) -> Void
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    @State private var purgeableSize: Int64 = 0
    @State private var usedSize: Int64 = 0
    @State private var hoverAvailable: Bool = false
    @State private var hoverPurgeable: Bool = false
    @State private var hoverUsed: Bool = false
    @State private var isHovered: Bool = false
    @State private var isHoveredName: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: PearMetrics.spacingL) {
            HStack(alignment: .center, spacing: PearMetrics.spacingL) {
                volume.icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .padding(PearMetrics.spacingS)
                    .background(
                        ThemeColors.shared(for: colorScheme).hoverSurface,
                        in: RoundedRectangle(
                            cornerRadius: PearMetrics.radiusS,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: PearMetrics.spacingXS) {
                    HStack {
                        HStack(spacing: 8) {
                            Button(action: openStorageSettings) {
                                Text(volume.name)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(
                                        ThemeColors.shared(for: colorScheme).primaryText
                                    )
                                    .underline(isHoveredName)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                            .onHover { isHoveredName = $0 }
                            .help("Open Storage Settings")

                            if volume.isExternal {
                                Button {
                                    onEject(volume)
                                } label: {
                                    Image(systemName: "eject.fill")
                                        .font(.caption.weight(.semibold))
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(
                                    ThemeColors.shared(for: colorScheme).secondaryText
                                )
                                .help("Eject \(volume.name)")
                            }
                        }

                        Spacer()

                        Text(String(format: "%.0f%% full", percentUsed))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            .padding(.horizontal, PearMetrics.spacingS)
                            .frame(height: 24)
                            .background(
                                ThemeColors.shared(for: colorScheme).accentSurface,
                                in: Capsule(style: .continuous)
                            )
                    }

                    HStack {
                        Image(systemName: volume.isExternal ? "externaldrive" : "internaldrive")
                        Text(volume.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                }
            }

            HStack(spacing: PearMetrics.spacingS) {
                storageMetric(
                    title: "Used",
                    value: ByteCountFormatter.string(
                        fromByteCount: volume.usedSpace,
                        countStyle: .file
                    ),
                    isHighlighted: hoverUsed
                )

                storageMetric(
                    title: "Available",
                    value: ByteCountFormatter.string(
                        fromByteCount: volume.realAvailableSpace,
                        countStyle: .file
                    ),
                    isHighlighted: hoverAvailable
                )

                if volume.purgeableSpace > 0 {
                    storageMetric(
                        title: "Purgeable",
                        value: ByteCountFormatter.string(
                            fromByteCount: volume.purgeableSpace,
                            countStyle: .file
                        ),
                        isHighlighted: hoverPurgeable
                    )
                    .help(
                        "Purgeable space is managed automatically by macOS and cannot be freed manually."
                    )
                }
            }

            VStack(alignment: .leading, spacing: PearMetrics.spacingS) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ThemeColors.shared(for: colorScheme).hoverSurface)

                        Capsule()
                            .fill(ThemeColors.shared(for: colorScheme).accent.opacity(0.42))
                            .frame(width: geo.size.width * purgeableFraction)
                            .animation(
                                animationEnabled && !reduceMotion && !volume.hasAnimated
                                    ? .spring(response: 0.7, dampingFraction: 0.72)
                                    : .linear(duration: 0), value: purgeableSize
                            )
                            .help(
                                "Purgeable space is managed automatically by macOS and cannot be freed manually."
                            )

                        Capsule()
                            .fill(ThemeColors.shared(for: colorScheme).accent)
                            .frame(width: geo.size.width * usedFraction)
                            .animation(
                                animationEnabled && !reduceMotion && !volume.hasAnimated
                                    ? .spring(response: 0.7, dampingFraction: 0.72)
                                    : .linear(duration: 0), value: usedSize)

                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: geo.size.width * usedFraction)
                                .onHover { hoverUsed = $0 }

                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: geo.size.width * purgeableOnlyFraction)
                                .onHover { hoverPurgeable = $0 }

                            Rectangle()
                                .fill(Color.clear)
                                .onHover { hoverAvailable = $0 }
                        }
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("0")
                    Spacer()
                    Text(
                        ByteCountFormatter.string(
                            fromByteCount: volume.totalSpace,
                            countStyle: .file
                        )
                    )
                }
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
        }
        .padding(PearMetrics.spacingL)
        .background {
            RoundedRectangle(cornerRadius: PearMetrics.radiusL, style: .continuous)
                .fill(
                    isHovered
                        ? ThemeColors.shared(for: colorScheme).elevatedSurface
                        : ThemeColors.shared(for: colorScheme).secondaryBG
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PearMetrics.radiusL, style: .continuous)
                        .strokeBorder(
                            ThemeColors.shared(for: colorScheme).separator,
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: ThemeColors.shared(for: colorScheme).windowShadow,
                    radius: isHovered ? 12 : 5,
                    y: isHovered ? 6 : 2
                )
        }
        .scaleEffect(isHovered ? 1.006 : 1)
        .animation(
            .easeOut(duration: animationEnabled && !reduceMotion ? PearMotion.standard : 0),
            value: isHovered
        )
        .onHover { isHovered = $0 }
        .onAppear {
            if volume.hasAnimated {
                purgeableSize = volume.usedSpace + volume.purgeableSpace
                usedSize = volume.usedSpace
            } else {
                startVolumeAnimation()
            }
        }
    }

    private var percentUsed: Double {
        guard volume.totalSpace > 0 else { return 0 }
        return Double(volume.usedSpace) / Double(volume.totalSpace) * 100
    }

    private var usedFraction: CGFloat {
        storageFraction(for: usedSize)
    }

    private var purgeableFraction: CGFloat {
        storageFraction(for: purgeableSize)
    }

    private var purgeableOnlyFraction: CGFloat {
        storageFraction(for: volume.purgeableSpace)
    }

    private func storageFraction(for size: Int64) -> CGFloat {
        guard volume.totalSpace > 0 else { return 0 }
        return min(max(CGFloat(size) / CGFloat(volume.totalSpace), 0), 1)
    }

    private func storageMetric(
        title: LocalizedStringKey,
        value: String,
        isHighlighted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: PearMetrics.spacingXS) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(
                    isHighlighted
                        ? ThemeColors.shared(for: colorScheme).accent
                        : ThemeColors.shared(for: colorScheme).primaryText
                )
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PearMetrics.spacingM)
        .background(
            ThemeColors.shared(for: colorScheme).hoverSurface,
            in: RoundedRectangle(cornerRadius: PearMetrics.radiusS, style: .continuous)
        )
    }

    private func openStorageSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.settings.Storage"
            )
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func startVolumeAnimation() {
        purgeableSize = 0
        usedSize = 0

        if animationEnabled && !reduceMotion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.purgeableSize = volume.usedSpace + volume.purgeableSpace
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.usedSize = volume.usedSpace
                self.markVolumeAsAnimated()
            }
        } else {
            self.purgeableSize = volume.usedSpace + volume.purgeableSpace
            self.usedSize = volume.usedSpace
            self.markVolumeAsAnimated()
        }
    }

    private func markVolumeAsAnimated() {
        if let index = appState.volumeInfos.firstIndex(where: { $0.id == volume.id }) {
            appState.volumeInfos[index].hasAnimated = true
        }
    }

}
