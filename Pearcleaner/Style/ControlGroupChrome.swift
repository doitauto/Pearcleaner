//
//  ControlGroupChrome.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/8/25.
//

import SwiftUI

public enum ControlGroupLevel: Int {
    case primary
    case secondary
}

public struct ControlGroupMetrics {
    static let primaryGroupRadius: CGFloat = PearMetrics.radiusL
    static let secondaryGroupRadius: CGFloat = PearMetrics.radiusS
}

public extension ControlGroupLevel {
    var cornerRadius: CGFloat {
        switch self {
        case .primary: ControlGroupMetrics.primaryGroupRadius
        case .secondary: ControlGroupMetrics.secondaryGroupRadius
        }
    }
}

public extension View {
    func controlGroup(level: ControlGroupLevel = .primary) -> some View {
        modifier(ControlGroupChrome(level: level, shapeBuilder: {
            RoundedRectangle(cornerRadius: level.cornerRadius, style: .continuous)
        }))
    }

    func controlGroup<S>(_ shape: S, level: ControlGroupLevel = .primary) -> some View where S: InsettableShape {
        modifier(ControlGroupChrome<S>(level: level, shapeBuilder: { shape }))
    }
}

private struct ControlGroupChrome<Shape: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme)
    private var colorScheme

    var level: ControlGroupLevel
    var shapeBuilder: () -> Shape

    var dark: Bool { colorScheme == .dark }

    private var theme: ThemeColors {
        ThemeColors.shared(for: colorScheme)
    }

    private var innerRimOpacity: Double {
        switch level {
        case .primary:
            return dark ? 0.15 : 0
        case .secondary:
            return dark ? 0.1 : 0
        }
    }

    private var outerRimOpacity: Double {
        switch level {
        case .primary:
            return dark ? 0.18 : 0.10
        case .secondary:
            return dark ? 0.12 : 0.08
        }
    }

    private var shadowOpacity: Double {
        switch level {
        case .primary:
            return dark ? 0.18 : 0.08
        case .secondary:
            return dark ? 0.10 : 0.04
        }
    }

    private var material: Material {
        switch level {
        case .primary:
            return .thin
        case .secondary:
            return .regular
        }
    }

    func body(content: Content) -> some View {
        content
            .background(material, in: shape)
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(theme.separator.opacity(outerRimOpacity), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: dark ? 6 : 8, x: 0, y: 2)
            .chromeBorder(shape: shape, highlightEnabled: true, rimEnabled: false, shadowEnabled: false, highlightIntensity: innerRimOpacity)
            .containerShape(shape)
    }

    private var shape: Shape {
        shapeBuilder()
    }
}
