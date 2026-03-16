import SwiftUI
import ApplicationServices

struct OnboardingView: View {
    let appState: AppState
    let onComplete: () -> Void
    @State private var pollTimer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Typeness Needs Accessibility Permission")
                .font(.title2.bold())

            Text("Typeness uses Accessibility permission to:\n• Register global hotkeys that work in any app\n• Insert transcribed text at your cursor position")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if appState.accessibilityStatus == .granted {
                Label("Accessibility Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                Button("Continue") {
                    UserDefaults.standard.set(true, forKey: "hasShownOnboarding")
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Open System Settings") {
                    let options = [(kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String): true] as CFDictionary
                    AXIsProcessTrustedWithOptions(options)
                    startPolling()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(width: 400)
        .onDisappear {
            pollTimer?.invalidate()
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                appState.accessibilityStatus = .granted
            }
        }
    }
}
