import Foundation

public struct ModelSchemeRequest: Equatable {
    public let method: String
    public let path: String
    public let body: Data

    public init(method: String, path: String, body: Data) {
        self.method = method
        self.path = path
        self.body = body
    }
}

public struct ModelSchemeResponse: Equatable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

public struct HTTPRequest: Equatable {
    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let body: Data

    public init(url: URL, method: String, headers: [String: String], body: Data) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Equatable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

public protocol HTTPClient {
    func send(_ request: HTTPRequest) throws -> HTTPResponse
}

public enum ModelBridgeError: Error, Equatable, CustomStringConvertible {
    case unsupportedMethod(String)
    case rejectedPath(String)
    case missingConfiguration
    case invalidEndpoint

    public var description: String {
        switch self {
        case .unsupportedMethod(let method):
            return "unsupported model bridge method: \(method)"
        case .rejectedPath(let path):
            return "model bridge rejected non-model path: \(path)"
        case .missingConfiguration:
            return "missing model configuration"
        case .invalidEndpoint:
            return "invalid model endpoint"
        }
    }
}

public final class SessionModelBridge {
    public static let chatCompletionsPath = "/v1/chat/completions"

    private let configurationStore: ModelConfigurationStore
    private let httpClient: HTTPClient

    public init(configurationStore: ModelConfigurationStore, httpClient: HTTPClient) {
        self.configurationStore = configurationStore
        self.httpClient = httpClient
    }

    public func handle(_ request: ModelSchemeRequest) throws -> ModelSchemeResponse {
        guard request.method.uppercased() == "POST" else {
            throw ModelBridgeError.unsupportedMethod(request.method)
        }
        guard request.path == Self.chatCompletionsPath else {
            throw ModelBridgeError.rejectedPath(request.path)
        }
        guard let configuration = try configurationStore.load() else {
            throw ModelBridgeError.missingConfiguration
        }

        let upstream = try httpClient.send(HTTPRequest(
            url: try endpointURL(baseURL: configuration.baseURL, path: request.path),
            method: "POST",
            headers: [
                "Authorization": "Bearer \(configuration.apiToken)",
                "Content-Type": "application/json"
            ],
            body: request.body
        ))

        return ModelSchemeResponse(
            statusCode: upstream.statusCode,
            body: upstream.body
        )
    }

    private func endpointURL(baseURL: URL, path: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ModelBridgeError.invalidEndpoint
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, requestPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        guard let url = components.url else {
            throw ModelBridgeError.invalidEndpoint
        }
        return url
    }
}

extension SessionModelBridge: @unchecked Sendable {}

public final class URLSessionHTTPClient: HTTPClient {
    public init() {}

    public func send(_ request: HTTPRequest) throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = URLSessionResultBox()

        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            resultBox.data = data
            resultBox.response = response
            resultBox.error = error
            semaphore.signal()
        }.resume()

        semaphore.wait()

        if let error = resultBox.error {
            throw error
        }
        let statusCode = (resultBox.response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPResponse(statusCode: statusCode, body: resultBox.data ?? Data())
    }
}

private final class URLSessionResultBox: @unchecked Sendable {
    var data: Data?
    var response: URLResponse?
    var error: Error?
}
