import Foundation

protocol ClockProviding {
    var now: Date { get }
}

struct SystemClock: ClockProviding {
    var now: Date { Date() }
}
