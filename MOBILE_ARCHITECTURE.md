# NOW iOS Mobile Architecture

## App State Routing

The root router should be state-driven:

```text
if user is not authenticated:
  AuthFlow
else if profile is incomplete:
  OnboardingFlow
else if active match exists:
  MatchFlow
else:
  DiscoveryFlow
```

## Navigation Flows

### AuthFlow

```text
WelcomeScreen
LoginScreen
RegisterScreen
ForgotPasswordScreen
```

### OnboardingFlow

```text
CreateProfileScreen
UploadPhotosScreen
IntroLoopScreen
ProfileReviewScreen
```

### DiscoveryFlow

```text
GoOnlineScreen
TodayIntentScreen
DiscoveryMapScreen
ProfilePreviewSheet
```

Map point actions:

- `view`: marks point as viewed today.
- `interested`: marks point as interested today.
- `notNow`: hides point until tomorrow.
- `block`: hides user permanently.

Only `unseen`, `viewed`, and `interested` points are visible on the map.

### MatchFlow

```text
ActiveMatchScreen
FirstLoopScreen
TemporaryChatScreen
MeetingProposalScreen
MeetingModeScreen
WeMetConfirmationScreen
CancelMatchSheet
ReportUserScreen
```

### AccountFlow

```text
HistoryScreen
HistoryDetailScreen
SettingsScreen
EditProfileScreen
BlockedUsersScreen
SafetySettingsScreen
```

## Feature Modules

### Auth

Responsibilities:

- register
- login
- logout
- token refresh
- forgot password

### Profile

Responsibilities:

- create profile
- edit profile
- validate publishable profile
- upload photos
- upload intro loop
- block contact details in profile text

### TodayIntent

Responsibilities:

- plan: coffee / walk / lunch / dinner / activity
- intent: friendly / date / romantic / open-minded
- time today: now / lunch / afternoon / evening

### DiscoveryMap

Responsibilities:

- request location permission
- send location pings
- show approximate map points
- support point states
- open profile preview
- hide not-now and blocked users

### Match

Responsibilities:

- enforce one active match
- show match lifecycle
- cancel match
- expire match at end of day
- complete via We Met

### Loops

Responsibilities:

- record first loop
- upload first loop
- check mutual first loops
- unlock temporary chat

### Chat

Responsibilities:

- temporary chat only
- no empty messages
- block contacts, links, emails, phone numbers, and social handles
- close chat on We Met, cancel, or expiry

### Meeting

Responsibilities:

- create proposal
- edit proposal
- accept/reject proposal
- open meeting mode
- update status: on my way / arrived / delayed
- safety controls

### Safety

Responsibilities:

- report user
- block user
- emergency action
- safety event logging

## API Dependencies

The iOS client should depend on the same backend contract as Android:

```text
Auth API
Profile API
Media API
Online API
Discovery API
Interaction API
Match API
Loop API
Chat API
Meeting API
History API
Moderation API
Safety API
```

## Realtime Events

Preferred endpoint:

```text
WebSocket /matches/{match_id}/events
```

Events:

```text
message.created
loop.uploaded
chat.unlocked
meeting.proposed
meeting.accepted
meeting.status_changed
match.cancelled
match.expired
we_met.requested
safety.triggered
```
