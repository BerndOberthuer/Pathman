#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// A Path that has an owner and a group associated with it
public protocol Ownable: StatDelegate {
    /// The uid of the user that owns the file
    var owner: uid_t { get set }
    /// The gid of the group that owns the file
    var group: gid_t { get set }
    /// The name of the user that owns the file
    var ownerName: String? { get set }
    /// The name of the group that owns the file
    var groupName: String? { get set }

    func change(owner uid: uid_t, group gid: gid_t) throws
}

public extension Ownable {
    public var owner: uid_t {
        get { return info.owner }
        set { try? change(owner: newValue, group: ~0) }
    }
    public var group: gid_t {
        get { return info.group }
        set { try? change(owner: ~0, group: newValue) }
    }

    public var ownerName: String? {
        get {
            guard let username = try? getUserInfo(owner).pw_name else { return nil }
            return String(cString: username)
        }
        set {
            guard let username = newValue else { return }
            try? change(owner: username)
        }
    }
    public var groupName: String? {
        get {
            guard let groupname = try? getGroupInfo(group).gr_name else { return nil }
            return String(cString: groupname)
        }
        set {
            guard let groupname = newValue else { return }
            try? change(group: groupname)
        }
    }

    /**
    Change the owner and/or group to the specified names

    - Parameter owner: The username to lookup for the new owner
    - Parameter group: The groupname to lookup for the new group

    - Throws: `UserInfoError.userDoesNotExist` when there was no user found with the specified username
    - Throws: `UserInfoError.interruptedBySignal` when the API call was interrupted by a signal handler
    - Throws: `UserInfoError.ioError` when an I/O error occurred during the API call
    - Throws: `UserInfoError.noMoreProcessFileDescriptors` when the process has no more available file descriptors
    - Throws: `UserInfoError.noMoreSystemFileDescriptors` when the system has no more available file descriptors
    - Throws: `UserInfoError.outOfMemory` when there is insufficient memory to allocate the underlying C passwd struct
    - Throws: `GroupInfoError.groupDoesNotExist` when there was no group found with the specified group name
    - Throws: `GroupInfoError.interruptedBySignal` when the API call was interrupted by a signal handler
    - Throws: `GroupInfoError.ioError` when an I/O error occurred during the API call
    - Throws: `GroupInfoError.noMoreProcessFileDescriptors` when the process has no more available file descriptors
    - Throws: `GroupInfoError.noMoreSystemFileDescriptors` when the system has no more available file descriptors
    - Throws: `GroupInfoError.outOfMemory` when there is insufficient memory to allocate the underlying C group struct
    - Throws: `ChangeOwnershipError.permissionDenied` when the calling process does not have the proper permissions to modify path ownership
    - Throws: `ChangeOwnershipError.badAddress` when the path points to a location outside your addressible address space
    - Throws: `ChangeOwnershipError.tooManySymlinks` when too many symlinks were encounter while resolving the path
    - Throws: `ChangeOwnershipError.pathnameTooLong` when the path has more than `PATH_MAX` number of characters
    - Throws: `ChangeOwnershipError.pathDoesNotExist` when the path does not exist
    - Throws: `ChangeOwnershipError.noKernelMemory` when there is insufficient memory to change the path's ownership
    - Throws: `ChangeOwnershipError.pathComponentNotDirectory` when a component of the path is not a directory
    - Throws: `ChangeOwnershipError.readOnlyFileSystem` when the file system is in read-only mode
    - Throws: `ChangeOwnershipError.ioError` when an I/O error occurred during the API call
    */
    public func change(owner username: String? = nil, group groupname: String? = nil) throws {
        let uid: uid_t
        let gid: gid_t

        if let username = username {
            uid = try getUserInfo(username).pw_uid
        } else {
            uid = ~0
        }

        if let groupname = groupname {
            gid = try getGroupInfo(groupname).gr_gid
        } else {
            gid = ~0
        }

        try change(owner: uid, group: gid)
    }
}
