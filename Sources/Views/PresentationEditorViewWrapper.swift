import SwiftUI

struct PresentationEditorViewWrapper: View {
    @State var presentation: EditablePresentation
    let onSave: (EditablePresentation) -> Void
    let onClose: () -> Void
    
    var body: some View {
        PresentationEditorView(
            presentation: $presentation,
            onSave: onSave,
            onClose: onClose
        )
        .onDisappear {
            // Auto-save sempre que o editor sai da tela
            onSave(presentation)
        }
    }
}

