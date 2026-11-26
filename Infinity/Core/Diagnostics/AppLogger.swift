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

enum DiagnosticCategory {
    case lifecycle
}

enum DiagnosticLevel {
    case info
    case error
}

struct DiagnosticLogger {
    static let shared = DiagnosticLogger()

    func log(_ category: DiagnosticCategory, _ message: String, level: DiagnosticLevel = .info) {
        switch level {
        case .info: AppLogger.info(message)
        case .error: AppLogger.error(message)
        }
    }
}
