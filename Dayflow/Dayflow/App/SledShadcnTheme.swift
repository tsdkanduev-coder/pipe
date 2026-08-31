import SwiftUI
import ShadcnUI

/// Locked Designer map: shadcn nova + neutral OKLCH, SF Pro, radius 0.5rem.
/// Dark `--sidebar-primary` is patched to `oklch(0.922 0 0)`.
enum SledShadcnTheme {
  static let darkSidebarPrimaryOKLCH = "oklch(0.922 0 0)"
  static let radiusPoints: CGFloat = 8

  static let darkNeutral: ShadcnPaletteSpec = ShadcnPaletteSpec(
    cssVars: ["sidebar-primary": darkSidebarPrimaryOKLCH],
    fallback: .neutralDark
  )

  static let current = ShadcnTheme(
    light: .neutralLight,
    dark: darkNeutral,
    radius: ShadcnRadius(base: radiusPoints),
    typography: ShadcnTypography()
  )
}

extension ButtonStyle where Self == PlainButtonStyle {
  /// Native chrome (MenuBarExtra / Settings / traffic-light hosts). Not a ShadKit overlay.
  static var shadcnBare: PlainButtonStyle { .plain }
}
