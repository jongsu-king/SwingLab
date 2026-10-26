import SwiftUI

enum SLTheme {
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
            Text(title).font(.title2.weight(.semibold)).foregroundStyle(SLTheme.ink)
            Text(message).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 28)
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
