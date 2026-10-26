import SwiftUI

enum AppTab: Hashable { case home, swing, course, performance }

struct AppRouter: View {
    @State private var selection = AppTab.home
    @Environment(AppPreferences.self) private var preferences
    var body: some View {
        @Bindable var preferences = preferences
        TabView(selection: $selection) {
            NavigationStack { HomeView(selection: $selection) }.tabItem { Label(preferences.text("Home"), systemImage: "house") }.tag(AppTab.home)
            NavigationStack { SwingView() }.tabItem { Label(preferences.text("Swing"), systemImage: "figure.golf") }.tag(AppTab.swing)
            NavigationStack { CourseView() }.tabItem { Label(preferences.text("Course"), systemImage: "map") }.tag(AppTab.course)
            NavigationStack { PerformanceView() }.tabItem { Label(preferences.text("Performance"), systemImage: "chart.xyaxis.line") }.tag(AppTab.performance)
        }
        .id(preferences.libraryRevision)
        .contrast(preferences.outdoorContrast ? 1.25 : 1)
        .sheet(isPresented: Binding(get: { !preferences.completedOnboarding }, set: { if !$0 { preferences.completedOnboarding = true } })) {
            OnboardingView().interactiveDismissDisabled()
        }
    }
}
