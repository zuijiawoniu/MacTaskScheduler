import Foundation

@MainActor
final class SchedulerEngine {
    private var timer: Timer?
    private let pollInterval: TimeInterval

    init(pollInterval: TimeInterval = 20) {
        self.pollInterval = pollInterval
    }

    func start(onTick: @escaping @MainActor () -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            Task { @MainActor in
                onTick()
            }
        }
        Task { @MainActor in
            onTick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
