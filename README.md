# NOW iOS

Native iOS client for NOW.

NOW is a map-first mobile app for meeting one nearby person today. The iOS app should be built natively with Swift, SwiftUI, MapKit, CoreLocation, AVFoundation, and a backend API shared with Android.

## Product Core

- One active match at a time.
- One-day lifecycle for online sessions, likes, passes, matches, and temporary chat.
- Map-first discovery, no swipe deck.
- Discovery points are approximate, not exact user locations.
- `Not Now` hides a person until tomorrow.
- `Block` hides a person permanently.
- Mutual today-interest creates one active match.
- First loops unlock temporary chat.
- Meeting place and time should be confirmed through NOW for safety.

## Suggested Stack

- SwiftUI
- Swift Concurrency
- MapKit
- CoreLocation
- AVFoundation
- URLSession
- Keychain
- Native WebSocket

## Repository Layout

```text
NOW/
  App/
    NOWApp.swift
    AppRouter.swift
    AppState.swift

  Core/
    API/
      NOWAPIClient.swift
      Endpoint.swift
      AuthInterceptor.swift
    Models/
      User.swift
      Profile.swift
      TodayIntent.swift
      MapPoint.swift
      Match.swift
      Loop.swift
      Message.swift
      Meeting.swift
    Location/
      LocationService.swift
      LocationPermissionManager.swift
    Media/
      CameraService.swift
      UploadService.swift
    Realtime/
      WebSocketClient.swift
    Storage/
      TokenStorage.swift
    DesignSystem/
      Colors.swift
      Typography.swift
      Components/

  Features/
    Auth/
    Onboarding/
    Profile/
    TodayIntent/
    DiscoveryMap/
    ProfilePreview/
    Match/
    Loops/
    Chat/
    MeetingProposal/
    MeetingMode/
    History/
    Settings/
    Safety/
    Moderation/
```

## Xcode Project

Open the native app target:

```bash
open NOW.xcodeproj
```

Target:

```text
NOW
```

Default backend URL for simulator and phone builds:

```text
http://68.183.179.8:8080
```

For local-only development, override `NOW_API_BASE_URL` to `http://127.0.0.1:8080`
and start the backend:

```bash
cd /Users/dim4egster/my_projects/now_back
make db-up
make migrate
make run
```

If command-line builds fail with Command Line Tools selected, switch to full Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Current verified simulator:

```text
iPhone 17 / iOS 26.5
```

Build:

```bash
xcodebuild -project NOW.xcodeproj -scheme NOW -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build
```

Install and run the latest debug build:

```bash
APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -path '*/Build/Products/Debug-iphonesimulator/NOW.app' | sort | tail -n 1)"
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.sim.now
```

## Physical iPhone Staging Build

The app is configured to use the public staging backend by default:

```text
http://68.183.179.8:8080
```

Prerequisites on the Mac:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Open Xcode once, sign in with an Apple ID, select a development team, and trust
the iPhone. On the phone, enable Developer Mode if iOS asks for it.

List connected devices:

```bash
./scripts/build-device.sh devices
```

Build a phone app:

```bash
DEVELOPMENT_TEAM=<APPLE_TEAM_ID> \
BUNDLE_ID=com.example.now.staging \
./scripts/build-device.sh build
```

Install and launch on a connected iPhone:

```bash
DEVICE_ID=<IPHONE_DEVICE_ID> \
DEVELOPMENT_TEAM=<APPLE_TEAM_ID> \
BUNDLE_ID=com.example.now.staging \
RUN_AFTER_INSTALL=1 \
./scripts/build-device.sh install
```

`NOW_API_BASE_URL` is written into `Info.plist` at build time and read by
`NOWAPIClient`, so the same source build can target the local simulator,
LAN backend, or staging VPS.

## First Build Target

The current target is a backend-driven navigation prototype:

```text
Welcome
 -> Login or registration
 -> Bootstrap
 -> Discovery Map
 -> Profile Preview
 -> Active Match
 -> First Loops
 -> Temporary Chat
```

Meeting proposal, meeting mode, and history use the same backend-driven state.
Meeting proposals use Apple Maps autocomplete and require the user to select a
resolved place with a real name, address, and coordinate before submission.

## Backend Integration Layer

The first real API layer lives in:

```text
NOW/Core/API/
NOW/Core/Storage/
NOW/Core/Media/
```

Start with `NOWAPIClient`, `APIEnvironment`, `AuthTokenStore`, backend DTOs, and
`MediaUploadService`. The default backend is `http://68.183.179.8:8080`.

`AppState` uses this API layer for authentication, bootstrap, discovery map,
profile preview, like/pass, First Loop upload, chat, meeting state, history,
and realtime active-match updates. API failures remain visible and never switch
the app to locally fabricated user state.
