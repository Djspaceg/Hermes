//
//  NetworkMonitor.swift
//  Hermes
//
//  Network connectivity monitoring using NWPathMonitor
//

import Foundation
import Network
import Combine

/// Monitors network connectivity status using Apple's Network framework
@MainActor
class NetworkMonitor: ObservableObject {
    // MARK: - Properties
    
    /// Published property indicating current network connectivity status
    @Published private(set) var isConnected: Bool = true
    
    /// Combine publisher for reachability changes
    var reachabilityPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.hermes.networkmonitor")
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Initialization
    
    init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Starts monitoring network connectivity
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    /// Stops monitoring network connectivity
    func stopMonitoring() {
        monitor.cancel()
    }
}
