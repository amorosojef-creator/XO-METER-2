import SwiftUI

@main struct XOMeterApp: App {
    @StateObject private var store = XOStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(XOTheme.accent)
        }
    }
}

enum XOTab: String, CaseIterable {
    case home = "Home", scan = "Scan", saver = "Saver", bills = "Bills", settings = "Settings"
    var icon: String {
        switch self { case .home: "house.fill"; case .scan: "viewfinder"; case .saver: "leaf"; case .bills: "doc.text"; case .settings: "gearshape" }
    }
}
struct RootView: View {
    @State private var tab: XOTab = .home
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case .home: HomeView(openTab: { tab = $0 })
                case .scan: ScanView()
                case .saver: SaverView()
                case .bills: BillsView()
                case .settings: SettingsView()
                }
            }.frame(maxHeight: .infinity)
                .id(tab)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
            HStack {
                ForEach(XOTab.allCases, id: \.self) { item in
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) { tab = item }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.icon).font(.system(size: 20))
                            Text(item.rawValue).font(.system(size: 10))
                        }
                        .foregroundStyle(tab == item ? XOTheme.accent : XOTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                    }.buttonStyle(.plain)
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).stroke(.white.opacity(0.12)))
            .padding(.horizontal, 15).padding(.bottom, 7)
        }
        .background(XOTheme.bg.ignoresSafeArea())
    }
}
