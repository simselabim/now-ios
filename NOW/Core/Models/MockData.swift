import Foundation
import CoreLocation

enum MockData {
    static let maya = UserProfile(
        id: UUID(),
        name: "Maya",
        age: 29,
        distance: "420 m",
        plan: .coffee,
        intent: .date,
        occupation: "Creative",
        languages: ["English", "Russian"],
        interests: ["Films", "Coffee", "Surfing", "Food", "Travel"],
        sharedInterests: ["Films", "Coffee", "Travel"],
        prompt: "I know the best breakfast places and too much about films."
    )

    static let ren = UserProfile(
        id: UUID(),
        name: "Ren",
        age: 31,
        distance: "760 m",
        plan: .walk,
        intent: .friendly,
        occupation: "Product",
        languages: ["English", "Indonesian"],
        interests: ["Design", "Walking", "Music", "Startups"],
        sharedInterests: ["Music"],
        prompt: "A good first meeting is simple, public, and easy to leave."
    )

    static let ana = UserProfile(
        id: UUID(),
        name: "Ana",
        age: 27,
        distance: "1.2 km",
        plan: .dinner,
        intent: .romantic,
        occupation: "Hospitality",
        languages: ["English", "Spanish"],
        interests: ["Food", "Dancing", "Beach", "Photography"],
        sharedInterests: ["Food", "Beach"],
        prompt: "Dinner, honest conversation, no pressure."
    )

    static let mapPoints: [MapPoint] = [
        MapPoint(
            id: UUID(),
            profile: maya,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.6504, longitude: 115.1387),
            state: .unseen,
            isMutualMock: true
        ),
        MapPoint(
            id: UUID(),
            profile: ren,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.6521, longitude: 115.1358),
            state: .unseen,
            isMutualMock: false
        ),
        MapPoint(
            id: UUID(),
            profile: ana,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.6488, longitude: 115.1411),
            state: .unseen,
            isMutualMock: false
        )
    ]

    static let history: [HistoryItem] = [
        HistoryItem(id: UUID(), name: "Noah", detail: "Walk yesterday", status: "Met")
    ]
}
