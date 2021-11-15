import XCTest
import AsyncCollections

final class TaskQueueTests: XCTestCase {
    func testTaskQueue() async throws {
        let queue = TaskQueue<Int>(maxConcurrentTasks: 32)
        let array = Array((0..<8000))
        let result = try await array.concurrentMap { value -> Int in
            try await queue.add {
                try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100000))
                return value
            }
        }

        XCTAssertEqual(result, array)
    }

    func testMaxConcurrent() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let queue = TaskQueue<Int>(maxConcurrentTasks: 8)
        let array = Array((0..<800))
        let result = try await array.concurrentMap { value -> Int in
            try await queue.add {
                let c = await count.add(1)
                await maxCount.max(c)
                try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100000))
                await count.add(-1)
                return value
            }
        }

        XCTAssertEqual(result, array)
        let maxValue = await maxCount.value
        XCTAssertGreaterThan(maxValue, 1)
        XCTAssertLessThanOrEqual(maxValue, 8)
    }

    func testCancellation() async throws {
        let count = Count(0)

        let queue = TaskQueue<Int>(maxConcurrentTasks: 16)
        let array = Array((1...200).reversed())
        let task = Task {
            _ = try await array.concurrentMap { value -> Int in
                try await queue.add {
                    try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100000))
                    await count.add(value)
                    return value
                }
            }
        }
        try await Task.sleep(nanoseconds: 1000 * 1000)
        task.cancel()
        let value = await count.value
        XCTAssertNotEqual(value, array.reduce(0, +))
    }
}
