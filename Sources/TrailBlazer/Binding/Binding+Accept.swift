#if os(Linux)
import func Glibc.accept
#else
import func Darwin.accept
#endif
private let cAcceptConnection = accept

extension Binding {
    public func accept() throws -> Connection {
        // No sense storing/casting the accepted connection. We know exactly
        // which path it's connected to and which protocol and there are no ports
        let connectionFileDescriptor = cAcceptConnection(fileDescriptor, nil, nil)

        guard connectionFileDescriptor != -1 else {
            throw AcceptError.getError()
        }

        return Connection(Open(path, descriptor: connectionFileDescriptor, options: openOptions))
    }

    public func accept(_ closure: @escaping (Connection) throws -> ()) throws {
        try closure(accept())
    }
}
