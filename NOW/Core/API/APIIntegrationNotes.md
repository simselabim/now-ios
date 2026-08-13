# iOS API Integration Notes

This folder contains the first real backend integration layer for NOW iOS.

## Main Types

- `NOWAPIClient`: URLSession-based backend client.
- `APIEnvironment`: base URL config from the built app's `NOWAPIBaseURL` value.
- `AuthTokenStoring`: async token storage protocol.
- `UserDefaultsAuthTokenStore`: current local token store. Replace with Keychain before production.
- `BackendDTOs.swift`: request and response models matching the Rust backend.
- `MediaUploadService`: uploads bytes to the `upload_url` returned by `/media/upload-intent`.
- `PlaceSearchField`: shows nearby cafes as Apple Maps markers and resolves map or autocomplete selection into a confirmed name, address, and coordinate before a meeting proposal can be sent.

## Configured Backend

Use the backend embedded into the app build:

```swift
let client = NOWAPIClient(environment: .appDefault)
```

## Minimal Flow

```swift
let client = NOWAPIClient()
let media = MediaUploadService()

try await client.register(email: "person@example.com", password: "test-password")

let bootstrap = try await client.bootstrap()

let photoIntent = try await client.createUploadIntent(
    kind: .profilePhoto,
    contentType: "image/jpeg",
    fileSizeBytes: imageData.count
)
try await media.upload(data: imageData, intent: photoIntent)
try await client.uploadPhoto(storageKey: photoIntent.storageKey, position: 1, isMain: true)

let map = try await client.discoverMap()
let detail = try await client.activeMatchDetail()
```

## Current AppState Integration

`AppState` now uses `NOWAPIClient` for the first backend-driven path:

```text
Welcome
 -> Login or registration
 -> /app/bootstrap
 -> /events WebSocket
 -> /discover/map
 -> /discover/points/{point_id}
 -> like/pass
 -> event-driven active match state
 -> Apple Maps place search
 -> meeting proposal with confirmed place details
```

After reconnect or foreground activation, `AppState` fetches
`/matches/active/detail` once to reconcile the authoritative state. It does not
poll the active match while the WebSocket is healthy.

## Backend Docs

The backend source of truth lives in:

- `now_back/docs/openapi.yaml`
- `now_back/docs/mobile-dev-notes.md`
- [`now_back/docs/product-configuration.md`](https://github.com/simselabim/now_back/blob/main/docs/product-configuration.md)
