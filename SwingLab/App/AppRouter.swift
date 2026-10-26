import SwiftUI

struct AppRouter: View {
    @Environment(AppPreferences.self) private var preferences
    var body: some View {
        @Bindable var preferences = preferences
        TabView {
            NavigationStack { HomeView() }.tabItem { Label(preferences.text("Home"), systemImage: "house") }
            NavigationStack { SwingView() }.tabItem { Label(preferences.text("Swing"), systemImage: "figure.golf") }
            NavigationStack { CourseView() }.tabItem { Label(preferences.text("Course"), systemImage: "map") }
            NavigationStack { PerformanceView() }.tabItem { Label(preferences.text("Performance"), systemImage: "chart.xyaxis.line") }
        }
        .id(preferences.libraryRevision)
        .sheet(isPresented: Binding(get: { !preferences.completedOnboarding }, set: { if !$0 { preferences.completedOnboarding = true } })) {
            OnboardingView().interactiveDismissDisabled()
        }
    }
}
