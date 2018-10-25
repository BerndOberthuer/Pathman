import Cdirent

/** An object containing a collection of files, directories, and other paths
    from some kind of traversal or enumeration (ie: globbing or getting
    directory children)
*/
public struct PathCollection: Equatable, CustomStringConvertible {
    /// The file paths
    public internal(set) var files: [FilePath] = []
    /// The directory paths
    public internal(set) var directories: [DirectoryPath] = []
    /// Other paths
    public internal(set) var other: [GenericPath] = []

    /// Whether or not this collection is empty
    public var isEmpty: Bool { return files.isEmpty && directories.isEmpty && other.isEmpty }
    /// The number of paths stored in this collection
    public var count: Int { return files.count + directories.count + other.count }

    public var description: String {
        return "\(type(of: self))(files: \(files), directories: \(directories), other: \(other))"
    }

    /** Initializer
        - Parameter files: The FilePaths to begin with as a part of this collection
        - Parameter directories: The DirectoryPaths to begin with as a part of this collection
        - Parameter other: The remaining Paths to begin with as a part of this collection
    */
    public init(files: [FilePath] = [], directories: [DirectoryPath] = [], other: [GenericPath] = []) {
        self.files = files
        self.directories = directories
        self.other = other
    }

    public init(_ openDirectory: OpenDirectory, options: DirectoryEnumerationOptions = []) {
        self.init(DirectoryIterator(openDirectory), options: options)
    }

    private init(_ iterator: DirectoryIterator, options: DirectoryEnumerationOptions = []) {
        while let path = iterator.next() {
            guard !["..", "."].contains(path.lastComponent) else { continue }

            guard options.contains(.includeHidden) || !(path.lastComponent ?? ".").hasPrefix(".") else { continue }

            if let file = FilePath(path) {
                files.append(file)
            } else if let dir = DirectoryPath(path) {
                directories.append(dir)
            } else {
                other.append(path)
            }
        }
    }

    /// Combine two PathCollections into a single new PathCollection
    public static func + (lhs: PathCollection, rhs: PathCollection) -> PathCollection {
        return PathCollection(files: lhs.files + rhs.files,
                              directories: lhs.directories + rhs.directories,
                              other: lhs.other + rhs.other)
    }

    /// Combines the items from one PathCollection into this PathCollection
    public static func += (lhs: inout PathCollection, rhs: PathCollection) {
        lhs.files += rhs.files
        lhs.directories += rhs.directories
        lhs.other += rhs.other
    }

    /// Whether or not two PathCollections are equivalent
    public static func == (lhs: PathCollection, rhs: PathCollection) -> Bool {
        return lhs.files == rhs.files && lhs.directories == rhs.directories && lhs.other == rhs.other
    }
}

private struct DirectoryIterator: IteratorProtocol {
    let openDirectory: OpenDirectory
    var dir: DIRType { return openDirectory.descriptor }
    var path: DirectoryPath { return openDirectory.path }

    init(_ openDirectory: OpenDirectory) {
        self.openDirectory = openDirectory
        self.openDirectory.rewind()
    }

    /**
    Iterates through self

    - Returns: The next path in the directory or nil if all paths have been returned
    */
    func next() -> GenericPath? {
        // Read the next entry in the directory. This C API call should never fail
        guard let entry = readdir(dir) else { return nil }

        // Pulls the directory path from the C dirent struct
        return genPath(entry)
    }

    /**
    Generates a GenericPath from the given dirent pointer

    - Parameter ent: A pointer to the C dirent struct containing the path to generate
    - Returns: A GenericPath to the item pointed to in the dirent struct
    */
    private func genPath(_ ent: UnsafeMutablePointer<dirent>) -> GenericPath {
        // Get the path name (last path component) from the C dirent struct.
        // char[256] in C is converted to a 256 item tuple in Swift. This
        // block converts that to an char * array that can be used to
        // initialize a Swift String using the cString initializer
        let name = withUnsafePointer(to: &ent.pointee.d_name) { (ptr) -> String in
            return ptr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: ent.pointee.d_name)) {
                return String(cString: $0)
            }
        }

        // The full path is the concatenation of self with the path name
        return self.path + name
    }
}
