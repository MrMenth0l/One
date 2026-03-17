#if canImport(SwiftUI)
import SwiftUI

public enum OneTheme {
    public struct Palette {
        public let isDark: Bool
        public let background: Color
        public let backgroundTop: Color
        public let surface: Color
        public let surfaceMuted: Color
        public let surfaceStrong: Color
        public let glass: Color
        public let glassStroke: Color
        public let border: Color
        public let text: Color
        public let subtext: Color
        public let accent: Color
        public let accentSoft: Color
        public let success: Color
        public let danger: Color
        public let warning: Color
        public let symbol: Color
        public let shadowColor: Color
    }

    public static let radiusXL: CGFloat = 30
    public static let radiusLarge: CGFloat = 24
    public static let radiusMedium: CGFloat = 18
    public static let radiusSmall: CGFloat = 14

    public static func palette(for scheme: ColorScheme) -> Palette {
        switch scheme {
        case .dark:
            return Palette(
                isDark: true,
                background: Color(hex: 0x0B0E14),
                backgroundTop: Color(hex: 0x121722),
                surface: Color(hex: 0x171D27),
                surfaceMuted: Color(hex: 0x10151D),
                surfaceStrong: Color(hex: 0x1F2835),
                glass: Color(hex: 0x141924, alpha: 0.72),
                glassStroke: Color.white.opacity(0.06),
                border: Color.white.opacity(0.08),
                text: Color(hex: 0xF4F7FB),
                subtext: Color(hex: 0x99A4B8),
                accent: Color(hex: 0x69AFFF),
                accentSoft: Color(hex: 0x69AFFF, alpha: 0.18),
                success: Color(hex: 0x43D27F),
                danger: Color(hex: 0xFF7A69),
                warning: Color(hex: 0xFFC562),
                symbol: Color(hex: 0xD8E0ED),
                shadowColor: Color.black.opacity(0.35)
            )
        default:
            return Palette(
                isDark: false,
                background: Color(hex: 0xF3F4F8),
                backgroundTop: Color(hex: 0xFAFBFD),
                surface: Color.white,
                surfaceMuted: Color(hex: 0xF4F6FB),
                surfaceStrong: Color(hex: 0xEFF3F8),
                glass: Color.white.opacity(0.72),
                glassStroke: Color.white.opacity(0.70),
                border: Color(hex: 0x111827, alpha: 0.08),
                text: Color(hex: 0x0F141B),
                subtext: Color(hex: 0x6A7385),
                accent: Color(hex: 0x0A84FF),
                accentSoft: Color(hex: 0x0A84FF, alpha: 0.14),
                success: Color(hex: 0x2ABF68),
                danger: Color(hex: 0xF15D4A),
                warning: Color(hex: 0xF4A42C),
                symbol: Color(hex: 0x374357),
                shadowColor: Color.black.opacity(0.08)
            )
        }
    }

    public static func preferredColorScheme(from theme: Theme?) -> ColorScheme? {
        switch theme ?? .system {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}

public extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct OneScreenBackground: View {
    let palette: OneTheme.Palette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(palette.isDark ? 0.08 : 0.52))
                    .frame(width: 320, height: 320)
                    .blur(radius: 12)
                    .offset(x: -120, y: -160)
            }
            .ignoresSafeArea()
        }
    }
}

struct OneScrollScreen<Content: View>: View {
    let palette: OneTheme.Palette
    let bottomPadding: CGFloat
    @ViewBuilder let content: Content

    init(
        palette: OneTheme.Palette,
        bottomPadding: CGFloat = 116,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        ZStack {
            OneScreenBackground(palette: palette)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, bottomPadding)
            }
        }
    }
}

struct OneGlassCard<Content: View>: View {
    let palette: OneTheme.Palette
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(
        palette: OneTheme.Palette,
        padding: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .fill(palette.glass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .stroke(palette.glassStroke, lineWidth: 1)
        )
        .shadow(color: palette.shadowColor, radius: 18, x: 0, y: 10)
    }
}

struct OneSurfaceCard<Content: View>: View {
    let palette: OneTheme.Palette
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(
        palette: OneTheme.Palette,
        padding: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 8)
    }
}

struct OneSectionHeading: View {
    let palette: OneTheme.Palette
    let title: String
    let meta: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.text)
            Spacer()
            if let meta, !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.subtext)
            }
        }
    }
}

struct OneHeroHeader<Trailing: View>: View {
    let palette: OneTheme.Palette
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    init(
        palette: OneTheme.Palette,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.palette = palette
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.subtext)
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 4)
    }
}

struct OneMarkBadge: View {
    let palette: OneTheme.Palette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x0D1117), Color(hex: 0x202936)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 54, height: 54)
            Text("1")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
        }
    }
}

struct OneAvatarBadge: View {
    let palette: OneTheme.Palette
    let initials: String

    var body: some View {
        Circle()
            .fill(palette.surfaceStrong)
            .frame(width: 42, height: 42)
            .overlay(
                Text(initials)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
            )
            .overlay(
                Circle()
                    .stroke(palette.border, lineWidth: 1)
            )
    }
}

struct OneChip: View {
    enum Kind {
        case neutral
        case strong
        case success
        case danger
    }

    let palette: OneTheme.Palette
    let title: String
    let kind: Kind

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(foreground)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }

    private var foreground: Color {
        switch kind {
        case .neutral:
            return palette.subtext
        case .strong:
            return palette.accent
        case .success:
            return palette.success
        case .danger:
            return palette.danger
        }
    }

    private var background: Color {
        switch kind {
        case .neutral:
            return palette.surfaceMuted
        case .strong:
            return palette.accentSoft
        case .success:
            return palette.success.opacity(palette.isDark ? 0.18 : 0.12)
        case .danger:
            return palette.danger.opacity(palette.isDark ? 0.18 : 0.12)
        }
    }

    private var border: Color {
        switch kind {
        case .neutral:
            return palette.border
        case .strong:
            return palette.accent.opacity(0.18)
        case .success:
            return palette.success.opacity(0.24)
        case .danger:
            return palette.danger.opacity(0.24)
        }
    }
}

struct OneProgressCluster: View {
    let palette: OneTheme.Palette
    let progress: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.surfaceStrong, lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.45), palette.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(palette.text)
        }
        .frame(width: 54, height: 54)
    }
}

struct OneActivityLane: View {
    let palette: OneTheme.Palette
    let values: [Double]
    let labels: [String]
    let highlightIndex: Int?
    var onSelectIndex: ((Int) -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Group {
                        if let onSelectIndex {
                            Button {
                                onSelectIndex(index)
                            } label: {
                                laneCell(index: index, value: value)
                            }
                            .buttonStyle(.plain)
                        } else {
                            laneCell(index: index, value: value)
                        }
                    }
                }
            }
        }
        .frame(height: 92)
    }

    private func laneCell(index: Int, value: Double) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(barFill(for: index))
                .frame(height: max(18, 20 + (60 * value)))
            Text(labels[safe: index] ?? "")
                .font(.system(size: 10, weight: highlightIndex == index ? .bold : .medium))
                .foregroundStyle(highlightIndex == index ? palette.text : palette.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private func barFill(for index: Int) -> LinearGradient {
        let accent = highlightIndex == index ? palette.accent : palette.accent.opacity(palette.isDark ? 0.7 : 0.9)
        return LinearGradient(
            colors: [accent.opacity(0.35), accent],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

struct OneSegmentedControl<Option: Hashable>: View {
    let palette: OneTheme.Palette
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let onSelect: (Option) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(title(option))
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selection == option ? palette.text : palette.subtext)
                        .background(
                            RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                                .fill(selection == option ? palette.surface : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .fill(palette.glass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .stroke(palette.glassStroke, lineWidth: 1)
        )
    }
}

struct OneActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let palette: OneTheme.Palette
    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(style == .primary ? Color.white : palette.text)
                .background(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .fill(style == .primary ? AnyShapeStyle(primaryFill) : AnyShapeStyle(palette.surface))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .stroke(style == .primary ? Color.clear : palette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var primaryFill: LinearGradient {
        LinearGradient(
            colors: [palette.accent, palette.accent.opacity(0.82)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct OneSettingsRow: View {
    let palette: OneTheme.Palette
    let icon: String
    let title: String
    let meta: String
    let tail: String?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(palette.surfaceStrong)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.symbol)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(meta)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.subtext)
            }
            Spacer()
            if let tail, !tail.isEmpty {
                Text(tail)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.subtext)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.subtext)
            }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
