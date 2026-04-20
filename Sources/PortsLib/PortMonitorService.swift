import Foundation
import Combine

public class PortMonitorService: ObservableObject {
    @Published public var ports: [PortInfo] = []
    @Published public var scanError: String?
    @Published public var isScanning: Bool = false

    public let settings: AppSettings

    private let scanner: PortScannerProtocol
    private let resolver: ProjectResolverProtocol
    private let healthChecker: HealthCheckerProtocol
    private let notificationService: NotificationServiceProtocol

    private var timer: Timer?
    private var settingsCancellable: AnyCancellable?

    public init(
        scanner: PortScannerProtocol = PortScanner(),
        resolver: ProjectResolverProtocol = ProjectResolver(),
        healthChecker: HealthCheckerProtocol = HealthChecker(),
        notificationService: NotificationServiceProtocol = NotificationService(),
        settings: AppSettings = AppSettings()
    ) {
        self.scanner = scanner
        self.resolver = resolver
        self.healthChecker = healthChecker
        self.notificationService = notificationService
        self.settings = settings

        settingsCancellable = settings.$scanInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.restartTimer()
            }
    }

    public func startMonitoring() {
        performScan()
        startTimer()
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() {
        performScan()
    }

    public func killProcess(pid: Int32) -> Bool {
        return ShellExecutor.kill(pid: pid)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: settings.scanInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performScan()
        }
    }

    private func restartTimer() {
        guard timer != nil else { return }
        startTimer()
    }

    private func performScan() {
        let excludedPorts = settings.excludedPorts
        let excludedNames = Constants.excludedProcessNames
        let scanner = self.scanner
        let resolver = self.resolver
        let healthChecker = self.healthChecker

        DispatchQueue.main.async { [weak self] in
            self?.isScanning = true
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                var scanned = try scanner.scan(
                    excludedPorts: excludedPorts,
                    excludedProcessNames: excludedNames
                )

                for i in scanned.indices {
                    if let name = resolver.resolve(pid: scanned[i].pid) {
                        scanned[i].projectName = name
                    }
                }

                for i in scanned.indices {
                    scanned[i].status = healthChecker.check(port: scanned[i].port)
                }

                DispatchQueue.main.async {
                    guard let self else { return }
                    self.applyLabels(&scanned)
                    self.detectDisappearedPorts(current: scanned)
                    self.invalidateStaleCacheEntries(current: scanned)
                    self.ports = scanned
                    self.scanError = nil
                    self.isScanning = false
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.scanError = error.localizedDescription
                    self.isScanning = false
                }
            }
        }
    }

    private func applyLabels(_ ports: inout [PortInfo]) {
        for i in ports.indices {
            if let label = settings.portLabels[ports[i].port] {
                ports[i].label = label
            }
        }
    }

    private func detectDisappearedPorts(current: [PortInfo]) {
        guard settings.notificationsEnabled else { return }
        guard !ports.isEmpty else { return }

        let currentPorts = Set(current.map(\.port))
        for prev in ports where !currentPorts.contains(prev.port) {
            notificationService.notifyPortDown(
                port: prev.port,
                projectName: prev.label ?? prev.projectName
            )
        }
    }

    private func invalidateStaleCacheEntries(current: [PortInfo]) {
        let currentPids = Set(current.map(\.pid))
        let previousPids = Set(ports.map(\.pid))
        let gone = previousPids.subtracting(currentPids)
        if !gone.isEmpty {
            resolver.invalidateCache(for: gone)
        }
    }
}
