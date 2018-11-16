import XCTest
import Dispatch
@testable import TrailBlazer

class BindingTests: XCTestCase {
    func testAccepting() {
        let socket = SocketPath("/tmp/com.trailblazer.sock")!

        let binding: Binding
        do {
            binding = try socket.bind()
        } catch {
            XCTFail("Failed to bind to socket with error \(error)")
            return
        }

        #if os(macOS)
        XCTAssertNoThrow(try binding.listen(maxQueued: 1))

        let acceptConnection = XCTestExpectation(description: "Ensure connection is properly accepted")

        DispatchQueue.global(qos: .background).async {
            do {
                try binding.accept { connection in
                    acceptConnection.fulfill()
                }
            } catch {
                print("Failed to accept connection with error \(type(of: error)).\(error)")
            }
        }

        XCTAssertNoThrow(try socket.connect(type: .stream))

        XCTAssertEqual(XCTWaiter.wait(for: [acceptConnection], timeout: 5.0), .completed)
        #endif
    }
}
