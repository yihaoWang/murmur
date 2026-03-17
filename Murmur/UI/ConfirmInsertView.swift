import SwiftUI

struct ConfirmInsertView: View {
    let text: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var editableText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Confirm Text")
                .font(.headline)

            TextEditor(text: $editableText)
                .frame(minHeight: 80, maxHeight: 200)
                .font(.body)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Insert") { onConfirm(editableText) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear { editableText = text }
    }
}
