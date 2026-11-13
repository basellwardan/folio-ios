import SwiftUI

/// The app language the user picked in the globe menu on the home screen.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, arabic

    var id: String { rawValue }

    /// Shown in the menu; each language is written in its own script.
    var menuTitle: String {
        switch self {
        case .system: tr("System language")
        case .english: "English"
        case .arabic: "العربية"
        }
    }
}

/// Holds the current language. Changing it re-renders the whole app (see `RootView`),
/// flips the layout to right-to-left for Arabic, and switches date formats.
@Observable
final class Localizer {
    static let shared = Localizer()

    private static let key = "appLanguage"

    private(set) var language: AppLanguage

    func setLanguage(_ new: AppLanguage) {
        language = new
        UserDefaults.standard.set(new.rawValue, forKey: Self.key)
        // Lets iOS show its own screens (camera scanner, Face ID prompt) in the same language
        // from the next launch.
        switch new {
        case .system: UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english: UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .arabic: UserDefaults.standard.set(["ar"], forKey: "AppleLanguages")
        }
    }

    private init() {
        // Also reads `-appLanguage arabic` passed as a launch argument (CI screenshots).
        let saved = UserDefaults.standard.string(forKey: Self.key) ?? ""
        language = AppLanguage(rawValue: saved) ?? .system
    }

    var isArabic: Bool {
        switch language {
        case .arabic: true
        case .english: false
        case .system: Locale.preferredLanguages.first?.hasPrefix("ar") ?? false
        }
    }

    /// Arabic with Western digits, so dates match the numbers printed on the documents.
    var locale: Locale {
        if isArabic { return Locale(identifier: "ar@numbers=latn") }
        return language == .english ? Locale(identifier: "en_US") : .current
    }

    var layoutDirection: LayoutDirection { isArabic ? .rightToLeft : .leftToRight }
}

// MARK: - Lookup

/// Translates an English UI string. English is the key; unknown keys fall back to English.
func tr(_ english: String) -> String {
    guard Localizer.shared.isArabic else { return english }
    return L10n.arabic[english] ?? english
}

/// Translates a format string, then fills in the arguments (use `%@`, or `%1$@`/`%2$@` when
/// Arabic needs a different word order).
func tr(_ english: String, _ args: CVarArg...) -> String {
    String(format: tr(english), locale: Localizer.shared.locale, arguments: args)
}

enum L10n {
    // MARK: Counted nouns (Arabic has singular, dual, 3–10 plural and 11+ forms)

    static func documents(_ n: Int) -> String {
        Localizer.shared.isArabic
            ? arabicCount(n, one: "مستند واحد", two: "مستندان", few: "مستندات", many: "مستندًا")
            : (n == 1 ? "1 document" : "\(n) documents")
    }

    static func days(_ n: Int) -> String {
        Localizer.shared.isArabic
            ? arabicCount(n, one: "يوم واحد", two: "يومان", few: "أيام", many: "يومًا")
            : (n == 1 ? "1 day" : "\(n) days")
    }

    /// Big countdown on the Key Dates panel ("12 Days", "3 Months", "2 Years").
    static func countdownDays(_ n: Int) -> String {
        Localizer.shared.isArabic ? days(n) : (n == 1 ? "1 Day" : "\(n) Days")
    }

    static func countdownMonths(_ n: Int) -> String {
        Localizer.shared.isArabic
            ? arabicCount(n, one: "شهر واحد", two: "شهران", few: "أشهر", many: "شهرًا")
            : (n == 1 ? "1 Month" : "\(n) Months")
    }

    static func countdownYears(_ n: Int) -> String {
        Localizer.shared.isArabic
            ? arabicCount(n, one: "سنة واحدة", two: "سنتان", few: "سنوات", many: "سنة")
            : (n == 1 ? "1 Year" : "\(n) Years")
    }

    private static func arabicCount(_ n: Int, one: String, two: String, few: String, many: String) -> String {
        switch n {
        case 1: one
        case 2: two
        case 3...10: "\(n) \(few)"
        default: n == 0 ? "0 \(few)" : "\(n) \(many)"
        }
    }

    // MARK: Arabic strings

    static let arabic: [String: String] = [
        // Home
        "Scan": "مسح",
        "Expiring": "قريب الانتهاء",
        "Add Document": "إضافة مستند",
        "Language": "اللغة",
        "System language": "لغة الجهاز",
        "Welcome to Folio": "مرحبًا بك في Folio",
        "Create a folder for each person, then add their IDs, passports and licenses.":
            "أنشئ مجلدًا لكل شخص، ثم أضف هوياته وجوازات سفره ورخصه.",
        "Add a person": "إضافة شخص",
        "% valid": "٪ صالحة",
        "%@ · %@ due": "%@ · %@ مستحقة",
        "New person": "شخص جديد",

        // Key dates
        "Key Dates": "التواريخ المهمة",
        "%@ · renewals": "%@ · التجديدات",
        "All renewals": "كل التجديدات",
        "No documents yet": "لا توجد مستندات بعد",
        "All clear": "كل شيء سليم",
        "Today": "اليوم",
        "Add a document to track its expiry": "أضف مستندًا لمتابعة تاريخ انتهائه",
        "Nothing expires soon": "لا شيء ينتهي قريبًا",
        "We're here": "نحن هنا",

        // Expiring list
        "Needs attention": "بحاجة إلى انتباه",
        "Everything is up to date": "كل مستنداتك سارية",
        "Nothing expires in the next 90 days.": "لا شيء ينتهي خلال الـ 90 يومًا القادمة.",
        "%@ ago": "منذ %@",
        "in %@": "بعد %@",

        // Person
        "Edit person": "تعديل الشخص",
        "Delete person": "حذف الشخص",
        "Add document": "إضافة مستند",
        "Delete %@?": "حذف %@؟",
        "Delete person and %@": "حذف الشخص و%@",
        "Their scans are erased from this iPhone. This cannot be undone.":
            "ستُحذف صوره الممسوحة من هذا الآيفون. لا يمكن التراجع عن ذلك.",
        "Folder since %@": "مجلد منذ %@",
        "Documents": "المستندات",
        "Valid": "سارية",
        "Expired": "منتهية",
        "No expiry": "بلا انتهاء",
        "This folder is empty": "هذا المجلد فارغ",
        "Scan or import %@'s ID, passport or license.": "امسح أو استورد هوية %@ أو جواز سفره أو رخصته.",
        "Add first document": "إضافة أول مستند",

        // Document
        "Tap to flip · drag to spin": "اضغط للقلب · اسحب للتدوير",
        "Notes": "ملاحظات",
        "Delete document": "حذف المستند",
        "Edit": "تعديل",
        "Delete this document?": "حذف هذا المستند؟",
        "Delete": "حذف",
        "The scans are erased from this iPhone. This cannot be undone.":
            "ستُحذف الصور الممسوحة من هذا الآيفون. لا يمكن التراجع عن ذلك.",
        "Details": "التفاصيل",
        "Number": "الرقم",
        "Holder": "صاحب المستند",
        "Type": "النوع",
        "Issued by": "جهة الإصدار",
        "Issue date": "تاريخ الإصدار",
        "Expiry date": "تاريخ الانتهاء",
        "Expires today": "ينتهي اليوم",
        "Expires in %@": "ينتهي بعد %@",
        "Expired %@ ago": "انتهى منذ %@",
        "Scans": "الصور الممسوحة",
        "Front": "الوجه الأمامي",
        "Back": "الوجه الخلفي",
        "Add front": "إضافة الوجه الأمامي",
        "Add back": "إضافة الوجه الخلفي",
        "ISSUED": "الإصدار",
        "EXPIRES": "الانتهاء",
        "No back side scanned": "لم يُمسح الوجه الخلفي",
        "No number": "بلا رقم",

        // Document editor
        "Reading text on device…": "جارٍ قراءة النص على الجهاز…",
        "Owner": "المالك",
        "Person": "الشخص",
        "Title (optional)": "العنوان (اختياري)",
        "Document number": "رقم المستند",
        "Dates": "التواريخ",
        "Issued": "صدر في",
        "Expires": "له تاريخ انتهاء",
        "Expiry": "ينتهي في",
        "You'll get reminders 90, 30 and 7 days before.": "ستصلك تذكيرات قبل 90 و30 و7 أيام من الانتهاء.",
        "Anything else": "أي معلومات أخرى",
        "New document": "مستند جديد",
        "Edit document": "تعديل المستند",
        "Cancel": "إلغاء",
        "Save": "حفظ",
        "Found on the scan": "وُجد في الصورة",
        "No. %@": "رقم %@",
        "Expires %@": "ينتهي %@",
        "Issued %@": "صدر %@",
        "That photo could not be opened.": "تعذّر فتح هذه الصورة.",

        // Person editor
        "Name": "الاسم",
        "NAME": "الاسم",
        "Full name": "الاسم الكامل",
        "COLOR": "اللون",

        // Lock
        "Folio is locked": "Folio مقفل",
        "Your documents stay encrypted on this iPhone.": "تبقى مستنداتك مشفّرة على هذا الآيفون.",
        "Unlock with %@": "فتح باستخدام %@",
        "Passcode": "رمز الدخول",
        "Unlock your documents": "افتح مستنداتك",

        // Reminders
        "%@ expires today": "%@ ينتهي اليوم",
        "%@ expires in %@": "%@ ينتهي بعد %@",
        "%1$@'s %2$@ needs renewing.": "%2$@ الخاص بـ %1$@ يحتاج إلى التجديد.",

        // Document types
        "National ID": "الهوية الوطنية",
        "Passport": "جواز السفر",
        "Driver's License": "رخصة القيادة",
        "Residence Permit": "تصريح الإقامة",
        "Health Insurance": "التأمين الصحي",
        "Birth Certificate": "شهادة الميلاد",
        "Vehicle Registration": "تسجيل المركبة",
        "Other": "أخرى",
        "ID": "هوية",
        "License": "رخصة",
        "Residency": "إقامة",
        "Insurance": "تأمين",
        "Birth": "ميلاد",
        "Vehicle": "مركبة",
    ]
}
