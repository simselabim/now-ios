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
