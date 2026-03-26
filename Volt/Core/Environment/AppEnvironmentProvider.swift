import Foundation

protocol EnvironmentProviding: AnyObject {
    var currentEnvironment: TradingEnvironment { get }
    func updateEnvironment(_ environment: TradingEnvironment)
}

final class AppEnvironmentProvider: EnvironmentProviding {
    private(set) var currentEnvironment: TradingEnvironment

    init(currentEnvironment: TradingEnvironment) {
        self.currentEnvironment = currentEnvironment
    }

    func updateEnvironment(_ environment: TradingEnvironment) {
        currentEnvironment = environment
    }
}
