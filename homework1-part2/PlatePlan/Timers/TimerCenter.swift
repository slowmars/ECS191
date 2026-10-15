import AlarmKit
import Foundation
import Observation
import SwiftUI
import UserNotifications

/// Runs cooking timers as real system timers (AlarmKit), so they ring like the Clock app
/// even when PlatePlan is closed, the phone is locked, or it's on silent, and show a live
/// countdown on the Lock Screen and in the Dynamic Island.
///
/// If the user doesn't allow alarms, timers fall back to a regular notification with sound.
@MainActor
@Observable
final class TimerCenter {
    struct RunningTimer: Identifiable, Hashable {
        let id: UUID
        let key: String
        let title: String
        let fireDate: Date
        let usesAlarm: Bool
    }

    private(set) var running: [RunningTimer] = []
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            // Drop timers the user stopped from the Lock Screen or that finished ringing.
            for await alarms in AlarmManager.shared.alarmUpdates {
                let active = Set(alarms.map(\.id))
                self?.running.removeAll { $0.usesAlarm && !active.contains($0.id) }
            }
        }
    }

    /// Identifies a step's timer so cooking mode can show it again when you swipe back.
    static func key(recipeID: String, step: Int) -> String { "\(recipeID)#\(step)" }

    func timer(for key: String) -> RunningTimer? {
        running.first { $0.key == key && $0.fireDate > .now.addingTimeInterval(-60) }
    }

    func start(seconds: Int, recipe: Recipe, step: Int) async {
        let key = Self.key(recipeID: recipe.id, step: step)
        if let existing = timer(for: key) { cancel(existing) }
        let metadata = CookingTimerMetadata(recipeName: recipe.name, stepNumber: step + 1)
        let fireDate = Date.now.addingTimeInterval(TimeInterval(seconds))

        if await alarmsAllowed(), let id = try? await scheduleAlarm(seconds: seconds, metadata: metadata) {
            running.append(RunningTimer(id: id, key: key, title: metadata.title, fireDate: fireDate, usesAlarm: true))
            return
        }
        let id = UUID()
        await scheduleNotification(id: id, seconds: seconds, metadata: metadata)
        running.append(RunningTimer(id: id, key: key, title: metadata.title, fireDate: fireDate, usesAlarm: false))
    }

    func cancel(_ timer: RunningTimer) {
        if timer.usesAlarm {
            try? AlarmManager.shared.cancel(id: timer.id)
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timer.id.uuidString])
        }
        running.removeAll { $0.id == timer.id }
    }

    // MARK: AlarmKit

    private func alarmsAllowed() async -> Bool {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized: return true
        case .denied: return false
        case .notDetermined: return (try? await manager.requestAuthorization()) == .authorized
        @unknown default: return false
        }
    }

    private func scheduleAlarm(seconds: Int, metadata: CookingTimerMetadata) async throws -> UUID {
        let tint = Color.accentColor
        let presentation = AlarmPresentation(
            alert: .init(title: "Time's up: \(metadata.title)"),
            countdown: .init(title: LocalizedStringResource(stringLiteral: metadata.title),
                             pauseButton: AlarmButton(text: "Pause", textColor: tint, systemImageName: "pause.fill")),
            paused: .init(title: "Paused",
                          resumeButton: AlarmButton(text: "Resume", textColor: tint, systemImageName: "play.fill"))
        )
        let attributes = AlarmAttributes(presentation: presentation, metadata: metadata, tintColor: tint)
        let id = UUID()
        _ = try await AlarmManager.shared.schedule(
            id: id,
            configuration: .timer(duration: TimeInterval(seconds), attributes: attributes)
        )
        return id
    }

    // MARK: Notification fallback

    private func scheduleNotification(id: UUID, seconds: Int, metadata: CookingTimerMetadata) async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = metadata.title
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(seconds, 1)), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger))
    }
}
