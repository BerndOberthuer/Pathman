#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Protocol declaration for types that contain an offset which points to a
/// byte location in the file and may be moved around
public protocol Seekable: class {
    /// The location in the path from where reading and writing begin. Measured
    /// in bytes from the beginning of the path
    var offset: OSInt { get set }

    func seek(_ offset: Offset) throws -> OSInt

    func seek(fromStart bytes: OSInt) throws -> OSInt
    func seek(fromEnd bytes: OSInt) throws -> OSInt
    func seek(fromCurrent bytes: OSInt) throws -> OSInt
    // These are available on the following filesystems:
    // Btrfs, OCFS, XFS, ext4, tmpfs, and the macOS filesystem
    #if SEEK_DATA && SEEK_HOLE
    func seek(toNextHoleAfter offset: OSInt) throws -> OSInt
    func seek(toNextDataAfter offset: OSInt) throws -> OSInt
    #endif

    func rewind() throws -> OSInt
}

public extension Seekable {
    /// Seeks using the specified offset
    @discardableResult
    public func seek(_ offset: Offset) throws -> OSInt {
        let newOffset: OSInt

        switch offset.type {
        case .beginning: newOffset = try seek(fromStart: offset.bytes)
        case .end: newOffset = try seek(fromEnd: offset.bytes)
        case .current: newOffset = try seek(fromCurrent: offset.bytes)
        #if SEEK_DATA && SEEK_HOLE
        case .data: newOffset = try seek(toNextDataAfter: offset.bytes)
        case .hole: newOffset = try seek(toNextHoleAfter: offset.bytes)
        #endif
        default: throw SeekError.unknownOffsetType
        }

        self.offset = newOffset
        return self.offset
    }
}

/// 
public struct Offset {
    public struct OffsetType: RawRepresentable, Equatable {
        public typealias RawValue = OptionInt
        public let rawValue: RawValue

        public static let beginning = OffsetType(rawValue: SEEK_SET)
        public static let end = OffsetType(rawValue: SEEK_END)
        public static let current = OffsetType(rawValue: SEEK_CUR)
        #if SEEK_DATA && SEEK_HOLE
        public static let data = OffsetType(rawValue: SEEK_DATA)
        public static let hole = OffsetType(rawValue: SEEK_HOLE)
        #endif

        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }

    var type: OffsetType
    var bytes: OSInt

    init(_ type: OffsetType, _ bytes: OSInt) {
        self.type = type
        self.bytes = bytes
    }

    public init(type: OffsetType, bytes: OSInt) {
        self.type = type
        self.bytes = bytes
    }
}
