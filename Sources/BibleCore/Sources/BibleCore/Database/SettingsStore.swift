// SettingsStore.swift — App-level settings persistence

import Foundation
import SwiftData

/// A key-value setting stored in the database.
@Model
public final class Setting {
    @Attribute(.unique) public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// Manages app-level key-value settings.
@Observable
public final class SettingsStore {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - String

    public func getString(_ key: String) -> String? {
        fetchSetting(key)?.value
    }

    public func setString(_ key: String, value: String) {
        upsert(key: key, value: value)
    }

    // MARK: - Bool

    public func getBool(_ key: String, default defaultValue: Bool = false) -> Bool {
        guard let str = getString(key) else { return defaultValue }
        return str == "true"
    }

    public func setBool(_ key: String, value: Bool) {
        upsert(key: key, value: value ? "true" : "false")
    }

    // MARK: - Int

    public func getInt(_ key: String, default defaultValue: Int = 0) -> Int {
        guard let str = getString(key) else { return defaultValue }
        return Int(str) ?? defaultValue
    }

    public func setInt(_ key: String, value: Int) {
        upsert(key: key, value: String(value))
    }

    // MARK: - Double

    public func getDouble(_ key: String, default defaultValue: Double = 0.0) -> Double {
        guard let str = getString(key) else { return defaultValue }
        return Double(str) ?? defaultValue
    }

    public func setDouble(_ key: String, value: Double) {
        upsert(key: key, value: String(value))
    }

    // MARK: - Active Workspace

    /// Key for the currently active workspace ID.
    public static let activeWorkspaceKey = "active_workspace_id"

    public var activeWorkspaceId: UUID? {
        get { getString(SettingsStore.activeWorkspaceKey).flatMap(UUID.init) }
        set { setString(SettingsStore.activeWorkspaceKey, value: newValue?.uuidString ?? "") }
    }

    // MARK: - Private

    private func fetchSetting(_ key: String) -> Setting? {
        var descriptor = FetchDescriptor<Setting>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func upsert(key: String, value: String) {
        if let existing = fetchSetting(key) {
            existing.value = value
        } else {
            modelContext.insert(Setting(key: key, value: value))
        }
        try? modelContext.save()
    }
}

// MARK: - AppPreferenceKey Accessors

public extension SettingsStore {
    func getString(_ key: AppPreferenceKey) -> String {
        if let stored = readStoredValue(for: key) {
            return stored
        }
        return AppPreferenceRegistry.stringDefault(for: key) ?? ""
    }

    func setString(_ key: AppPreferenceKey, value: String) {
        let definition = AppPreferenceRegistry.definition(for: key)
        switch definition.storage {
        case .swiftData:
            setString(key.rawValue, value: value)
        case .userDefaults:
            UserDefaults.standard.set(value, forKey: key.rawValue)
        case .action:
            break
        }
    }

    func getBool(_ key: AppPreferenceKey) -> Bool {
        let fallback = AppPreferenceRegistry.boolDefault(for: key) ?? false
        let definition = AppPreferenceRegistry.definition(for: key)

        switch definition.storage {
        case .swiftData:
            guard let raw = getString(key.rawValue) else { return fallback }
            return raw == "true"
        case .userDefaults:
            if let boolValue = UserDefaults.standard.object(forKey: key.rawValue) as? Bool {
                return boolValue
            }
            if let raw = UserDefaults.standard.string(forKey: key.rawValue) {
                return raw == "true"
            }
            return fallback
        case .action:
            return fallback
        }
    }

    func setBool(_ key: AppPreferenceKey, value: Bool) {
        let definition = AppPreferenceRegistry.definition(for: key)
        switch definition.storage {
        case .swiftData:
            setString(key.rawValue, value: value ? "true" : "false")
        case .userDefaults:
            UserDefaults.standard.set(value, forKey: key.rawValue)
        case .action:
            break
        }
    }

    func getInt(_ key: AppPreferenceKey) -> Int {
        let fallback = AppPreferenceRegistry.intDefault(for: key) ?? 0
        let definition = AppPreferenceRegistry.definition(for: key)

        switch definition.storage {
        case .swiftData:
            guard let raw = getString(key.rawValue) else { return fallback }
            return Int(raw) ?? fallback
        case .userDefaults:
            let object = UserDefaults.standard.object(forKey: key.rawValue)
            if let intValue = object as? Int {
                return intValue
            }
            if let stringValue = object as? String {
                return Int(stringValue) ?? fallback
            }
            return fallback
        case .action:
            return fallback
        }
    }

    func setInt(_ key: AppPreferenceKey, value: Int) {
        let definition = AppPreferenceRegistry.definition(for: key)
        switch definition.storage {
        case .swiftData:
            setString(key.rawValue, value: String(value))
        case .userDefaults:
            UserDefaults.standard.set(value, forKey: key.rawValue)
        case .action:
            break
        }
    }

    func getStringSet(_ key: AppPreferenceKey) -> [String] {
        let definition = AppPreferenceRegistry.definition(for: key)
        switch definition.storage {
        case .swiftData:
            let raw = getString(key.rawValue)
            return AppPreferenceRegistry.decodeCSVSet(raw)
        case .userDefaults:
            if let values = UserDefaults.standard.array(forKey: key.rawValue) as? [String] {
                return values
            }
            let raw = UserDefaults.standard.string(forKey: key.rawValue)
            return AppPreferenceRegistry.decodeCSVSet(raw)
        case .action:
            return []
        }
    }

    func setStringSet(_ key: AppPreferenceKey, values: [String]) {
        let encoded = AppPreferenceRegistry.encodeCSVSet(values)
        let definition = AppPreferenceRegistry.definition(for: key)
        switch definition.storage {
        case .swiftData:
            setString(key.rawValue, value: encoded)
        case .userDefaults:
            UserDefaults.standard.set(values.sorted(), forKey: key.rawValue)
        case .action:
            break
        }
    }

    private func readStoredValue(for key: AppPreferenceKey) -> String? {
        let definition = AppPreferenceRegistry.definition(for: key)
        switch definition.storage {
        case .swiftData:
            return getString(key.rawValue)
        case .userDefaults:
            let object = UserDefaults.standard.object(forKey: key.rawValue)
            if let boolValue = object as? Bool {
                return boolValue ? "true" : "false"
            }
            if let intValue = object as? Int {
                return String(intValue)
            }
            return object as? String
        case .action:
            return nil
        }
    }
}
