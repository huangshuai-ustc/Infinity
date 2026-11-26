import Foundation
import Testing
@testable import Infinity

@MainActor
struct DesktopPetStateTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private var afternoon: Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 14))!
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let name = "InfinityTests.DesktopPet.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test func initialStateUsesExpectedLevels() {
        let state = DesktopPetState.initial(at: start)
        #expect(state.fullness == 80)
        #expect(state.mood == 70)
        #expect(state.updatedAt == start)
        #expect(state.lastFedAt == nil)
        #expect(state.lastPettedAt == nil)
    }

    @Test func levelsDecayOverTimeAndClampAtZero() {
        let state = DesktopPetState.initial(at: start)
        let later = state.settled(at: start.addingTimeInterval(5 * 3600))
        #expect(later.fullness == 60)
        #expect(later.mood == 55)
        let muchLater = state.settled(at: start.addingTimeInterval(100 * 3600))
        #expect(muchLater.fullness == 0)
        #expect(muchLater.mood == 0)
    }

    @Test func backwardsClockDoesNotChangeLevelsOrTimestamp() {
        let state = DesktopPetState.initial(at: start)
        let earlier = state.settled(at: start.addingTimeInterval(-3600))
        #expect(earlier == state)
    }

    @Test func feedingAndPettingRaiseLevelsAndChooseRecentPoses() {
        var state = DesktopPetState.initial(at: afternoon)
        state.feed(at: afternoon)
        #expect(state.fullness == 100)
        #expect(state.mood == 75)
        #expect(state.pose(at: afternoon.addingTimeInterval(60), calendar: calendar) == .eating)

        let afterEating = afternoon.addingTimeInterval(DesktopPetState.eatingDuration + 1)
        state.pet(at: afterEating)
        #expect(state.mood > 75)
        #expect(state.pose(at: afterEating.addingTimeInterval(60), calendar: calendar) == .happy)
    }

    @Test func hungerTakesPriorityOverSleepingHours() {
        let night = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 2))!
        var state = DesktopPetState.initial(at: night)
        #expect(state.pose(at: night, calendar: calendar) == .sleeping)
        state.fullness = 10
        #expect(state.pose(at: night, calendar: calendar) == .hungry)
    }

    @Test func poseChangeDatesContainActionEndsAndHourlyTicks() {
        var state = DesktopPetState.initial(at: start)
        state.feed(at: start)
        #expect(state.poseChangeDates(after: start, hours: 2) == [
            start.addingTimeInterval(DesktopPetState.eatingDuration),
            start.addingTimeInterval(3600),
            start.addingTimeInterval(7200),
        ])
    }

    @Test func unreadableStateIsPreservedAndUpdateRefusesToOverwriteIt() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let corrupt = Data("not-json".utf8)
        defaults.set(corrupt, forKey: DesktopPetStateRepository.key)

        #expect(DesktopPetStateRepository.load(from: defaults) == .unreadable)
        #expect(defaults.data(forKey: DesktopPetStateRepository.unreadableKey) == corrupt)
        #expect(!DesktopPetStateRepository.update(in: defaults, at: start) { $0.feed(at: $1) })
        #expect(defaults.data(forKey: DesktopPetStateRepository.key) == corrupt)
    }

    @Test func legacyStateMovesOnlyWhenDestinationIsEmpty() {
        let (source, sourceName) = makeDefaults()
        let (destination, destinationName) = makeDefaults()
        defer {
            source.removePersistentDomain(forName: sourceName)
            destination.removePersistentDomain(forName: destinationName)
        }
        let data = Data("legacy".utf8)
        source.set(data, forKey: DesktopPetStateRepository.key)
        #expect(DesktopPetStateRepository.moveLegacyState(from: source, to: destination))
        #expect(destination.data(forKey: DesktopPetStateRepository.key) == data)
        #expect(source.data(forKey: DesktopPetStateRepository.key) == nil)

        source.set(Data("newer".utf8), forKey: DesktopPetStateRepository.key)
        #expect(!DesktopPetStateRepository.moveLegacyState(from: source, to: destination))
        #expect(destination.data(forKey: DesktopPetStateRepository.key) == data)
    }

    @Test func storePersistsActionsAndCanResetLocalData() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let store = DesktopPetStore(defaults: defaults, now: { self.start })

        store.feed()
        #expect(store.state.lastFedAt == start)
        #expect(DesktopPetStore(defaults: defaults, now: { self.start }).state == store.state)

        store.removeLocalData()
        #expect(defaults.data(forKey: DesktopPetStateRepository.key) == nil)
        #expect(store.state == .initial(at: start))
    }

    @Test func storeReportsCorruptDataAndRecoversAfterAnExplicitAction() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let corrupt = Data("broken".utf8)
        defaults.set(corrupt, forKey: DesktopPetStateRepository.key)
        let store = DesktopPetStore(defaults: defaults, now: { self.start })
        #expect(store.hasUnreadableStoredState)

        store.pet()
        #expect(!store.hasUnreadableStoredState)
        #expect(defaults.data(forKey: DesktopPetStateRepository.unreadableKey) == corrupt)
    }
}
