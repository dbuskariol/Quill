import Foundation
import Observation
import Sparkle

struct UpdateConfiguration: Equatable {
    let feed: URL
    let publicKey: String
    static func validated(feed: String?, publicKey: String?) -> Self? {
        guard let feed, let url = URL(string: feed), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil,
              let publicKey, let key = Data(base64Encoded: publicKey), key.count == 32 else { return nil }
        return Self(feed: url, publicKey: publicKey)
    }
}

@MainActor @Observable final class SoftwareUpdateController: NSObject, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?
    private var checkObservation: NSKeyValueObservation?
    private(set) var canCheck = false
    private(set) var automaticallyChecks = false
    private(set) var automaticallyDownloads = false
    private(set) var status = "Updates unavailable: a Quill HTTPS feed and public signing key have not been configured."
    var isConfigured: Bool { controller != nil }
    var version: String {
        "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"))"
    }
    override init() {
        super.init()
        guard UpdateConfiguration.validated(feed: Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
                                            publicKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String) != nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        do { try controller.updater.start() }
        catch { status = "Updater could not start: \(error.localizedDescription)"; return }
        self.controller = controller
        status = "Ready to check for signed Quill updates."
        refresh()
        checkObservation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    private func refresh() {
        guard let updater = controller?.updater else { return }
        canCheck = updater.canCheckForUpdates
        automaticallyChecks = updater.automaticallyChecksForUpdates
        automaticallyDownloads = updater.automaticallyDownloadsUpdates
    }
    func setAutomaticChecks(_ enabled: Bool) { controller?.updater.automaticallyChecksForUpdates = enabled; refresh() }
    func setAutomaticDownloads(_ enabled: Bool) { controller?.updater.automaticallyDownloadsUpdates = enabled; refresh() }
    func checkNow() {
        guard canCheck else { return }
        status = "Checking for updates…"
        controller?.checkForUpdates(nil)
        refresh()
    }
    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in self?.status = "Update failed: \(message)"; self?.refresh() }
    }
    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        let message = error?.localizedDescription
        Task { @MainActor [weak self] in
            self?.status = message.map { "Update check ended: \($0)" } ?? "Update check completed."
            self?.refresh()
        }
    }
}
