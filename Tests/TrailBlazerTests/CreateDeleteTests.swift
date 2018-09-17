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
        guard let file = FilePath(base + "abcdefg.test") else {
            XCTFail("Path \(base.string)/abcdefg.test exists and is not a file")
            return
        }

        do {
            let open = try file.create()
            XCTAssertTrue(file.exists)
            XCTAssertTrue(file.isFile)
            try open.write("Hello World")
        } catch {
            XCTFail("Failed to create/write to file with error \(error)")
        }
    }

    func testDeleteFile() {
        guard let file = FilePath(base + "abcdefg.test") else {
            XCTFail("Path \(base.string)/abcdefg.test exists and is not a file")
            return
        }

        if !file.exists { testCreateFile() }

        XCTAssertNoThrow(try file.delete())
    }

    func testCreateDirectory() {
        guard let dir = DirectoryPath(base + "hijklmnop") else {
            XCTFail("Path \(base.string)/hijklmnop exists and is not a directory")
            return
        }

        XCTAssertNoThrow(try dir.create())
        XCTAssertTrue(dir.exists)
        XCTAssertTrue(dir.isDirectory)
    }

    func testDeleteDirectory() {
        guard let dir = DirectoryPath(base + "hijklmnop") else {
            XCTFail("Path \(base.string)/hijklmnop exists and is not a directory")
            return
        }

        if !dir.exists { testCreateDirectory() }

        XCTAssertNoThrow(try dir.delete())
    }

    func testDeleteNonEmptyDirectory() {
        guard let dir = DirectoryPath(base + "qrstuvwxyz") else {
            XCTFail("Path \(base.string)/qrstuvwxyz exists and is not a directory")
            return
        }

        XCTAssertNoThrow(try dir.create())
        XCTAssertTrue(dir.exists)

        for num in 1...10 {
            guard let file = FilePath(base + "qrstuvwxyz/\(num).test") else {
                XCTFail("Path \(base.string)/qrstuvwxyz/\(num).test exists and is not a file")
                return
            }

            do {
                try file.create()
                XCTAssertTrue(file.exists)
                XCTAssertTrue(file.isFile)
            } catch OpenFileError.pathExists {
                continue
            } catch {
                XCTFail("Failed to create \(file) with error \(error)")
                break
            }
        }

        do {
            try dir.delete()
            XCTFail("Did not fail to delete nonEmpty directory")
        } catch {}
    }

    func testDeleteDirectoryRecursive() {
        guard let dir = DirectoryPath(base + "/qrstuvwxyz") else {
            XCTFail("Path \(base.string)/qrstuvwxyz exists and is not a directory")
            return
        }

        if !dir.exists { testDeleteNonEmptyDirectory() }

        XCTAssertNoThrow(try dir.recursiveDelete())
    }

    func testCreateIntermediates() {
        guard let dir = DirectoryPath(base + "testIntermediate1") else {
            XCTFail("Path \(base.string)/testIntermediate1 exists and is not a directory")
            return
        }
        XCTAssertFalse(dir.exists)

        guard let file = FilePath(dir + "testIntermediate2" + "abcdefg.test") else {
            XCTFail("Path \(base.string)/testIntermediate1/testIntermediate2/abcdefg.test exists and is not a file")
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

    static var allTests = [
        ("testCreateFile", testCreateFile),
        ("testDeleteFile", testDeleteFile),
        ("testCreateDirectory", testCreateDirectory),
        ("testDeleteDirectory", testDeleteDirectory),
        ("testDeleteNonEmptyDirectory", testDeleteNonEmptyDirectory),
        ("testDeleteDirectoryRecursive", testDeleteDirectoryRecursive),
        ("testCreateIntermediates", testCreateIntermediates),
    ]
}
