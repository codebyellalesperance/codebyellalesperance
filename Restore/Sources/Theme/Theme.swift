import SwiftUI

// Copenhagen-minimal palette from the round-5/6 living wireframe.
enum Palette {
    static let bone = Color(red: 0.961, green: 0.957, blue: 0.941)      // #F5F4F0
    static let ink = Color(red: 0.106, green: 0.106, blue: 0.094)       // #1B1B18
    static let grey = Color(red: 0.455, green: 0.455, blue: 0.424)      // #74746C
    static let faint = Color(red: 0.639, green: 0.635, blue: 0.604)     // #A3A29A
    static let hairline = Color(red: 0.894, green: 0.886, blue: 0.859)  // #E4E2DB
    static let pine = Color(red: 0.278, green: 0.412, blue: 0.361)      // #47695C
    static let clay = Color(red: 0.690, green: 0.514, blue: 0.333)      // #B08355
    static let greyBlue = Color(red: 0.549, green: 0.596, blue: 0.635)  // #8C98A2
    static let skyTop = Color(red: 0.682, green: 0.773, blue: 0.824)    // #AEC5D2
    static let skyMid = Color(red: 0.788, green: 0.847, blue: 0.847)    // #C9D8D8
}

extension Font {
    static func hanken(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom("Hanken Grotesk", size: size).weight(weight)
    }
}

// Sky, clouds and misty pine hills — pure gradients, no assets.
struct SkyBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Palette.skyTop, location: 0.0),
                        .init(color: Palette.skyMid, location: 0.28),
                        .init(color: Color(red: 0.906, green: 0.910, blue: 0.878), location: 0.62),
                        .init(color: Palette.bone, location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                // Clouds
                Ellipse()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: geo.size.width * 1.1, height: 130)
                    .blur(radius: 32)
                    .position(x: geo.size.width * 0.2, y: 120)
                Ellipse()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: geo.size.width * 1.2, height: 150)
                    .blur(radius: 36)
                    .position(x: geo.size.width * 0.95, y: 230)
                // Hills
                Ellipse()
                    .fill(Palette.pine.opacity(0.5))
                    .frame(width: geo.size.width * 1.7, height: 340)
                    .blur(radius: 44)
                    .position(x: geo.size.width * 0.12, y: geo.size.height + 60)
                Ellipse()
                    .fill(Palette.pine.opacity(0.42))
                    .frame(width: geo.size.width * 2.0, height: 400)
                    .blur(radius: 50)
                    .position(x: geo.size.width * 0.9, y: geo.size.height + 90)
            }
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var corner: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(Color.white.opacity(0.38))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassCard(corner: CGFloat = 18) -> some View {
        modifier(GlassCard(corner: corner))
    }
}

struct LabelText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.hanken(11, .medium))
            .kerning(1.6)
            .foregroundStyle(Palette.grey)
    }
}

struct RxText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.hanken(13))
            .monospacedDigit()
            .foregroundStyle(Palette.pine)
    }
}
