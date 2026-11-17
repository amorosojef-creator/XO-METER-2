import SwiftUI

enum XOTheme {
    static let bg = Color(red: 13/255, green: 14/255, blue: 18/255)          // #0D0E12
    static let surface = Color(red: 32/255, green: 33/255, blue: 38/255)     // #202126
    static let text = Color(red: 245/255, green: 245/255, blue: 247/255)     // #F5F5F7
    static let accent = Color(red: 1.0, green: 214/255, blue: 0)             // #FFD600
    static let accentGlow = Color(red: 1.0, green: 214/255, blue: 0)         // kept flat; no glow
    static let muted = Color(red: 0.66, green: 0.66, blue: 0.70)
}

struct GlassPanel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(XOTheme.surface.opacity(0.88))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.10), lineWidth: 1))
            }
    }
}
struct XOButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(XOTheme.accentGlow, in: RoundedRectangle(cornerRadius: 15))
            .foregroundStyle(.black)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
