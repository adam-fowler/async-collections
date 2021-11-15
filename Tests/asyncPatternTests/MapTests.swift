import XCTest
import asyncPatterns

final class MapTests: XCTestCase {
    func testAsyncMap() async throws {
        let array = Array((0..<80))
        let result = try await array.asyncMap { value -> Int in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100000))
            return value
        }

        XCTAssertEqual(result, array)
    }

    func testConcurrentMap() async throws {
        let array = Array((0..<800))
        let result = try await array.concurrentMap { value -> Int in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100000))
            return value
        }

        XCTAssertEqual(result, array)
    }

    func testConcurrentAsyncMap() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array((0..<80))
        let result = try await array.asyncMap { value -> Int in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100000))
            await count.add(-1)
            return value
        }

        XCTAssertEqual(result, array)
        let maxValue = await maxCount.value
        XCTAssertEqual(maxValue, 1)
    }

    func testConcurrentConcurrentMap() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array((0..<800))
        let result = try await array.concurrentMap { value -> Int in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100000))
            await count.add(-1)
            return value
        }

        XCTAssertEqual(result, array)
        let maxValue = await maxCount.value
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testAsyncMapErrorThrowing() async throws {
        struct TaskError: Error {}

        do {
            _ = try await (1...8).asyncMap { element -> Int in
                if element == 4 {
                    throw TaskError()
                }
                return element
            }
            XCTFail("Should have failed")
        } catch is TaskError {
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testConcurrentMapErrorThrowing() async throws {
        struct TaskError: Error {}

        do {
            _ = try await (1...8).concurrentMap { element -> Int in
                if element == 4 {
                    throw TaskError()
                }
                return element
            }
            XCTFail("Should have failed")
        } catch is TaskError {
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testAsyncMapCancellation() async throws {
        let count = Count(1)

        let array = Array((1...8).reversed())
        let task = Task {
            _ = try await array.asyncMap { value -> Int in
                try await Task.sleep(nanoseconds: numericCast(value) * 1000 * 100)
                await count.mul(value)
                return value
            }
        }
        try await Task.sleep(nanoseconds: 15 * 1000 * 100)
        task.cancel()
        let value = await count.value
        XCTAssertNotEqual(value, 1*2*3*4*5*6*7*8)
    }

    func testConcurrentMapCancellation() async throws {
        let count = Count(1)

        let array = Array((1...8).reversed())
        let task = Task {
            _ = try await array.concurrentMap { value -> Int in
                try await Task.sleep(nanoseconds: numericCast(value) * 1000 * 100)
                await count.mul(value)
                return value
            }
        }
        try await Task.sleep(nanoseconds: 1 * 1000 * 100)
        task.cancel()
        let value = await count.value
        XCTAssertNotEqual(value, 1*2*3*4*5*6*7*8)
    }
}
