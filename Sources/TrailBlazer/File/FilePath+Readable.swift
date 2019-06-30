#if os(Linux)
import func Glibc.clearerr
import func Glibc.feof
import func Glibc.fread
#else
import func Darwin.clearerr
import func Darwin.feof
import func Darwin.fread
#endif
/// The C function used to read from an opened file descriptor
private let cReadFile = fread
private let cIsEOF = feof
private let cClearError = clearerr

import struct Foundation.Data

private var _buffers: [FilePath: UnsafeMutableRawPointer] = [:]
private var _bufferSizes: [FilePath: Int] = [:]

private var alignment = MemoryLayout<CChar>.alignment

extension FilePath: ReadableByOpened, DefaultReadByteCount {
    /// The buffer used to store data read from a path
    var buffer: UnsafeMutableRawPointer? {
        get { return _buffers[self] }
        nonmutating set {
            buffer?.deallocate()

            guard let newBuffer = newValue else {
                _buffers.removeValue(forKey: self)
                return
            }

            _buffers[self] = newBuffer
        }
    }

    /// The size of the buffer used to store read data
    var bufferSize: Int? {
        get { return _bufferSizes[self] }
        nonmutating set {
            guard let newSize = newValue else {
                _bufferSizes.removeValue(forKey: self)
                return
            }

            buffer = UnsafeMutableRawPointer.allocate(byteCount: newSize, alignment: alignment)
            _bufferSizes[self] = newSize
        }
    }

    /**
     Read data from a descriptor

     - Parameter sizeToRead: The number of bytes to read from the descriptor
     - Returns: The Data read from the descriptor

     - Throws: `ReadError.wouldBlock` when the file was opened with the `.nonBlock` flag and the read operation would
               block
     - Throws: `ReadError.badFileDescriptor` when the underlying file descriptor is invalid or not opened
     - Throws: `ReadError.badBufferAddress` when the buffer points to a location outside you accessible address space
     - Throws: `ReadError.interruptedBySignal` when the API call was interrupted by a signal handler
     - Throws: `ReadError.cannotReadFileDescriptor` when the underlying file descriptor is attached to a path which is
               unsuitable for reading or the file was opened with the `.direct` flag and either the buffer addres, the
               byteCount, or the offset are not suitably aligned
     - Throws: `ReadError.ioError` when an I/O error occured during the API call
     */
    public static func read(bytes sizeToRead: ByteRepresentable = FilePath.defaultByteCount,
                            from opened: Open<FilePath>) throws -> Data {
        guard opened.mayRead else {
            throw ReadError.cannotReadFileStream
        }
        let bytes = sizeToRead.bytes

        let bytesToRead = bytes > opened.size ? Int(opened.size) : bytes

        // If we haven't allocated a buffer before, then allocate one now
        if opened.path.buffer == nil {
            opened.path.bufferSize = bytesToRead
            // If the buffer size is less than bytes we're going to read then reallocate the buffer
        } else if let bSize = opened.path.bufferSize, bSize < bytesToRead {
            opened.path.bufferSize = bytesToRead
        }
        // Reading the file returns the number of bytes read (or 0 if there was an error or the eof was encountered)
        let bytesRead = cReadFile(opened.path.buffer!, 1, bytesToRead, opened.descriptor)
        guard bytesRead != 0 || cIsEOF(opened.descriptor) != 0 else {
            cClearError(opened.descriptor)
            throw ReadError()
        }

        // Return the Data read from the descriptor
        return Data(bytes: opened.path.buffer!, count: bytesRead)
    }
}
