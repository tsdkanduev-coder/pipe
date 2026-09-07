import SwiftUI

struct OnboardingHowPIPWorksStep: View {
  var onContinue: () -> Void

  private let ink = Color(hex: "492304")
  private let muted = Color(hex: "89380E")

  private let beats: [(icon: String, title: String, body: String)] = [
    (
      "rectangle.dashed.badge.record",
      "PIP records this Mac",
      "Screenshots stay in ~/Library/Application Support/PIP. Dayflow is a separate app and is not touched."
    ),
    (
      "cpu",
      "Qwen 3.5 reads the frames locally",
      "Ollama runs qwen3.5:4b on this machine. No cloud key. Cards appear after about 15 minutes of recording."
    ),
    (
      "point.3.connected.trianglepath.dotted",
      "Agents get a briefing, not the screen",
      "MultiTool or Codex can ask PIP what you did. They get a short briefing, never the recording."
    ),
  ]

  var body: some View {
    VStack(spacing: 0) {
      Spacer().frame(height: 36)

      Text("How PIP works")
        .font(.custom("InstrumentSerif-Regular", size: 40))
        .tracking(-1.2)
        .multilineTextAlignment(.center)
        .foregroundColor(ink)
        .frame(maxWidth: 720)

      Text("Three steps. Local end to end.")
        .font(.custom("Figtree", size: 18))
        .foregroundColor(muted)
        .padding(.top, 10)

      Spacer().frame(height: 36)

      VStack(spacing: 12) {
        ForEach(Array(beats.enumerated()), id: \.offset) { index, beat in
          HStack(alignment: .top, spacing: 16) {
            ZStack {
              Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 40, height: 40)
              Image(systemName: beat.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ink)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("\(index + 1). \(beat.title)")
                .font(.custom("Figtree-Bold", size: 16))
                .foregroundColor(ink)
              Text(beat.body)
                .font(.custom("Figtree-Medium", size: 14))
                .foregroundColor(muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
          }
          .padding(16)
          .background(Color.white.opacity(0.35))
          .cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color(hex: "E4D3C2"), lineWidth: 1)
          )
        }
      }
      .frame(maxWidth: 680)

      Spacer()

      HStack(spacing: 16) {
        DayflowSurfaceButton(
          action: onContinue,
          content: {
            Text("Continue")
              .font(.custom("Figtree", size: 14))
              .fontWeight(.semibold)
          },
          background: Color(hex: "402C00"),
          foreground: .white,
          borderColor: .clear,
          cornerRadius: 8,
          horizontalPadding: 48,
          verticalPadding: 12,
          minWidth: 180,
          showOverlayStroke: true
        )
      }
      .padding(.bottom, 48)
    }
    .padding(.horizontal, 48)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
