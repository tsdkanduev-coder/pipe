import SwiftUI
import ShadcnUI

/// Local LLM only. Cloud Account / Providers / Referral / MCP stay hidden.
struct SettingsLocalModelTabView: View {
  @ObservedObject var viewModel: ProvidersSettingsViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: Space.x6) {
      ShadcnCard {
        ShadcnCardHeader {
          ShadcnCardTitle("Local model")
          ShadcnCardDescription(
            "Sled uses Ollama or LM Studio on this Mac. Capture still runs when the runtime is down; summaries stay empty."
          )
        }
        ShadcnCardContent {
          LabeledContent("Engine") {
            Text(viewModel.localEngine.displayName)
          }
          LabeledContent("Model") {
            Text(viewModel.localModelId.isEmpty ? "Not configured" : viewModel.localModelId)
          }
          LabeledContent("Endpoint") {
            Text(viewModel.localBaseURL)
          }
          LabeledContent("Status") {
            Text(LocalLLMRuntimeStatus.current().userMessage)
          }
          if !LocalLLMRuntimeStatus.current().isReady {
            Text("No runtime: summaries paused, capture runs.")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}
