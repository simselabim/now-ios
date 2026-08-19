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
