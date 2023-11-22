import AsyncCollections
import XCTest

final class FlatMapTests: XCTestCase {
    func testAsyncFlatMap() async throws {
        let array = MereSequence(0..<80).map { _ in MereSequence(0..<8) }
        let result = try await array.asyncFlatMap { value -> MereSequence<Int> in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value
        }

        XCTAssertEqual(result, array.flatMap { $0 })
    }

    func testConcurrentFlatMap() async throws {
        let array = MereSequence(0..<800).map { _ in MereSequence(0..<8) }
        let result = try await array.concurrentFlatMap { value -> MereSequence<Int> in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value
        }

        XCTAssertEqual(result, array.flatMap { $0 })
    }

    func testConcurrentFlatMapWithString() async throws {
        let array = MereSequence(0..<800).map { _ in MereSequence(0..<8) }
        let result = try await array.concurrentFlatMap { value -> [String] in
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            return value.map(String.init)
        }

        XCTAssertEqual(result, array.flatMap { $0.map(String.init) })
    }

    func testAsyncFlatMapConcurrency() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<80).map { _ in Array(0..<8) }
        let result = try await array.asyncFlatMap { value -> Array<Int> in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value
        }

        XCTAssertEqual(result, array.flatMap { $0 })
        let maxValue = await maxCount.value
        XCTAssertEqual(maxValue, 1)
    }

    func testConcurrentFlatMapConcurrency() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<800).map { _ in Array(0..<8) }
        let result = try await array.concurrentFlatMap { value -> [Int] in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value
        }

        XCTAssertEqual(result, array.flatMap { $0 })
        let maxValue = await maxCount.value
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testConcurrentFlatMapConcurrencyWithMaxTasks() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = MereSequence(0..<800).map { _ in MereSequence(0..<8) }
        let result = try await array.concurrentFlatMap(maxConcurrentTasks: 4) {
            value -> MereSequence<Int> in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value
        }

        XCTAssertEqual(result, array.flatMap { $0 })
        let maxValue = await maxCount.value
        XCTAssertLessThanOrEqual(maxValue, 4)
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testConcurrentFlatMapConcurrencyWithMaxTasksWithArray() async throws {
        let count = Count(0)
        let maxCount = Count(0)

        let array = Array(0..<800).map { _ in Array(0..<8) }
        let result = try await array.concurrentFlatMap(maxConcurrentTasks: 4) { value -> [Int] in
            let c = await count.add(1)
            await maxCount.max(c)
            try await Task.sleep(nanoseconds: UInt64.random(in: 1000..<100_000))
            await count.add(-1)
            return value
        }

        XCTAssertEqual(result, array.flatMap { $0 })
        let maxValue = await maxCount.value
        XCTAssertLessThanOrEqual(maxValue, 4)
        XCTAssertGreaterThan(maxValue, 1)
    }

    func testAsyncFlatMapErrorThrowing() async throws {
        struct TaskError: Error {}

        do {
            _ = try await (1...8).asyncFlatMap { element -> [Int] in
                if element == 4 {
                    throw TaskError()
                }
                return [element]
            }
            XCTFail("Should have failed")
        } catch is TaskError {
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testConcurrentFlatMapErrorThrowing() async throws {
        struct TaskError: Error {}

        do {
            _ = try await (1...8).concurrentFlatMap { element -> MereSequence<Int> in
                if element == 4 {
                    throw TaskError()
                }
                return MereSequence([element])
            }
            XCTFail("Should have failed")
        } catch is TaskError {
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testAsyncFlatMapCancellation() async throws {
        let count = Count(1)

        let array = MereSequence((1...8).reversed()).map { MereSequence([$0]) }
        let task = Task {
            _ = try await array.asyncFlatMap { value -> MereSequence<Int> in
                let first = value.first(where: { _ in true })!
                try await Task.sleep(nanoseconds: numericCast(first) * 1000 * 100)
                await count.mul(first)
                return value
            }
        }
        try await Task.sleep(nanoseconds: 15 * 1000 * 100)
        task.cancel()
        let value = await count.value
        XCTAssertNotEqual(value, 1 * 2 * 3 * 4 * 5 * 6 * 7 * 8)
    }

    func testConcurrentFlatMapCancellation() async throws {
        let count = Count(1)

        let array = MereSequence((1...8).reversed()).map { MereSequence([$0]) }
        let task = Task {
            _ = try await array.concurrentFlatMap { value -> MereSequence<Int> in
                let first = value.first(where: { _ in true })!
                try await Task.sleep(nanoseconds: numericCast(first) * 1000 * 100)
                await count.mul(first)
                return value
            }
        }
        try await Task.sleep(nanoseconds: 1 * 1000 * 100)
        task.cancel()
        let value = await count.value
        XCTAssertNotEqual(value, 1 * 2 * 3 * 4 * 5 * 6 * 7 * 8)
    }
}

/// A base `Sequence` type.
private struct MereSequence<Element: Hashable>: Sequence {
    /// Use an unordered underlying sequence, no need to assume order.
    let underlying: Set<Element>

    /// Don't always return `self.underlying.count` to truly test the property as "underestimated".
    /// This will test the parts where there is a `for-loop`, followed by a `while let` and
    /// the `while let` is supposed to accumulate any remaining elements that are
    /// after `underestimatedCount` in the sequence's order.
    var underestimatedCount: Int {
        Bool.random() ? (self.underlying.count / 2) : self.underlying.count
    }

    struct Iterator: IteratorProtocol {
        var base: Set<Element>.Iterator

        mutating func next() -> Element? {
            self.base.next()
        }
    }

    func makeIterator() -> Iterator {
        Iterator(base: self.underlying.makeIterator())
    }

    init(_ sequence: some Sequence<Element>) {
        self.underlying = .init(sequence)
    }
}

extension MereSequence: Sendable where Element: Sendable { }
