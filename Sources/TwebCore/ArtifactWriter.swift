import Foundation

public struct ArtifactPathResolver: Equatable {
    public let tempDirectory: URL

    public init(tempDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)) {
        self.tempDirectory = tempDirectory
    }

    public func resolve(_ requestedPath: String) throws -> URL {
        let url = URL(fileURLWithPath: requestedPath)
        if url.path == requestedPath, requestedPath.hasPrefix("/") {
            return url
        }

        let fileName = url.lastPathComponent.isEmpty ? "artifact" : url.lastPathComponent
        return tempDirectory.appendingPathComponent(fileName, isDirectory: false)
    }
}

public protocol ArtifactWriter {
    @discardableResult
    func write(data: Data, requestedPath: String) throws -> URL

    @discardableResult
    func write(text: String, requestedPath: String) throws -> URL
}

public final class LocalArtifactWriter: ArtifactWriter {
    private let resolver: ArtifactPathResolver
    private let fileManager: FileManager

    public init(
        resolver: ArtifactPathResolver = ArtifactPathResolver(),
        fileManager: FileManager = .default
    ) {
        self.resolver = resolver
        self.fileManager = fileManager
    }

    @discardableResult
    public func write(data: Data, requestedPath: String) throws -> URL {
        let url = try resolver.resolve(requestedPath)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
        return url
    }

    @discardableResult
    public func write(text: String, requestedPath: String) throws -> URL {
        let data = Data(text.utf8)
        return try write(data: data, requestedPath: requestedPath)
    }
}
