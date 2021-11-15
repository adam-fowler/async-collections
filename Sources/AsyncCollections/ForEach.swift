
extension Sequence {
    /// Run async closure for each member of a Sequence
    ///
    /// The closure calls are made serially. The next call is only made once the previous call
    /// has finished. Returns once the closure has run on all the elements of the Sequence
    /// or when the closure throws an error
    /// - Parameter body: Closure to be called for each element
    public func asyncForEach(_ body: @escaping (Element) async throws -> Void) async rethrows {
        for element in self {
            try await body(element)
        }
    }

    /// Run async closure for each member of a sequence
    ///
    /// This differs from `asyncForEach` in that it uses a `TaskGroup` to run closure
    /// for all the elements of the Sequence. So all the closures can run concurrently. Returns
    /// only when the closure has been run on all the elements of the Sequence.
    /// - Parameters:
    ///   - priority: Task priority for tasks in TaskGroup
    ///   - body: Closure to be called for each element
    public func concurrentForEach(priority: TaskPriority? = nil, _ body: @escaping (Element) async throws -> Void) async rethrows {
        try await withThrowingTaskGroup(of: Void.self) { group in
            self.forEach { element in
                group.addTask(priority: priority) {
                    try await body(element)
                }
            }
            try await group.waitForAll()
        }
    }

}
