import SwiftUI

struct DesignSystem {
    static var background: Color {
        switch SettingsManager.shared.selectedTheme {
        case .def:
            // Modern dark grey / soft light
            return SettingsManager.shared.isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.13) : Color(red: 0.96, green: 0.96, blue: 0.97)
        case .terminal:
            return SettingsManager.shared.isDarkMode ? Color.black : Color(white: 0.95)
        }
    }
    
    static var surface: Color {
        switch SettingsManager.shared.selectedTheme {
        case .def:
            // Glassy effect helper (used with opacity usually) or lighter grey
            return SettingsManager.shared.isDarkMode ? Color(red: 0.18, green: 0.18, blue: 0.19) : Color.white
        case .terminal:
            return SettingsManager.shared.isDarkMode ? Color(nsColor: .windowBackgroundColor) : Color.white
        }
    }
    
    static var text: Color {
        switch SettingsManager.shared.selectedTheme {
        case .def:
            return SettingsManager.shared.isDarkMode ? Color(white: 0.95) : Color(red: 0.1, green: 0.1, blue: 0.12)
        case .terminal:
            return SettingsManager.shared.isDarkMode ? Color.white : Color.black
        }
    }
    
    static var accent: Color {
        switch SettingsManager.shared.selectedTheme {
        case .def:
            // Apple-like blue/purple gradient feel often uses this blue
            return Color.accentColor
        case .terminal:
            return SettingsManager.shared.isDarkMode ? Color.white : Color.black
        }
    }
    
    static var border: Color {
        switch SettingsManager.shared.selectedTheme {
        case .def:
            return SettingsManager.shared.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
        case .terminal:
            return SettingsManager.shared.isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
        }
    }
    
    static var fontName: String {
        switch SettingsManager.shared.selectedTheme {
        case .def: return "SF Pro Text" // System Default
        case .terminal: return "Courier New"
        }
    }
    
    static var cornerRadius: CGFloat {
        switch SettingsManager.shared.selectedTheme {
        case .def: return 12
        case .terminal: return 0
        }
    }
    
    static func font(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if SettingsManager.shared.selectedTheme == .def {
            return .system(size: size, weight: weight, design: .default)
        }
        return .custom(fontName, size: size).weight(weight)
    }
}

// MARK: - New Modifiers

struct GlassyCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .stroke(DesignSystem.border, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// Legacy modifiers (kept for Terminal theme compatibility)
struct CyberCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.background)
            .border(DesignSystem.border, width: 1)
    }
}

struct DitherEffect: ViewModifier {
    func body(content: Content) -> some View {
        // Only apply dither if terminal theme
        if SettingsManager.shared.selectedTheme == .terminal {
            content.overlay(
                GeometryReader { geometry in
                    Path { path in
                        let step: CGFloat = 4
                        for x in stride(from: 0, to: geometry.size.width, by: step) {
                            for y in stride(from: 0, to: geometry.size.height, by: step) {
                                if (Int(x/step) + Int(y/step)) % 2 == 0 {
                                    path.addRect(CGRect(x: x, y: y, width: 1, height: 1))
                                }
                            }
                        }
                    }
                    .fill(DesignSystem.text.opacity(0.05))
                }
            )
        } else {
            content
        }
    }
}

struct Blinking: ViewModifier {
    @State private var isVisible = true
    
    func body(content: Content) -> some View {
        // Only blink in terminal
        if SettingsManager.shared.selectedTheme == .terminal {
            content
                .opacity(isVisible ? 1 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                        isVisible = false
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func elementStyle() -> some View {
        modifier(ThemeAwareStyle())
    }
    
    func cyberStyle() -> some View {
        self.modifier(CyberCard())
    }
    
    func dithered() -> some View {
        self.modifier(DitherEffect())
    }
    
    func blinking() -> some View {
        self.modifier(Blinking())
    }
}

struct ThemeAwareStyle: ViewModifier {
    func body(content: Content) -> some View {
        if SettingsManager.shared.selectedTheme == .def {
            content.modifier(GlassyCard())
        } else {
            content.modifier(CyberCard())
        }
    }
}
