import SwiftUI

struct ItemTile: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .frame(width: 120, height: 60)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct InputView: View {
    @ObservedObject var viewModel: DownloadViewModel
    @FocusState private var idFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                BrandingImage()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Download One Item From Jamf Dev")
                        .font(.headline)
                    Text("Select the item type and enter the ID, then click \"Download\".")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 16)

            HStack(spacing: 12) {
                ItemTile(
                    title: "Script",
                    icon: "doc.text",
                    isSelected: viewModel.selectedType == .script,
                    action: { viewModel.selectedType = .script }
                )
                ItemTile(
                    title: "Ext Attribute",
                    icon: "puzzlepiece.extension",
                    isSelected: viewModel.selectedType == .extensionAttribute,
                    action: { viewModel.selectedType = .extensionAttribute }
                )
            }
            .padding(.bottom, 12)

            Text("Enter the item ID number.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            TextField("", text: $viewModel.itemIdText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .focused($idFieldFocused)
                .onSubmit {
                    guard !viewModel.itemIdText.isEmpty else { return }
                    Task { await viewModel.startDownload() }
                }

            Spacer()

            HStack {
                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut(.cancelAction)

                Button("Download") {
                    Task { await viewModel.startDownload() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.itemIdText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .onAppear {
            idFieldFocused = true
        }
    }
}
