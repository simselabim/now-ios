# iOS API Integration Notes

This folder contains the first real backend integration layer for NOW iOS.

## Main Types

- `NOWAPIClient`: URLSession-based backend client.
- `APIEnvironment`: base URL config for simulator, Android reference, or physical device.
- `AuthTokenStoring`: async token storage protocol.
- `UserDefaultsAuthTokenStore`: current local token store. Replace with Keychain before production.
- `BackendDTOs.swift`: request and response models matching the Rust backend.
- `MediaUploadService`: uploads bytes to the `upload_url` returned by `/media/upload-intent`.

## Local Backend

Default iOS simulator base URL:

```swift
let client = NOWAPIClient(environment: .iOSSimulator)
```

Physical device on the same Wi-Fi:

```swift
let client = NOWAPIClient(environment: .physicalDevice(macLANIP: "192.168.1.10"))
```

## Minimal Flow

```swift
let client = NOWAPIClient()
let media = MediaUploadService()

try await client.login(email: "demo.ava@example.com", password: "password123")

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

## Backend Docs

The backend source of truth lives in:

- `now_back/docs/openapi.yaml`
- `now_back/docs/mobile-dev-notes.md`

