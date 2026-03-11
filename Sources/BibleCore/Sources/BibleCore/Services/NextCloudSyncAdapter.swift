// NextCloudSyncAdapter.swift — Android-aligned WebDAV adapter for remote sync

import Foundation

/**
 Represents one remote file or folder exposed by a non-CloudKit sync backend.

 The shape mirrors Android's `CloudFile` contract closely enough for a future patch-sync engine to
 reuse Android's folder, patch, and secret-marker semantics without translating between unrelated
 models.

 `timestamp` intentionally carries a single millisecond value rather than separate creation and
 modification fields. WebDAV responses do not expose a portable creation timestamp, so the
 NextCloud adapter populates this field from DAV `getlastmodified` when available. That preserves a
 stable ordering field for incremental patch discovery even though the source property differs from
 Android's OwnCloud library.
 */
public struct RemoteSyncFile: Sendable, Equatable {
    /// Backend-specific identifier used for later `GET`, `PUT`, `DELETE`, and folder listing calls.
    public let id: String

    /// Human-readable file or folder name.
    public let name: String

    /// File size in bytes. Folders report `0`.
    public let size: Int64

    /// Best-available backend timestamp expressed as milliseconds since 1970.
    public let timestamp: Int64

    /// Parent folder identifier.
    public let parentID: String

    /// Android-compatible MIME type string. Folders use `DIR`.
    public let mimeType: String

    /**
     Creates one remote file descriptor.

     - Parameters:
       - id: Backend-specific identifier used for future operations.
       - name: Human-readable file or folder name.
       - size: File size in bytes.
       - timestamp: Best-available backend timestamp in milliseconds since 1970.
       - parentID: Parent folder identifier.
       - mimeType: Android-compatible MIME type string.
     - Side effects: none.
     - Failure modes: This initializer cannot fail.
     */
    public init(
        id: String,
        name: String,
        size: Int64,
        timestamp: Int64,
        parentID: String,
        mimeType: String
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.timestamp = timestamp
        self.parentID = parentID
        self.mimeType = mimeType
    }
}

/**
 Android-aligned NextCloud/WebDAV adapter built on top of `WebDAVClient`.

 This actor is the iOS equivalent of Android's `NextCloudAdapter`. It is intentionally limited to
 transport-facing responsibilities:
 - normalize the optional base sync folder path
 - map DAV resources into Android-shaped `RemoteSyncFile` values
 - create folder paths with Android's `createFullPath` behavior
 - manage the secret marker file used to prove sync-folder ownership

 The actor does not implement patch numbering, database diff generation, or local sync-state
 persistence. Those remain higher-level responsibilities, just as Android keeps them in `CloudSync`
 and the sync DAO layer rather than inside the adapter itself.

 Data dependencies:
 - `WebDAVSyncConfiguration` supplies the resolved DAV root, username, and optional base folder path
 - `WebDAVClient` performs authenticated transport operations

 Side effects:
 - `verifyConnection`, `listFiles`, `get`, `download`, and `isSyncFolderKnown` perform remote DAV requests
 - `createNewFolder` and base-folder initialization issue `MKCOL` requests
 - `upload` and `makeSyncFolderKnown` upload remote file payloads with HTTP `PUT`
 - `delete` removes remote paths with HTTP `DELETE`

 Concurrency:
 - this type is an actor so repeated calls can safely share the lazily initialized base-folder cache
   without external locking
 */
public actor NextCloudSyncAdapter {
    /// Android-compatible MIME type used for folders in `RemoteSyncFile` payloads.
    public static let folderMimeType = "DIR"

    /// MIME type Android uses for uploaded patch archives and marker files.
    public static let gzipMimeType = "application/gzip"

    private let client: WebDAVClient
    private let davBasePath: String
    private let baseFolderPath: String?
    private var cachedBaseFolderID: String?

    /**
     Creates a NextCloud/WebDAV adapter from persisted Android-compatible settings.

     - Parameters:
       - configuration: Persisted WebDAV settings including server root, username, and optional sync folder path.
       - password: Password or app password used for HTTP Basic authentication.
       - session: URL session used for transport. Tests can inject a mocked session.
     - Side effects:
       - resolves the configured server root into a DAV endpoint
       - creates a transport client that will be reused by later actor calls
     - Failure modes:
       - throws `WebDAVClientError.invalidURL` when the configured server root cannot be normalized into a DAV endpoint
     */
    public init(
        configuration: WebDAVSyncConfiguration,
        password: String,
        session: URLSession = .shared
    ) throws {
        let davBaseURL = try configuration.resolvedDAVBaseURL()
        self.client = WebDAVClient(
            baseURL: davBaseURL,
            username: configuration.username,
            password: password,
            session: session
        )
        self.davBasePath = Self.normalizedIdentifier(davBaseURL.path)
        self.baseFolderPath = Self.normalizedOptionalIdentifier(configuration.folderPath)
        self.cachedBaseFolderID = nil
    }

    /**
     Verifies connectivity and credentials by issuing a root-level DAV `PROPFIND`.

     - Side effects: performs a remote DAV request.
     - Failure modes:
       - rethrows transport and authentication failures emitted by `WebDAVClient.testConnection()`
     */
    public func verifyConnection() async throws {
        _ = try await client.testConnection()
    }

    /**
     Loads metadata for one remote file or folder.

     - Parameter id: Backend-specific identifier returned by prior adapter calls.
     - Returns: One `RemoteSyncFile` for the requested path.
     - Side effects: performs a depth-0 DAV `PROPFIND`.
     - Failure modes:
       - rethrows DAV transport failures, including 404-style missing-resource responses
       - throws `WebDAVClientError.invalidResponse` when the server returns no matching resource payload
     */
    public func get(id: String) async throws -> RemoteSyncFile {
        let normalizedID = Self.normalizedIdentifier(id)
        let files = try await client.propfind(path: requestPath(for: normalizedID), depth: 0)
        guard let file = files.first(where: { identifier(forServerPath: $0.path) == normalizedID }) ?? files.first else {
            throw WebDAVClientError.invalidResponse
        }
        return remoteSyncFile(from: file)
    }

    /**
     Lists files below one or more parent folders.

     When `modifiedAtLeast` is provided, the adapter mirrors Android's NextCloud behavior by using
     WebDAV `SEARCH` instead of a shallow `PROPFIND`, giving the future patch-sync engine a
     timestamp-filtered incremental listing path.

     - Parameters:
       - parentIDs: Parent folder identifiers to search under. `nil` defaults to the configured base folder or DAV root.
       - name: Optional exact filename filter.
       - mimeType: Optional Android-compatible MIME type filter. Folders use `DIR`.
       - modifiedAtLeast: Optional lower-bound timestamp for incremental listing.
     - Returns: Remote files that match the requested filters.
     - Side effects:
       - may create the configured base folder path on first use
       - performs one DAV `PROPFIND` or `SEARCH` per requested parent folder
     - Failure modes:
       - rethrows DAV transport failures from folder creation or listing requests
     */
    public func listFiles(
        parentIDs: [String]? = nil,
        name: String? = nil,
        mimeType: String? = nil,
        modifiedAtLeast: Date? = nil
    ) async throws -> [RemoteSyncFile] {
        let parents: [String]
        if let parentIDs {
            parents = parentIDs
        } else {
            parents = [try await defaultParentID()]
        }
        var collected: [RemoteSyncFile] = []

        for parentID in parents.map(Self.normalizedIdentifier) {
            let files: [WebDAVFile]
            if let modifiedAtLeast {
                files = try await client.search(
                    path: requestPath(for: parentID),
                    modifiedAfter: modifiedAtLeast
                )
            } else {
                files = try await client.propfind(path: requestPath(for: parentID), depth: 1)
            }

            let children = files
                .map(remoteSyncFile(from:))
                .filter { $0.id != parentID }
            collected.append(contentsOf: children)
        }

        return collected.filter { file in
            let nameMatches = name.map { file.name == $0 } ?? true
            let mimeMatches = mimeType.map { file.mimeType == $0 } ?? true
            return nameMatches && mimeMatches
        }
    }

    /**
     Lists direct child folders of the requested parent folder.

     - Parameter parentID: Parent folder identifier.
     - Returns: Child folders represented as `RemoteSyncFile` values with `DIR` MIME types.
     - Side effects: performs a DAV listing request.
     - Failure modes:
       - rethrows DAV transport failures from `listFiles(parentIDs:name:mimeType:modifiedAtLeast:)`
     */
    public func getFolders(parentID: String) async throws -> [RemoteSyncFile] {
        try await listFiles(parentIDs: [parentID], mimeType: Self.folderMimeType)
    }

    /**
     Downloads one remote file payload into memory.

     - Parameter id: Backend-specific file identifier.
     - Returns: Raw file payload bytes.
     - Side effects: performs an authenticated HTTP `GET`.
     - Failure modes:
       - rethrows DAV transport failures from `WebDAVClient.get(path:)`
     */
    public func download(id: String) async throws -> Data {
        try await client.get(path: requestPath(for: id))
    }

    /**
     Creates a remote folder, defaulting to the configured base sync folder or DAV root.

     - Parameters:
       - name: Folder name to create.
       - parentID: Optional parent folder identifier. `nil` uses the configured base sync folder or DAV root.
     - Returns: Metadata for the created folder using Android-compatible `DIR` MIME typing.
     - Side effects:
       - may create the configured base folder path on first use
       - issues DAV `MKCOL` requests for the new folder path
    - Failure modes:
       - rethrows DAV transport failures except that HTTP 405 is treated as "already exists" to match Android's `createFullPath` behavior
     */
    public func createNewFolder(name: String, parentID: String? = nil) async throws -> RemoteSyncFile {
        let resolvedParentID: String
        if let parentID {
            resolvedParentID = Self.normalizedIdentifier(parentID)
        } else {
            resolvedParentID = try await defaultParentID()
        }
        let folderID = Self.join(parent: resolvedParentID, child: name)
        try await ensureCollectionExists(id: folderID)
        return RemoteSyncFile(
            id: folderID,
            name: name,
            size: 0,
            timestamp: Self.currentTimestampMilliseconds(),
            parentID: resolvedParentID,
            mimeType: Self.folderMimeType
        )
    }

    /**
     Uploads a local file to the remote backend.

     - Parameters:
       - name: Destination file name.
       - fileURL: Local file URL whose contents will be uploaded.
       - parentID: Parent folder identifier.
       - contentType: MIME type sent with the DAV `PUT`. Defaults to Android's gzip patch type.
     - Returns: Metadata for the uploaded remote file.
     - Side effects:
       - reads the local file into memory
       - performs an authenticated DAV `PUT`
     - Failure modes:
       - rethrows filesystem read failures from `Data(contentsOf:)`
       - rethrows DAV transport failures from `WebDAVClient.put(path:data:contentType:)`
     */
    public func upload(
        name: String,
        fileURL: URL,
        parentID: String,
        contentType: String = NextCloudSyncAdapter.gzipMimeType
    ) async throws -> RemoteSyncFile {
        let resolvedParentID = Self.normalizedIdentifier(parentID)
        let fileData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let fileID = Self.join(parent: resolvedParentID, child: name)
        try await client.put(
            path: requestPath(for: fileID),
            data: fileData,
            contentType: contentType
        )
        return RemoteSyncFile(
            id: fileID,
            name: name,
            size: Int64(fileData.count),
            timestamp: Self.currentTimestampMilliseconds(),
            parentID: resolvedParentID,
            mimeType: contentType
        )
    }

    /**
     Deletes one remote file or folder.

     - Parameter id: Backend-specific identifier returned by prior adapter calls.
     - Side effects: performs an authenticated DAV `DELETE`.
     - Failure modes:
       - rethrows DAV transport failures from `WebDAVClient.delete(path:)`
     */
    public func delete(id: String) async throws {
        try await client.delete(path: requestPath(for: id))
    }

    /**
     Verifies whether a sync folder is still owned by this device using Android's secret-marker file.

     - Parameters:
       - syncFolderID: Global sync folder identifier.
       - secretFileName: Previously persisted secret marker filename.
     - Returns: `true` when the marker file still exists in the sync folder; otherwise `false`.
     - Side effects: performs a depth-0 DAV `PROPFIND` for the marker file.
     - Failure modes:
       - returns `false` for HTTP 404-style missing marker responses
       - rethrows all other DAV transport failures because they indicate connectivity or permission issues rather than a clean ownership miss
     */
    public func isSyncFolderKnown(syncFolderID: String, secretFileName: String) async throws -> Bool {
        let markerID = Self.join(parent: syncFolderID, child: secretFileName)
        do {
            _ = try await client.propfind(path: requestPath(for: markerID), depth: 0)
            return true
        } catch WebDAVClientError.unexpectedStatus(let statusCode) where statusCode == 404 {
            return false
        }
    }

    /**
     Uploads Android's secret marker file and returns the generated filename.

     - Parameters:
       - syncFolderID: Global sync folder identifier that should be marked as owned by this device.
       - deviceIdentifier: Stable device identifier used in the marker filename prefix.
     - Returns: Generated marker filename that callers can persist locally.
     - Side effects: performs an authenticated DAV `PUT` of an empty marker payload.
     - Failure modes:
       - rethrows DAV transport failures from `WebDAVClient.put(path:data:contentType:)`
     */
    public func makeSyncFolderKnown(syncFolderID: String, deviceIdentifier: String) async throws -> String {
        let secretFileName = "device-known-\(deviceIdentifier)-\(UUID().uuidString)"
        let markerID = Self.join(parent: syncFolderID, child: secretFileName)
        try await client.put(
            path: requestPath(for: markerID),
            data: Data(),
            contentType: Self.gzipMimeType
        )
        return secretFileName
    }

    private func defaultParentID() async throws -> String {
        if let ensuredBaseFolderID = try await ensuredBaseFolderID() {
            return ensuredBaseFolderID
        }
        return "/"
    }

    private func ensuredBaseFolderID() async throws -> String? {
        guard let baseFolderPath else {
            return nil
        }
        if let cachedBaseFolderID {
            return cachedBaseFolderID
        }
        try await ensureCollectionExists(id: baseFolderPath)
        cachedBaseFolderID = baseFolderPath
        return baseFolderPath
    }

    private func ensureCollectionExists(id: String) async throws {
        let normalizedID = Self.normalizedIdentifier(id)
        guard normalizedID != "/" else {
            return
        }

        var current = ""
        for component in normalizedID.split(separator: "/") {
            current += "/\(component)"
            do {
                try await client.mkcol(path: requestPath(for: current))
            } catch WebDAVClientError.unexpectedStatus(let statusCode) where statusCode == 405 {
                continue
            }
        }
    }

    private func remoteSyncFile(from file: WebDAVFile) -> RemoteSyncFile {
        let identifier = identifier(forServerPath: file.path)
        let normalizedID = Self.normalizedIdentifier(identifier)
        let parentID = Self.parentIdentifier(for: normalizedID)
        let fallbackName = normalizedID == "/" ? "/" : normalizedID.split(separator: "/").last.map(String.init) ?? "/"
        return RemoteSyncFile(
            id: normalizedID,
            name: file.displayName.isEmpty ? fallbackName : file.displayName,
            size: file.contentLength ?? 0,
            timestamp: Int64((file.lastModified?.timeIntervalSince1970 ?? 0) * 1000),
            parentID: parentID,
            mimeType: file.isDirectory ? Self.folderMimeType : (file.contentType ?? "application/octet-stream")
        )
    }

    private func requestPath(for identifier: String) -> String {
        let normalizedID = Self.normalizedIdentifier(identifier)
        if normalizedID == "/" {
            return ""
        }
        return String(normalizedID.dropFirst())
    }

    private func identifier(forServerPath serverPath: String) -> String {
        let normalizedServerPath = Self.normalizedIdentifier(serverPath)
        guard normalizedServerPath.hasPrefix(davBasePath) else {
            return normalizedServerPath
        }
        let suffix = String(normalizedServerPath.dropFirst(davBasePath.count))
        return suffix.isEmpty ? "/" : Self.normalizedIdentifier(suffix)
    }

    private static func normalizedOptionalIdentifier(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return nil
        }
        return normalizedIdentifier(trimmed)
    }

    private static func normalizedIdentifier(_ value: String) -> String {
        let components = value
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !components.isEmpty else {
            return "/"
        }
        return "/" + components.joined(separator: "/")
    }

    private static func parentIdentifier(for identifier: String) -> String {
        let normalized = normalizedIdentifier(identifier)
        guard normalized != "/" else {
            return "/"
        }
        let components = normalized.split(separator: "/")
        guard components.count > 1 else {
            return "/"
        }
        return "/" + components.dropLast().joined(separator: "/")
    }

    private static func join(parent: String, child: String) -> String {
        let normalizedParent = normalizedIdentifier(parent)
        let trimmedChild = child.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedChild.isEmpty else {
            return normalizedParent
        }
        return normalizedParent == "/" ? "/\(trimmedChild)" : "\(normalizedParent)/\(trimmedChild)"
    }

    private static func currentTimestampMilliseconds() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
