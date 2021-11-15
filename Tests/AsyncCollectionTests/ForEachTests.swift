import XCTest
import AsyncCollections

final class ForEachTests: XCTestCase {
    func testAsyncForEach() async {
        let count = Count(1)

        let primes = [2,3,5,7,11,13]
        await primes.asyncForEach { await count.mul($0) }

        let value = await count.value
        XCTAssertEqual(value, 2 * 3 * 5 * 7 * 11 * 13)
    }

    func testConcurrentForEach() async {
        let count = Count(1)

        let primes = [2,3,5,7,11,13]
        await primes.concurrentForEach { await count.mul($0) }

        let value = await count.value
        XCTAssertEqual(value, 2 * 3 * 5 * 7 * 11 * 13)
    }

    func testConcurrentAsyncForEach() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        try await (0..<8).asyncForEach { _ in
            let value = await count.add(1)
            await maxCount.max(value)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<1000*1000))
            await count.add(-1)
        }

        let maxValue = await maxCount.value
        XCTAssertEqual(maxValue, 1)
    }

    func testConcurrentConcurrentForEach() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        try await (0..<8).concurrentForEach { _ in
            let value = await count.add(1)
            await maxCount.max(value)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<1000*1000))
            await count.add(-1)
        }

        let maxValue = await maxCount.value
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testAsyncForEachIrregularDuration() async throws {
        let count = Count(1)

        let primes = [2,3,5,7,11,13]
        try await primes.asyncForEach {
            await count.mul($0)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<1000*1000))
        }

        let value = await count.value
        XCTAssertEqual(value, 2 * 3 * 5 * 7 * 11 * 13)
    }

    func testConcurrentForEachIrregularDuration() async throws {
        let count = Count(1)

        let primes = [2,3,5,7,11,13]
        try await primes.concurrentForEach {
            await count.mul($0)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<1000*1000))
        }

        let value = await count.value
        XCTAssertEqual(value, 2 * 3 * 5 * 7 * 11 * 13)
    }

    func testAsyncForEachErrorThrowing() async throws {
        struct TaskError: Error {}
        let count = Count(1)

        do {
            try await (1...8).asyncForEach {
                await count.mul($0)
                if $0 == 4 {
                    throw TaskError()
                }
            }
            XCTFail("Should have failed")
        } catch is TaskError {
            let value = await count.value
            XCTAssertNotEqual(value, 1*2*3*4*5*6*7*8)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testConcurrentForEachErrorThrowing() async throws {
        struct TaskError: Error {}
        let count = Count(1)

        let task = Task {
            try await (0..<8).concurrentForEach {
                await count.mul($0)
                if $0 == 4 {
                    throw TaskError()
                }
            }
        }
        switch await task.result {
        case .failure(let error):
            guard error is TaskError else {
                XCTFail("Error: \(error)")
                return
            }
        case .success:
            XCTFail("Should have failed")
        }
    }

    func testAsyncForEachCancellation() async throws {
        let count = Count(1)

        let primes = Array((1...8).reversed())
        let task = Task {
            try await primes.asyncForEach {
                try await Task.sleep(nanoseconds: numericCast($0) * 1000 * 100)
                await count.mul($0)
            }
        }
        try await Task.sleep(nanoseconds: 15 * 1000 * 100)
        task.cancel()

        let value = await count.value
        XCTAssertNotEqual(value, 1*2*3*4*5*6*7*8)
    }

    func testConcurrentForEachCancellation() async throws {
        let count = Count(1)

        let primes = Array((1...8).reversed())
        let task = Task {
            try await primes.asyncForEach {
                try await Task.sleep(nanoseconds: numericCast($0) * 1000 * 100)
                await count.mul($0)
            }
        }
        try await Task.sleep(nanoseconds: 10 * 1000 * 100)
        task.cancel()

        let value = await count.value
        XCTAssertNotEqual(value, 1*2*3*4*5*6*7*8)
    }
}

actor Count {
    var value: Int

    init(_ value: Int = 0) {
        self.value = value
    }

    func set(_ rhs: Int) {
        self.value = rhs
    }

    @discardableResult func add(_ rhs: Int) -> Int {
        self.value += rhs
        return self.value
    }

    @discardableResult func mul(_ rhs: Int) -> Int {
        self.value *= rhs
        return self.value
    }

    @discardableResult func min(_ rhs: Int) -> Int {
        self.value = Swift.min(self.value, rhs)
        return self.value
    }

    @discardableResult func max(_ rhs: Int) -> Int {
        self.value = Swift.max(self.value, rhs)
        return self.value
    }
}
