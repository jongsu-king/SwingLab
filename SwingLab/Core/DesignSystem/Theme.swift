import SwiftUI

enum SLTheme {
    enum Space {
        static let xxs: CGFloat = 4, xs: CGFloat = 8, sm: CGFloat = 12
        static let md: CGFloat = 16, lg: CGFloat = 24, xl: CGFloat = 32
    }
    enum TypeScale {
        static let display: Font = .largeTitle.weight(.medium)
        static let title: Font = .title2.weight(.semibold)
        static let headline: Font = .headline
        static let body: Font = .body
        static let caption: Font = .caption
        static let numeric: Font = .system(.body, design: .monospaced)
    }
    static let cornerRadius: CGFloat = 8
    static let hairline: CGFloat = 0.5
    static let background = adaptive(light: 0xF6F5F1, dark: 0x161D19)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x202823)
    static let ink = adaptive(light: 0x202823, dark: 0xF6F5F1)
    static let forest = adaptive(light: 0x375746, dark: 0xB5C7A0)
    static let sage = Color(red: 181/255, green: 199/255, blue: 160/255)
    static let sand = adaptive(light: 0x786443, dark: 0xCFBA96)
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1)
        })
    }
}

struct SLEmptyState: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light)).foregroundStyle(SLTheme.forest).accessibilityHidden(true)
            Text(title).font(SLTheme.TypeScale.title).foregroundStyle(SLTheme.ink)
            Text(message).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, SLTheme.Space.lg)
    }
}
struct SLSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(SLTheme.ink)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SLListRow: View {
    let title: String
    let detail: String
    let symbol: String
    var body: some View {
        HStack(spacing: SLTheme.Space.md) {
            Image(systemName: symbol).font(.title3).foregroundStyle(SLTheme.forest).frame(width: 26)
            VStack(alignment: .leading, spacing: SLTheme.Space.xxs) {
                Text(title).font(SLTheme.TypeScale.headline).foregroundStyle(SLTheme.ink)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }.frame(minHeight: 44).contentShape(Rectangle())
    }
}

struct SLInlineNotice: View {
    let message: String
    var symbol: String = "info.circle"
    var body: some View {
        Label(message, systemImage: symbol).font(SLTheme.TypeScale.caption)
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
