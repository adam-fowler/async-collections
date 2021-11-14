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

}
