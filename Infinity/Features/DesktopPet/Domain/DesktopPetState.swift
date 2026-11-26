import Foundation

enum DesktopPetPose: String, CaseIterable, Sendable {
    case idle
    case happy
    case eating
    case hungry
    case sleeping
}

struct DesktopPetState: Codable, Equatable, Sendable {
    static let name = "脏脏橘"
    static let levelRange = 0.0...100.0
    static let fullnessDecayPerHour = 4.0
    static let moodDecayPerHour = 3.0
    static let feedFullness = 30.0
    static let feedMood = 5.0
    static let petMood = 15.0
    static let hungryThreshold = 25.0
    static let happyThreshold = 80.0
    static let eatingDuration: TimeInterval = 2 * 60
    static let pettedDuration: TimeInterval = 10 * 60
    static let sleepingHours = 0..<7

    var fullness: Double
    var mood: Double
    var updatedAt: Date
    var lastFedAt: Date?
    var lastPettedAt: Date?

    static func initial(at date: Date) -> Self {
        Self(fullness: 80, mood: 70, updatedAt: date, lastFedAt: nil, lastPettedAt: nil)
    }

    func settled(at date: Date) -> Self {
        let hours = max(0, date.timeIntervalSince(updatedAt)) / 3600
        var result = self
        result.fullness = Self.clamped(fullness - hours * Self.fullnessDecayPerHour)
        result.mood = Self.clamped(mood - hours * Self.moodDecayPerHour)
        result.updatedAt = max(date, updatedAt)
        return result
    }

    mutating func feed(at date: Date) {
        self = settled(at: date)
        fullness = Self.clamped(fullness + Self.feedFullness)
        mood = Self.clamped(mood + Self.feedMood)
        lastFedAt = date
    }

    mutating func pet(at date: Date) {
        self = settled(at: date)
        mood = Self.clamped(mood + Self.petMood)
        lastPettedAt = date
    }

    func pose(at date: Date, calendar: Calendar = .current) -> DesktopPetPose {
        let current = settled(at: date)
        if let lastFedAt, Self.isRecent(lastFedAt, within: Self.eatingDuration, at: date) { return .eating }
        if let lastPettedAt, Self.isRecent(lastPettedAt, within: Self.pettedDuration, at: date) { return .happy }
        if current.fullness < Self.hungryThreshold { return .hungry }
        if Self.sleepingHours.contains(calendar.component(.hour, from: date)) { return .sleeping }
        if current.mood >= Self.happyThreshold { return .happy }
        return .idle
    }

    func statusText(at date: Date, calendar: Calendar = .current) -> String {
        switch pose(at: date, calendar: calendar) {
        case .idle: return "\(Self.name)在发呆"
        case .happy: return "\(Self.name)很开心"
        case .eating: return "\(Self.name)正在吃饭"
        case .hungry: return "\(Self.name)饿了，想吃饭"
        case .sleeping: return "\(Self.name)在睡觉"
        }
    }

    func poseChangeDates(after date: Date, hours: Int = 6) -> [Date] {
        var dates = (1...max(1, hours)).map { date.addingTimeInterval(Double($0) * 3600) }
        if let lastFedAt { dates.append(lastFedAt.addingTimeInterval(Self.eatingDuration)) }
        if let lastPettedAt { dates.append(lastPettedAt.addingTimeInterval(Self.pettedDuration)) }
        return Array(Set(dates.filter { $0 > date })).sorted()
    }

    private static func clamped(_ value: Double) -> Double {
        min(levelRange.upperBound, max(levelRange.lowerBound, value))
    }

    private static func isRecent(_ moment: Date, within duration: TimeInterval, at date: Date) -> Bool {
        let elapsed = date.timeIntervalSince(moment)
        return elapsed >= 0 && elapsed < duration
    }
}

enum DesktopPetWidgetKind {
    static let kind = "InfinityDesktopPetWidget"
}

enum DesktopPetDefaults {
    static let appGroupInfoKey = "InfinityAppGroupIdentifier"

    static func resolved() -> UserDefaults {
#if os(iOS)
        if let identifier = Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String,
           !identifier.isEmpty,
           FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil,
           let shared = UserDefaults(suiteName: identifier) {
            return shared
        }
#endif
        return .standard
    }
}

enum DesktopPetStateLoadResult: Equatable, Sendable {
    case missing
    case loaded(DesktopPetState)
    case unreadable
}

enum DesktopPetStateRepository {
    static let key = "infinity-desktop-pet-state-v1"
    static let unreadableKey = "infinity-desktop-pet-state-v1.unreadable"

    static func load(from defaults: UserDefaults) -> DesktopPetStateLoadResult {
        guard let data = defaults.data(forKey: key) else { return .missing }
        do {
            return .loaded(try JSONDecoder().decode(DesktopPetState.self, from: data))
        } catch {
            if defaults.object(forKey: unreadableKey) == nil {
                defaults.set(data, forKey: unreadableKey)
            }
            return .unreadable
        }
    }

    static func save(_ state: DesktopPetState, to defaults: UserDefaults) throws {
        defaults.set(try JSONEncoder().encode(state), forKey: key)
    }

    @discardableResult
    static func update(
        in defaults: UserDefaults,
        at date: Date,
        _ change: (inout DesktopPetState, Date) -> Void
    ) -> Bool {
        var state: DesktopPetState
        switch load(from: defaults) {
        case .missing: state = .initial(at: date)
        case .loaded(let stored): state = stored
        case .unreadable: return false
        }
        change(&state, date)
        do {
            try save(state, to: defaults)
            return true
        } catch {
            return false
        }
    }

    static func moveLegacyState(from source: UserDefaults, to destination: UserDefaults) -> Bool {
        guard source !== destination,
              destination.object(forKey: key) == nil,
              let data = source.data(forKey: key) else { return false }
        destination.set(data, forKey: key)
        source.removeObject(forKey: key)
        return true
    }

    static func remove(from defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: unreadableKey)
    }
}
