// SyncSettingsView.swift — Sync backend settings

import SwiftUI
import SwiftData
import BibleCore

/**
 Configures the active sync backend and surfaces backend-specific settings.

 The screen now acts as the entry point for both the existing CloudKit implementation and the
 in-progress NextCloud/WebDAV path. It preserves the current iCloud toggle/status flow while also
 allowing Android-compatible WebDAV credentials to be edited and connection-tested without changing
 the active CloudKit runtime mid-session.

 Data dependencies:
 - `SyncService` provides the effective iCloud sync mode, account description, runtime state, and
   last known sync timestamp
 - SwiftData's environment `modelContext` provides access to `SettingsStore` through
   `RemoteSyncSettingsStore`
 - localized strings provide backend labels, field titles, status text, and warnings

 Side effects:
 - changing the selected backend persists `sync_adapter` through `RemoteSyncSettingsStore`
 - editing WebDAV credentials updates local state and can be persisted to SwiftData + Keychain
 - testing a NextCloud/WebDAV connection builds a transient `WebDAVClient` and performs a network
   request against the configured server
 - toggling iCloud sync calls back into `SyncService` and can persist a restart-required sync mode
 - disabling iCloud sync first presents a confirmation dialog before mutating the service state
 */
public struct SyncSettingsView: View {
    /// Shared CloudKit sync service injected from the app environment.
    @Environment(SyncService.self) private var syncService

    /// SwiftData context used to materialize the local settings store.
    @Environment(\.modelContext) private var modelContext

    /// Whether the destructive disable-sync confirmation dialog is presented.
    @State private var showDisableConfirmation = false

    /// Whether the restart-required informational alert is presented.
    @State private var showRestartAlert = false

    /// Currently selected sync backend shown in the backend picker.
    @State private var selectedBackend: RemoteSyncBackend = .iCloud

    /// User-entered or persisted NextCloud/WebDAV server root URL.
    @State private var serverURL = ""

    /// User-entered or persisted NextCloud/WebDAV username.
    @State private var username = ""

    /// User-entered or persisted NextCloud/WebDAV password.
    @State private var password = ""

    /// User-entered or persisted optional sync folder path.
    @State private var folderPath = ""

    /// Guards one-time loading of persisted backend settings into local view state.
    @State private var hasLoadedSettings = false

    /// Whether a NextCloud/WebDAV connection test is currently in flight.
    @State private var isTestingConnection = false

    /// Latest result from the manual NextCloud/WebDAV connection test, if any.
    @State private var remoteConnectionStatus: RemoteConnectionStatus?

    /**
     Represents the last manual WebDAV connection-test result shown in the status section.

     The enum is view-local because it only drives transient UI feedback and is never persisted.
     */
    private enum RemoteConnectionStatus: Equatable {
        /// The most recent connection test completed successfully.
        case success

        /// The most recent connection test failed with a human-readable message.
        case failure(String)
    }

    /**
     Creates the sync settings screen with environment-provided sync services and settings storage.
     */
    public init() {}

    /**
     Builds backend selection, iCloud controls, and NextCloud/WebDAV configuration sections.
     */
    public var body: some View {
        Form {
            backendSection

            if selectedBackend == .iCloud {
                iCloudSections
            } else if selectedBackend == .nextCloud {
                nextCloudSections
            }
        }
        .navigationTitle(String(localized: "sync_adapter"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadPersistedSettingsIfNeeded()
        }
        .onDisappear {
            persistRemoteSettings()
        }
        .onChange(of: selectedBackend) { _, newValue in
            remoteSettingsStore.selectedBackend = newValue
            remoteConnectionStatus = nil
        }
        .confirmationDialog(
            String(localized: "disable_sync_title"),
            isPresented: $showDisableConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "disable_sync"), role: .destructive) {
                syncService.toggleSync()
                showRestartAlert = true
            }
        } message: {
            Text(String(localized: "disable_sync_warning"))
        }
        .alert(String(localized: "restart_required"), isPresented: $showRestartAlert) {
            Button(String(localized: "ok")) {}
        } message: {
            Text(String(localized: "restart_to_apply_sync"))
        }
    }

    /**
     Backend selection section shared by all sync modes.
     */
    private var backendSection: some View {
        Section {
            Picker(String(localized: "sync_adapter"), selection: $selectedBackend) {
                Text(String(localized: "icloud_sync"))
                    .tag(RemoteSyncBackend.iCloud)
                Text(String(localized: "adapters_next_cloud"))
                    .tag(RemoteSyncBackend.nextCloud)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "prefs_sync_introduction_summary1"))
                Text(String(format: String(localized: "sync_adapter_summary"), selectedBackendTitle))
            }
        }
    }

    /**
     Groups the existing CloudKit-only sections so they can be hidden when another backend is
     selected.
     */
    private var iCloudSections: some View {
        Group {
            Section {
                Toggle(String(localized: "icloud_sync_enabled"), isOn: Binding(
                    get: { syncService.isEnabled },
                    set: { newValue in
                        if !newValue {
                            showDisableConfirmation = true
                        } else {
                            syncService.toggleSync()
                            showRestartAlert = true
                        }
                    }
                ))
                .disabled(syncService.requiresRestart)
                Text(String(localized: "icloud_sync_description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "icloud_sync"))
            }

            Section {
                HStack {
                    Text(String(localized: "status"))
                    Spacer()
                    iCloudStatusView
                }

                if syncService.isEnabled && !syncService.requiresRestart {
                    HStack {
                        Text(String(localized: "icloud_account"))
                        Spacer()
                        Text(accountText)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(String(localized: "last_sync"))
                        Spacer()
                        Text(lastSyncText)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(String(localized: "sync_status"))
            }

            if syncService.isEnabled && !syncService.requiresRestart {
                Section {
                    Text(String(localized: "sync_what_syncs"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(String(localized: "sync_data_included"))
                }
            }
        }
    }

    /**
     Groups NextCloud/WebDAV credential editing and connection-testing UI.
     */
    private var nextCloudSections: some View {
        Group {
            Section {
                TextField(String(localized: "auth_server_uri"), text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textContentType(.URL)
                    #endif

                TextField(String(localized: "auth_username"), text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textContentType(.username)
                    #endif

                SecureField(String(localized: "auth_password"), text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textContentType(.password)
                    #endif

                TextField(String(localized: "auth_folder_path"), text: $folderPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text(String(localized: "adapters_next_cloud"))
            } footer: {
                Text(String(localized: "auth_folder_path_summary"))
            }

            Section {
                Button(String(localized: "test_connection")) {
                    Task {
                        await testRemoteConnection()
                    }
                }
                .disabled(isTestingConnection)

                HStack(alignment: .top) {
                    Text(String(localized: "status"))
                    Spacer()
                    remoteStatusView
                }
            } header: {
                Text(String(localized: "sync_status"))
            }
        }
    }

    /**
     Builds the trailing status label for the current iCloud runtime state.
     */
    @ViewBuilder
    private var iCloudStatusView: some View {
        switch syncService.state {
        case .disabled:
            SwiftUI.Label(String(localized: "sync_disabled"), systemImage: "icloud.slash")
                .foregroundStyle(.secondary)
        case .noAccount:
            SwiftUI.Label(String(localized: "no_icloud_account"), systemImage: "person.crop.circle.badge.xmark")
                .foregroundStyle(.red)
        case .idle:
            SwiftUI.Label(String(localized: "sync_active"), systemImage: "checkmark.icloud")
                .foregroundStyle(.green)
        case .syncing:
            SwiftUI.Label(String(localized: "syncing"), systemImage: "arrow.triangle.2.circlepath.icloud")
                .foregroundStyle(.blue)
        case .pendingRestart:
            SwiftUI.Label(String(localized: "restart_to_apply_sync"), systemImage: "arrow.clockwise.icloud")
                .foregroundStyle(.orange)
        case .error(let msg):
            SwiftUI.Label(msg, systemImage: "exclamationmark.icloud")
                .foregroundStyle(.orange)
        }
    }

    /**
     Builds the trailing connection-test state for the NextCloud/WebDAV section.
     */
    @ViewBuilder
    private var remoteStatusView: some View {
        if isTestingConnection {
            HStack(spacing: 8) {
                ProgressView()
                Text(String(localized: "loading"))
                    .foregroundStyle(.secondary)
            }
        } else if let remoteConnectionStatus {
            switch remoteConnectionStatus {
            case .success:
                SwiftUI.Label(String(localized: "ok"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failure(let message):
                SwiftUI.Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.trailing)
            }
        } else {
            Text("—")
                .foregroundStyle(.secondary)
        }
    }

    /**
     Human-readable backend name used in the backend summary footer.

     Failure modes:
     - `.googleDrive` falls back to the Android display name even though that backend is not yet
       exposed in the picker on iOS
     */
    private var selectedBackendTitle: String {
        switch selectedBackend {
        case .iCloud:
            return String(localized: "icloud_sync")
        case .nextCloud:
            return String(localized: "adapters_next_cloud")
        case .googleDrive:
            return String(localized: "adapters_google_drive")
        }
    }

    /**
     Store wrapper used to read and write local remote-sync configuration.

     Side effects:
     - each access materializes a fresh `SettingsStore` and `RemoteSyncSettingsStore` against the
       current `modelContext`
     */
    private var remoteSettingsStore: RemoteSyncSettingsStore {
        RemoteSyncSettingsStore(settingsStore: SettingsStore(modelContext: modelContext))
    }

    /**
     Loads persisted backend and NextCloud/WebDAV settings into local view state exactly once.

     Side effects:
     - reads backend selection from SwiftData-backed local settings
     - reads WebDAV password from Keychain through `RemoteSyncSettingsStore`
     - mutates view state for the picker and credential fields

     Failure modes:
     - if a not-yet-supported backend such as `.googleDrive` was previously stored, the view falls
       back to `.iCloud` for presentation without deleting the persisted value until the user makes
       a new selection
     */
    private func loadPersistedSettingsIfNeeded() {
        guard !hasLoadedSettings else {
            return
        }

        let persistedBackend = remoteSettingsStore.selectedBackend
        switch persistedBackend {
        case .iCloud, .nextCloud:
            selectedBackend = persistedBackend
        case .googleDrive:
            selectedBackend = .iCloud
        }

        if let configuration = remoteSettingsStore.loadWebDAVConfiguration() {
            serverURL = configuration.serverURL
            username = configuration.username
            folderPath = configuration.folderPath ?? ""
        }
        password = remoteSettingsStore.webDAVPassword() ?? ""
        hasLoadedSettings = true
    }

    /**
     Persists the currently edited remote-sync state.

     Side effects:
     - writes the selected backend to `sync_adapter`
     - writes WebDAV server, username, folder path, and password through `RemoteSyncSettingsStore`
       into SwiftData and Keychain

     Failure modes:
     - persistence errors from Keychain writes are swallowed because this view should not crash on
       local settings save failures; the user still receives connection-test feedback separately
     */
    private func persistRemoteSettings() {
        let store = remoteSettingsStore
        store.selectedBackend = selectedBackend
        try? store.saveWebDAVConfiguration(
            WebDAVSyncConfiguration(
                serverURL: serverURL,
                username: username,
                folderPath: normalizedFolderPath
            ),
            password: password
        )
    }

    /**
     Runs a manual NextCloud/WebDAV connection test against the current form values.

     The test uses the same Android-compatible server-root semantics as the persisted config:
     `WebDAVSyncConfiguration` resolves the stored server root into a DAV endpoint before issuing a
     root-level `PROPFIND`.

     Side effects:
     - persists the current form values before testing so later sync flows use the same settings
     - performs a network request using `WebDAVClient.testConnection()`
     - updates transient view state for progress and status feedback

     Failure modes:
     - invalid local URL input is converted into the Android-derived `invalid_url_message`
     - transport or authentication failures surface the underlying localized error when available,
       otherwise they fall back to `sign_in_failed`
     */
    @MainActor
    private func testRemoteConnection() async {
        isTestingConnection = true
        remoteConnectionStatus = nil
        persistRemoteSettings()
        defer { isTestingConnection = false }

        do {
            let configuration = WebDAVSyncConfiguration(
                serverURL: serverURL,
                username: username,
                folderPath: normalizedFolderPath
            )
            let client = try configuration.makeWebDAVClient(password: password)
            _ = try await client.testConnection()
            remoteConnectionStatus = .success
        } catch WebDAVClientError.invalidURL {
            remoteConnectionStatus = .failure(String(localized: "invalid_url_message"))
        } catch {
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            remoteConnectionStatus = .failure(
                message.isEmpty ? String(localized: "sign_in_failed") : message
            )
        }
    }

    /**
     Normalizes the optional folder path before persistence and transport use.

     - Returns: Trimmed folder path, or `nil` when the user left the field empty.
     - Side Effects: none.
     - Failure modes: This helper cannot fail.
     */
    private var normalizedFolderPath: String? {
        let trimmed = folderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /**
     Human-readable iCloud account description shown in the iCloud status section.
     */
    private var accountText: String {
        switch syncService.state {
        case .noAccount:
            return String(localized: "no_icloud_account")
        default:
            return syncService.accountDescription ?? "—"
        }
    }

    /**
     Relative last-sync timestamp shown in the iCloud status section.

     Failure modes:
     - returns an em dash placeholder when no sync timestamp has been recorded yet
     */
    private var lastSyncText: String {
        guard let date = syncService.lastSyncDate else {
            return "—"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
