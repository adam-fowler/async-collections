import AsyncCollections
import XCTest

final class FilterTests: XCTestCase {
    func testAsyncFilter() async throws {
        let array = Array(0..<80).map { (element: $0, isIncluded: Bool.random()) }
        let result = try await array.asyncFilter { value -> Bool in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value.isIncluded
        }

        XCTAssertTrue(result.allSatisfy(\.isIncluded))
        XCTAssertEqual(result.map(\.element), array.filter(\.isIncluded).map(\.element))
    }

    func testConcurrentFilter() async throws {
        let array = Array(0..<80).map { (element: $0, isIncluded: Bool.random()) }
        let result = try await array.concurrentFilter { value -> Bool in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value.isIncluded
        }

        XCTAssertTrue(result.allSatisfy(\.isIncluded))
        XCTAssertEqual(result.map(\.element), array.filter(\.isIncluded).map(\.element))
    }

    func testConcurrentFilterWithString() async throws {
        let array = Array(0..<80).map { (element: "\($0)", isIncluded: Bool.random()) }
        let result = try await array.concurrentFilter { value -> Bool in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value.isIncluded
        }

        XCTAssertTrue(result.allSatisfy(\.isIncluded))
        XCTAssertEqual(result.map(\.element), array.filter(\.isIncluded).map(\.element))
    }

    func testAsyncFilterConcurrency() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<80).map { (element: "\($0)", isIncluded: Bool.random()) }
        let result = try await array.asyncFilter { value -> Bool in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value.isIncluded
        }

        XCTAssertTrue(result.allSatisfy(\.isIncluded))
        XCTAssertEqual(result.map(\.element), array.filter(\.isIncluded).map(\.element))
        let maxValue = await maxCount.value
        XCTAssertEqual(maxValue, 1)
    }

    func testConcurrentFilterConcurrency() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<80).map { (element: "\($0)", isIncluded: Bool.random()) }
        let result = try await array.concurrentFilter { value -> Bool in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value.isIncluded
        }

        XCTAssertTrue(result.allSatisfy(\.isIncluded))
        XCTAssertEqual(result.map(\.element), array.filter(\.isIncluded).map(\.element))
        let maxValue = await maxCount.value
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testConcurrentFilterConcurrencyWithMaxTasks() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<80).map { (element: "\($0)", isIncluded: Bool.random()) }
        let result = try await array.concurrentFilter(maxConcurrentTasks: 4) { value -> Bool in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value.isIncluded
        }

        XCTAssertTrue(result.allSatisfy(\.isIncluded))
        XCTAssertEqual(result.map(\.element), array.filter(\.isIncluded).map(\.element))
        let maxValue = await maxCount.value
        XCTAssertLessThanOrEqual(maxValue, 4)
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testAsyncFilterErrorThrowing() async throws {
        struct TaskError: Error {}

        do {
            _ = try await(1...8).asyncFilter { element -> Bool in
                if element == 4 {
                    throw TaskError()
                }
                return Bool.random()
            }
            XCTFail("Should have failed")
        } catch is TaskError {
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testConcurrentFilterErrorThrowing() async throws {
        struct TaskError: Error {}

        do {
            _ = try await(1...8).concurrentFilter { element -> Bool in
                if element == 4 {
                    throw TaskError()
                }
                return Bool.random()
            }
            XCTFail("Should have failed")
        } catch is TaskError {
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testAsyncFilterCancellation() async throws {
        let count = Count(1)

        let array = Array((1...8).reversed())
        let task = Task {
            _ = try await array.asyncFilter { value -> Bool in
                try await Task.sleep(nanoseconds: numericCast(value) * 1000 * 100)
                await count.mul(value)
                return Bool.random()
            }
        }
        try await Task.sleep(nanoseconds: 15 * 1000 * 100)
        task.cancel()
        let value = await count.value
        XCTAssertNotEqual(value, 1 * 2 * 3 * 4 * 5 * 6 * 7 * 8)
    }

    func testConcurrentFilterCancellation() async throws {
        let count = Count(1)

        let array = Array((1...8).reversed())
        let task = Task {
            _ = try await array.concurrentFilter { value -> Bool in
                try await Task.sleep(nanoseconds: numericCast(value) * 1000 * 100)
                await count.mul(value)
                return Bool.random()
            }
        }
        try await Task.sleep(nanoseconds: 1 * 1000 * 100)
        task.cancel()
        let value = await count.value
        XCTAssertNotEqual(value, 1 * 2 * 3 * 4 * 5 * 6 * 7 * 8)
    }
}
