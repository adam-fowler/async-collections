import Collections

public actor TaskQueue<Result> {
    public typealias TaskFunc = () async throws -> Result
    struct TaskDetails {
        let cb: () async throws -> Result
        let continuation: UnsafeContinuation<Result, Error>
    }
    var queue: Deque<TaskDetails>
    var numInProgress: Int
    let maxConcurrent: Int

    public init(maxConcurrent: Int = 4) {
        self.queue = .init()
        self.numInProgress = 0
        self.maxConcurrent = maxConcurrent
    }
    
    public func addTask(_ function: @escaping TaskFunc) async throws -> Result {
        if numInProgress < maxConcurrent {
            return try await performTask(function)
        } else {
            return try await withUnsafeThrowingContinuation { cont in
                queue.append(.init(cb: function, continuation: cont))
            }
        }
    }
    
    func performTask(_ task: TaskDetails) async {
        do {
            let result = try await performTask(task.cb)
            task.continuation.resume(returning: result)
        } catch {
            task.continuation.resume(throwing: error)
        }
    }

    func performTask(_ function: TaskFunc) async rethrows -> Result {
        self.numInProgress += 1
        let result = try await function()
        if let t = queue.popFirst() {
            Task {
                self.numInProgress -= 1
                await self.performTask(t)
            }
        } else {
            self.numInProgress -= 1
        }
        return result
    }
}
