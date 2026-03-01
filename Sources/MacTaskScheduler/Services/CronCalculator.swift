import Foundation

enum CronCalculator {
    static func nextDate(expression: String, after current: Date) -> Date? {
        let fields = expression.split(separator: " ").map(String.init)
        guard fields.count == 5 else { return nil }

        guard let minuteSet = parseField(fields[0], min: 0, max: 59),
              let hourSet = parseField(fields[1], min: 0, max: 23),
              let daySet = parseField(fields[2], min: 1, max: 31),
              let monthSet = parseField(fields[3], min: 1, max: 12),
              let weekdaySet = parseField(fields[4], min: 0, max: 6)
        else {
            return nil
        }

        let calendar = Calendar.current
        guard let start = calendar.date(bySetting: .second, value: 0, of: current)?.addingTimeInterval(60) else {
            return nil
        }

        // Search up to one year in minutes.
        let maxChecks = 60 * 24 * 366
        var candidate = start

        for _ in 0..<maxChecks {
            let comp = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: candidate)
            let minute = comp.minute ?? -1
            let hour = comp.hour ?? -1
            let day = comp.day ?? -1
            let month = comp.month ?? -1
            let weekday = ((comp.weekday ?? 1) + 6) % 7 // cron uses 0 = Sunday

            if minuteSet.contains(minute) &&
                hourSet.contains(hour) &&
                daySet.contains(day) &&
                monthSet.contains(month) &&
                weekdaySet.contains(weekday) {
                return candidate
            }

            candidate = candidate.addingTimeInterval(60)
        }

        return nil
    }

    private static func parseField(_ field: String, min: Int, max: Int) -> Set<Int>? {
        var values = Set<Int>()
        let parts = field.split(separator: ",")

        for partSub in parts {
            let part = String(partSub)
            if part == "*" {
                values.formUnion(min...max)
                continue
            }

            if part.hasPrefix("*/") {
                guard let step = Int(part.dropFirst(2)), step > 0 else { return nil }
                var value = min
                while value <= max {
                    values.insert(value)
                    value += step
                }
                continue
            }

            if part.contains("-") {
                let rangeParts = part.split(separator: "-")
                guard rangeParts.count == 2,
                      let start = Int(rangeParts[0]),
                      let end = Int(rangeParts[1]),
                      start <= end
                else { return nil }
                for value in start...end where value >= min && value <= max {
                    values.insert(value)
                }
                continue
            }

            guard let value = Int(part), value >= min, value <= max else { return nil }
            values.insert(value)
        }

        return values.isEmpty ? nil : values
    }
}
