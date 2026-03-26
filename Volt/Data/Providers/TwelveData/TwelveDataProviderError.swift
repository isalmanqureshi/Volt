import Foundation

enum TwelveDataProviderError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidURL
    case requestFailed(statusCode: Int, message: String?)
    case emptyResponse
    case decodingFailed(String)
    case mappingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing Twelve Data API key"
        case .invalidURL: return "Invalid Twelve Data request URL"
        case .requestFailed(let statusCode, let message): return "HTTP \(statusCode): \(message ?? "Unknown error")"
        case .emptyResponse: return "Empty Twelve Data response"
        case .decodingFailed(let message): return "Failed to decode response: \(message)"
        case .mappingFailed(let message): return "Failed to map provider response: \(message)"
        }
    }
}
