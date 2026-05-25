import SwiftUI

struct ResultView: View {
    let isSuccess: Bool
    let title: String
    let detail: String
    let outputURL: URL?
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                BrandingImage(badge: isSuccess ? .success : .error)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isSuccess ? title : "Error")
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer()

            HStack {
                Spacer()

                if isSuccess, let url = outputURL {
                    Button("Open in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }

                Button("Done") {
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}
