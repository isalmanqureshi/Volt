import OSLog

enum AppLogger {
    static let app = Logger(subsystem: "com.volt.app", category: "app")
    static let market = Logger(subsystem: "com.volt.app", category: "market")
    static let portfolio = Logger(subsystem: "com.volt.app", category: "portfolio")
    static let analytics = Logger(subsystem: "com.volt.app", category: "analytics")
    static let migration = Logger(subsystem: "com.volt.app", category: "migration")
    static let scenario = Logger(subsystem: "com.volt.app", category: "scenario")
}
