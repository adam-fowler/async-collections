@testable import AsyncCollections
import XCTest

final class AsyncSemaphoreTests: XCTestCase {
    func testSignalWait() async throws {
        let semaphore = AsyncSemaphore()
        let rt = semaphore.signal()
        XCTAssertEqual(rt, false)
        try await semaphore.wait()
    }

    func testNoWaitingTask() async throws {
        let semaphore = AsyncSemaphore(value: 1)
        let rt = semaphore.signal()
        XCTAssertEqual(rt, false)
        let rt2 = semaphore.signal()
        XCTAssertEqual(rt2, false)
        try await semaphore.wait()
    }

    func testWaitSignal() async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore()
            group.addTask {
                try await semaphore.wait()
            }
            group.addTask {
                semaphore.signal()
            }
        }
    }

    func testWaitDelayedSignal() async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore()
            group.addTask {
                try await semaphore.wait()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 100_000)
                let rt = semaphore.signal()
                XCTAssertEqual(rt, true)
            }
        }
    }

    func testDoubleWaitSignal() async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore()
            group.addTask {
                try await semaphore.wait()
            }
            group.addTask {
                try await semaphore.wait()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 100_000)
                let rt = semaphore.signal()
                XCTAssertEqual(rt, true)
                let rt2 = semaphore.signal()
                XCTAssertEqual(rt2, true)
            }
        }
    }

    func testManySignalWait() async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore()
            group.addTask {
                semaphore.signal()
                try await semaphore.wait()
                semaphore.signal()
                try await semaphore.wait()
                semaphore.signal()
                try await semaphore.wait()
            }
            group.addTask {
                semaphore.signal()
                semaphore.signal()
                semaphore.signal()
                try await semaphore.wait()
                try await semaphore.wait()
                try await semaphore.wait()
            }
            group.addTask {
                semaphore.signal()
                semaphore.signal()
                try await semaphore.wait()
                try await semaphore.wait()
                semaphore.signal()
                try await semaphore.wait()
            }
        }
    }

    func testCancellationWhileSuspended() async throws {
        let semaphore = AsyncSemaphore()
        let task = Task {
            do {
                try await semaphore.wait()
            } catch is CancellationError {
                XCTAssertEqual(semaphore.getValue(), 0)
            } catch {
                XCTFail("Wrong Error")
            }
        }
        try await Task.sleep(nanoseconds: 10000)
        task.cancel()
    }

    func testCancellationBeforeWait() async throws {
        let semaphore = AsyncSemaphore()
        let task = Task {
            do {
                do {
                    try await Task.sleep(nanoseconds: 100_000)
                } catch {}
                try await semaphore.wait()
            } catch is CancellationError {
                XCTAssertEqual(semaphore.getValue(), 0)
            } catch {
                XCTFail("Wrong Error")
            }
        }
        task.cancel()
    }
}
