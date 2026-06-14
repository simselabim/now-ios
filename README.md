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
      APIClient.swift
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

Local simulator backend URL:

```text
http://127.0.0.1:8080
```

Before running the app, start the backend:

```bash
cd /Users/Sim_1/Documents/now/now_back
make db-up
make migrate
make seed-demo
make run
```

If command-line builds fail with Command Line Tools selected, switch to full Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then a simulator build should be:

```bash
xcodebuild -project NOW.xcodeproj -scheme NOW -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## First Build Target

The current target is a backend-driven navigation prototype:

```text
Welcome
 -> Demo Login
 -> Bootstrap
 -> Discovery Map
 -> Profile Preview
 -> Active Match
 -> First Loops
 -> Temporary Chat
```

Meeting proposal, meeting mode, and history screens still exist and are ready to
be wired to the backend next.

## Backend Integration Layer

The first real API layer lives in:

```text
NOW/Core/API/
NOW/Core/Storage/
NOW/Core/Media/
```

Start with `NOWAPIClient`, `APIEnvironment`, `AuthTokenStore`, backend DTOs, and
`MediaUploadService`. The local simulator default is `http://127.0.0.1:8080`.

Demo login:

```text
demo.ava@example.com / password123
```

`AppState` already uses this API layer for demo login, bootstrap, discovery map,
profile preview open, like/pass, first loop upload, temporary message sending,
and active match detail refresh.
