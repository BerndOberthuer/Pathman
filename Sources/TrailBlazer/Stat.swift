import ErrNo
import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif

public struct StatInfo: StatDescriptor, StatPath {
    var path: String?
    var options: StatOptions
    var fileDescriptor: FileDescriptor?
    var buffer: stat = stat()
    var hasInfo: Bool = false

    init() {
        path = nil
        options = []
        fileDescriptor = nil
    }

    init(_ buffer: stat = stat()) {
        self.init()
        self.buffer = buffer
    }

    mutating func getInfo(options: StatOptions = []) throws {
        if let fd = self.fileDescriptor {
            try StatInfo.update(fd, &self.buffer)
        } else if let path = self.path {
            try StatInfo.update(path, options: options, &self.buffer)
        }
        self.hasInfo = true
    }
}

protocol Stat {
    var buffer: stat { get set }
    var hasInfo: Bool { get set }

    init(_ buffer: stat)

    /// ID of device containing file
    var id: dev_t { get }
    /// inode number
    var inode: ino_t { get }
    /// The type of the file
    var type: FileType { get }
    /// The file permissions
    var permissions: FileMode { get }
    /// user ID of owner
    var user: uid_t { get }
    /// group ID of owner
    var group: gid_t { get }
    /// device ID (if special file)
    var device: dev_t { get }
    /// total size, in bytes
    var size: Int { get }
    /// blocksize for filesystem I/O
    var blockSize: Int { get }
    /// number of 512B blocks allocated
    var blocks: Int { get }

    /// time of last access
    var lastAccess: Date { get }
    /// time of last modification
    var lastModified: Date { get }
    /// time of last status change
    var lastAttributeChange: Date { get }
}

extension Stat {
    public var id: dev_t {
        return buffer.st_dev
    }
    public var inode: ino_t {
        return buffer.st_ino
    }
    public var type: FileType {
        return FileType(rawValue: buffer.st_mode)!
    }
    public var permissions: FileMode {
        return FileMode(rawValue: buffer.st_mode)
    }
    public var user: uid_t {
        return buffer.st_uid
    }
    public var group: gid_t {
        return buffer.st_gid
    }
    public var device: dev_t {
        return buffer.st_rdev
    }
    public var size: Int {
        return buffer.st_size
    }
    public var blockSize: Int {
        return buffer.st_blksize
    }
    public var blocks: Int {
        return buffer.st_blocks
    }

    public var lastAccess: Date {
        return Date(timeIntervalSince1970: Self.timespecToTimeInterval(buffer.st_atim))
    }
    public var lastModified: Date {
        return Date(timeIntervalSince1970: Self.timespecToTimeInterval(buffer.st_mtim))
    }
    public var lastAttributeChange: Date {
        return Date(timeIntervalSince1970: Self.timespecToTimeInterval(buffer.st_ctim))
    }

    private static func timespecToTimeInterval(_ spec: timespec) -> TimeInterval {
        return TimeInterval(spec.tv_sec) + (Double(spec.tv_nsec) * pow(10.0,-9.0))
    }
}

protocol StatDescriptor: Stat {
    var fileDescriptor: FileDescriptor? { get set }
    init(_ fileDescriptor: FileDescriptor, buffer: stat)
    mutating func update() throws
    static func update(_ fileDescriptor: FileDescriptor, _ buffer: inout stat) throws
}

extension StatDescriptor {
    /**
    Get information about a file

    - Throws:
        - StatError.permissionDenied: (Shouldn't occur) Search permission is denied for one of the directories in the path prefix of pathname.
        - StatError.badFileDescriptor: fileDescriptor is bad.
        - StatError.badAddress: Bad address.
        - StatError.tooManySymlinks: Too many symbolic links encountered while traversing the path.
        - StatError.pathnameTooLong: (Shouldn't occur) pathname is too long.
        - StatError.noRouteToPathname: (Shouldn't occur) A component of pathname does not exist, or pathname is an empty string.
        - StatError.outOfMemory: Out of memory (i.e., kernel memory).
        - StatError.notADirectory: (Shouldn't occur) A component of the path prefix of pathname is not a directory.
        - StatError.fileTooLarge: fileDescriptor refers to a file whose size, inode number, or number of blocks cannot be represented in, respectively, the types off_t, ino_t, or blkcnt_t.
    */
    public static func update(_ fileDescriptor: FileDescriptor, _ buffer: inout stat) throws {
        guard fstat(fileDescriptor, &buffer) == 0 else { throw StatError.getError() }
    }

    public mutating func update() throws {
        try Self.update(fileDescriptor!, &buffer)
        self.hasInfo = true
    }

    public init(_ fileDescriptor: FileDescriptor, buffer: stat = stat()) {
        self.init(buffer)
        self.fileDescriptor = fileDescriptor
    }
}

protocol StatPath: Stat {
    var path: String? { get set }
    var options: StatOptions { get set }
    init<PathType: Path>(_ path: PathType, options: StatOptions, buffer: stat)
    init(_ path: String, options: StatOptions, buffer: stat)
    mutating func update(options: StatOptions) throws
    static func update(_ path: String, options: StatOptions, _ buffer: inout stat) throws
}

extension StatPath {
    /**
    Get information about a file

    - Throws:
        - StatError.permissionDenied: Search permission is denied for one of the directories in the path prefix of pathname.
        - StatError.badAddress: Bad address.
        - StatError.tooManySymlinks: Too many symbolic links encountered while traversing the path.
        - StatError.pathnameTooLong: pathname is too long.
        - StatError.noRouteToPathname: A component of pathname does not exist, or pathname is an empty string.
        - StatError.outOfMemory: Out of memory (i.e., kernel memory).
        - StatError.notADirectory: A component of the path prefix of pathname is not a directory.
        - StatError.fileTooLarge: fileDescriptor refers to a file whose size, inode number, or number of blocks cannot be represented in, respectively, the types off_t, ino_t, or blkcnt_t.
    */
    public static func update(_ path: String, options: StatOptions = [], _ buffer: inout stat) throws {
        let statResponse: Int32
        if options.contains(.getLinkInfo) {
            statResponse = lstat(path, &buffer)
        } else {
            statResponse = stat(path, &buffer)
        }
        guard statResponse == 0 else { throw StatError.getError() }
    }

    public mutating func update(options: StatOptions = []) throws {
        var options = options
        options.insert(self.options)
        try Self.update(self.path!, options: options, &self.buffer)
        self.hasInfo = true
    }

    public init(_ path: String, options: StatOptions = [], buffer: stat = stat()) {
        self.init(buffer)
        self.path = path
        self.options = options
    }

    public init<PathType: Path>(_ path: PathType, options: StatOptions = [], buffer: stat = stat()) {
        self.init(path.path, options: options, buffer: buffer)
    }
}

public struct StatOptions: OptionSet {
    public let rawValue: Int

    public static let getLinkInfo = StatOptions(rawValue: 1 << 0)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public enum FileType: UInt32 {
    public typealias RawValue = UInt32
    case socket
    case link
    case regular
    case block
    case directory
    case character
    case fifo
    public static let file: FileType = .regular

    public init?(rawValue: UInt32) {
        switch rawValue & S_IFMT {
        case S_IFSOCK: self = .socket
        case S_IFLNK: self = .link
        case S_IFREG: self = .regular
        case S_IFBLK: self = .block
        case S_IFDIR: self = .directory
        case S_IFCHR: self = .character
        case S_IFIFO: self = .fifo
        default: return nil
        }
    }
}

public protocol StatDelegate {
    var info: StatInfo { get }
}

public extension StatDelegate {
    public var id: dev_t {
        return info.id
    }
    public var inode: ino_t {
        return info.inode
    }
    public var type: FileType {
        return info.type
    }
    public var permissions: FileMode {
        return info.permissions
    }
    public var user: uid_t {
        return info.user
    }
    public var group: gid_t {
        return info.group
    }
    public var device: dev_t {
        return info.device
    }
    public var size: Int {
        return info.size
    }
    public var blockSize: Int {
        return info.blockSize
    }
    public var blocks: Int {
        return info.blocks
    }

    public var lastAccess: Date {
        return info.lastAccess
    }
    public var lastModified: Date {
        return info.lastModified
    }
    public var lastAttributeChange: Date {
        return info.lastAttributeChange
    }
}
