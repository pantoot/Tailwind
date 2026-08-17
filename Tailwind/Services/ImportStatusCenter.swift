import Foundation
import SwiftUI
import Combine

/// Durable status for long-running import jobs.
///
/// Replaces per-view `@State` strings that auto-cleared after a few seconds:
/// progress vanished if you switched segments mid-import, and the three
/// failure paths set a message that then stuck forever. Owning the state at
/// app level also lets the share-extension and URL import paths report
/// progress, which previously ran completely invisibly.
@MainActor
final class ImportStatusCenter: ObservableObject {

    enum Phase: Equatable {
        case running
        case success
        case failure
    }

    struct Status: Identifiable, Equatable {
        let id: UUID
        let title: String
        let detail: String
        let phase: Phase
    }

    /// The job in flight, or its success message.
    @Published private(set) var current: Status?

    /// Failures the user has not dismissed yet. Kept separate from `current`
    /// so that starting an unrelated import cannot erase a failure the user
    /// has not seen — background share-extension imports and a user-tapped
    /// Apple Health import routinely overlap.
    @Published private(set) var failures: [Status] = []

    /// Success messages clear themselves; failures never do — a failure the
    /// user did not see is the bug this class exists to fix.
    private static let successLinger: Duration = .seconds(6)

    private var clearTask: Task<Void, Never>?

    func start(_ title: String, detail: String = "") {
        clearTask?.cancel()
        current = Status(id: UUID(), title: title, detail: detail, phase: .running)
    }

    /// Updates the running job's detail line. Ignored when no job is running,
    /// so a late progress callback cannot resurrect a finished job.
    func progress(_ detail: String) {
        guard let running = current, running.phase == .running else { return }
        current = Status(id: running.id, title: running.title, detail: detail, phase: .running)
    }

    func succeed(_ detail: String, title: String? = nil) {
        clearTask?.cancel()
        let status = Status(
            id: UUID(),
            title: title ?? current?.title ?? "Import",
            detail: detail,
            phase: .success
        )
        current = status
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: Self.successLinger)
            guard !Task.isCancelled else { return }
            // Only clear if nothing else has since taken over the banner.
            if self?.current?.id == status.id { self?.current = nil }
        }
    }

    func fail(_ detail: String, title: String? = nil) {
        clearTask?.cancel()
        failures.append(Status(
            id: UUID(),
            title: title ?? current?.title ?? "Import failed",
            detail: detail,
            phase: .failure
        ))
        current = nil
    }

    /// Dismisses the active job's status. Failures are dismissed by id.
    func dismiss() {
        clearTask?.cancel()
        current = nil
    }

    func dismissFailure(id: UUID) {
        failures.removeAll { $0.id == id }
    }
}
