import CoreLocation
import XCTest
@testable import NOW

final class ProductFeatureAvailabilityTests: XCTestCase {
    func testTomorrowExtensionIsHiddenFromMatchScreen() {
        XCTAssertFalse(ProductFeatureAvailability.tomorrowExtension)
    }

    func testNowConfirmationIsHiddenFromMeetingProposalScreen() {
        XCTAssertFalse(ProductFeatureAvailability.meetingProposalNowConfirmation)
    }
}

final class AuthenticationFormValidationTests: XCTestCase {
    func testRegistrationRequiresEmailAndPasswordAndFocusesEmailFirst() {
        let validation = AuthenticationFormValidator.validate(
            mode: .registration,
            email: "   ",
            password: ""
        )

        XCTAssertEqual(validation.emailError, "Email is required.")
        XCTAssertEqual(validation.passwordError, "Password is required.")
        XCTAssertEqual(validation.firstInvalidField, .email)
    }

    func testRegistrationRejectsInvalidEmailAndShortPassword() {
        let validation = AuthenticationFormValidator.validate(
            mode: .registration,
            email: "not-an-email",
            password: "short"
        )

        XCTAssertEqual(validation.emailError, "Enter a valid email.")
        XCTAssertEqual(validation.passwordError, "Password must be at least 8 characters.")
    }

    func testRegistrationErrorsDisappearWhenValuesBecomeValid() {
        let validation = AuthenticationFormValidator.validate(
            mode: .registration,
            email: "person@example.com",
            password: "password"
        )

        XCTAssertNil(validation.emailError)
        XCTAssertNil(validation.passwordError)
        XCTAssertNil(validation.firstInvalidField)
    }

    func testSignInDoesNotUseRegistrationSpecificValidation() {
        let validation = AuthenticationFormValidator.validate(
            mode: .signIn,
            email: "",
            password: ""
        )

        XCTAssertNil(validation.emailError)
        XCTAssertNil(validation.passwordError)
    }

    func testExistingAccountServerErrorIsAttachedToEmail() {
        let error = APIError.server(statusCode: 409, message: "email already exists")

        XCTAssertEqual(
            RegistrationServerErrorMapper.fieldError(for: error),
            .email("An account with this email already exists. Sign in instead.")
        )
    }

    func testUnrelatedServerErrorDoesNotBecomeAFieldError() {
        let error = APIError.server(statusCode: 500, message: "internal error")

        XCTAssertNil(RegistrationServerErrorMapper.fieldError(for: error))
    }

    func testServerConflictIsPresentedWithoutDebugWrapper() {
        let error = APIError.server(
            statusCode: 409,
            message: "conflict: this pair already matched today"
        )

        XCTAssertEqual(
            APIErrorMessagePresenter.message(for: error),
            "This pair already matched today."
        )
    }

    func testInternalServerMessageIsNotExposed() {
        let error = APIError.server(statusCode: 500, message: "database connection failed")

        XCTAssertEqual(
            APIErrorMessagePresenter.message(for: error),
            "The server could not complete the request. Please try again."
        )
    }
}

final class TodayIntentSelectionTests: XCTestCase {
    func testGoOnlineIsEnabledWithNoSelections() {
        XCTAssertTrue(GoOnlineActionPolicy.isEnabled(isLoading: false))
        XCTAssertFalse(GoOnlineActionPolicy.isEnabled(isLoading: true))
    }

    func testVoiceOverReportsSelectionState() {
        XCTAssertEqual(IntentOptionAccessibility.value(isSelected: true), "Selected")
        XCTAssertEqual(IntentOptionAccessibility.value(isSelected: false), "Not selected")
    }

    func testEveryCategorySupportsZeroThroughThreeSelections() {
        var plans = Set<Plan>()
        var intents = Set<Intent>()
        var times = Set<TimeWindow>()

        for (index, plan) in Plan.goOnlineOptions.enumerated() {
            plans.toggleMembership(of: plan)
            XCTAssertEqual(plans.count, index + 1)
        }
        for (index, intent) in Intent.goOnlineOptions.enumerated() {
            intents.toggleMembership(of: intent)
            XCTAssertEqual(intents.count, index + 1)
        }
        for (index, time) in TimeWindow.goOnlineOptions.enumerated() {
            times.toggleMembership(of: time)
            XCTAssertEqual(times.count, index + 1)
        }

        Plan.goOnlineOptions.forEach { plans.toggleMembership(of: $0) }
        Intent.goOnlineOptions.forEach { intents.toggleMembership(of: $0) }
        TimeWindow.goOnlineOptions.forEach { times.toggleMembership(of: $0) }
        XCTAssertTrue(plans.isEmpty)
        XCTAssertTrue(intents.isEmpty)
        XCTAssertTrue(times.isEmpty)
    }

    func testAllNineSelectionsAndRestoredIntentArePreserved() {
        let allSelected = TodayIntent(
            plans: Set(Plan.goOnlineOptions),
            intents: Set(Intent.goOnlineOptions),
            timeWindows: Set(TimeWindow.goOnlineOptions)
        )
        let restored = TodayIntent(
            plans: allSelected.plans,
            intents: allSelected.intents,
            timeWindows: allSelected.timeWindows
        )

        XCTAssertEqual(allSelected.plans.count, 3)
        XCTAssertEqual(allSelected.intents.count, 3)
        XCTAssertEqual(allSelected.timeWindows.count, 3)
        XCTAssertEqual(restored, allSelected)
    }

    func testLegacySingleValuesDecodeAsOneElementArrays() throws {
        let data = Data(
            #"{"id":"11111111-1111-1111-1111-111111111111","user_id":"22222222-2222-2222-2222-222222222222","intent_date":"2026-08-18","plans":"coffee","intents":"friendly","times_today":"now","created_at":"2026-08-18T00:00:00Z","updated_at":"2026-08-18T00:00:00Z"}"#.utf8
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(TodayIntentDTO.self, from: data)

        XCTAssertEqual(decoded.plans, [.coffee])
        XCTAssertEqual(decoded.intents, [.friendly])
        XCTAssertEqual(decoded.timesToday, [.now])
    }
}

final class MeetingModeChatTests: XCTestCase {
    func testLoopThumbnailLetsOuterButtonReceiveTap() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("NOW/Features/Chat/ChatScreen.swift"),
            encoding: .utf8
        )
        let loopSlotStart = try XCTUnwrap(source.range(of: "private struct LoopSlot")?.lowerBound)
        let loopSlotEnd = try XCTUnwrap(source.range(of: "enum MatchLoopSlot")?.lowerBound)
        let loopSlotSource = source[loopSlotStart..<loopSlotEnd]

        XCTAssertTrue(loopSlotSource.contains("Button(action: onTap)"))
        XCTAssertTrue(loopSlotSource.contains(".allowsHitTesting(false)"))
    }

    func testMatchLoopViewerOpensOnlyOneLoopAtATime() {
        var state = MatchLoopViewerState()

        state.open(.mine)
        let firstPlaybackID = state.selection?.playbackID
        XCTAssertEqual(state.selection?.slot, .mine)

        state.open(.theirs)

        XCTAssertEqual(state.selection?.slot, .theirs)
        XCTAssertNotEqual(state.selection?.playbackID, firstPlaybackID)
    }

    func testMatchLoopViewerClosesWhenTappingOutsideVideo() {
        var state = MatchLoopViewerState()
        state.open(.mine)

        state.close()

        XCTAssertNil(state.selection)
    }

    func testReopeningSameLoopCreatesFreshPlaybackSession() {
        var state = MatchLoopViewerState()
        state.open(.mine)
        let firstPlaybackID = state.selection?.playbackID
        state.close()

        state.open(.mine)

        XCTAssertEqual(state.selection?.slot, .mine)
        XCTAssertNotEqual(state.selection?.playbackID, firstPlaybackID)
    }

    func testMeetingModeLoopViewerSupportsBothCirclesSwitchingAndExitCleanup() {
        var state = MatchLoopViewerState()

        state.open(.mine)
        XCTAssertEqual(state.selection?.slot, .mine)

        let myPlaybackID = state.selection?.playbackID
        state.open(.theirs)
        XCTAssertEqual(state.selection?.slot, .theirs)
        XCTAssertNotEqual(state.selection?.playbackID, myPlaybackID)

        state.close()
        XCTAssertNil(state.selection)
    }

    func testMessageTimelineDeduplicatesAndSortsChronologically() {
        let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let messages = [
            Message(id: secondID, sender: .them, text: "Second", createdAt: start.addingTimeInterval(2)),
            Message(id: firstID, sender: .me, text: "First", createdAt: start),
            Message(id: secondID, sender: .them, text: "Second", createdAt: start.addingTimeInterval(2))
        ]

        let normalized = MessageTimeline.normalized(messages)

        XCTAssertEqual(normalized.map(\.id), [firstID, secondID])
    }

    func testServerSequenceOverridesTimestampsForCanonicalOrder() {
        let firstID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let secondID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let sameDeviceTime = Date(timeIntervalSince1970: 1_700_000_005)
        let messages = [
            Message(
                id: secondID,
                sender: .them,
                text: "Second",
                createdAt: sameDeviceTime.addingTimeInterval(-60),
                sequence: 2
            ),
            Message(
                id: firstID,
                sender: .me,
                text: "First",
                createdAt: sameDeviceTime,
                sequence: 1
            )
        ]

        XCTAssertEqual(MessageTimeline.normalized(messages).map(\.id), [firstID, secondID])
    }

    func testPendingMessageStaysAfterServerSequencedHistoryUntilAck() {
        let pendingID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let confirmedID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let pending = Message(
            id: pendingID,
            sender: .me,
            text: "Pending",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            clientMessageId: pendingID,
            deliveryState: .sending
        )
        let confirmed = Message(
            id: confirmedID,
            sender: .them,
            text: "Confirmed",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            sequence: 4
        )

        XCTAssertEqual(
            MessageTimeline.normalized([pending, confirmed]).map(\.id),
            [confirmedID, pendingID]
        )
    }

    func testHistoryAndRealtimeMergeUsesServerSequenceAndDeduplicates() {
        let firstClientID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let secondClientID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let firstServerID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let secondServerID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let sameTimestamp = Date(timeIntervalSince1970: 1_700_000_200)
        let first = Message(
            id: firstServerID,
            sender: .me,
            text: "First",
            createdAt: sameTimestamp,
            clientMessageId: firstClientID,
            sequence: 41
        )
        let second = Message(
            id: secondServerID,
            sender: .them,
            text: "Second",
            createdAt: sameTimestamp,
            clientMessageId: secondClientID,
            sequence: 42
        )

        let merged = MessageTimeline.reconciled(
            local: [second, second],
            authoritative: [second, first]
        )

        XCTAssertEqual(merged.map(\.clientMessageId), [firstClientID, secondClientID])
        XCTAssertEqual(merged.map(\.sequence), [41, 42])
    }

    func testReconnectReplacesPendingMessageWithAuthoritativeAckWithoutDuplicate() {
        let clientID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let serverID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let pending = Message(
            id: clientID,
            sender: .me,
            text: "On my way",
            createdAt: Date(timeIntervalSince1970: 1_700_000_010),
            clientMessageId: clientID,
            deliveryState: .sending
        )
        let authoritative = Message(
            id: serverID,
            sender: .me,
            text: "On my way",
            createdAt: Date(timeIntervalSince1970: 1_700_000_011),
            clientMessageId: clientID,
            sequence: 12
        )

        let reconciled = MessageTimeline.reconciled(
            local: [pending],
            authoritative: [authoritative]
        )

        XCTAssertEqual(reconciled.count, 1)
        XCTAssertEqual(reconciled[0].clientMessageId, clientID)
        XCTAssertEqual(reconciled[0].serverId, serverID)
        XCTAssertEqual(reconciled[0].sequence, 12)
        XCTAssertEqual(reconciled[0].deliveryState, .sent)
    }

    func testStaleReconnectSnapshotDoesNotRemoveNewerLocalMessages() {
        let first = Message(
            id: UUID(),
            sender: .them,
            text: "First",
            createdAt: Date(timeIntervalSince1970: 1_700_000_020)
        )
        let second = Message(
            id: UUID(),
            sender: .me,
            text: "Second",
            createdAt: Date(timeIntervalSince1970: 1_700_000_021)
        )

        let reconciled = MessageTimeline.reconciled(
            local: [first, second],
            authoritative: [first]
        )

        XCTAssertEqual(reconciled.map(\.text), ["First", "Second"])
    }

    func testFailedMessageRetryKeepsStableClientMessageID() {
        let clientID = UUID()
        let failed = Message(
            id: clientID,
            sender: .me,
            text: "Retry me",
            createdAt: Date(),
            clientMessageId: clientID,
            deliveryState: .failed("No connection")
        )

        let retrying = MessageTimeline.updating(
            [failed],
            clientMessageId: clientID,
            deliveryState: .sending
        )

        XCTAssertEqual(retrying.count, 1)
        XCTAssertEqual(retrying[0].clientMessageId, clientID)
        XCTAssertEqual(retrying[0].deliveryState, .sending)
    }

    func testRapidPendingMessagesRemainIndependentlyVisible() {
        let start = Date(timeIntervalSince1970: 1_700_000_030)
        let rapidMessages = (0..<3).map { offset in
            let clientID = UUID()
            return Message(
                id: clientID,
                sender: .me,
                text: "Rapid \(offset)",
                createdAt: start.addingTimeInterval(Double(offset)),
                clientMessageId: clientID,
                deliveryState: .sending
            )
        }

        let normalized = MessageTimeline.normalized(rapidMessages)

        XCTAssertEqual(normalized.count, 3)
        XCTAssertEqual(Set(normalized.map(\.clientMessageId)).count, 3)
        XCTAssertTrue(normalized.allSatisfy { $0.deliveryState == .sending })
    }

    func testMeetingPanelStartsAboveMinimumAndExpandsForKeyboard() {
        let containerHeight: CGFloat = 844
        let initial = MeetingChatPanelMetrics.defaultHeight(containerHeight: containerHeight)
        let expanded = MeetingChatPanelMetrics.expandedHeight(containerHeight: containerHeight)

        XCTAssertGreaterThan(initial, MeetingChatPanelMetrics.minimumHeight)
        XCTAssertGreaterThan(expanded, initial)
        XCTAssertEqual(
            MeetingChatPanelMetrics.clampedHeight(10_000, containerHeight: containerHeight),
            expanded
        )
        XCTAssertLessThan(MeetingChatPanelMetrics.collapsedHeight, MeetingChatPanelMetrics.minimumHeight)
    }

    func testMeetingInformationIsVisibleOnlyWhenFullyExpandedWithoutKeyboard() {
        let containerHeight: CGFloat = 844
        let expandedHeight = MeetingChatPanelMetrics.expandedHeight(
            containerHeight: containerHeight
        )
        let intermediateHeight = MeetingChatPanelMetrics.defaultHeight(
            containerHeight: containerHeight
        )

        XCTAssertTrue(
            MeetingInformationVisibilityPolicy.showsInformation(
                panelHeight: expandedHeight,
                containerHeight: containerHeight,
                isPanelCollapsed: false,
                isKeyboardVisible: false
            )
        )
        XCTAssertFalse(
            MeetingInformationVisibilityPolicy.showsInformation(
                panelHeight: expandedHeight,
                containerHeight: containerHeight,
                isPanelCollapsed: false,
                isKeyboardVisible: true
            )
        )
        XCTAssertFalse(
            MeetingInformationVisibilityPolicy.showsInformation(
                panelHeight: intermediateHeight,
                containerHeight: containerHeight,
                isPanelCollapsed: false,
                isKeyboardVisible: false
            )
        )
        XCTAssertFalse(
            MeetingInformationVisibilityPolicy.showsInformation(
                panelHeight: expandedHeight,
                containerHeight: containerHeight,
                isPanelCollapsed: true,
                isKeyboardVisible: false
            )
        )
    }

    func testExpandedMeetingPanelStaysExpandedAcrossKeyboardGeometryChanges() {
        let fullScreenHeight: CGFloat = 844
        let keyboardScreenHeight: CGFloat = 500
        let fullExpandedHeight = MeetingChatPanelMetrics.expandedHeight(
            containerHeight: fullScreenHeight
        )

        let keyboardExpandedHeight = MeetingInformationVisibilityPolicy.adjustedPanelHeight(
            fullExpandedHeight,
            oldContainerHeight: fullScreenHeight,
            newContainerHeight: keyboardScreenHeight
        )
        let restoredExpandedHeight = MeetingInformationVisibilityPolicy.adjustedPanelHeight(
            keyboardExpandedHeight,
            oldContainerHeight: keyboardScreenHeight,
            newContainerHeight: fullScreenHeight
        )

        XCTAssertEqual(
            keyboardExpandedHeight,
            MeetingChatPanelMetrics.expandedHeight(containerHeight: keyboardScreenHeight)
        )
        XCTAssertEqual(restoredExpandedHeight, fullExpandedHeight)
    }

    func testIntermediateMeetingPanelStaysIntermediateAcrossHeightChanges() {
        let fullScreenHeight: CGFloat = 844
        let keyboardScreenHeight: CGFloat = 500
        let intermediateHeight = MeetingChatPanelMetrics.defaultHeight(
            containerHeight: fullScreenHeight
        )

        let adjustedHeight = MeetingInformationVisibilityPolicy.adjustedPanelHeight(
            intermediateHeight,
            oldContainerHeight: fullScreenHeight,
            newContainerHeight: keyboardScreenHeight
        )

        XCTAssertEqual(
            adjustedHeight,
            MeetingChatPanelMetrics.clampedHeight(
                intermediateHeight,
                containerHeight: keyboardScreenHeight
            )
        )
    }

    func testWeMetConfirmationFlagDecodesForCurrentParticipant() throws {
        let data = Data(
            #"{"can_send_message":true,"can_create_proposal":true,"can_confirm_we_met":false,"has_confirmed_we_met":true}"#.utf8
        )
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let flags = try decoder.decode(ActiveMatchFlagsDTO.self, from: data)

        XCTAssertEqual(flags.hasConfirmedWeMet, true)
        XCTAssertFalse(flags.canConfirmWeMet)
    }

    func testCloseKindlyUsesDedicatedCancellationReason() {
        XCTAssertEqual(CancelReasonDTO.closedKindly.rawValue, "closed_kindly")
    }

    func testMatchScreensExposeCloseMatchInsteadOfCloseKindly() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePaths = [
            "NOW/Features/Loops/FirstLoopScreen.swift",
            "NOW/Features/MeetingMode/MeetingModeScreen.swift",
            "NOW/Features/MeetingProposal/MeetingProposalScreen.swift",
        ]

        for sourcePath in sourcePaths {
            let source = try String(
                contentsOf: repositoryURL.appendingPathComponent(sourcePath),
                encoding: .utf8
            )

            XCTAssertTrue(source.contains("Button(\"Close match\")"), sourcePath)
            XCTAssertFalse(source.contains("Button(\"Close kindly\")"), sourcePath)
            XCTAssertTrue(source.contains("appState.cancelMatch("), sourcePath)
        }

        let meetingModeSource = try String(
            contentsOf: repositoryURL.appendingPathComponent(
                "NOW/Features/MeetingMode/MeetingModeScreen.swift"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(meetingModeSource.contains("meeting-mode-close-kindly"))
    }
}

final class MeetingModeActionLayoutTests: XCTestCase {
    func testActionButtonsSplitSmallAndLargePhoneWidthsWithoutOverlap() {
        for availableWidth: CGFloat in [292, 402] {
            let frames = MeetingModeActionLayout.buttonFrames(availableWidth: availableWidth)

            XCTAssertEqual(frames.leading.width, frames.trailing.width, accuracy: 0.001)
            XCTAssertEqual(frames.leading.minX, 0, accuracy: 0.001)
            XCTAssertEqual(
                frames.trailing.minX - frames.leading.maxX,
                MeetingModeActionLayout.horizontalSpacing,
                accuracy: 0.001
            )
            XCTAssertEqual(frames.trailing.maxX, availableWidth, accuracy: 0.001)
            XCTAssertFalse(frames.leading.intersects(frames.trailing))
        }
    }

    func testComposerGapIsAtLeastHalfTheActionRowHeight() {
        XCTAssertGreaterThanOrEqual(
            MeetingModeActionLayout.composerGap,
            MeetingModeActionLayout.actionRowHeight / 2
        )
    }
}

final class LoopPlaybackAudioStateTests: XCTestCase {
    func testMuteControlStateMatchesPlayerAudioAndVoiceOverAction() {
        var state = LoopPlaybackAudioState(isMuted: false)

        XCTAssertFalse(state.isMuted)
        XCTAssertEqual(state.systemImageName, "speaker.wave.2.fill")
        XCTAssertEqual(state.accessibilityActionLabel, "Mute loop")

        state.mute()

        XCTAssertTrue(state.isMuted)
        XCTAssertEqual(state.systemImageName, "speaker.slash.fill")
        XCTAssertEqual(state.accessibilityActionLabel, "Unmute loop")

        state.unmute()

        XCTAssertFalse(state.isMuted)
        XCTAssertEqual(state.accessibilityActionLabel, "Mute loop")
    }

    func testFirstLoopScreenWiresTheExplicitMuteControl() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent(
                "NOW/Features/Loops/FirstLoopScreen.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("showsMuteControl: true"))
        XCTAssertTrue(source.contains("first-loop-mute-control"))
    }
}

final class MeetingProposalActionPolicyTests: XCTestCase {
    private let aliceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let bobID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    func testOnlyOtherParticipantCanAcceptPendingProposal() {
        let proposal = makeProposal(proposerUserID: aliceID)

        XCTAssertTrue(proposal.isAuthored(by: aliceID))
        XCTAssertFalse(proposal.canBeAccepted(by: aliceID))
        XCTAssertTrue(proposal.canBeAccepted(by: bobID))
        XCTAssertFalse(proposal.canBeAccepted(by: nil))
    }

    func testCounterproposalFlipsAcceptingParticipant() {
        let counterproposal = makeProposal(proposerUserID: bobID, version: 2)

        XCTAssertTrue(counterproposal.canBeAccepted(by: aliceID))
        XCTAssertFalse(counterproposal.canBeAccepted(by: bobID))
    }

    func testAcceptedProposalCannotBeAcceptedAgain() {
        let proposal = makeProposal(proposerUserID: aliceID, status: .accepted)

        XCTAssertFalse(proposal.canBeAccepted(by: bobID))
    }

    private func makeProposal(
        proposerUserID: UUID,
        version: Int = 1,
        status: MeetingProposalStatus = .pending
    ) -> MeetingProposal {
        MeetingProposal(
            id: UUID(),
            matchId: UUID(),
            proposerUserId: proposerUserID,
            version: version,
            placeExternalID: "apple:test-place",
            placeName: "Test Place",
            placeCategory: .cafe,
            placeAddress: "Test Address",
            coordinate: nil,
            proposedAt: Date().addingTimeInterval(1_800),
            time: "18:00",
            dateLabel: "Today",
            status: status
        )
    }
}

final class MeetingModeMapPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFreshMeetingModeShowsThreeMarkersAndServerAccuracyRadius() {
        let presentation = MeetingModeMapPresentation(
            userCoordinate: coordinate(latitude: -8.6478, longitude: 115.1385),
            partnerLocation: partnerLocation(expiresAt: now.addingTimeInterval(90)),
            meetingCoordinate: coordinate(latitude: -8.6500, longitude: 115.1400),
            now: now
        )

        XCTAssertEqual(presentation.markerCount, 3)
        XCTAssertEqual(presentation.partnerAccuracyRadiusM, 200)
    }

    func testExpiredPartnerLocationIsHiddenWithoutRemovingMeetingPlace() {
        let meetingCoordinate = coordinate(latitude: -8.6500, longitude: 115.1400)
        let presentation = MeetingModeMapPresentation(
            userCoordinate: coordinate(latitude: -8.6478, longitude: 115.1385),
            partnerLocation: partnerLocation(expiresAt: now.addingTimeInterval(-1)),
            meetingCoordinate: meetingCoordinate,
            now: now
        )

        XCTAssertNil(presentation.partnerLocation)
        XCTAssertEqual(presentation.markerCount, 2)
        XCTAssertEqual(presentation.meetingCoordinate?.latitude, meetingCoordinate.latitude)
        XCTAssertEqual(presentation.meetingCoordinate?.longitude, meetingCoordinate.longitude)
    }

    func testManualMapMovementDisablesLaterAutomaticFit() {
        var policy = MeetingModeCameraPolicy()

        XCTAssertTrue(policy.allowsAutomaticFit)
        policy.recordUserAdjustment()
        XCTAssertFalse(policy.allowsAutomaticFit)
    }

    private func partnerLocation(expiresAt: Date) -> PartnerMeetingLocation {
        PartnerMeetingLocation(
            coordinate: coordinate(latitude: -8.6485, longitude: 115.1390),
            accuracyRadiusM: 200,
            updatedAt: now,
            expiresAt: expiresAt
        )
    }

    private func coordinate(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
