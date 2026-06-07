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

## First Build Target

Build a mock-driven navigation prototype first:

```text
Welcome
 -> Login/Register
 -> Create Profile
 -> Go Online
 -> Today Intent
 -> Discovery Map
 -> Profile Preview
 -> Active Match
 -> First Loops
 -> Temporary Chat
 -> Meeting Proposal
 -> Meeting Mode
 -> History
```

Do not port the web prototype. Use it only as product reference.
