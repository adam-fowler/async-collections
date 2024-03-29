import Collections

/// Queue for managing the running of Tasks ensuring only so many concurrent tasks are
/// running at any one point in time.
///
/// TaskQueue can be used in conjunction with `concurrentMap` and `concurrentForEach`
/// to run concurrent tasks across a Sequence while limiting the number of concurrent
/// tasks running at one point in time e.g.
/// ```
/// let queue = TaskQueue(maxConcurrent: 8)
/// let result = await array.concurrentMap { element in
///     await queue.add { element in
///         await asyncOperation(element)
///     }
/// }
/// ```
@available(*, deprecated, message: "Use concurrentMap(maxConcurrentTasks:priority:transform:)")
public actor TaskQueue<Result: Sendable> {
    /// Task closure
    public typealias TaskFunc = @Sendable () async throws -> Result

    /// Task details stored in queue, body of operation and continuation
    /// to resume when task completes
    struct TaskDetails {
        let body: TaskFunc
        let continuation: UnsafeContinuation<Result, Error>
    }

    /// task queue
    var queue: Deque<TaskDetails>
    /// number of tasks in progress
    var numInProgress: Int
    /// maximum concurrent tasks that can run at any one time
    let maxConcurrentTasks: Int
    /// priority of tasks
    let priority: TaskPriority?

    /// Create task queue
    /// - Parameters:
    ///   - maxConcurrent: Maximum number of concurrent tasks queue allows
    ///   - priority: priority of queued tasks
    public init(maxConcurrentTasks: Int, priority: TaskPriority? = nil) {
        self.queue = .init()
        self.numInProgress = 0
        self.maxConcurrentTasks = maxConcurrentTasks
        self.priority = priority
    }

    /// Add task to queue
    ///
    /// - Parameter body: Body of task function
    /// - Returns: Result of task
    public func add(_ body: @escaping TaskFunc) async throws -> Result {
        return try await withUnsafeThrowingContinuation { cont in
            if numInProgress < maxConcurrentTasks {
                numInProgress += 1
                Task(priority: priority) {
                    await self.performTask(.init(body: body, continuation: cont))
                }
            } else {
                queue.append(.init(body: body, continuation: cont))
            }
        }
    }

    /// perform task and resume continuation
    func performTask(_ task: TaskDetails) async {
        do {
            let result = try await performTask(task.body)
            task.continuation.resume(returning: result)
        } catch {
            task.continuation.resume(throwing: error)
        }
    }

    /// perform task
    func performTask(_ function: TaskFunc) async rethrows -> Result {
        let result = try await function()
        // once task is complete if there are tasks on the queue then
        // initiate next task from queue.
        if let t = queue.popFirst(), !Task.isCancelled {
            Task(priority: self.priority) {
                await self.performTask(t)
            }
        } else {
            assert(self.numInProgress > 0)
            self.numInProgress -= 1
        }
        return result
    }
}
