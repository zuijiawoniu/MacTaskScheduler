import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans
    case en
    case de
    case ko
    case ja
    case ar
    case ru
    case fr
    case es

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "English"
        case .de: return "Deutsch"
        case .ko: return "한국어"
        case .ja: return "日本語"
        case .ar: return "العربية"
        case .ru: return "Русский"
        case .fr: return "Français"
        case .es: return "Español"
        }
    }
}

@MainActor
final class I18N: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
        }
    }

    private static let key = "app_language"

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        self.language = AppLanguage(rawValue: saved ?? "") ?? .zhHans
    }

    func t(_ key: String) -> String {
        let langMap = Self.translations[language] ?? [:]
        if let value = langMap[key] {
            return value
        }
        return Self.en[key] ?? key
    }

    private static let en: [String: String] = [
        "app.name": "MacTaskScheduler",
        "search.placeholder": "Search by name/path/schedule",
        "btn.add": "Add",
        "btn.edit": "Edit",
        "btn.delete": "Delete",
        "ctx.run_now": "Run Now",
        "ctx.duplicate": "Duplicate Task",
        "ctx.delete": "Delete Task",
        "btn.run_now": "Run Now",
        "btn.cancel": "Cancel",
        "btn.save": "Save",
        "btn.help": "Help",
        "language": "Language",
        "enabled": "Enabled",
        "task.none.title": "No Task Selected",
        "task.none.desc": "Create or choose a task.",
        "column.settings": "Columns",
        "column.name": "Task Name",
        "column.enabled": "Enabled",
        "column.modified": "Modified Time",
        "column.schedule": "Schedule",
        "column.next_run": "Next Run",
        "sort.by": "Sort",
        "sort.asc": "Ascending",
        "sort.desc": "Descending",
        "detail.mode": "Mode",
        "detail.mode_script": "Run Script",
        "detail.mode_reminder": "Popup Reminder",
        "detail.reminder_message": "Reminder Message",
        "detail.notification_settings_hint": "If notifications are blocked, enable them in System Settings.",
        "detail.open_notification_settings": "Open Notification Settings",
        "detail.send_test_notification": "Send Test Notification",
        "detail.notification_status": "Notification Status:",
        "detail.notification_status_authorized": "Authorized",
        "detail.notification_status_denied": "Denied",
        "detail.notification_status_not_determined": "Not Determined",
        "detail.notification_status_provisional": "Provisional",
        "detail.notification_status_ephemeral": "Ephemeral",
        "detail.notification_status_unknown": "Unknown",
        "detail.refresh_status": "Refresh",
        "detail.script": "Script",
        "detail.args": "Args",
        "detail.working_dir": "Working Dir",
        "detail.timeout": "Timeout",
        "detail.schedule": "Schedule",
        "detail.next_run": "Next Run",
        "detail.last_run": "Last Run",
        "detail.last_exit": "Last Exit",
        "detail.logs": "Execution Logs",
        "detail.logs_loading": "Loading logs...",
        "detail.no_logs": "No logs yet.",
        "detail.logs_preview_prefix": "Showing latest",
        "detail.logs_preview_suffix": "logs",
        "detail.load_all_logs": "Load All Logs",
        "detail.show_recent_logs": "Show Recent Only",
        "detail.showing_all_logs": "Showing all",
        "detail.large_logs_trimmed_prefix": "Large logs trimmed:",
        "detail.large_logs_trimmed_suffix": "entry(s)",
        "detail.load_full_large_logs": "Load Full Content",
        "detail.show_large_logs_preview": "Show Trimmed Preview",
        "editor.create": "Create Task",
        "editor.edit": "Edit Task",
        "editor.name": "Task Name",
        "editor.reminder_only": "Reminder Only (No Script)",
        "editor.reminder_message": "Reminder Message",
        "editor.reminder_message_placeholder": "Optional reminder text",
        "editor.script_path": "Script Path",
        "editor.args": "Arguments (space-separated)",
        "editor.working_dir": "Working Directory",
        "editor.timeout": "Run Timeout",
        "editor.timeout_unit": "seconds",
        "editor.schedule_type": "Schedule Type",
        "editor.base_info": "Basic Info",
        "editor.schedule_config": "Schedule Config",
        "editor.run_at": "Run At",
        "editor.date": "Date",
        "editor.weekdays": "Weekdays",
        "editor.day_of_month": "Day of Month",
        "editor.anchor_date": "Anchor Date",
        "editor.time": "Time",
        "editor.second": "Second",
        "editor.cron": "Cron expression (m h dom mon dow)",
        "editor.example": "Example: */30 * * * *",
        "editor.interval.every": "Every",
        "editor.interval.unit": "Unit",
        "editor.interval.minute": "Minute(s)",
        "editor.interval.hour": "Hour(s)",
        "editor.interval.day": "Day(s)",
        "editor.err.name": "Task name is required.",
        "editor.err.script": "Script path is required.",
        "editor.err.weekday": "Please select at least one weekday.",
        "editor.err.cron": "Cron expression is invalid or unsupported.",
        "schedule.once": "Run Once",
        "schedule.every_interval": "Repeat Every X Minutes/Hours/Days",
        "schedule.weekly": "Specific Weekdays",
        "schedule.monthly": "Specific Day of Month",
        "schedule.every_x_days": "Every X Days",
        "schedule.cron": "Cron",
        "browse": "Browse",
        "help.title": "Script Help",
        "help.app_name": "App Name",
        "help.version": "Version",
        "help.release_date": "Release Date",
        "help.contact": "Contact",
        "help.python": "For Python scripts, add this first line:",
        "help.shell": "For shell scripts, add this first line:",
        "help.chmod": "Grant executable permission:",
        "help.close": "Close"
    ]

    private static let translations: [AppLanguage: [String: String]] = [
        .en: en,
        .zhHans: [
            "app.name": "周期任务管理",
            "search.placeholder": "按名称/路径/规则搜索",
            "btn.add": "新增",
            "btn.edit": "编辑",
            "btn.delete": "删除",
            "ctx.run_now": "立即执行",
            "ctx.duplicate": "复制任务",
            "ctx.delete": "删除任务",
            "btn.run_now": "立即执行",
            "btn.cancel": "取消",
            "btn.save": "保存",
            "btn.help": "帮助",
            "language": "语言",
            "enabled": "启用",
            "task.none.title": "未选择任务",
            "task.none.desc": "请创建或选择一个任务。",
            "column.settings": "列设置",
            "column.name": "任务名称",
            "column.enabled": "启用",
            "column.modified": "修改时间",
            "column.schedule": "周期",
            "column.next_run": "下次执行",
            "sort.by": "排序",
            "sort.asc": "升序",
            "sort.desc": "降序",
            "detail.mode": "模式",
            "detail.mode_script": "执行脚本",
            "detail.mode_reminder": "弹窗提醒",
            "detail.reminder_message": "提醒内容",
            "detail.notification_settings_hint": "如被拦截，请在系统设置中开启通知权限。",
            "detail.open_notification_settings": "打开通知设置",
            "detail.send_test_notification": "发送测试通知",
            "detail.notification_status": "通知状态：",
            "detail.notification_status_authorized": "已授权",
            "detail.notification_status_denied": "已拒绝",
            "detail.notification_status_not_determined": "未决定",
            "detail.notification_status_provisional": "临时授权",
            "detail.notification_status_ephemeral": "临时会话",
            "detail.notification_status_unknown": "未知",
            "detail.refresh_status": "刷新",
            "detail.script": "脚本",
            "detail.args": "参数",
            "detail.working_dir": "工作目录",
            "detail.timeout": "超时",
            "detail.schedule": "调度规则",
            "detail.next_run": "下次执行",
            "detail.last_run": "上次执行",
            "detail.last_exit": "上次退出码",
            "detail.logs": "执行日志",
            "detail.logs_loading": "日志加载中...",
            "detail.no_logs": "暂无日志。",
            "detail.logs_preview_prefix": "当前显示最近",
            "detail.logs_preview_suffix": "条日志",
            "detail.load_all_logs": "加载全部日志",
            "detail.show_recent_logs": "仅显示最近",
            "detail.showing_all_logs": "当前显示全部",
            "detail.large_logs_trimmed_prefix": "大日志已截断：",
            "detail.large_logs_trimmed_suffix": "条",
            "detail.load_full_large_logs": "加载完整内容",
            "detail.show_large_logs_preview": "显示截断预览",
            "editor.create": "新建任务",
            "editor.edit": "编辑任务",
            "editor.name": "任务名称",
            "editor.reminder_only": "仅提醒（不执行脚本）",
            "editor.reminder_message": "提醒内容",
            "editor.reminder_message_placeholder": "可选：提醒文案",
            "editor.script_path": "脚本路径",
            "editor.args": "参数（空格分隔）",
            "editor.working_dir": "工作目录",
            "editor.timeout": "执行超时",
            "editor.timeout_unit": "秒",
            "editor.schedule_type": "调度类型",
            "editor.base_info": "基础信息",
            "editor.schedule_config": "调度配置",
            "editor.run_at": "执行时间",
            "editor.date": "日期",
            "editor.weekdays": "星期",
            "editor.day_of_month": "每月日期",
            "editor.anchor_date": "锚点日期",
            "editor.time": "时间",
            "editor.second": "秒",
            "editor.cron": "Cron 表达式 (m h dom mon dow)",
            "editor.example": "示例: */30 * * * *",
            "editor.interval.every": "每",
            "editor.interval.unit": "单位",
            "editor.interval.minute": "分钟",
            "editor.interval.hour": "小时",
            "editor.interval.day": "天",
            "editor.err.name": "任务名称不能为空。",
            "editor.err.script": "脚本路径不能为空。",
            "editor.err.weekday": "请至少选择一个星期。",
            "editor.err.cron": "Cron 表达式无效或不支持。",
            "schedule.once": "单次执行",
            "schedule.every_interval": "每 X 分钟/小时/天循环",
            "schedule.weekly": "指定星期",
            "schedule.monthly": "指定每月日期",
            "schedule.every_x_days": "每 X 天",
            "schedule.cron": "Cron",
            "browse": "浏览",
            "help.title": "脚本帮助",
            "help.app_name": "软件名",
            "help.version": "版本",
            "help.release_date": "发布日期",
            "help.contact": "联系邮箱",
            "help.python": "Python 脚本建议在第一行添加：",
            "help.shell": "Shell 脚本建议在第一行添加：",
            "help.chmod": "为脚本增加执行权限：",
            "help.close": "关闭"
        ],
        .de: [
            "btn.add": "Hinzufügen", "btn.edit": "Bearbeiten", "btn.delete": "Löschen", "ctx.run_now": "Jetzt ausführen", "ctx.duplicate": "Aufgabe duplizieren", "ctx.delete": "Aufgabe löschen", "btn.run_now": "Jetzt ausführen", "btn.cancel": "Abbrechen", "btn.save": "Speichern", "btn.help": "Hilfe", "enabled": "Aktiviert", "browse": "Durchsuchen", "editor.name": "Aufgabenname", "editor.reminder_only": "Nur Erinnerung (kein Skript)", "editor.reminder_message": "Erinnerungstext", "editor.reminder_message_placeholder": "Optionaler Erinnerungstext", "editor.script_path": "Skriptpfad", "editor.args": "Argumente", "editor.timeout": "Ausführungs-Timeout", "editor.timeout_unit": "Sekunden", "detail.mode": "Modus", "detail.mode_script": "Skript ausführen", "detail.mode_reminder": "Popup-Erinnerung", "detail.reminder_message": "Erinnerungstext", "detail.notification_settings_hint": "Wenn blockiert, in den Systemeinstellungen Benachrichtigungen aktivieren.", "detail.open_notification_settings": "Benachrichtigungseinstellungen öffnen", "detail.send_test_notification": "Testbenachrichtigung senden", "detail.notification_status": "Benachrichtigungsstatus:", "detail.notification_status_authorized": "Zugelassen", "detail.notification_status_denied": "Abgelehnt", "detail.notification_status_not_determined": "Nicht entschieden", "detail.notification_status_provisional": "Vorläufig", "detail.notification_status_ephemeral": "Ephemeral", "detail.notification_status_unknown": "Unbekannt", "detail.refresh_status": "Aktualisieren", "detail.script": "Skript", "detail.args": "Argumente", "detail.timeout": "Zeitlimit", "detail.logs_loading": "Protokolle werden geladen...", "detail.logs_preview_prefix": "Zeige zuletzt", "detail.logs_preview_suffix": "Protokolle", "detail.load_all_logs": "Alle Protokolle laden", "detail.show_recent_logs": "Nur letzte anzeigen", "detail.showing_all_logs": "Zeige alle", "detail.large_logs_trimmed_prefix": "Große Protokolle gekürzt:", "detail.large_logs_trimmed_suffix": "Eintrag/Einträge", "detail.load_full_large_logs": "Vollständig laden", "detail.show_large_logs_preview": "Gekürzte Vorschau", "schedule.once": "Einmal ausführen", "schedule.every_interval": "Alle X Minuten/Stunden/Tage", "schedule.weekly": "Bestimmte Wochentage", "schedule.monthly": "Bestimmter Monatstag", "schedule.every_x_days": "Alle X Tage", "help.title": "Skripthilfe", "help.python": "Für Python-Skripte diese erste Zeile hinzufügen:", "help.shell": "Für Shell-Skripte diese erste Zeile hinzufügen:", "help.chmod": "Ausführungsrecht vergeben:", "help.close": "Schließen", "column.name": "Aufgabe", "column.modified": "Geändert", "language": "Sprache"
        ],
        .ko: [
            "btn.add": "추가", "btn.edit": "수정", "btn.delete": "삭제", "ctx.run_now": "즉시 실행", "ctx.duplicate": "작업 복제", "ctx.delete": "작업 삭제", "btn.run_now": "즉시 실행", "btn.cancel": "취소", "btn.save": "저장", "btn.help": "도움말", "enabled": "활성화", "browse": "찾아보기", "editor.name": "작업 이름", "editor.reminder_only": "알림 전용(스크립트 없음)", "editor.reminder_message": "알림 메시지", "editor.reminder_message_placeholder": "선택 사항: 알림 문구", "editor.script_path": "스크립트 경로", "editor.args": "인수", "editor.timeout": "실행 시간 제한", "editor.timeout_unit": "초", "detail.mode": "모드", "detail.mode_script": "스크립트 실행", "detail.mode_reminder": "팝업 알림", "detail.reminder_message": "알림 메시지", "detail.notification_settings_hint": "차단되어 있다면 시스템 설정에서 알림을 허용하세요.", "detail.open_notification_settings": "알림 설정 열기", "detail.send_test_notification": "테스트 알림 보내기", "detail.notification_status": "알림 상태:", "detail.notification_status_authorized": "허용됨", "detail.notification_status_denied": "거부됨", "detail.notification_status_not_determined": "미결정", "detail.notification_status_provisional": "임시 허용", "detail.notification_status_ephemeral": "임시 세션", "detail.notification_status_unknown": "알 수 없음", "detail.refresh_status": "새로고침", "detail.script": "스크립트", "detail.args": "인수", "detail.timeout": "시간 제한", "detail.logs_loading": "로그 불러오는 중...", "detail.logs_preview_prefix": "최근", "detail.logs_preview_suffix": "개 로그 표시", "detail.load_all_logs": "모든 로그 불러오기", "detail.show_recent_logs": "최근 로그만 보기", "detail.showing_all_logs": "전체 로그 표시", "detail.large_logs_trimmed_prefix": "큰 로그가 잘렸습니다:", "detail.large_logs_trimmed_suffix": "개 항목", "detail.load_full_large_logs": "전체 내용 로드", "detail.show_large_logs_preview": "잘린 미리보기", "schedule.once": "한 번 실행", "schedule.every_interval": "매 X분/시간/일", "schedule.weekly": "요일 지정", "schedule.monthly": "매월 날짜 지정", "schedule.every_x_days": "X일마다", "help.title": "스크립트 도움말", "help.python": "Python 스크립트 첫 줄에 추가:", "help.shell": "Shell 스크립트 첫 줄에 추가:", "help.chmod": "실행 권한 부여:", "help.close": "닫기", "column.name": "작업", "column.modified": "수정 시간", "language": "언어"
        ],
        .ja: [
            "btn.add": "追加", "btn.edit": "編集", "btn.delete": "削除", "ctx.run_now": "今すぐ実行", "ctx.duplicate": "タスクを複製", "ctx.delete": "タスクを削除", "btn.run_now": "今すぐ実行", "btn.cancel": "キャンセル", "btn.save": "保存", "btn.help": "ヘルプ", "enabled": "有効", "browse": "参照", "editor.name": "タスク名", "editor.reminder_only": "リマインダーのみ（スクリプトなし）", "editor.reminder_message": "リマインダーメッセージ", "editor.reminder_message_placeholder": "任意: リマインド文言", "editor.script_path": "スクリプトパス", "editor.args": "引数", "editor.timeout": "実行タイムアウト", "editor.timeout_unit": "秒", "detail.mode": "モード", "detail.mode_script": "スクリプト実行", "detail.mode_reminder": "ポップアップ通知", "detail.reminder_message": "リマインダーメッセージ", "detail.notification_settings_hint": "ブロックされている場合は、システム設定で通知を有効にしてください。", "detail.open_notification_settings": "通知設定を開く", "detail.send_test_notification": "テスト通知を送信", "detail.notification_status": "通知ステータス:", "detail.notification_status_authorized": "許可", "detail.notification_status_denied": "拒否", "detail.notification_status_not_determined": "未決定", "detail.notification_status_provisional": "仮許可", "detail.notification_status_ephemeral": "一時セッション", "detail.notification_status_unknown": "不明", "detail.refresh_status": "更新", "detail.script": "スクリプト", "detail.args": "引数", "detail.timeout": "タイムアウト", "detail.logs_loading": "ログを読み込み中...", "detail.logs_preview_prefix": "最新", "detail.logs_preview_suffix": "件のログを表示", "detail.load_all_logs": "すべてのログを読み込む", "detail.show_recent_logs": "最新のみ表示", "detail.showing_all_logs": "すべて表示中", "detail.large_logs_trimmed_prefix": "大きなログを省略:", "detail.large_logs_trimmed_suffix": "件", "detail.load_full_large_logs": "完全な内容を読み込む", "detail.show_large_logs_preview": "省略プレビュー表示", "schedule.once": "1回実行", "schedule.every_interval": "X分/時間/日ごと", "schedule.weekly": "曜日指定", "schedule.monthly": "毎月の日付指定", "schedule.every_x_days": "X日ごと", "help.title": "スクリプトヘルプ", "help.python": "Pythonスクリプトの1行目に追加:", "help.shell": "Shellスクリプトの1行目に追加:", "help.chmod": "実行権限を付与:", "help.close": "閉じる", "column.name": "タスク", "column.modified": "更新日時", "language": "言語"
        ],
        .ar: [
            "btn.add": "إضافة", "btn.edit": "تعديل", "btn.delete": "حذف", "ctx.run_now": "تشغيل الآن", "ctx.duplicate": "نسخ المهمة", "ctx.delete": "حذف المهمة", "btn.run_now": "تشغيل الآن", "btn.cancel": "إلغاء", "btn.save": "حفظ", "btn.help": "مساعدة", "enabled": "مفعّل", "browse": "استعراض", "editor.name": "اسم المهمة", "editor.reminder_only": "تذكير فقط (بدون سكربت)", "editor.reminder_message": "رسالة التذكير", "editor.reminder_message_placeholder": "اختياري: نص التذكير", "editor.script_path": "مسار السكربت", "editor.args": "المعاملات", "editor.timeout": "مهلة التنفيذ", "editor.timeout_unit": "ثانية", "detail.mode": "الوضع", "detail.mode_script": "تشغيل سكربت", "detail.mode_reminder": "تذكير منبثق", "detail.reminder_message": "رسالة التذكير", "detail.notification_settings_hint": "إذا كانت محظورة، فعّل الإشعارات من إعدادات النظام.", "detail.open_notification_settings": "فتح إعدادات الإشعارات", "detail.send_test_notification": "إرسال إشعار تجريبي", "detail.notification_status": "حالة الإشعارات:", "detail.notification_status_authorized": "مسموح", "detail.notification_status_denied": "مرفوض", "detail.notification_status_not_determined": "غير محدد", "detail.notification_status_provisional": "مؤقت", "detail.notification_status_ephemeral": "جلسة مؤقتة", "detail.notification_status_unknown": "غير معروف", "detail.refresh_status": "تحديث", "detail.script": "السكربت", "detail.args": "المعاملات", "detail.timeout": "المهلة", "detail.logs_loading": "جارٍ تحميل السجلات...", "detail.logs_preview_prefix": "عرض أحدث", "detail.logs_preview_suffix": "سجل", "detail.load_all_logs": "تحميل كل السجلات", "detail.show_recent_logs": "عرض الأحدث فقط", "detail.showing_all_logs": "عرض كل السجلات", "detail.large_logs_trimmed_prefix": "تم اختصار السجلات الكبيرة:", "detail.large_logs_trimmed_suffix": "عنصر", "detail.load_full_large_logs": "تحميل المحتوى الكامل", "detail.show_large_logs_preview": "عرض المعاينة المختصرة", "schedule.once": "تشغيل مرة واحدة", "schedule.every_interval": "كل X دقيقة/ساعة/يوم", "schedule.weekly": "أيام أسبوع محددة", "schedule.monthly": "يوم محدد من الشهر", "schedule.every_x_days": "كل X أيام", "help.title": "مساعدة السكربت", "help.python": "لـ Python أضف هذا في أول سطر:", "help.shell": "لـ Shell أضف هذا في أول سطر:", "help.chmod": "إضافة صلاحية التنفيذ:", "help.close": "إغلاق", "column.name": "المهمة", "column.modified": "وقت التعديل", "language": "اللغة"
        ],
        .ru: [
            "btn.add": "Добавить", "btn.edit": "Изменить", "btn.delete": "Удалить", "ctx.run_now": "Запустить сейчас", "ctx.duplicate": "Дублировать задачу", "ctx.delete": "Удалить задачу", "btn.run_now": "Запустить сейчас", "btn.cancel": "Отмена", "btn.save": "Сохранить", "btn.help": "Справка", "enabled": "Включено", "browse": "Обзор", "editor.name": "Имя задачи", "editor.reminder_only": "Только напоминание (без скрипта)", "editor.reminder_message": "Текст напоминания", "editor.reminder_message_placeholder": "Необязательно: текст напоминания", "editor.script_path": "Путь к скрипту", "editor.args": "Аргументы", "editor.timeout": "Таймаут выполнения", "editor.timeout_unit": "сек", "detail.mode": "Режим", "detail.mode_script": "Запуск скрипта", "detail.mode_reminder": "Всплывающее напоминание", "detail.reminder_message": "Текст напоминания", "detail.notification_settings_hint": "Если заблокировано, включите уведомления в системных настройках.", "detail.open_notification_settings": "Открыть настройки уведомлений", "detail.send_test_notification": "Отправить тестовое уведомление", "detail.notification_status": "Статус уведомлений:", "detail.notification_status_authorized": "Разрешено", "detail.notification_status_denied": "Запрещено", "detail.notification_status_not_determined": "Не определено", "detail.notification_status_provisional": "Временное", "detail.notification_status_ephemeral": "Временная сессия", "detail.notification_status_unknown": "Неизвестно", "detail.refresh_status": "Обновить", "detail.script": "Скрипт", "detail.args": "Аргументы", "detail.timeout": "Таймаут", "detail.logs_loading": "Загрузка логов...", "detail.logs_preview_prefix": "Показаны последние", "detail.logs_preview_suffix": "логов", "detail.load_all_logs": "Загрузить все логи", "detail.show_recent_logs": "Показать только последние", "detail.showing_all_logs": "Показаны все", "detail.large_logs_trimmed_prefix": "Крупные логи сокращены:", "detail.large_logs_trimmed_suffix": "записей", "detail.load_full_large_logs": "Загрузить полный текст", "detail.show_large_logs_preview": "Показать сокращенно", "schedule.once": "Однократный запуск", "schedule.every_interval": "Каждые X минут/часов/дней", "schedule.weekly": "Дни недели", "schedule.monthly": "День месяца", "schedule.every_x_days": "Каждые X дней", "help.title": "Справка по скриптам", "help.python": "Для Python добавьте в первую строку:", "help.shell": "Для shell добавьте в первую строку:", "help.chmod": "Выдать право на выполнение:", "help.close": "Закрыть", "column.name": "Задача", "column.modified": "Время изменения", "language": "Язык"
        ],
        .fr: [
            "btn.add": "Ajouter", "btn.edit": "Modifier", "btn.delete": "Supprimer", "ctx.run_now": "Exécuter", "ctx.duplicate": "Dupliquer la tâche", "ctx.delete": "Supprimer la tâche", "btn.run_now": "Exécuter", "btn.cancel": "Annuler", "btn.save": "Enregistrer", "btn.help": "Aide", "enabled": "Activé", "browse": "Parcourir", "editor.name": "Nom de tâche", "editor.reminder_only": "Rappel uniquement (sans script)", "editor.reminder_message": "Message de rappel", "editor.reminder_message_placeholder": "Optionnel : texte du rappel", "editor.script_path": "Chemin du script", "editor.args": "Arguments", "editor.timeout": "Délai d'exécution", "editor.timeout_unit": "secondes", "detail.mode": "Mode", "detail.mode_script": "Exécuter le script", "detail.mode_reminder": "Rappel pop-up", "detail.reminder_message": "Message de rappel", "detail.notification_settings_hint": "Si bloqué, activez les notifications dans les réglages système.", "detail.open_notification_settings": "Ouvrir les réglages de notifications", "detail.send_test_notification": "Envoyer une notification de test", "detail.notification_status": "Statut des notifications :", "detail.notification_status_authorized": "Autorisé", "detail.notification_status_denied": "Refusé", "detail.notification_status_not_determined": "Non déterminé", "detail.notification_status_provisional": "Provisoire", "detail.notification_status_ephemeral": "Éphémère", "detail.notification_status_unknown": "Inconnu", "detail.refresh_status": "Actualiser", "detail.script": "Script", "detail.args": "Arguments", "detail.timeout": "Délai", "detail.logs_loading": "Chargement des journaux...", "detail.logs_preview_prefix": "Affichage des", "detail.logs_preview_suffix": "journaux récents", "detail.load_all_logs": "Charger tous les journaux", "detail.show_recent_logs": "Afficher seulement les récents", "detail.showing_all_logs": "Affichage de tous les", "detail.large_logs_trimmed_prefix": "Grands journaux tronqués :", "detail.large_logs_trimmed_suffix": "entrée(s)", "detail.load_full_large_logs": "Charger le contenu complet", "detail.show_large_logs_preview": "Afficher l'aperçu tronqué", "schedule.once": "Exécution unique", "schedule.every_interval": "Toutes les X minutes/heures/jours", "schedule.weekly": "Jours de semaine", "schedule.monthly": "Jour du mois", "schedule.every_x_days": "Tous les X jours", "help.title": "Aide script", "help.python": "Pour Python, ajoutez cette première ligne :", "help.shell": "Pour shell, ajoutez cette première ligne :", "help.chmod": "Donner la permission d'exécution :", "help.close": "Fermer", "column.name": "Tâche", "column.modified": "Heure modifiée", "language": "Langue"
        ],
        .es: [
            "btn.add": "Agregar", "btn.edit": "Editar", "btn.delete": "Eliminar", "ctx.run_now": "Ejecutar ahora", "ctx.duplicate": "Duplicar tarea", "ctx.delete": "Eliminar tarea", "btn.run_now": "Ejecutar ahora", "btn.cancel": "Cancelar", "btn.save": "Guardar", "btn.help": "Ayuda", "enabled": "Habilitado", "browse": "Examinar", "editor.name": "Nombre de tarea", "editor.reminder_only": "Solo recordatorio (sin script)", "editor.reminder_message": "Mensaje de recordatorio", "editor.reminder_message_placeholder": "Opcional: texto del recordatorio", "editor.script_path": "Ruta del script", "editor.args": "Argumentos", "editor.timeout": "Tiempo límite", "editor.timeout_unit": "segundos", "detail.mode": "Modo", "detail.mode_script": "Ejecutar script", "detail.mode_reminder": "Recordatorio emergente", "detail.reminder_message": "Mensaje de recordatorio", "detail.notification_settings_hint": "Si está bloqueado, habilita las notificaciones en Ajustes del sistema.", "detail.open_notification_settings": "Abrir ajustes de notificaciones", "detail.send_test_notification": "Enviar notificación de prueba", "detail.notification_status": "Estado de notificaciones:", "detail.notification_status_authorized": "Autorizado", "detail.notification_status_denied": "Denegado", "detail.notification_status_not_determined": "No determinado", "detail.notification_status_provisional": "Provisional", "detail.notification_status_ephemeral": "Efímero", "detail.notification_status_unknown": "Desconocido", "detail.refresh_status": "Actualizar", "detail.script": "Script", "detail.args": "Argumentos", "detail.timeout": "Límite de tiempo", "detail.logs_loading": "Cargando registros...", "detail.logs_preview_prefix": "Mostrando los últimos", "detail.logs_preview_suffix": "registros", "detail.load_all_logs": "Cargar todos los registros", "detail.show_recent_logs": "Mostrar solo recientes", "detail.showing_all_logs": "Mostrando todos los", "detail.large_logs_trimmed_prefix": "Registros grandes recortados:", "detail.large_logs_trimmed_suffix": "entrada(s)", "detail.load_full_large_logs": "Cargar contenido completo", "detail.show_large_logs_preview": "Mostrar vista recortada", "schedule.once": "Ejecutar una vez", "schedule.every_interval": "Cada X minutos/horas/días", "schedule.weekly": "Días de la semana", "schedule.monthly": "Día del mes", "schedule.every_x_days": "Cada X días", "help.title": "Ayuda de script", "help.python": "Para Python, agrega esta primera línea:", "help.shell": "Para shell, agrega esta primera línea:", "help.chmod": "Dar permiso de ejecución:", "help.close": "Cerrar", "column.name": "Tarea", "column.modified": "Hora de modificación", "language": "Idioma"
        ]
    ]
}
