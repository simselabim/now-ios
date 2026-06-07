# NOW Domain Models

## User

- id
- phone/email
- auth status
- created at
- updated at

## Profile

- id
- user id
- name
- age
- bio
- occupation
- languages
- interests
- publish status

## Photo

- id
- profile id
- url
- order
- is main

## IntroLoop

- id
- user id
- media url
- duration
- created at

## TodayIntent

- id
- user id
- local date
- plan
- intent
- time window

## OnlineSession

- id
- user id
- started at
- expires at
- status

## MapPoint

- id
- profile id
- approximate latitude
- approximate longitude
- distance
- state: unseen / viewed / interested
- plan
- intent
- available today

Hidden states:

- not now: hidden until tomorrow
- blocked: hidden permanently

## DailyView

- viewer user id
- viewed user id
- local date

## DailyLike

- from user id
- to user id
- local date
- status

## DailyPass

- from user id
- to user id
- local date

## Match

- id
- user a id
- user b id
- local date
- status: active / met / cancelled / expired
- created at
- closed at

## Loop

- id
- match id
- sender id
- media url
- phase: first / on_the_way
- duration
- created at

## Message

- id
- match id
- sender id
- text
- created at
- moderation status

## MeetingProposal

- id
- match id
- proposer id
- place name
- latitude
- longitude
- proposed time
- status

## MeetingStatus

- id
- match id
- user id
- status: on_my_way / arrived / delayed
- created at

## MeetingConfirmation

- id
- match id
- user id
- status: confirmed / disputed / reported / pending
- created at

## Report

- id
- reporter id
- reported user id
- match id
- reason
- details
- status

## Block

- blocker id
- blocked user id
- created at

## SafetyEvent

- id
- match id
- user id
- type
- metadata
- created at
