import XCTest
import Foundation
@testable import TrailBlazer

class CreateDeleteTests: XCTestCase {
    private lazy var base: DirectoryPath = {
        #if os(Linux)
        return DirectoryPath.home!
        #else
        return DirectoryPath("/tmp")!
        #endif
    }()

    func testCreateFile() {
        guard let file = FilePath(base + "\(UUID()).test") else {
            XCTFail("Test path exists and is not a file")
            return
        }

        do {
            let open = try file.create()
            XCTAssertTrue(file.exists)
            XCTAssertTrue(file.isFile)
            try? open.write("Hello World")
        } catch {
            XCTFail("Failed to create test file with error \(error)")
        }

        try? file.delete()
    }

    func testDeleteFile() {
        guard let file = FilePath(base + "\(UUID()).test") else {
            XCTFail("Test path exists and is not a file")
            return
        }

        do {
            try file.create()
        } catch {
            XCTFail("Failed to create test file with error \(error)")
            return
        }

        XCTAssertNoThrow(try file.delete())
    }

    func testCreateDirectory() {
        guard let dir = DirectoryPath(base + "\(UUID())") else {
            XCTFail("Test path exists and is not a directory")
            return
        }

        XCTAssertNoThrow(try dir.create())
        XCTAssertTrue(dir.exists)
        XCTAssertTrue(dir.isDirectory)

        try? dir.delete()
    }

    func testDeleteDirectory() {
        guard let dir = DirectoryPath(base + "\(UUID())") else {
            XCTFail("Test path exists and is not a directory")
            return
        }

        do {
            try dir.create()
        } catch {
            XCTFail("Failed to create test directory with error \(error)")
            return
        }

        XCTAssertNoThrow(try dir.delete())
    }

    func testDeleteNonEmptyDirectory() {
        guard let dir = DirectoryPath(base + "\(UUID())") else {
            XCTFail("Test path exists and is not a directory")
            return
        }

        do {
            try dir.create()
        } catch {
            XCTFail("Failed to create test directory with error \(error)")
            return
        }

        for num in 1...10 {
            guard let file = FilePath(dir + "\(num).test") else {
                XCTFail("Test path exists and is not a file")
                return
            }

            do {
                try file.create()
            } catch OpenFileError.pathExists {
                continue
            } catch {
                XCTFail("Failed to create test file with error \(error)")
                break
            }
        }

        do {
            try dir.delete()
            XCTFail("Did not fail to delete nonEmpty directory")
        } catch {}

        try? dir.recursiveDelete()
    }

    func testDeleteDirectoryRecursive() {
        guard let dir = DirectoryPath(base + "\(UUID())") else {
            XCTFail("Test path exists and is not a directory")
            return
        }

        do {
            try dir.create()
        } catch {
            XCTFail("Failed to create test directory with error \(error)")
            return
        }

        for num in 1...10 {
            guard let file = FilePath(dir + "\(num).test") else {
                XCTFail("Test path exists and is not a file")
                return
            }

            do {
                try file.create()
            } catch OpenFileError.pathExists {
                continue
            } catch {
                XCTFail("Failed to create test file with error \(error)")
                break
            }
        }

        XCTAssertNoThrow(try dir.recursiveDelete())
    }

    func testCreateIntermediates() {
        guard let dir = DirectoryPath(base + "\(UUID())") else {
            XCTFail("Test path exists and is not a directory")
            return
        }
        XCTAssertFalse(dir.exists)

        guard let file = FilePath(dir + "\(UUID())" + "\(UUID()).test") else {
            XCTFail("Test path exists and is not a file")
            return
        }

        do {
            let open = try file.create(options: .createIntermediates)
            XCTAssertTrue(file.exists)
            XCTAssertTrue(file.isFile)
            try open.write("Hello World")
        } catch {
            XCTFail("Failed to create/write to file with error \(type(of: error))(\(error))")
        }

        try? dir.recursiveDelete()
    }
}
