import Foundation

enum TwelveDataMapperError: Error, Equatable {
    case invalidPrice(String)
    case invalidDate(String)
}

enum TwelveDataMapper {
    private static let quoteDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func mapQuote(_ dto: TwelveDataQuoteDTO, fallbackDate: Date = Date()) throws -> Quote {
        guard let close = dto.close, let price = Decimal(string: close) else {
            throw TwelveDataMapperError.invalidPrice(dto.close ?? "nil")
        }

        let changePercent = Decimal(string: dto.percentChange ?? "0") ?? 0
        let timestamp = resolveQuoteTimestamp(dto: dto, fallbackDate: fallbackDate)

        return Quote(
            symbol: dto.symbol,
            lastPrice: price,
            changePercent: changePercent,
            timestamp: timestamp,
            source: "twelveData",
            isSimulated: false
        )
    }

    static func mapCandles(_ dto: TwelveDataTimeSeriesDTO) throws -> [Candle] {
        try dto.values.map { value in
            guard
                let open = Decimal(string: value.open),
                let high = Decimal(string: value.high),
                let low = Decimal(string: value.low),
                let close = Decimal(string: value.close)
            else {
                throw TwelveDataMapperError.invalidPrice("OHLC parsing failed")
            }

            let volume = Decimal(string: value.volume ?? "0") ?? 0
            guard let date = parseTimeSeriesDate(value.datetime) else {
                throw TwelveDataMapperError.invalidDate(value.datetime)
            }

            return Candle(
                symbol: dto.meta.symbol,
                interval: dto.meta.interval,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                timestamp: date,
                isComplete: true
            )
        }
    }

    private static func resolveQuoteTimestamp(dto: TwelveDataQuoteDTO, fallbackDate: Date) -> Date {
        if let timestamp = dto.timestamp {
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }

        if let dateText = dto.datetime {
            if let date = quoteDateFormatter.date(from: dateText) {
                return date
            }

            if let parsed = DateFormatter.twelveDataDateTime.date(from: dateText) {
                return parsed
            }
        }

        return fallbackDate
    }

    private static func parseTimeSeriesDate(_ value: String) -> Date? {
        DateFormatter.twelveDataDateTime.date(from: value) ?? quoteDateFormatter.date(from: value)
    }
}

private extension DateFormatter {
    static let twelveDataDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
