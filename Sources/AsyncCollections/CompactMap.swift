
extension Sequence where Element: Sendable {
    /// Returns an array containing the non-`nil` results of calling the given
    /// transformation with each element of this sequence.
    ///
    /// Use this method to receive an array of non-optional values when your
    /// transformation produces an optional value.
    ///
    /// The closure calls are made serially. The next call is only made once the previous call
    /// has finished. Returns once the closure has run on all the elements of the Sequence
    /// or when the closure throws an error.
    /// - Parameter transform: An async  mapping closure. transform accepts an
    ///     element of this sequence as its parameter and returns a transformed value of
    ///     the same or of a different type.
    /// - Returns: An array containing the transformed elements of this sequence.
    public func asyncCompactMap<T>(_ transform: @Sendable (Element) async throws -> T?) async rethrows -> [T] {
        var result = ContiguousArray<T>()

        var iterator = self.makeIterator()

        // Add remaining elements, if any.
        while let next = iterator.next() {
            if let element = try await transform(next) {
                result.append(element)
            }
        }
        return Array(result)
    }

    /// Returns an array containing, in order, the non-`nil` results of calling the given
    /// transformation with each element of this sequence.
    ///
    /// Use this method to receive an array of non-optional values when your
    /// transformation produces an optional value.
    ///
    /// This differs from `asyncCompactMap` in that it uses a `TaskGroup` to run the transform
    /// closure for all the elements of the Sequence. This allows all the transform closures
    /// to run concurrently instead of serially. Returns only when the closure has been run
    /// on all the elements of the Sequence.
    /// - Parameters:
    ///   - priority: Task priority for tasks in TaskGroup
    ///   - isIncluded: An async closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be included in the returned array.
    /// - Returns: An array of the elements that `isIncluded` allowed.
    public func concurrentCompactMap<T: Sendable>(priority: TaskPriority? = nil, _ isIncluded: @Sendable @escaping (Element) async throws -> T?) async rethrows -> [T] {
        let result: ContiguousArray<(Int, T)> = try await withThrowingTaskGroup(
            of: (Int, T)?.self
        ) { group in
            for (index, element) in self.enumerated() {
                group.addTask(priority: priority) {
                    if let transformed = try await isIncluded(element) {
                        return (index, transformed)
                    } else {
                        return nil
                    }
                }
            }
            // Code for collating results copied from Sequence.map in Swift codebase
            var result = ContiguousArray<(Int, T)>()

            // Add all the elements.
            while let next = try await group.next() {
                if let enumerated = next {
                    result.append(enumerated)
                }
            }
            return result
        }

        return result.sorted(by: { $0.0 < $1.0 }).map(\.1)
    }

    /// Returns an array containing, in order, the non-`nil` results of calling the given
    /// transformation with each element of this sequence.
    ///
    /// Use this method to receive an array of non-optional values when your
    /// transformation produces an optional value.
    ///
    /// This differs from `asyncCompactMap` in that it uses a `TaskGroup` to run the transform
    /// closure for all the elements of the Sequence. This allows all the transform closures
    /// to run concurrently instead of serially. Returns only when the closure has been run
    /// on all the elements of the Sequence.
    /// - Parameters:
    ///   - maxConcurrentTasks: Maximum number of tasks to running at the same time
    ///   - priority: Task priority for tasks in TaskGroup
    ///   - isIncluded: An async closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be included in the returned array.
    /// - Returns: An array of the elements that `isIncluded` allowed.
    public func concurrentCompactMap<T: Sendable>(maxConcurrentTasks: Int, priority: TaskPriority? = nil, _ isIncluded: @Sendable @escaping (Element) async throws -> T?) async rethrows -> [T] {
        let result: ContiguousArray<(Int, T)> = try await withThrowingTaskGroup(
            of: (Int, T)?.self
        ) { group in
            var result = ContiguousArray<(Int, T)>()

            for (index, element) in self.enumerated() {
                if index >= maxConcurrentTasks {
                    if let enumerated = try await group.next() ?? nil {
                        result.append(enumerated)
                    }
                }
                group.addTask(priority: priority) {
                    if let transformed = try await isIncluded(element) {
                        return (index, transformed)
                    } else {
                        return nil
                    }
                }
            }

            // Add remaining elements, if any.
            while let next = try await group.next() {
                if let enumerated = next {
                    result.append(enumerated)
                }
            }
            return result
        }

        return result.sorted(by: { $0.0 < $1.0 }).map(\.1)
    }
}
