import Foundation

struct HebrewDate {
    let day: Int
    let monthName: String
    let year: Int

    var formatted: String {
        "\(day) \(monthName) \(year)"
    }
}

enum HebrewCalendar {

    private static let monthNames = [
        "Tishrei", "Cheshvan", "Kislev", "Tevet", "Shevat", "Adar",
        "Adar II", "Nisan", "Iyar", "Sivan", "Tammuz", "Av", "Elul"
    ]

    private static let monthNamesLeap = [
        "Tishrei", "Cheshvan", "Kislev", "Tevet", "Shevat", "Adar I",
        "Adar II", "Nisan", "Iyar", "Sivan", "Tammuz", "Av", "Elul"
    ]

    static func isLeapYear(_ year: Int) -> Bool {
        let mod = year % 19
        return [3, 6, 8, 11, 14, 17, 0].contains(mod)
    }

    private static func elapsedMonths(_ year: Int) -> Int {
        let fullCycles = (year - 1) / 19
        let remaining = (year - 1) % 19
        return fullCycles * 235 + (remaining * 7 + 1) / 19 + remaining * 12
    }

    private static func yearStart(_ year: Int) -> Int {
        let monthsElapsed = elapsedMonths(year)

        var parts = 204 + 793 * monthsElapsed
        var hours = 5 + 12 * monthsElapsed + parts / 1080
        parts = parts % 1080
        var days = 1 + 29 * monthsElapsed + hours / 24
        hours = hours % 24

        let dayOfWeek = days % 7
        var altDay = days

        // Dehiya 1: No Rosh Hashanah on Sun, Wed, or Fri
        if dayOfWeek == 0 || dayOfWeek == 3 || dayOfWeek == 5 {
            altDay = days + 1
        }

        // Dehiya 2: Late molad — postpone
        if hours >= 18 {
            altDay = days + 1
            let newDow = altDay % 7
            if newDow == 0 || newDow == 3 || newDow == 5 {
                altDay += 1
            }
        }

        // Dehiya 3: Non-leap year, Tuesday, molad >= 9h 204p
        if !isLeapYear(year) && dayOfWeek == 2 &&
            (hours > 9 || (hours == 9 && parts >= 204)) {
            altDay = days + 2
        }

        // Dehiya 4: After leap year, Monday, molad >= 15h 589p
        if isLeapYear(year - 1) && dayOfWeek == 1 &&
            (hours > 15 || (hours == 15 && parts >= 589)) {
            altDay = days + 1
        }

        if altDay > days { days = altDay }
        return days
    }

    private static func daysInYear(_ year: Int) -> Int {
        yearStart(year + 1) - yearStart(year)
    }

    private static func monthLengths(_ year: Int) -> [Int] {
        let yearLength = daysInYear(year)
        let leap = isLeapYear(year)

        var days = [30, 0, 0, 29, 30]
        if leap {
            days += [30, 29]
        } else {
            days += [29]
        }
        days += [30, 29, 30, 29, 30, 29]

        let base = leap ? 384 : 354
        if yearLength == base - 1 {
            days[1] = 29; days[2] = 29  // deficient
        } else if yearLength == base {
            days[1] = 29; days[2] = 30  // regular
        } else {
            days[1] = 30; days[2] = 30  // complete
        }
        return days
    }

    private static func gregorianToJDN(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y +
               y / 4 - y / 100 + y / 400 - 32045
    }

    private static let epochJDN = 347997

    // MARK: - Public API

    static func convert(year gyear: Int, month gmonth: Int, day gday: Int) -> HebrewDate {
        let jdn = gregorianToJDN(year: gyear, month: gmonth, day: gday)
        var hyear = gyear + 3761
        var startJDN = epochJDN + yearStart(hyear)

        while startJDN > jdn {
            hyear -= 1
            startJDN = epochJDN + yearStart(hyear)
        }
        var nextStartJDN = epochJDN + yearStart(hyear + 1)
        while nextStartJDN <= jdn {
            hyear += 1
            startJDN = nextStartJDN
            nextStartJDN = epochJDN + yearStart(hyear + 1)
        }

        let mdays = monthLengths(hyear)
        var remaining = jdn - startJDN
        var hmonth = 0
        let leap = isLeapYear(hyear)

        for i in 0..<mdays.count {
            if remaining < mdays[i] {
                hmonth = i
                break
            }
            remaining -= mdays[i]
        }
        let hday = remaining + 1

        let monthName: String
        if leap {
            monthName = monthNamesLeap[hmonth]
        } else if hmonth <= 5 {
            monthName = monthNames[hmonth]
        } else {
            monthName = monthNames[hmonth + 1]
        }

        return HebrewDate(day: hday, monthName: monthName, year: hyear)
    }

    static func convert(from date: Date) -> HebrewDate {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return convert(year: comps.year!, month: comps.month!, day: comps.day!)
    }
}
