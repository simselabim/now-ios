# NOW API Contract

## Auth

```text
POST /auth/register
POST /auth/login
POST /auth/logout
POST /auth/forgot-password
GET  /me
```

## Profile

```text
GET    /profiles/me
PUT    /profiles/me
POST   /profiles/me/photos
DELETE /profiles/me/photos/{photo_id}
POST   /profiles/me/intro-loop
GET    /profiles/{id}
```

## Online / Today Intent

```text
POST   /online
DELETE /online
PUT    /today-intent
GET    /today-intent/me
```

## Discovery

```text
GET  /discover/map
GET  /discover/points/{point_id}
POST /discover/profiles/{profile_id}/view
POST /discover/profiles/{profile_id}/like
POST /discover/profiles/{profile_id}/pass
```

## Match

```text
GET  /matches/active
GET  /matches/{match_id}
POST /matches/{match_id}/cancel
POST /matches/{match_id}/we-met
POST /matches/{match_id}/confirm
POST /matches/{match_id}/dispute
```

## Loops

```text
POST /matches/{match_id}/loops
GET  /matches/{match_id}/loops
```

## Chat

```text
GET  /matches/{match_id}/messages
POST /matches/{match_id}/messages
```

## Meeting

```text
POST /matches/{match_id}/meeting-proposals
PUT  /matches/{match_id}/meeting-proposals/{proposal_id}
POST /matches/{match_id}/meeting-proposals/{proposal_id}/accept
POST /matches/{match_id}/meeting-proposals/{proposal_id}/reject
POST /matches/{match_id}/meeting-status
```

## Moderation / Safety

```text
POST   /users/{id}/report
POST   /users/{id}/block
DELETE /users/{id}/block
GET    /blocks
POST   /matches/{match_id}/safety-events
POST   /matches/{match_id}/emergency
```

## History

```text
GET /history
GET /history/{id}
```
