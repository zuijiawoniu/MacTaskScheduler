import Foundation

enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
    case once
    case everyInterval
    case weekly
    case monthly
    case everyXDays
    case cron

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once: return "Run Once"
        case .everyInterval: return "Repeat Every X Minutes"
        case .weekly: return "Specific Weekdays"
        case .monthly: return "Specific Day of Month"
        case .everyXDays: return "Every X Days"
        case .cron: return "Cron Expression"
        }
    }
}

struct ScheduleRule: Codable, Equatable {
    var kind: ScheduleKind

    var runAt: Date
    var intervalMinutes: Int
    var weekdays: [Int]
    var dayOfMonth: Int
    var hour: Int
    var minute: Int
    var everyXDays: Int
    var anchorDate: Date
    var cronExpression: String

    init(kind: ScheduleKind = .once) {
        let now = Date()
        self.kind = kind
        self.runAt = now
        self.intervalMinutes = 60
        self.weekdays = [2]
        self.dayOfMonth = 1
        self.hour = 9
        self.minute = 0
        self.everyXDays = 1
        self.anchorDate = now
        self.cronExpression = "*/15 * * * *"
    }

    func nextRunDate(after current: Date) -> Date? {
        let calendar = Calendar.current

        switch kind {
        case .once:
            return runAt > current ? runAt : nil

        case .everyInterval:
            let step = max(intervalMinutes, 1)
            return current.addingTimeInterval(TimeInterval(step * 60))

        case .weekly:
            guard !weekdays.isEmpty else { return nil }
            let time = normalizedTimeComponents()
            let sortedDays = weekdays.map { min(max($0, 1), 7) }.sorted()

            for dayOffset in 0...13 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: current) else { continue }
                let weekday = calendar.component(.weekday, from: date)
                if sortedDays.contains(weekday) {
                    var comp = calendar.dateComponents([.year, .month, .day], from: date)
                    comp.hour = time.hour
                    comp.minute = time.minute
                    comp.second = 0
                    if let candidate = calendar.date(from: comp), candidate > current {
                        return candidate
                    }
                }
            }
            return nil

        case .monthly:
            let time = normalizedTimeComponents()
            let day = min(max(dayOfMonth, 1), 31)

            for monthOffset in 0...24 {
                guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: current) else { continue }
                let yearMonth = calendar.dateComponents([.year, .month], from: monthDate)
                guard let firstOfMonth = calendar.date(from: yearMonth),
                      let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
                else {
                    continue
                }

                let targetDay = min(day, range.count)
                var comp = calendar.dateComponents([.year, .month], from: firstOfMonth)
                comp.day = targetDay
                comp.hour = time.hour
                comp.minute = time.minute
                comp.second = 0

                if let candidate = calendar.date(from: comp), candidate > current {
                    return candidate
                }
            }
            return nil

        case .everyXDays:
            let interval = max(everyXDays, 1)
            let time = normalizedTimeComponents()

            guard let anchor = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: anchorDate) else {
                return nil
            }

            if anchor > current {
                return anchor
            }

            let dayDiff = calendar.dateComponents([.day], from: anchor, to: current).day ?? 0
            let periods = (dayDiff / interval) + 1
            return calendar.date(byAdding: .day, value: periods * interval, to: anchor)

        case .cron:
            return CronCalculator.nextDate(expression: cronExpression, after: current)
        }
    }

    func descriptionText() -> String {
        switch kind {
        case .once:
            return "Once @ \(DateFormatters.full.string(from: runAt))"
        case .everyInterval:
            return "Every \(max(intervalMinutes, 1)) minute(s)"
        case .weekly:
            let dayText = weekdays.sorted().map(WeekdayMapper.label(for:)).joined(separator: ",")
            return "Weekly [\(dayText)] \(String(format: "%02d:%02d", hour, minute))"
        case .monthly:
            return "Monthly day \(dayOfMonth) \(String(format: "%02d:%02d", hour, minute))"
        case .everyXDays:
            return "Every \(max(everyXDays, 1)) day(s) \(String(format: "%02d:%02d", hour, minute))"
        case .cron:
            return "Cron: \(cronExpression)"
        }
    }

    private func normalizedTimeComponents() -> (hour: Int, minute: Int) {
        (min(max(hour, 0), 23), min(max(minute, 0), 59))
    }
}

enum WeekdayMapper {
    static func label(for weekday: Int) -> String {
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "?"
        }
    }
}

enum DateFormatters {
    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
