# AsyncCollections

Functions for running async processes on Swift Collections

## ForEach

Run an async function on every element of a Sequence.
```swift
await array.asyncForEach {
    await asyncProcess($0)
}
```
The async closures are run serially ie the closure run on the current element of a sequence has to finish before we run the closure on the next element.

To run the closures concurrently use
```swift
try await array.concurrentForEach {
    try await asyncProcess($0)
}
```

## Map

Return an array transformed by an async function. 
```swift
let result = await array.asyncMap {
    return await asyncTransform($0)
}
```
Similar to `asyncForEach` there is a `concurrentMap` as well which will run the closures concurrently.

## TaskQueue

Use a `TaskQueue` to manage the number of concurrent tasks when processing a large sequence. 

```swift
let queue = TaskQueue<Int>(maxConcurrentTasks: 8)
let result = try await array.concurrentMap { value -> Int in
    try await queue.add {
        return await asyncTransform(value)
    }
}
```
