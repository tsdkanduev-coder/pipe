import SwiftUI

/// S7 chrome tokens. Light + dark resolve from the same pair.
/// Paper / near-black only, plus Dayflow’s existing interactive accent.
enum SledChrome {
  static let paperHex = "FAFAFA"
  static let inkHex = "0A0A0A"
  /// Dayflow interactive accent (`#F96E00`). Not a new brand hue.
  static let accentHex = "F96E00"

  static let paper = Color(hex: paperHex)
  static let ink = Color(hex: inkHex)
  static let accent = Color(hex: accentHex)

  struct Palette: Equatable {
    let background: Color
    let foreground: Color
    let secondary: Color
    let hairline: Color
    let surface: Color
    let accent: Color
    let onAccent: Color
  }

  static func palette(for colorScheme: ColorScheme) -> Palette {
    switch colorScheme {
    case .dark:
      return Palette(
        background: ink,
        foreground: paper,
        secondary: paper.opacity(0.56),
        hairline: paper.opacity(0.12),
        surface: paper.opacity(0.06),
        accent: accent,
        onAccent: paper
      )
    default:
      return Palette(
        background: paper,
        foreground: ink,
        secondary: ink.opacity(0.56),
        hairline: ink.opacity(0.10),
        surface: ink.opacity(0.04),
        accent: accent,
        onAccent: paper
      )
    }
  }

  /// Dense layout + type-as-hierarchy. No extra decorative sizes.
  enum TypeRamp {
    static let title = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 11, weight: .regular)
    static let status = Font.system(size: 11, weight: .semibold)
  }

  enum Space {
    static let tight: CGFloat = 4
    static let row: CGFloat = 6
    static let stack: CGFloat = 8
    static let inset: CGFloat = 10
  }
}

private enum SledChromeKey: EnvironmentKey {
  static let defaultValue = SledChrome.palette(for: .light)
}

extension EnvironmentValues {
  var sledChrome: SledChrome.Palette {
    get { SledChrome.palette(for: colorScheme) }
    set { self[SledChromeKey.self] = newValue }
  }
}
