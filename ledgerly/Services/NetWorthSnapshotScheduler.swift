import BackgroundTasks
import Foundation

final class NetWorthSnapshotScheduler {
    static let taskIdentifier = "com.yohannescodes.ledgerly.networth.snapshot"

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else { return }
            self?.handle(task: task)
        }
    }

    func scheduleNext() {
        guard let nextRun = nextRunDate() else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = nextRun
        do {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Best-effort; the system may reject if it already has a pending request.
        }
    }

    private func handle(task: BGAppRefreshTask) {
        scheduleNext()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operation = BlockOperation { [persistence] in
            let service = NetWorthService(persistence: persistence)
            service.ensureDailySnapshot()
        }

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        queue.addOperation(operation)
    }

    private func nextRunDate(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        guard let todayAtFive = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date) else {
            return nil
        }
        if date < todayAtFive {
            return todayAtFive
        }
        return calendar.date(byAdding: .day, value: 1, to: todayAtFive)
    }
}
