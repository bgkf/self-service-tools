import SwiftUI

struct OverlayView: View {
    @ObservedObject var viewModel: EnablerViewModel

    var body: some View {
        VStack(spacing: 16) {
            header
            Divider()
            instructions
            countdown
            statusText
            doneButton
        }
        .padding(24)
        .frame(width: 440, height: 380)
        .onAppear {
            viewModel.start()
        }
        .alert("Error", isPresented: showError, actions: {
            Button("OK") { NSApp.terminate(nil) }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
    }

    private var showError: Binding<Bool> {
        Binding(
            get: { viewModel.status == .error },
            set: { _ in }
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, isActive: viewModel.status == .active || viewModel.status == .warning)
            Text("Enable System Audio for Notion")
                .font(.headline)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            step(number: 1, text: "In the Screen Recording list, scroll to the bottom")
            step(number: 2, text: "Find \"System Audio Recording Only\"")
            step(number: 3, text: "Toggle it ON for Notion")
            step(number: 4, text: "Click \"Done — Revert Now\" or wait for auto-revert")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func step(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
        }
    }

    private var countdown: some View {
        Text(viewModel.countdownText)
            .font(.system(size: 48, weight: .bold, design: .monospaced))
            .foregroundStyle(viewModel.status == .warning ? .red : .primary)
            .contentTransition(.numericText())
            .animation(.default, value: viewModel.secondsRemaining)
    }

    private var statusText: some View {
        Group {
            switch viewModel.status {
            case .active:
                Text("Admin rights active — complete the steps above")
            case .warning:
                Text("⚠️ Reverting soon — finish up!")
                    .foregroundStyle(.red)
            case .reverting:
                Text("Reverting admin rights…")
            case .done:
                Text("Done — admin rights removed.")
                    .foregroundStyle(.green)
            case .error:
                EmptyView()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var doneButton: some View {
        Button(action: { viewModel.doneEarly() }) {
            Text("Done — Revert Now")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .keyboardShortcut(.return, modifiers: [])
        .disabled(viewModel.status == .reverting || viewModel.status == .done)
    }
}
