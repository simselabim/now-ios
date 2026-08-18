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
