import SwiftUI

struct OnboardingAgentContextStep: View {
  var onBack: () -> Void
  var onContinue: () -> Void

  @State private var buttonTitle = "Connect MCP"
  @State private var status = ""

  private let ink = Color(hex: "492304")
  private let muted = Color(hex: "89380E")

  var body: some View {
    VStack(spacing: 0) {
      Spacer().frame(height: 48)

      Text("Connect MCP")
        .font(.custom("InstrumentSerif-Regular", size: 40))
        .tracking(-1.2)
        .multilineTextAlignment(.center)
        .foregroundColor(ink)
        .frame(maxWidth: 720)

      Text(
        "One server named pipe. PIP writes it into MultiTool and Codex. Then ask either of them what you did today."
      )
      .font(.custom("Figtree", size: 16))
      .foregroundColor(muted)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 560)
      .padding(.top, 12)

      Spacer().frame(height: 36)

      VStack(alignment: .leading, spacing: 10) {
        Text("After you connect")
          .font(.custom("Figtree-Bold", size: 14))
          .foregroundColor(ink)
        Text("1. Open MultiTool or Codex.")
          .font(.custom("Figtree-Medium", size: 14))
          .foregroundColor(muted)
        Text("2. Ask what you did today. They should use the pipe server.")
          .font(.custom("Figtree-Medium", size: 14))
          .foregroundColor(muted)
        Text("3. Restart the agent app if it was already open.")
          .font(.custom("Figtree-Medium", size: 14))
          .foregroundColor(muted)
      }
      .padding(20)
      .frame(maxWidth: 520, alignment: .leading)
      .background(Color.white.opacity(0.35))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(hex: "E4D3C2"), lineWidth: 1)
      )

      Spacer().frame(height: 24)

      DayflowSurfaceButton(
        action: connectMCP,
        content: {
          Text(buttonTitle)
            .font(.custom("Figtree", size: 16))
            .fontWeight(.semibold)
        },
        background: Color(hex: "402C00"),
        foreground: .white,
        borderColor: .clear,
        cornerRadius: 8,
        horizontalPadding: 48,
        verticalPadding: 14,
        minWidth: 220,
        showOverlayStroke: true
      )

      if !status.isEmpty {
        Text(status)
          .font(.custom("Figtree", size: 13))
          .foregroundColor(muted)
          .multilineTextAlignment(.center)
          .padding(.top, 12)
          .frame(maxWidth: 480)
      }

      Spacer()

      HStack(spacing: 16) {
        DayflowSurfaceButton(
          action: onBack,
          content: {
            Text("Back")
              .font(.custom("Figtree", size: 14))
              .fontWeight(.semibold)
          },
          background: Color.white.opacity(0.7),
          foreground: ink,
          borderColor: Color(hex: "E4D3C2"),
          cornerRadius: 8,
          horizontalPadding: 28,
          verticalPadding: 12,
          minWidth: 120
        )

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
      .padding(.bottom, 40)
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear { refreshStatus() }
  }

  private func connectMCP() {
    let connected = AgentClientRegistration.connectPreferredClients()
    if connected.isEmpty {
      buttonTitle = "Retry"
      status = "Nothing to write yet. Install MultiTool or Codex, then try again."
    } else {
      buttonTitle = "Connected"
      status = "Wrote pipe to \(connected.map(\.displayName).joined(separator: ", ")). Restart those apps, then ask what you did today."
    }
  }

  private func refreshStatus() {
    let names = AgentClientRegistration.connectedPreferredNames()
    if names.isEmpty { return }
    buttonTitle = "Connected"
    status = "Already connected: \(names.joined(separator: ", "))."
  }
}
