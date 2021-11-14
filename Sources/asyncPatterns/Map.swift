
extension Sequence {
    public func asyncMap<T>(_ transform: @escaping (Element) async throws -> T) async rethrows -> [T] {
        // Code for collating results copied from Sequence.map
        let initialCapacity = underestimatedCount
        var result = ContiguousArray<T>()
        result.reserveCapacity(initialCapacity)

        for element in self {
            try await result.append(transform(element))
        }
        return Array(result)
    }

    public func concurrentMap<T>(_ transform: @escaping (Element) async throws -> T) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            self.enumerated().forEach { element in
                group.addTask {
                    let result = try await transform(element.1)
                    return (element.0, result)
                }
            }
            // Code for collating results copied from Sequence.map
            let initialCapacity = underestimatedCount
            var result = ContiguousArray<(Int, T)>()
            result.reserveCapacity(initialCapacity)

            // Add elements up to the initial capacity without checking for regrowth.
            for _ in 0..<initialCapacity {
                try await result.append(group.next()!)
            }
            // Add remaining elements, if any.
            while let element = try await group.next() {
                result.append(element)
            }

            return Array(unsafeUninitializedCapacity: result.count) { buffer, count in
                for value in result {
                    buffer[value.0] = value.1
                }
                count = result.count
            }
        }
    }
}
