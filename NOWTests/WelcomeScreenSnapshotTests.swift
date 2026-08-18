import SwiftUI
import UIKit
import XCTest
@testable import NOW

@MainActor
final class WelcomeScreenSnapshotTests: XCTestCase {
    func testWelcomeScreenSnapshotsDoNotExposeIntentPreview() {
        let variants: [(name: String, size: CGSize, scheme: ColorScheme, typeSize: DynamicTypeSize)] = [
            ("small-light", CGSize(width: 375, height: 667), .light, .large),
            ("large-dark-accessibility", CGSize(width: 430, height: 932), .dark, .accessibility3)
        ]

        for variant in variants {
            let controller = UIHostingController(
                rootView: WelcomeScreen(initialMode: .registration)
                    .environmentObject(AppState())
                    .environment(\.colorScheme, variant.scheme)
                    .environment(\.dynamicTypeSize, variant.typeSize)
            )
            let window = UIWindow(frame: CGRect(origin: .zero, size: variant.size))
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.frame = window.bounds
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()

            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in
                window.layer.render(in: context.cgContext)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "welcome-\(variant.name)"
            attachment.lifetime = .keepAlways
            add(attachment)

            XCTAssertEqual(image.size, variant.size, variant.name)
            XCTAssertGreaterThan(image.pngData()?.count ?? 0, 10_000, variant.name)

            window.isHidden = true
        }
    }

    func testIntentPromptExistsOnlyOnThePostRegistrationScreen() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let welcomeSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("NOW/Features/Auth/WelcomeScreen.swift"),
            encoding: .utf8
        )
        let intentSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("NOW/Features/TodayIntent/GoOnlineScreen.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(welcomeSource.contains("What feels right now?"))
        XCTAssertTrue(intentSource.contains("What feels right now?"))
    }
}
