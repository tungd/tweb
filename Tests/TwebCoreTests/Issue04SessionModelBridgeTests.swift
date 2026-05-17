import Foundation
import XCTest
@testable import TwebCore

final class Issue04SessionModelBridgeTests: XCTestCase {
    func testBridgeForwardsChatCompletionsBodyToConfiguredEndpoint() throws {
        let body = Data(#"{"model":"test-model","messages":[{"role":"user","content":"hi"}]}"#.utf8)
        let responseBody = Data(#"{"choices":[{"message":{"role":"assistant","content":"hello"}}]}"#.utf8)
        let http = FakeHTTPClient(response: HTTPResponse(statusCode: 200, body: responseBody))
        let bridge = makeBridge(httpClient: http)

        let response = try bridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/v1/chat/completions",
            body: body
        ))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, responseBody)
        XCTAssertEqual(http.requests.map(\.url.absoluteString), [
            "https://llm.example.test/v1/chat/completions"
        ])
        XCTAssertEqual(http.requests.first?.method, "POST")
        XCTAssertEqual(http.requests.first?.body, body)
    }

    func testBridgeInjectsNativeAuthorizationWithoutExposingTokenInRequestBody() throws {
        let body = Data(#"{"model":"test-model","messages":[]}"#.utf8)
        let http = FakeHTTPClient(response: HTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8)))
        let bridge = makeBridge(httpClient: http)

        _ = try bridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/v1/chat/completions",
            body: body
        ))

        XCTAssertEqual(http.requests.first?.headers["Authorization"], "Bearer sk-test")
        XCTAssertFalse(String(data: http.requests.first?.body ?? Data(), encoding: .utf8)?.contains("sk-test") ?? true)
    }

    func testBridgeInjectsConfiguredModelWhenRequestBodyOmitsModel() throws {
        let body = Data(#"{"messages":[{"role":"user","content":"hi"}]}"#.utf8)
        let http = FakeHTTPClient(response: HTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8)))
        let bridge = makeBridge(httpClient: http)

        _ = try bridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/v1/chat/completions",
            body: body
        ))

        let forwardedBody = String(data: http.requests.first?.body ?? Data(), encoding: .utf8)
        XCTAssertTrue(forwardedBody?.contains(#""model":"test-model""#) ?? false)
        XCTAssertTrue(forwardedBody?.contains(#""content":"hi""#) ?? false)
    }

    func testBridgeReplacesPageSuppliedPlaceholderModelWithConfiguredModel() throws {
        let body = Data(#"{"model":"tweb-configured-model","messages":[]}"#.utf8)
        let http = FakeHTTPClient(response: HTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8)))
        let bridge = makeBridge(httpClient: http)

        _ = try bridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/v1/chat/completions",
            body: body
        ))

        let forwardedBody = String(data: http.requests.first?.body ?? Data(), encoding: .utf8)
        XCTAssertTrue(forwardedBody?.contains(#""model":"test-model""#) ?? false)
        XCTAssertFalse(forwardedBody?.contains("tweb-configured-model") ?? true)
    }

    func testBridgeMergesConfiguredRequestOptionsIntoChatCompletionBody() throws {
        let body = Data(#"{"model":"tweb-configured-model","messages":[],"chat_template_kwargs":{"existing":true}}"#.utf8)
        let http = FakeHTTPClient(response: HTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8)))
        let bridge = makeBridge(
            httpClient: http,
            requestOptions: ModelConfiguration.lowLatencyRequestOptions
        )

        _ = try bridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/v1/chat/completions",
            body: body
        ))

        let forwardedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(http.requests.first?.body)) as? [String: Any]
        )
        XCTAssertEqual(forwardedObject["model"] as? String, "test-model")
        XCTAssertEqual(forwardedObject["reasoning_effort"] as? String, "low")

        let templateOptions = try XCTUnwrap(forwardedObject["chat_template_kwargs"] as? [String: Any])
        XCTAssertEqual(templateOptions["existing"] as? Bool, true)
        XCTAssertEqual(templateOptions["enable_thinking"] as? Bool, false)
        XCTAssertEqual(templateOptions["clear_thinking"] as? Bool, true)
    }

    func testNonModelPathsAreRejected() throws {
        let bridge = makeBridge(httpClient: FakeHTTPClient())

        XCTAssertThrowsError(try bridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/native/open-file",
            body: Data()
        ))) { error in
            XCTAssertEqual(error as? ModelBridgeError, .rejectedPath("/native/open-file"))
        }
    }

    func testUnsupportedMethodsAreRejected() throws {
        let bridge = makeBridge(httpClient: FakeHTTPClient())

        XCTAssertThrowsError(try bridge.handle(ModelSchemeRequest(
            method: "GET",
            path: "/v1/chat/completions",
            body: Data()
        ))) { error in
            XCTAssertEqual(error as? ModelBridgeError, .unsupportedMethod("GET"))
        }
    }

    func testForwardedResponsePreservesOpenAICompatibleShape() throws {
        let responseBody = Data(#"{"id":"chatcmpl-test","object":"chat.completion","choices":[]}"#.utf8)
        let http = FakeHTTPClient(response: HTTPResponse(statusCode: 200, body: responseBody))
        let bridge = makeBridge(httpClient: http)

        let response = try bridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/v1/chat/completions",
            body: Data(#"{"model":"test-model","messages":[]}"#.utf8)
        ))

        XCTAssertEqual(response.body, responseBody)
    }

    func testBridgeCountsForwardedModelRequests() throws {
        let bridge = makeBridge(httpClient: FakeHTTPClient())

        XCTAssertEqual(bridge.modelRequestCount, 0)

        _ = try bridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/v1/chat/completions",
            body: Data(#"{"model":"test-model","messages":[]}"#.utf8)
        ))
        _ = try bridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/v1/chat/completions",
            body: Data(#"{"model":"test-model","messages":[]}"#.utf8)
        ))

        XCTAssertEqual(bridge.modelRequestCount, 2)
    }

    private func makeBridge(
        httpClient: FakeHTTPClient,
        requestOptions: [String: JSONValue] = [:]
    ) -> SessionModelBridge {
        SessionModelBridge(
            configurationStore: InMemoryModelConfigurationStore(configuration: ModelConfiguration(
                baseURL: URL(string: "https://llm.example.test")!,
                modelName: "test-model",
                apiToken: "sk-test",
                requestOptions: requestOptions
            )),
            httpClient: httpClient
        )
    }
}
