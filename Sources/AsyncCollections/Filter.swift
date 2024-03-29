
extension Sequence where Element: Sendable {
    /// Returns an array containing, in order, the elements of the sequence
    /// that satisfy the given predicate.
    ///
    /// - Parameter isIncluded: An async closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be included in the returned array.
    /// - Returns: An array of the elements that `isIncluded` allowed.
    public func asyncFilter(_ isIncluded: @Sendable (Element) async throws -> Bool) async rethrows -> [Element] {
        var result = ContiguousArray<Element>()

        var iterator = self.makeIterator()

        while let element = iterator.next() {
            if try await isIncluded(element) {
                result.append(element)
            }
        }

        return Array(result)
    }

    /// Returns an array containing, in order, the elements of the sequence
    /// that satisfy the given predicate.
    ///
    /// This differs from `asyncFilter` in that it uses a `TaskGroup` to run the transform
    /// closure for all the elements of the Sequence. This allows all the transform closures
    /// to run concurrently instead of serially. Returns only when the closure has been run
    /// on all the elements of the Sequence.
    /// - Parameters:
    ///   - priority: Task priority for tasks in TaskGroup
    ///   - isIncluded: An async closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be included in the returned array.
    /// - Returns: An array of the elements that `isIncluded` allowed.
    public func concurrentFilter(priority: TaskPriority? = nil, _ isIncluded: @Sendable @escaping (Element) async throws -> Bool) async rethrows -> [Element] {
        let result: ContiguousArray<(Int, Element)> = try await withThrowingTaskGroup(
            of: (Int, Element)?.self
        ) { group in
            for (index, element) in self.enumerated() {
                group.addTask(priority: priority) {
                    if try await isIncluded(element) {
                        return (index, element)
                    } else {
                        return nil
                    }
                }
            }
            // Code for collating results copied from Sequence.map in Swift codebase
            var result = ContiguousArray<(Int, Element)>()

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

    /// Returns an array containing, in order, the elements of the sequence
    /// that satisfy the given predicate.
    ///
    /// This differs from `asyncFilter` in that it uses a `TaskGroup` to run the transform
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
    public func concurrentFilter(maxConcurrentTasks: Int, priority: TaskPriority? = nil, _ isIncluded: @Sendable @escaping (Element) async throws -> Bool) async rethrows -> [Element] {
        let result: ContiguousArray<(Int, Element)> = try await withThrowingTaskGroup(
            of: (Int, Element)?.self
        ) { group in
            var result = ContiguousArray<(Int, Element)>()

            for (index, element) in self.enumerated() {
                if index >= maxConcurrentTasks {
                    if let enumerated = try await group.next() ?? nil {
                        result.append(enumerated)
                    }
                }
                group.addTask(priority: priority) {
                    if try await isIncluded(element) {
                        return (index, element)
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
