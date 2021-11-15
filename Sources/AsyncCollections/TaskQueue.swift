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
public actor TaskQueue<Result> {
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
    /// priority of queued tasks
    let priority: TaskPriority?

    /// Create task queue
    /// - Parameters:
    ///   - maxConcurrent: Maximum number of concurrent tasks queue allows
    ///   - priority: priority of queued tasks
    public init(maxConcurrentTasks: Int = 4, priority: TaskPriority? = nil) {
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
        if numInProgress < maxConcurrentTasks {
            return try await performTask(body)
        } else {
            return try await withUnsafeThrowingContinuation { cont in
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
        self.numInProgress += 1
        let result = try await function()
        // once task is complete if there are tasks on the queue then
        // initiate task from queue.
        if let t = queue.popFirst(), !Task.isCancelled {
            Task(priority: priority) {
                self.numInProgress -= 1
                await self.performTask(t)
            }
        } else {
            self.numInProgress -= 1
        }
        return result
    }
}
