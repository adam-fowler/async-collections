
extension Sequence {
    public func asyncForEach(_ body: @escaping (Element) async throws -> Void) async rethrows {
        for element in self {
            try await body(element)
        }
    }

    public func concurrentForEach(_ body: @escaping (Element) async throws -> Void) async rethrows {
        try await withThrowingTaskGroup(of: Void.self) { group in
            self.forEach { element in
                group.addTask {
                    try await body(element)
                }
            }
            try await group.waitForAll()
        }
    }

}
