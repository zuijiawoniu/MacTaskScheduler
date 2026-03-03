import SwiftUI
import AppKit

struct TaskEditorView: View {
    @EnvironmentObject private var i18n: I18N
    @State private var draft: TaskItem

    let onCancel: () -> Void
    let onSave: (TaskItem) -> Void

    @State private var errorMessage = ""
    @State private var intervalValueText = ""

    init(task: TaskItem, onCancel: @escaping () -> Void, onSave: @escaping (TaskItem) -> Void) {
        _draft = State(initialValue: task)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.name.isEmpty ? i18n.t("editor.create") : i18n.t("editor.edit"))
                .font(.title3)
                .bold()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    baseInfoSection
                    scheduleSection
                }
                .padding(.vertical, 6)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(i18n.t("btn.cancel"), action: onCancel)
                Button(i18n.t("btn.save")) {
                    saveAction()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear {
            intervalValueText = draft.schedule.intervalValue() == 1 ? "" : String(draft.schedule.intervalValue())
        }
    }

    private var baseInfoSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                labeledField(i18n.t("editor.name")) {
                    TextField("", text: $draft.name)
                }

                labeledField(i18n.t("editor.script_path")) {
                    pathEditor(path: $draft.scriptPath, chooseDirectories: false, placeholder: "/Users/me/scripts/run.sh")
                }

                labeledField(i18n.t("editor.args")) {
                    TextField("", text: $draft.arguments)
                }

                labeledField(i18n.t("editor.working_dir")) {
                    pathEditor(path: $draft.workingDirectory, chooseDirectories: true, placeholder: "/Users/me/project")
                }

                Toggle(i18n.t("enabled"), isOn: $draft.isEnabled)
            }
        } label: {
            Text(i18n.t("editor.base_info"))
        }
    }

    private var scheduleSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Picker(i18n.t("editor.schedule_type"), selection: $draft.schedule.kind) {
                    ForEach(ScheduleKind.allCases) { kind in
                        Text(scheduleKindTitle(kind)).tag(kind)
                    }
                }
                .onChange(of: draft.schedule.kind) { newValue in
                    if newValue == .weekly && draft.schedule.weekdays.isEmpty {
                        draft.schedule.weekdays = [2]
                    }
                    if newValue == .everyInterval {
                        intervalValueText = draft.schedule.intervalValue() == 1 ? "" : String(draft.schedule.intervalValue())
                    }
                }

                scheduleFields
            }
        } label: {
            Text(i18n.t("editor.schedule_config"))
        }
    }

    @ViewBuilder
    private var scheduleFields: some View {
        switch draft.schedule.kind {
        case .once:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(i18n.t("editor.date"))
                    AppKitDatePicker(date: runAtDateBinding)
                        .frame(width: 150, height: 24)
                    Spacer()
                }
                HStack {
                    Text(i18n.t("editor.time"))
                    AppKitTimePicker(date: runAtTimeBinding)
                        .frame(width: 150, height: 24)
                    Spacer()
                }
            }

        case .everyInterval:
            HStack {
                Text(i18n.t("editor.interval.every"))
                TextField("", text: $intervalValueText)
                    .frame(width: 120)
                    .onChange(of: intervalValueText) { newValue in
                        let numeric = Int(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                        draft.schedule.setInterval(value: max(1, numeric), unit: draft.schedule.intervalUnit)
                    }
                Picker(i18n.t("editor.interval.unit"), selection: $draft.schedule.intervalUnit) {
                    Text(i18n.t("editor.interval.minute")).tag(IntervalUnit.minute)
                    Text(i18n.t("editor.interval.hour")).tag(IntervalUnit.hour)
                    Text(i18n.t("editor.interval.day")).tag(IntervalUnit.day)
                }
                .frame(width: 190)
                .onChange(of: draft.schedule.intervalUnit) { unit in
                    let numeric = Int(intervalValueText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                    draft.schedule.setInterval(value: max(1, numeric), unit: unit)
                }
            }

        case .weekly:
            HStack {
                Text(i18n.t("editor.weekdays"))
                ForEach(1...7, id: \.self) { day in
                    Button(WeekdayMapper.label(for: day)) {
                        toggleWeekday(day)
                    }
                    .buttonStyle(.bordered)
                    .tint(draft.schedule.weekdays.contains(day) ? .blue : .gray)
                }
            }
            timePicker

        case .monthly:
            HStack {
                Text(i18n.t("editor.day_of_month"))
                TextField("", value: $draft.schedule.dayOfMonth, formatter: NumberFormatter.integer)
                    .frame(width: 120)
            }
            timePicker

        case .everyXDays:
            HStack {
                Text(i18n.t("editor.interval.every"))
                TextField("", value: $draft.schedule.everyXDays, formatter: NumberFormatter.integer)
                    .frame(width: 120)
                Text(i18n.t("editor.interval.day"))
            }
            HStack {
                Text(i18n.t("editor.anchor_date"))
                AppKitDatePicker(date: $draft.schedule.anchorDate)
                    .frame(width: 150, height: 24)
                Spacer()
            }
            timePicker

        case .cron:
            TextField(i18n.t("editor.cron"), text: $draft.schedule.cronExpression)
            Text(i18n.t("editor.example"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timePicker: some View {
        HStack {
            Text(i18n.t("editor.time"))
            AppKitTimePicker(date: scheduleTimeBinding)
                .frame(width: 150, height: 24)
            Spacer()
        }
    }


    private var runAtDateBinding: Binding<Date> {
        Binding(
            get: { draft.schedule.runAt },
            set: { newDate in
                let calendar = Calendar.current
                let datePart = calendar.dateComponents([.year, .month, .day], from: newDate)
                let timePart = calendar.dateComponents([.hour, .minute, .second], from: draft.schedule.runAt)
                var merged = DateComponents()
                merged.year = datePart.year
                merged.month = datePart.month
                merged.day = datePart.day
                merged.hour = timePart.hour
                merged.minute = timePart.minute
                merged.second = timePart.second
                if let date = calendar.date(from: merged) {
                    draft.schedule.runAt = date
                }
            }
        )
    }

    private var runAtTimeBinding: Binding<Date> {
        Binding(
            get: { draft.schedule.runAt },
            set: { newTime in
                let calendar = Calendar.current
                let datePart = calendar.dateComponents([.year, .month, .day], from: draft.schedule.runAt)
                let timePart = calendar.dateComponents([.hour, .minute, .second], from: newTime)
                var merged = DateComponents()
                merged.year = datePart.year
                merged.month = datePart.month
                merged.day = datePart.day
                merged.hour = timePart.hour
                merged.minute = timePart.minute
                merged.second = timePart.second
                if let date = calendar.date(from: merged) {
                    draft.schedule.runAt = date
                }
            }
        )
    }

    private var scheduleTimeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                return calendar.date(from: DateComponents(hour: draft.schedule.hour, minute: draft.schedule.minute, second: draft.schedule.second)) ?? Date()
            },
            set: { newValue in
                let comp = Calendar.current.dateComponents([.hour, .minute, .second], from: newValue)
                draft.schedule.hour = comp.hour ?? 0
                draft.schedule.minute = comp.minute ?? 0
                draft.schedule.second = comp.second ?? 0
            }
        )
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .frame(width: 120, alignment: .leading)
            content()
        }
    }

    private func saveAction() {
        errorMessage = ""

        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = i18n.t("editor.err.name")
            return
        }

        guard !draft.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = i18n.t("editor.err.script")
            return
        }

        if draft.schedule.kind == .weekly && draft.schedule.weekdays.isEmpty {
            errorMessage = i18n.t("editor.err.weekday")
            return
        }

        if draft.schedule.kind == .cron,
           CronCalculator.nextDate(expression: draft.schedule.cronExpression, after: Date()) == nil {
            errorMessage = i18n.t("editor.err.cron")
            return
        }

        draft.schedule.dayOfMonth = min(max(draft.schedule.dayOfMonth, 1), 31)
        draft.schedule.everyXDays = min(max(draft.schedule.everyXDays, 1), 365)
        draft.schedule.second = min(max(draft.schedule.second, 0), 59)

        onSave(draft)
    }

    private func toggleWeekday(_ day: Int) {
        if let index = draft.schedule.weekdays.firstIndex(of: day) {
            draft.schedule.weekdays.remove(at: index)
        } else {
            draft.schedule.weekdays.append(day)
            draft.schedule.weekdays.sort()
        }
    }

    private func scheduleKindTitle(_ kind: ScheduleKind) -> String {
        switch kind {
        case .once: return i18n.t("schedule.once")
        case .everyInterval: return i18n.t("schedule.every_interval")
        case .weekly: return i18n.t("schedule.weekly")
        case .monthly: return i18n.t("schedule.monthly")
        case .everyXDays: return i18n.t("schedule.every_x_days")
        case .cron: return i18n.t("schedule.cron")
        }
    }

    private func pathEditor(path: Binding<String>, chooseDirectories: Bool, placeholder: String) -> some View {
        HStack {
            TextField(placeholder, text: path)
            Button(i18n.t("browse")) {
                if let selected = openPanel(chooseDirectories: chooseDirectories) {
                    path.wrappedValue = selected
                }
            }
        }
    }

    private func openPanel(chooseDirectories: Bool) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !chooseDirectories
        panel.canChooseDirectories = chooseDirectories
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = chooseDirectories
        panel.prompt = "Select"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}


private struct AppKitDatePicker: NSViewRepresentable {
    @Binding var date: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(date: $date)
    }

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay]
        picker.calendar = Calendar.current
        picker.timeZone = .current
        picker.dateValue = date
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.valueChanged(_:))
        return picker
    }

    func updateNSView(_ nsView: NSDatePicker, context: Context) {
        if nsView.dateValue != date {
            nsView.dateValue = date
        }
    }

    final class Coordinator: NSObject {
        @Binding var date: Date

        init(date: Binding<Date>) {
            _date = date
        }

        @objc func valueChanged(_ sender: NSDatePicker) {
            date = sender.dateValue
        }
    }
}


private struct AppKitTimePicker: NSViewRepresentable {
    @Binding var date: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(date: $date)
    }

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.hourMinuteSecond]
        picker.calendar = Calendar.current
        picker.timeZone = .current
        picker.dateValue = date
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.valueChanged(_:))
        return picker
    }

    func updateNSView(_ nsView: NSDatePicker, context: Context) {
        if nsView.dateValue != date {
            nsView.dateValue = date
        }
    }

    final class Coordinator: NSObject {
        @Binding var date: Date

        init(date: Binding<Date>) {
            _date = date
        }

        @objc func valueChanged(_ sender: NSDatePicker) {
            date = sender.dateValue
        }
    }
}

private extension NumberFormatter {
    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        return formatter
    }()
}
