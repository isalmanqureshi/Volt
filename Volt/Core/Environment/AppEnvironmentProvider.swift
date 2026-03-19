import Foundation

protocol EnvironmentProviding {
    var currentEnvironment: TradingEnvironment { get }
}

struct AppEnvironmentProvider: EnvironmentProviding {
    let currentEnvironment: TradingEnvironment
}
