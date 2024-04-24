import AsyncCollections
import XCTest

final class CompactCompactMapTests: XCTestCase {
    func testAsyncCompactMap() async throws {
        let array = Array(0..<80).map { (element: $0, isIncluded: Bool.random()) }
        let result = try await array.asyncCompactMap { value -> Int? in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value.isIncluded ? value.element : nil
        }

        XCTAssertEqual(result, array.filter(\.isIncluded).map(\.element))
    }

    func testConcurrentCompactMap() async throws {
        let array = Array(0..<800).map { (element: $0, isIncluded: Bool.random()) }
        let result = try await array.concurrentCompactMap { value -> Int? in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value.isIncluded ? value.element : nil
        }

        XCTAssertEqual(result, array.filter(\.isIncluded).map(\.element))
    }

    func testConcurrentCompactMapWithString() async throws {
        let array = Array(0..<800).map { (element: $0, isIncluded: Bool.random()) }
        let result = try await array.concurrentCompactMap { value -> String? in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value.isIncluded ? String(value.element) : nil
        }

        XCTAssertEqual(result, array.filter(\.isIncluded).map(\.element.description))
    }

    func testAsyncCompactMapNonOptionalClosure() async throws {
        let array = Array(0..<80)
        let result = try await array.asyncCompactMap { value -> Int in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value
        }

        XCTAssertEqual(result, array)
    }

    func testConcurrentCompactMapNonOptionalClosure() async throws {
        let array = Array(0..<800)
        let result = try await array.concurrentCompactMap { value -> Int in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value
        }

        XCTAssertEqual(result, array)
    }

    func testConcurrentCompactMapWithStringNonOptionalClosure() async throws {
        let array = Array(0..<800)
        let result = try await array.concurrentCompactMap { value -> String in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return String(value)
        }

        XCTAssertEqual(result, array.map(\.description))
    }

    func testAsyncCompactMapConcurrency() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<80).map { (element: $0, isIncluded: Bool.random()) }
        let result = try await array.asyncCompactMap { value -> Int? in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value.isIncluded ? value.element : nil
        }

        XCTAssertEqual(result, array.filter(\.isIncluded).map(\.element))
        let maxValue = await maxCount.value
        XCTAssertEqual(maxValue, 1)
    }

    func testConcurrentCompactMapConcurrency() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<800).map { (element: $0, isIncluded: Bool.random()) }
        let result = try await array.concurrentCompactMap { value -> Int? in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value.isIncluded ? value.element : nil
        }

        XCTAssertEqual(result, array.filter(\.isIncluded).map(\.element))
        let maxValue = await maxCount.value
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testConcurrentCompactMapConcurrencyWithMaxTasks() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<800).map { (element: $0, isIncluded: Bool.random()) }
        let result = try await array.concurrentCompactMap(maxConcurrentTasks: 4) { value -> Int? in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value.isIncluded ? value.element : nil
        }

        XCTAssertEqual(result, array.filter(\.isIncluded).map(\.element))
        let maxValue = await maxCount.value
        XCTAssertLessThanOrEqual(maxValue, 4)
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testConcurrentCompactMapConcurrencyWithMaxTasksNonOptionalClosure() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<800)
        let result = try await array.concurrentCompactMap(maxConcurrentTasks: 4) { value -> Int in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value
        }

        XCTAssertEqual(result, array)
        let maxValue = await maxCount.value
        XCTAssertLessThanOrEqual(maxValue, 4)
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testAsyncCompactMapErrorThrowing() async throws {
        struct TaskError: Error {}

        do {
            _ = try await(1...8).asyncCompactMap { element -> Int? in
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

    func testConcurrentCompactMapErrorThrowing() async throws {
        struct TaskError: Error {}

        do {
            _ = try await(1...8).concurrentCompactMap { element -> Int? in
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

    func testAsyncCompactMapCancellation() async throws {
        let count = Count(1)

        let array = Array((1...8).reversed())
        let task = Task {
            _ = try await array.asyncCompactMap { value -> Int? in
                try await Task.sleep(nanoseconds: numericCast(value) * 1000 * 100)
                await count.mul(value)
                return Bool.random() ? value : nil
            }
        }
        try await Task.sleep(nanoseconds: 15 * 1000 * 100)
        task.cancel()
        let value = await count.value
        XCTAssertNotEqual(value, 1 * 2 * 3 * 4 * 5 * 6 * 7 * 8)
    }

    func testConcurrentCompactMapCancellation() async throws {
        let count = Count(1)

        let array = Array((1...8).reversed())
        let task = Task {
            _ = try await array.concurrentCompactMap { value -> Int? in
                try await Task.sleep(nanoseconds: numericCast(value) * 1000 * 100)
                await count.mul(value)
                return Bool.random() ? value : nil
            }
        }
        try await Task.sleep(nanoseconds: 1 * 1000 * 100)
        task.cancel()
        let value = await count.value
        XCTAssertNotEqual(value, 1 * 2 * 3 * 4 * 5 * 6 * 7 * 8)
    }
}
