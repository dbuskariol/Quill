import AppKit
import Observation
import ServiceManagement

@MainActor @Observable final class AppPreferences {
    var showMenuBar: Bool { didSet { defaults.set(showMenuBar, forKey: "showMenuBar"); enforceReachability() } }
    var showDock: Bool { didSet { defaults.set(showDock, forKey: "showDock"); enforceReachability(); applyActivationPolicy() } }
    var quitWhenLastWindowCloses: Bool { didSet { defaults.set(quitWhenLastWindowCloses, forKey: "quitWhenLastWindowCloses") } }
    private(set) var loginStatus: SMAppService.Status = .notRegistered
    var loginError: String?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showMenuBar = defaults.object(forKey: "showMenuBar") as? Bool ?? true
        showDock = defaults.object(forKey: "showDock") as? Bool ?? true
        quitWhenLastWindowCloses = defaults.bool(forKey: "quitWhenLastWindowCloses")
        if !showMenuBar && !showDock { showDock = true }
        refreshLoginStatus()
    }
    private func enforceReachability() {
        if !showMenuBar && !showDock { showDock = true }
    }
    func applyActivationPolicy() { NSApp.setActivationPolicy(showDock ? .regular : .accessory) }
    func refreshLoginStatus() { loginStatus = SMAppService.mainApp.status }
    func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { loginError = error.localizedDescription }
        refreshLoginStatus()
    }
}
