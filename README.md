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
You can manage the number of tasks running at any one time with the `maxConcurrentTasks` parameter
```swift
try await array.concurrentForEach(maxConcurrentTasks: 4) {
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

Similar to `asyncForEach` there are versions of `asyncMap` that runs the transforms concurrently.

```swift
let result = await array.concurrentMap(maxConcurrentTasks: 8) {
    return await asyncTransform($0)
}
```


