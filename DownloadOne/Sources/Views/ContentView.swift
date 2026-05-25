import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DownloadViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .input:
                InputView(viewModel: viewModel)

            case .authenticating, .downloading, .writing:
                WorkingView(message: viewModel.statusMessage)

            case .success(let name, let path):
                ResultView(
                    isSuccess: true,
                    title: name,
                    detail: path,
                    outputURL: viewModel.resultOutputURL,
                    onDone: { NSApplication.shared.terminate(nil) }
                )

            case .failure(let message):
                ResultView(
                    isSuccess: false,
                    title: "Error",
                    detail: message,
                    outputURL: nil,
                    onDone: { NSApplication.shared.terminate(nil) }
                )
            }
        }
        .frame(width: 420, height: 260)
    }
}
