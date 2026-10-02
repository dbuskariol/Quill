import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    @Bindable var preferences: AppPreferences
    let expansion: ExpansionController
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var policy = ExpansionPolicy()
    @State private var resume = true
    @State private var launchAtLogin = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(step == 0 ? "Set up Quill" : step == 1 ? "Choose how expansion works" : "You’re ready")
                    .font(.title2).fontWeight(.semibold)
                Text(step == 0 ? "Two permissions let Quill expand text in other apps. Your library and copying work without them."
                     : step == 1 ? "Choose your applications and when Quill should run."
                     : "Type a saved abbreviation in a supported editor to try expansion. Press ⌘K to find snippets, macros and actions.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if step == 0 {
                ExpansionPermissionControls(expansion: expansion)
            } else if step == 1 {
                Picker("Expand in", selection: $policy.applicationScope) {
                    ForEach(ExpansionPolicy.ApplicationScope.allCases) { Text($0.title).tag($0) }
                }
                if policy.applicationScope == .selected {
                    ExpansionApplicationList(applications: policy.selectedApplications, emptyMessage: "Choose at least one application.", addLabel: "Add Application…") {
                        policy.add($0, excluding: false)
                    } remove: { ids in policy.selectedApplications.removeAll { ids.contains($0.id) } }
                }
                Text("Password fields and excluded applications never expand. Change exclusions in Settings → Expansion.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Enable expansion every time Quill opens", isOn: $resume)
                Toggle("Launch Quill at login", isOn: $launchAtLogin)
                Text(preferences.quitWhenLastWindowCloses ? "Closing Quill’s last window quits it. Change this in General settings if you want to keep expansion running." : "Closing the library keeps Quill running. You can pause expansion at any time.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("Expansion enabled", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Text(resume ? "Expansion will resume when you reopen Quill." : "Expansion stays enabled until you quit Quill.")
                if launchAtLogin, preferences.loginStatus == .requiresApproval {
                    Text("Approve Quill in macOS Login Items to launch at login.").font(.callout)
                    Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                }
                if let loginError = preferences.loginError { Text(loginError).foregroundStyle(.red) }
            }
            if let error { Text(error).foregroundStyle(.red).font(.callout).fixedSize(horizontal: false, vertical: true) }
            Divider()
            HStack {
                if step < 2 {
                    Button("Set Up Later") { preferences.setupDisposition = .deferred; dismiss() }.keyboardShortcut(.cancelAction)
                    if step == 1 { Button("Back") { step = 0; error = nil } }
                }
                Spacer()
                Button(step == 0 ? "Continue" : step == 1 ? "Enable Expansion" : "Done", action: advance)
                    .keyboardShortcut(.defaultAction)
                    .disabled(step == 0 ? !expansion.accessibilityGranted || !expansion.inputGranted : step == 1 && !policy.hasApplicationScope)
            }
        }
        .padding(20).frame(width: 460)
        .interactiveDismissDisabled()
        .onExitCommand { preferences.setupDisposition = step == 2 ? .completed : .deferred; dismiss() }
        .onAppear {
            policy = expansion.policy
            if !policy.hasApplicationScope { policy.applicationScope = .all }
            resume = expansion.duration == .always || !expansion.isEnabled
            launchAtLogin = preferences.loginStatus == .enabled || preferences.loginStatus == .requiresApproval
        }
    }
    private func advance() {
        error = nil
        if step == 0 { step = 1 }
        else if step == 1 {
            expansion.policy = policy
            expansion.duration = resume ? .always : .untilQuit
            expansion.enable()
            guard expansion.isEnabled else { error = expansion.status; return }
            if launchAtLogin && preferences.loginStatus != .enabled && preferences.loginStatus != .requiresApproval { preferences.setLaunchAtLogin(true) }
            else if !launchAtLogin && (preferences.loginStatus == .enabled || preferences.loginStatus == .requiresApproval) { preferences.setLaunchAtLogin(false) }
            step = 2
        } else { preferences.setupDisposition = .completed; dismiss() }
    }
}
