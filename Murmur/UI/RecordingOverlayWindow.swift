import AppKit
import SwiftUI

/// Floating HUD overlay at bottom-center of screen showing recording state.
final class RecordingOverlayWindow {
    private var window: NSWindow?
    private var hideTimer: Timer?
    private var showGeneration: Int = 0

    static let shared = RecordingOverlayWindow()

    func show(state: OverlayState) {
        hideTimer?.invalidate()
        hideTimer = nil
        showGeneration += 1

        let hostingView = NSHostingView(rootView: OverlayView(state: state))
        hostingView.frame = NSRect(x: 0, y: 0, width: 64, height: 64)

        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 64, height: 64),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.isOpaque = false
            w.backgroundColor = .clear
            w.level = .floating
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            w.hasShadow = false
            w.ignoresMouseEvents = true
            window = w
        }

        window?.contentView = hostingView
        window?.alphaValue = 1
        positionAtBottomCenter()
        window?.orderFrontRegardless()

        if state == .done {
            hideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.hide()
            }
        }
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        let gen = showGeneration
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            window?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.showGeneration == gen else { return }
            self.window?.orderOut(nil)
            self.window?.alphaValue = 1
        }
    }

    private func positionAtBottomCenter() {
        guard let screen = NSScreen.main, let window = window else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - window.frame.width / 2
        let y = screenFrame.origin.y + 80
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

enum OverlayState {
    case recording
    case transcribing
    case done
}

private struct OverlayView: View {
    let state: OverlayState
    @State private var blinkVisible = true

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 56, height: 56)
                .shadow(color: .clear, radius: 0)

            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(state == .recording && !blinkVisible ? .red.opacity(0.3) : iconColor)
        }
        .frame(width: 64, height: 64)
        .onAppear {
            if state == .recording {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    blinkVisible = false
                }
            }
        }
    }

    private var iconName: String {
        switch state {
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .done: return "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .recording: return .red
        case .transcribing: return .orange
        case .done: return .green
        }
    }
}
