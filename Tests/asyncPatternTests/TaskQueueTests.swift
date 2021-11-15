import XCTest
import asyncPatterns

final class TaskQueueTests: XCTestCase {
    func testTaskQueue() async throws {
        let queue = TaskQueue<Int>(maxConcurrent: 8)
        let array = Array((0..<800))
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

        let queue = TaskQueue<Int>(maxConcurrent: 8)
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
}
