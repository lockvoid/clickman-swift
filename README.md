# ClickMan for Swift

ClickMan records analytics events on Apple platforms and sends them to a
ClickMan server. A local SQLite queue keeps events across restarts and offline
periods. The client sends gzip batches, retries failed requests, and tracks app
lifecycle events on iOS.

Requires Swift 6, iOS 16 or later, or macOS 13 or later. The package uses GRDB
for its queue and URLSession for delivery.

## Add the package

For a local checkout, add the package and library product to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../clickman-swift")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "ClickMan", package: "clickman-swift")
    ])
]
```

In Xcode, add the package directory as a local package and link the `ClickMan`
product to your app target.

## Record events

Create one client at app startup and keep it alive for the application's lifetime:

```swift
import ClickMan
import Foundation

let analytics = try ClickMan(configuration: .init(
    endpoint: URL(string: "https://analytics.example.com")!,
    writeKey: "your-project-write-key"
))
analytics.identify("user_42")
analytics.setTraits(["plan": "pro"])
analytics.track("page_viewed", properties: ["screen": "home"])
```

Opening the queue can throw. Tracking does not wait for the network; invalid
properties or storage failures are logged. Properties accept JSON values, plus
`Date`, `URL`, and `UUID` values encoded as strings.

Sending runs in the background. By default, a batch becomes due after 20 queued
events or 30 seconds. The client also attempts to flush when the network returns
or the iOS app enters the background. You can request a send explicitly with
`await analytics.flush()`; retry delays still apply.

## Configuration and identity

Set options before creating the client:

```swift
var configuration = ClickMan.Configuration(
    endpoint: URL(string: "https://analytics.example.com")!,
    writeKey: "your-project-write-key"
)
configuration.flushAt = 10
configuration.flushInterval = .seconds(15)
configuration.tracksLifecycle = false
let analytics = try ClickMan(configuration: configuration)
```

The default queue lives in Application Support, is excluded from backups, and
holds at most 10,000 events. `storage` selects a different file and `maxQueue`
changes the event limit. Call `reset()` after sign-out to clear identity and traits.

Use the server's base URL as `endpoint`: the client appends `/v1/batch`. For a
server mounted at `/analytics`, use `https://example.com/analytics`.

## Develop and test

```sh
swift test
python3 scripts/queue-schema.py --check
```

The [protocol](docs/PROTOCOL.md) covers event fields, queue behavior, identity,
and delivery rules. The [local protocol snapshot](protocol/README.md) includes
the shared fixtures used by tests; no server checkout is needed. The
`ClickManE2EWorker` executable is a command-line driver for integration tests.

## License

[MIT](LICENSE).
