// WebDAVClient.swift — WebDAV transport foundation for cross-platform sync

import Foundation

/**
 Describes one file or collection returned by a WebDAV `PROPFIND` or `SEARCH` response.

 The payload intentionally preserves both the raw `href` reported by the server and a normalized
 `path` derived from that `href`. Sync layers can use the normalized path for follow-up `GET`,
 `PUT`, `MKCOL`, and `DELETE` operations without reparsing XML.
 */
public struct WebDAVFile: Sendable, Equatable {
    /// Raw WebDAV `href` value returned by the server, percent-decoded when possible.
    public let href: String

    /// Normalized URL path derived from `href`.
    public let path: String

    /// Human-readable display name for the resource.
    public let displayName: String

    /// Whether the resource is a directory/collection.
    public let isDirectory: Bool

    /// Optional content length reported by the server.
    public let contentLength: Int64?

    /// Optional MIME type reported by the server.
    public let contentType: String?

    /// Optional last-modified timestamp reported by the server.
    public let lastModified: Date?

    /**
     Creates one parsed WebDAV resource descriptor.

     - Parameters:
       - href: Raw `href` value from the server response.
       - path: Normalized URL path derived from `href`.
       - displayName: Human-readable file or folder name.
       - isDirectory: Whether the resource represents a collection.
       - contentLength: Optional byte size for file resources.
       - contentType: Optional MIME type.
       - lastModified: Optional last-modified timestamp.
     */
    public init(
        href: String,
        path: String,
        displayName: String,
        isDirectory: Bool,
        contentLength: Int64?,
        contentType: String?,
        lastModified: Date?
    ) {
        self.href = href
        self.path = path
        self.displayName = displayName
        self.isDirectory = isDirectory
        self.contentLength = contentLength
        self.contentType = contentType
        self.lastModified = lastModified
    }
}

/**
 Errors emitted by the WebDAV transport layer.
 */
public enum WebDAVClientError: Error, Equatable {
    /// The response was not an `HTTPURLResponse`.
    case invalidResponse

    /// The server returned an unexpected HTTP status code.
    case unexpectedStatus(Int)

    /// XML multistatus payload parsing failed.
    case invalidMultiStatusXML

    /// The WebDAV server URL could not be normalized into a valid request URL.
    case invalidURL
}

/**
 Parses WebDAV multistatus XML into strongly typed `WebDAVFile` values.

 The parser accepts both `PROPFIND` and `SEARCH` responses because both use the same DAV
 multistatus envelope. Namespace prefixes are ignored so the parser works with both `d:` and
 unprefixed element names.
 */
public enum WebDAVMultiStatusParser {
    /**
     Parses a WebDAV multistatus response body.

     - Parameter data: XML payload returned by a WebDAV `PROPFIND` or `SEARCH` request.
     - Returns: Parsed resources in the order returned by the server.

     Failure modes:
     - throws `WebDAVClientError.invalidMultiStatusXML` when the XML payload cannot be parsed
     */
    public static func parse(data: Data) throws -> [WebDAVFile] {
        let delegate = MultiStatusXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw WebDAVClientError.invalidMultiStatusXML
        }
        return delegate.files
    }
}

/**
 Minimal WebDAV client used by future non-CloudKit sync backends.

 This client focuses on transport and XML parsing only. It does not encode any Android patch-sync
 semantics on top of WebDAV; higher layers remain responsible for folder layout, patch numbering,
 and merge policy.

 Side effects:
 - network methods perform authenticated `URLSession` requests against the configured server
 - `propfind` and `search` parse DAV multistatus XML into `WebDAVFile` values

 - Important: Credentials are encoded as HTTP Basic auth headers on each request. Secret storage is
   intentionally outside this type so callers can supply credentials from Keychain or another store.
 - Important: This type is `@unchecked Sendable` because all stored properties are immutable after
   initialization and `URLSession` is safe to use concurrently from multiple tasks.
 */
public final class WebDAVClient: @unchecked Sendable {
    private let baseURL: URL
    private let authorizationHeader: String
    private let session: URLSession

    /**
     Creates a WebDAV client for one server root.

     - Parameters:
       - baseURL: Base DAV endpoint, for example `https://host/remote.php/dav/files/user`.
       - username: Username used for HTTP Basic authentication.
       - password: Password or app password used for HTTP Basic authentication.
       - session: URL session used for transport. Tests can inject a custom configuration.
     */
    public init(
        baseURL: URL,
        username: String,
        password: String,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
        self.authorizationHeader = "Basic \(credentials)"
    }

    /**
     Verifies server connectivity by issuing a root-level `PROPFIND`.

     - Returns: Parsed resources returned by the server for the requested root path.
     */
    public func testConnection() async throws -> [WebDAVFile] {
        try await propfind(path: "", depth: 0)
    }

    /**
     Lists files or folders at a given DAV path using `PROPFIND`.

     - Parameters:
       - path: Relative path under `baseURL`.
       - depth: WebDAV depth header value, typically `0` or `1`.
     - Returns: Parsed WebDAV resources from the server multistatus response.
     */
    public func propfind(path: String, depth: Int = 1) async throws -> [WebDAVFile] {
        let request = try makeRequest(
            path: path,
            method: "PROPFIND",
            headers: [
                "Depth": String(depth),
                "Content-Type": "application/xml; charset=utf-8",
            ],
            body: Data(
                """
                <?xml version="1.0" encoding="utf-8" ?>
                <d:propfind xmlns:d="DAV:">
                  <d:prop>
                    <d:displayname />
                    <d:getcontentlength />
                    <d:getcontenttype />
                    <d:getlastmodified />
                    <d:resourcetype />
                  </d:prop>
                </d:propfind>
                """.utf8
            )
        )
        let data = try await performDataRequest(request, allowedStatusCodes: [207])
        return try WebDAVMultiStatusParser.parse(data: data)
    }

    /**
     Downloads a raw file payload using HTTP `GET`.

     - Parameter path: Relative DAV path to download.
     - Returns: Raw response body.
     */
    public func get(path: String) async throws -> Data {
        let request = try makeRequest(path: path, method: "GET")
        return try await performDataRequest(request, allowedStatusCodes: [200])
    }

    /**
     Uploads a file payload using HTTP `PUT`.

     - Parameters:
       - path: Relative DAV destination path.
       - data: Raw payload to upload.
       - contentType: MIME type for the uploaded payload.
     */
    public func put(path: String, data: Data, contentType: String = "application/octet-stream") async throws {
        let request = try makeRequest(
            path: path,
            method: "PUT",
            headers: ["Content-Type": contentType],
            body: data
        )
        _ = try await performDataRequest(request, allowedStatusCodes: [200, 201, 204])
    }

    /**
     Creates a remote directory using `MKCOL`.

     - Parameter path: Relative DAV collection path to create.
     */
    public func mkcol(path: String) async throws {
        let request = try makeRequest(path: path, method: "MKCOL")
        _ = try await performDataRequest(request, allowedStatusCodes: [201])
    }

    /**
     Deletes a remote file or directory using HTTP `DELETE`.

     - Parameter path: Relative DAV path to remove.
     */
    public func delete(path: String) async throws {
        let request = try makeRequest(path: path, method: "DELETE")
        _ = try await performDataRequest(request, allowedStatusCodes: [200, 204])
    }

    /**
     Performs a WebDAV `SEARCH` for resources modified after a given timestamp.

     - Parameters:
       - path: Relative DAV collection path to search under.
       - modifiedAfter: Lower bound for `getlastmodified`.
     - Returns: Parsed WebDAV resources from the multistatus response.
     */
    public func search(path: String, modifiedAfter: Date) async throws -> [WebDAVFile] {
        let request = try makeRequest(
            path: path,
            method: "SEARCH",
            headers: ["Content-Type": "text/xml; charset=utf-8"],
            body: Data(searchBody(path: path, modifiedAfter: modifiedAfter).utf8)
        )
        let data = try await performDataRequest(request, allowedStatusCodes: [207])
        return try WebDAVMultiStatusParser.parse(data: data)
    }

    private func makeRequest(
        path: String,
        method: String,
        headers: [String: String] = [:],
        body: Data? = nil
    ) throws -> URLRequest {
        let url = try resolvedURL(for: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    private func resolvedURL(for path: String) throws -> URL {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw WebDAVClientError.invalidURL
        }
        let normalizedBasePath = "/" + components.path
            .split(separator: "/")
            .map(String.init)
            .joined(separator: "/")
        let finalPath: String
        if trimmed.isEmpty {
            finalPath = normalizedBasePath == "//" ? "/" : normalizedBasePath
        } else if normalizedBasePath == "/" {
            finalPath = "/\(trimmed)"
        } else {
            finalPath = "\(normalizedBasePath)/\(trimmed)"
        }
        components.path = finalPath
        guard let url = components.url else {
            throw WebDAVClientError.invalidURL
        }
        return url
    }

    private func performDataRequest(
        _ request: URLRequest,
        allowedStatusCodes: Set<Int>
    ) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WebDAVClientError.invalidResponse
        }
        guard allowedStatusCodes.contains(http.statusCode) else {
            throw WebDAVClientError.unexpectedStatus(http.statusCode)
        }
        return data
    }

    private func searchBody(path: String, modifiedAfter: Date) -> String {
        let href = (try? resolvedURL(for: path))?.path ?? "/"
        return """
        <?xml version="1.0" encoding="utf-8" ?>
        <d:searchrequest xmlns:d="DAV:">
          <d:basicsearch>
            <d:select>
              <d:prop>
                <d:displayname />
                <d:getcontentlength />
                <d:getcontenttype />
                <d:getlastmodified />
                <d:resourcetype />
              </d:prop>
            </d:select>
            <d:from>
              <d:scope>
                <d:href>\(Self.xmlEscaped(href))</d:href>
                <d:depth>infinity</d:depth>
              </d:scope>
            </d:from>
            <d:where>
              <d:gt>
                <d:prop><d:getlastmodified /></d:prop>
                <d:literal>\(Self.rfc1123String(from: modifiedAfter))</d:literal>
              </d:gt>
            </d:where>
            <d:orderby>
              <d:order>
                <d:prop><d:getlastmodified /></d:prop>
                <d:ascending />
              </d:order>
            </d:orderby>
          </d:basicsearch>
        </d:searchrequest>
        """
    }

    private static func rfc1123String(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: date)
    }

    private static func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

private final class MultiStatusXMLDelegate: NSObject, XMLParserDelegate {
    private struct ResponseAccumulator {
        var href: String?
        var displayName: String?
        var contentLength: Int64?
        var contentType: String?
        var lastModified: Date?
        var isDirectory = false
    }

    private static let rfc1123Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()

    var files: [WebDAVFile] = []

    private var currentResponse: ResponseAccumulator?
    private var textBuffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = Self.localName(from: qName ?? elementName)
        if name == "response" {
            currentResponse = ResponseAccumulator()
        } else if name == "collection" {
            currentResponse?.isDirectory = true
        }
        textBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = Self.localName(from: qName ?? elementName)
        let value = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "href":
            currentResponse?.href = value.removingPercentEncoding ?? value
        case "displayname":
            currentResponse?.displayName = value
        case "getcontentlength":
            currentResponse?.contentLength = Int64(value)
        case "getcontenttype":
            currentResponse?.contentType = value.isEmpty ? nil : value
        case "getlastmodified":
            currentResponse?.lastModified = Self.rfc1123Formatter.date(from: value)
        case "response":
            if let response = currentResponse, let href = response.href {
                let path = Self.normalizedPath(from: href)
                let displayName = response.displayName?.isEmpty == false
                    ? response.displayName!
                    : URL(fileURLWithPath: path).lastPathComponent
                files.append(
                    WebDAVFile(
                        href: href,
                        path: path,
                        displayName: displayName,
                        isDirectory: response.isDirectory,
                        contentLength: response.contentLength,
                        contentType: response.contentType,
                        lastModified: response.lastModified
                    )
                )
            }
            currentResponse = nil
        default:
            break
        }

        textBuffer = ""
    }

    private static func localName(from elementName: String) -> String {
        elementName.split(separator: ":").last.map(String.init) ?? elementName
    }

    private static func normalizedPath(from href: String) -> String {
        if let url = URL(string: href), let scheme = url.scheme {
            _ = scheme
            return url.path.isEmpty ? "/" : url.path
        }
        return href.hasPrefix("/") ? href : "/\(href)"
    }
}
