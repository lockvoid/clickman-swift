import Foundation

extension ClickMan {
    public struct Configuration: Sendable {
        /// The ingest server, e.g. `https://clickman.example.com`.
        public var endpoint: URL
        /// The write key of this app's source.
        public var writeKey: String
        /// A batch is sent once this many events are waiting.
        public var flushAt = 20
        /// A batch is sent once the oldest waiting event is this old.
        public var flushInterval: Duration = .seconds(30)
        /// The most events kept on the device; the oldest go first.
        public var maxQueue = 10_000
        /// Where the queue lives; Application Support/ClickMan by default.
        public var storage: URL?
        /// Sends the installation, update, foreground and background events.
        public var tracksLifecycle = true

        var session = URLSession(configuration: .ephemeral)
        var bundle = Bundle.main
        var pollInterval: Duration = .seconds(5)
        var observesSystem = true

        public init(endpoint: URL, writeKey: String) {
            self.endpoint = endpoint
            self.writeKey = writeKey
        }

        func validate() throws {
            guard flushAt > 0, maxQueue > 0, flushInterval > .zero, pollInterval >= .milliseconds(1) else {
                throw ClickManError.configuration("queue limits and intervals must be positive")
            }
            guard ["http", "https"].contains(endpoint.scheme?.lowercased() ?? ""),
                  endpoint.host?.isEmpty == false, endpoint.user == nil, endpoint.password == nil,
                  endpoint.query == nil, endpoint.fragment == nil else {
                throw ClickManError.configuration("the endpoint must be an absolute HTTP(S) URL without credentials, query or fragment")
            }
            guard !writeKey.isEmpty, writeKey.utf8.allSatisfy({ (33...126).contains($0) }) else {
                throw ClickManError.configuration("a public source write key without whitespace is required")
            }
            guard storage?.isFileURL != false else {
                throw ClickManError.configuration("the queue storage must be a file URL")
            }
        }

        func request() throws -> URLRequest {
            try validate()
            guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: true) else {
                throw ClickManError.configuration("the endpoint could not be parsed")
            }
            components.percentEncodedPath = components.percentEncodedPath
                .replacingOccurrences(of: #"/+$"#, with: "", options: .regularExpression) + "/v1/batch"
            guard let url = components.url else {
                throw ClickManError.configuration("the batch endpoint could not be constructed")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(writeKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            return request
        }
    }
}
