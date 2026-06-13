import Foundation
import AppKit

@MainActor
final class EnablerViewModel: ObservableObject {

    @Published var secondsRemaining = 120
    @Published var status: Status = .active
    @Published var errorMessage: String?

    private var timer: Timer?

    enum Status {
        case active
        case warning
        case reverting
        case done
        case error
    }

    func start() {
        do {
            try ElevationManager.elevate()
        } catch {
            errorMessage = "Failed to elevate privileges: \(error)\n\nMake sure the sudoers rule is staged on this Mac."
            status = .error
            return
        }

        SystemSettingsLauncher.openScreenRecording()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func doneEarly() {
        timer?.invalidate()
        timer = nil
        revertAndQuit()
    }

    private func tick() {
        secondsRemaining -= 1

        if secondsRemaining <= 30 && status == .active {
            status = .warning
        }

        if secondsRemaining <= 0 {
            timer?.invalidate()
            timer = nil
            revertAndQuit()
        }
    }

    private func revertAndQuit() {
        status = .reverting
        safeRevert()
        status = .done
        LockFile.release()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    func safeRevert() {
        guard ElevationManager.isAdmin() else { return }
        do {
            try ElevationManager.revert()
        } catch {
            NSLog("CRITICAL: NotionAudioEnabler failed to revert admin: %@", "\(error)")
            errorMessage = "Could not remove admin rights automatically.\n\nError: \(error)\n\nPlease contact IT to have your account reverted to standard."
            status = .error
        }
    }

    var countdownText: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }
}
