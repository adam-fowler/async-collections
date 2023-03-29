import Collections
import Foundation

/// A Semaphore implementation that can be used with Swift Concurrency.
///
/// Waiting on this semaphore will not stall the underlying thread
///
/// Much of this is inspired by the implementation from Gwendal Roué found
/// here https://github.com/groue/Semaphore. It manages to avoid the recursive
/// lock by decrementing the semaphore counter inside the withTaskCancellationHandler
/// function.
public final class AsyncSemaphore: @unchecked Sendable {
    struct Suspension: Sendable {
        let continuation: UnsafeContinuation<Void, Error>
        let id: UUID

        init(_ continuation: UnsafeContinuation<Void, Error>, id: UUID) {
            self.continuation = continuation
            self.id = id
        }
    }

    /// Semaphore value
    private var value: Int
    /// queue of suspensions waiting on semaphore
    private var suspended: Deque<Suspension>
    /// lock. Can only access `suspended` and `missedSignals` inside lock
    private let _lock: NSLock

    /// Initialize AsyncSemaphore
    public init(value: Int = 0) {
        self.value = .init(value)
        self.suspended = []
        self._lock = .init()
    }

    // Lock functionality has been moved to its own functions to avoid warning about using
    // lock in an asynchronous context
    func lock() { self._lock.lock() }
    func unlock() { self._lock.unlock() }

    /// Signal (increments) semaphore
    /// - Returns: Returns if a task was awaken
    @discardableResult public func signal() -> Bool {
        self.lock()
        self.value += 1
        if self.value <= 0 {
            // if value after signal is <= 0 then there should be a suspended
            // task in the suspended array.
            if let suspension = suspended.popFirst() {
                self.unlock()
                suspension.continuation.resume()
            } else {
                self.unlock()
                fatalError("Cannot have a negative semaphore value without values in the suspension array")
            }
            return true
        } else {
            self.unlock()
        }
        return false
    }

    ///  Wait for or decrement a semaphore
    public func wait() async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            self.lock()
            self.value -= 1
            if self.value >= 0 {
                self.unlock()
                return
            }
            try await withUnsafeThrowingContinuation { (cont: UnsafeContinuation<Void, Error>) in
                if Task.isCancelled {
                    self.value += 1
                    self.unlock()
                    // if the state is cancelled, send cancellation error to continuation
                    cont.resume(throwing: CancellationError())
                } else {
                    // set state to suspended and add to suspended array
                    self.suspended.append(.init(cont, id: id))
                    self.unlock()
                }
            }
        } onCancel: {
            self.lock()
            if let index = self.suspended.firstIndex(where: { $0.id == id }) {
                // if we find the suspension in the suspended array the remove and resume
                // continuation with a cancellation error
                self.value += 1
                let suspension = self.suspended.remove(at: index)
                self.unlock()
                suspension.continuation.resume(throwing: CancellationError())
            } else {
                self.unlock()
            }
        }
    }
}

extension AsyncSemaphore {
    // used in tests
    func getValue() -> Int {
        return self._lock.withLock {
            self.value
        }
    }
}
