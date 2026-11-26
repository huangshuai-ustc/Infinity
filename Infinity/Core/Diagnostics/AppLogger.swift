import OSLog

enum AppLogger {
    private static let logger = Logger(subsystem: "com.example.infinity", category: "desktop-pet")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
