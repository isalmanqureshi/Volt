import Foundation

protocol DemoScenarioBootstrapping {
    var scenarios: [DemoScenario] { get }
    func applyScenario(id: String)
    func resetScenario()
}
