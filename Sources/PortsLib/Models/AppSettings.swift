import Foundation
import Combine

public class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published public var scanInterval: TimeInterval {
        didSet { defaults.set(scanInterval, forKey: Keys.scanInterval) }
    }

    @Published public var excludedPorts: Set<Int> {
        didSet { defaults.set(Array(excludedPorts), forKey: Keys.excludedPorts) }
    }

    @Published public var portLabels: [Int: String] {
        didSet {
            let encoded = portLabels.reduce(into: [String: String]()) { dict, pair in
                dict[String(pair.key)] = pair.value
            }
            defaults.set(encoded, forKey: Keys.portLabels)
        }
    }

    @Published public var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private enum Keys {
        static let scanInterval = "scanInterval"
        static let excludedPorts = "excludedPorts"
        static let portLabels = "portLabels"
        static let notificationsEnabled = "notificationsEnabled"
        static let launchAtLogin = "launchAtLogin"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let interval = defaults.double(forKey: Keys.scanInterval)
        self.scanInterval = interval > 0 ? interval : Constants.defaultScanInterval

        if let stored = defaults.array(forKey: Keys.excludedPorts) as? [Int] {
            self.excludedPorts = Set(stored)
        } else {
            self.excludedPorts = Constants.defaultExcludedPorts
        }

        if let stored = defaults.dictionary(forKey: Keys.portLabels) as? [String: String] {
            self.portLabels = stored.reduce(into: [Int: String]()) { dict, pair in
                if let key = Int(pair.key) {
                    dict[key] = pair.value
                }
            }
        } else {
            self.portLabels = [:]
        }

        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? false
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
    }
}
