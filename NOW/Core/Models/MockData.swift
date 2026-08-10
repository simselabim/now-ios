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
        occupation: "Female",
        languages: ["English", "Russian"],
        interests: ["Films", "Coffee", "Surfing", "Food", "Travel"],
        sharedInterests: ["Films", "Coffee", "Travel"],
        prompt: "I know the best breakfast places and too much about films.",
        mainPhotoURL: nil,
        introLoopURL: nil
    )

    static let ren = UserProfile(
        id: UUID(),
        name: "Ren",
        age: 31,
        distance: "760 m",
        plan: .walk,
        intent: .friendly,
        occupation: "Male",
        languages: ["English", "Indonesian"],
        interests: ["Design", "Walking", "Music", "Startups"],
        sharedInterests: ["Music"],
        prompt: "A good first meeting is simple, public, and easy to leave.",
        mainPhotoURL: nil,
        introLoopURL: nil
    )

    static let ana = UserProfile(
        id: UUID(),
        name: "Ana",
        age: 27,
        distance: "1.2 km",
        plan: .dinner,
        intent: .romantic,
        occupation: "Female",
        languages: ["English", "Spanish"],
        interests: ["Food", "Dancing", "Beach", "Photography"],
        sharedInterests: ["Food", "Beach"],
        prompt: "Dinner, honest conversation, no pressure.",
        mainPhotoURL: nil,
        introLoopURL: nil
    )

    static let leo = UserProfile(
        id: UUID(),
        name: "Leo",
        age: 34,
        distance: "310 m",
        plan: .lunch,
        intent: .friendly,
        occupation: "Male",
        languages: ["English", "French"],
        interests: ["Architecture", "Lunch", "Jazz", "Cities"],
        sharedInterests: ["Lunch", "Cities"],
        prompt: "Free for a quick lunch and a proper city walk after.",
        mainPhotoURL: nil,
        introLoopURL: nil
    )

    static let lina = UserProfile(
        id: UUID(),
        name: "Lina",
        age: 30,
        distance: "980 m",
        plan: .activity,
        intent: .openMinded,
        occupation: "Female",
        languages: ["English", "German"],
        interests: ["Galleries", "Pilates", "Wine", "Books"],
        sharedInterests: ["Galleries", "Books"],
        prompt: "I prefer a plan with a little movement and no interview energy.",
        mainPhotoURL: nil,
        introLoopURL: nil
    )

    static let ethan = UserProfile(
        id: UUID(),
        name: "Ethan",
        age: 32,
        distance: "1.5 km",
        plan: .coffee,
        intent: .date,
        occupation: "Male",
        languages: ["English"],
        interests: ["Coffee", "Running", "Cinema", "Markets"],
        sharedInterests: ["Coffee", "Cinema"],
        prompt: "Coffee first. If it works, we can decide the second stop together.",
        mainPhotoURL: nil,
        introLoopURL: nil
    )

    static let nora = UserProfile(
        id: UUID(),
        name: "Nora",
        age: 28,
        distance: "1.8 km",
        plan: .walk,
        intent: .romantic,
        occupation: "Female",
        languages: ["English", "Italian"],
        interests: ["Parks", "Poetry", "Design", "Dessert"],
        sharedInterests: ["Parks", "Design"],
        prompt: "A walk, one good question, and maybe dessert if there is a spark.",
        mainPhotoURL: nil,
        introLoopURL: nil
    )

    static let mapPoints: [MapPoint] = [
        MapPoint(
            id: UUID(),
            profile: maya,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.667630, longitude: 115.139708),
            state: .unseen,
            isMutualMock: true
        ),
        MapPoint(
            id: UUID(),
            profile: ren,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.669330, longitude: 115.136808),
            state: .unseen,
            isMutualMock: false
        ),
        MapPoint(
            id: UUID(),
            profile: ana,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.666030, longitude: 115.142108),
            state: .unseen,
            isMutualMock: false
        ),
        MapPoint(
            id: UUID(),
            profile: leo,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.666630, longitude: 115.135608),
            state: .unseen,
            isMutualMock: true
        ),
        MapPoint(
            id: UUID(),
            profile: lina,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.670230, longitude: 115.143208),
            state: .viewed,
            isMutualMock: false
        ),
        MapPoint(
            id: UUID(),
            profile: ethan,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.663930, longitude: 115.137908),
            state: .triedBefore,
            isMutualMock: true
        ),
        MapPoint(
            id: UUID(),
            profile: nora,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.671330, longitude: 115.140508),
            state: .unseen,
            isMutualMock: false
        )
    ]

    static let history: [HistoryItem] = [
        HistoryItem(id: UUID(), name: "Noah", detail: "Walk yesterday", status: "Met")
    ]
}
