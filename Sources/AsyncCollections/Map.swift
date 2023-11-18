
extension Sequence where Element: Sendable {
    /// Returns an array containing the results of mapping the given async closure over
    /// the sequence’s elements.
    ///
    /// The closure calls are made serially. The next call is only made once the previous call
    /// has finished. Returns once the closure has run on all the elements of the Sequence
    /// or when the closure throws an error.
    /// - Parameter transform: An async  mapping closure. transform accepts an
    ///     element of this sequence as its parameter and returns a transformed value of
    ///     the same or of a different type.
    /// - Returns: An array containing the transformed elements of this sequence.
    public func asyncMap<T>(_ transform: @Sendable (Element) async throws -> T) async rethrows -> [T] {
        let initialCapacity = underestimatedCount
        var result = ContiguousArray<T>()
        result.reserveCapacity(initialCapacity)

        var iterator = self.makeIterator()

        // Add elements up to the initial capacity without checking for regrowth.
        for _ in 0..<initialCapacity {
            result.append(try await transform(iterator.next()!))
        }
        // Add remaining elements, if any.
        while let element = iterator.next() {
            result.append(try await transform(element))
        }
        return Array(result)
    }

    /// Returns an array containing the results of mapping the given async closure over
    /// the sequence’s elements.
    ///
    /// This differs from `asyncMap` in that it uses a `TaskGroup` to run the transform
    /// closure for all the elements of the Sequence. This allows all the transform closures
    /// to run concurrently instead of serially. Returns only when the closure has been run
    /// on all the elements of the Sequence.
    /// - Parameters:
    ///   - priority: Task priority for tasks in TaskGroup
    ///   - transform: An async  mapping closure. transform accepts an
    ///     element of this sequence as its parameter and returns a transformed value of
    ///     the same or of a different type.
    /// - Returns: An array containing the transformed elements of this sequence.
    public func concurrentMap<T>(priority: TaskPriority? = nil, _ transform: @Sendable @escaping (Element) async throws -> T) async rethrows -> [T] {
        let result: ContiguousArray<(Int, T)> = try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, element) in self.enumerated() {
                group.addTask(priority: priority) {
                    let result = try await transform(element)
                    return (index, result)
                }
            }
            // Code for collating results copied from Sequence.map in Swift codebase
            let initialCapacity = underestimatedCount
            var result = ContiguousArray<(Int, T)>()
            result.reserveCapacity(initialCapacity)

            // Add elements up to the initial capacity without checking for regrowth.
            for _ in 0..<initialCapacity {
                try await result.append(group.next()!)
            }
            // Add remaining elements, if any.
            while let enumerated = try await group.next() {
                result.append(enumerated)
            }
            return result
        }
        // construct final array and fill in elements
        return [T](unsafeUninitializedCapacity: result.count) { buffer, count in
            for value in result {
                (buffer.baseAddress! + value.0).initialize(to: value.1)
            }
            count = result.count
        }
    }

    /// Returns an array containing the results of mapping the given async closure over
    /// the sequence’s elements.
    ///
    /// This differs from `asyncMap` in that it uses a `TaskGroup` to run the transform
    /// closure for all the elements of the Sequence. This allows all the transform closures
    /// to run concurrently instead of serially. Returns only when the closure has been run
    /// on all the elements of the Sequence.
    /// - Parameters:
    ///   - maxConcurrentTasks: Maximum number of tasks to running at the same time
    ///   - priority: Task priority for tasks in TaskGroup
    ///   - transform: An async  mapping closure. transform accepts an
    ///     element of this sequence as its parameter and returns a transformed value of
    ///     the same or of a different type.
    /// - Returns: An array containing the transformed elements of this sequence.
    public func concurrentMap<T>(maxConcurrentTasks: Int, priority: TaskPriority? = nil, _ transform: @Sendable @escaping (Element) async throws -> T) async rethrows -> [T] {
        let result: ContiguousArray<(Int, T)> = try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var results = ContiguousArray<(Int, T)>()
            for (index, element) in self.enumerated() {
                if index >= maxConcurrentTasks {
                    if let result = try await group.next() {
                        results.append(result)
                    }
                }
                group.addTask(priority: priority) {
                    let result = try await transform(element)
                    return (index, result)
                }
            }

            // Add remaining elements, if any.
            while let enumerated = try await group.next() {
                results.append(enumerated)
            }
            return results
        }
        // construct final array and fill in elements
        return [T](unsafeUninitializedCapacity: result.count) { buffer, count in
            for value in result {
                (buffer.baseAddress! + value.0).initialize(to: value.1)
            }
            count = result.count
        }
    }
}
