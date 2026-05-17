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

public final class ModelRequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    public init() {}

    @discardableResult
    public func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
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
    private let requestCounter: ModelRequestCounter

    public init(
        configurationStore: ModelConfigurationStore,
        httpClient: HTTPClient,
        requestCounter: ModelRequestCounter = ModelRequestCounter()
    ) {
        self.configurationStore = configurationStore
        self.httpClient = httpClient
        self.requestCounter = requestCounter
    }

    public var modelRequestCount: Int {
        requestCounter.count
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

        requestCounter.increment()
        let upstream = try httpClient.send(HTTPRequest(
            url: try endpointURL(baseURL: configuration.baseURL, path: request.path),
            method: "POST",
            headers: [
                "Authorization": "Bearer \(configuration.apiToken)",
                "Content-Type": "application/json"
            ],
            body: try requestBody(request.body, configuration: configuration)
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

    private func requestBody(_ body: Data, configuration: ModelConfiguration) throws -> Data {
        guard
            !body.isEmpty,
            var object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        else {
            return body
        }

        if object["model"] as? String == configuration.modelName, configuration.requestOptions.isEmpty {
            return body
        }

        object = Self.merge(object, with: Self.jsonObject(from: configuration.requestOptions))
        object["model"] = configuration.modelName
        return try JSONSerialization.data(withJSONObject: object, options: [])
    }

    private static func merge(_ base: [String: Any], with overrides: [String: Any]) -> [String: Any] {
        var result = base
        for (key, value) in overrides {
            if
                let baseObject = result[key] as? [String: Any],
                let overrideObject = value as? [String: Any]
            {
                result[key] = merge(baseObject, with: overrideObject)
            } else {
                result[key] = value
            }
        }
        return result
    }

    private static func jsonObject(from values: [String: JSONValue]) -> [String: Any] {
        values.mapValues(jsonObject(from:))
    }

    private static func jsonObject(from value: JSONValue) -> Any {
        switch value {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .number(let value):
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.map(jsonObject(from:))
        case .object(let object):
            return jsonObject(from: object)
        }
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
