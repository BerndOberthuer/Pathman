public struct CopyOptions: OptionSet {
    public let rawValue: Int

    /**
    If the path to copy is a directory, use this to recursively copy all of
    its contents as opposed to just its immediate children
    */
    public static let recursive = CopyOptions(rawValue: 1)
    /// If the path to copy is a directory, this option will copy the hidden files as well
    public static let includeHidden = CopyOptions(rawValue: 1 << 1)
    /**
    Instead of using a buffer to copy File contents into the duplicate,
    directly copy the entire file into the other. Beware of using this if the
    file you're copying is large
    */
    public static let noBuffer = CopyOptions(rawValue: 1 << 2)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public protocol Copyable: Openable {
    associatedtype CopyablePathType: Path
    @discardableResult
    func copy(to newPath: CopyablePathType, options: CopyOptions) throws -> Open<OpenableType>
}

public extension Copyable where Self: Path {
    public func copy(into directory: DirectoryPath, options: CopyOptions = []) throws {
        let newPath = CopyablePathType(directory + lastComponent!) !! "Somehow, a different type of path ended up at \(directory + lastComponent!)"
        try copy(to: newPath, options: options)
    }
}

extension FilePath: Copyable {
    public typealias CopyablePathType = FilePath

    @discardableResult
    public func copy(to newPath: FilePath, options: CopyOptions = []) throws -> OpenFile {
        // Open self with read permissions
        let openPath: OpenFile = try open(permissions: .read)
        let originalOffset = openPath.offset
        // Make sure we're at the beginning of the file
        try openPath.rewind()

        // Create the path we're going to copy
        let newOpenPath = try newPath.create(mode: permissions, forceMode: true)
        try newOpenPath.change(owner: owner, group: group)

        // If we're not buffering, the buffer size is just the whole file size.
        // If we are buffering, follow the Linux cp(1) implementation, which
        // reads 32 kb at a time.
        let bufferSize: Int = options.contains(.noBuffer) ? Int(size) : 32.kb

        // If we're not buffering, this should really only run once
        repeat {
            try newOpenPath.write(try openPath.read(bytes: bufferSize))
        } while !openPath.eof // Stop reading from the file once we've reached the EOF
        openPath.offset = originalOffset

        return newOpenPath
    }
}

extension DirectoryPath: Copyable {
    public typealias CopyablePathType = DirectoryPath

    @discardableResult
    public func copy(to newPath: DirectoryPath, options: CopyOptions) throws -> OpenDirectory {
        let openPath: OpenDirectory
        if let open = opened {
            openPath = open
            openPath.rewind()
        } else {
            openPath = try open()
        }

        let childrenPaths = openPath.children(includeHidden: options.contains(.includeHidden))

        // The cp(1) utility skips directories unless the recursive options is
        // used. Let's be a little nicer and only skip non-empty directories
        guard childrenPaths.isEmpty || options.contains(.recursive) else { throw CopyError.nonEmptyDirectory }

        let newOpenPath = try newPath.create(mode: permissions, forceMode: true)
        try newOpenPath.change(owner: owner, group: group)

        for file in childrenPaths.files {
            try file.copy(into: newPath, options: options)
        }
        for directory in childrenPaths.directories {
            try directory.copy(into: newPath, options: options)
        }

        guard childrenPaths.other.isEmpty else { throw CopyError.uncopyablePath(childrenPaths.other.first!) }

        return newOpenPath
    }
}

extension Open: Copyable where PathType: Copyable {
    public typealias CopyablePathType = PathType.CopyablePathType

    @discardableResult
    public func copy(to newPath: CopyablePathType, options: CopyOptions = []) throws -> Open<PathType.OpenableType>{
        return try path.copy(to: newPath, options: options)
    }
}
