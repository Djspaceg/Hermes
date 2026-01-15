//
//  HTTPClient.swift
//  Hermes
//
//  Modern URLSession wrapper with async/await and proxy support
//  Replaces legacy URLConnection.{h,m}
//

import Foundation

/// Notification posted when proxy validity changes
extension Notification.Name {
    static let proxyValidityChanged = Notification.Name("URLConnectionProxyValidityChangedNotification")
}

/// Errors that can occur during HTTP requests
enum HTTPClientError: Error, LocalizedError {
    case timeout
    case invalidResponse
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Connection timeout."
        case .invalidResponse:
            return "Invalid response from server."
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

/// Modern HTTP client using URLSession with async/await
@objc(HTTPClient)
@objcMembers
final class HTTPClient: NSObject {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let timeout: TimeInterval
    
    // MARK: - Initialization
    
    /// Create an HTTP client with optional proxy configuration
    /// - Parameters:
    ///   - timeout: Request timeout in seconds (default: 30)
    ///   - applyProxy: Whether to apply Hermes proxy settings (default: true)
    init(timeout: TimeInterval = 30, applyProxy: Bool = true) {
        self.timeout = timeout
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        
        if applyProxy {
            Self.applyHermesProxyConfiguration(to: config)
        }
        
        self.session = URLSession(configuration: config)
        super.init()
    }
    
    // MARK: - Public API (Swift)
    
    /// Perform an HTTP request asynchronously
    /// - Parameter request: The URL request to execute
    /// - Returns: Response data
    /// - Throws: HTTPClientError on failure
    func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPClientError.invalidResponse
            }
            
            // Check for HTTP errors
            guard (200...299).contains(httpResponse.statusCode) else {
                let error = NSError(
                    domain: "HTTPClient",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]
                )
                throw HTTPClientError.networkError(error)
            }
            
            return data
        } catch let error as HTTPClientError {
            throw error
        } catch {
            throw HTTPClientError.networkError(error)
        }
    }
    
    // MARK: - Public API (Objective-C Compatibility)
    
    /// Perform an HTTP request with completion handler (Objective-C compatible)
    /// - Parameters:
    ///   - request: The URL request to execute
    ///   - completion: Completion handler with data and error
    @objc
    func performRequest(_ request: URLRequest, completion: @escaping (Data?, Error?) -> Void) {
        Task {
            do {
                let data = try await performRequest(request)
                completion(data, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    /// Create an HTTP client and perform a request (matches URLConnection API)
    /// - Parameters:
    ///   - request: The URL request to execute
    ///   - completion: Completion handler with data and error
    /// - Returns: The HTTP client instance
    @objc
    static func performRequest(_ request: URLRequest, completion: @escaping (Data?, Error?) -> Void) -> HTTPClient {
        let client = HTTPClient()
        client.performRequest(request, completion: completion)
        return client
    }
    
    // MARK: - Proxy Configuration
    
    /// Apply Hermes proxy settings to a URLSession configuration
    /// - Parameter config: The configuration to modify
    static func applyHermesProxyConfiguration(to config: URLSessionConfiguration) {
        let defaults = UserDefaults.standard
        let proxyType = defaults.integer(forKey: UserDefaultsKeys.enabledProxy)
        
        switch proxyType {
        case ProxyType.http.rawValue:
            if let host = defaults.string(forKey: UserDefaultsKeys.httpProxyHost),
               let port = defaults.object(forKey: UserDefaultsKeys.httpProxyPort) as? Int,
               isValidProxy(host: host, port: port) {
                config.connectionProxyDictionary = [
                    kCFNetworkProxiesHTTPEnable: true,
                    kCFNetworkProxiesHTTPProxy: host,
                    kCFNetworkProxiesHTTPPort: port,
                    kCFNetworkProxiesHTTPSEnable: true,
                    kCFNetworkProxiesHTTPSProxy: host,
                    kCFNetworkProxiesHTTPSPort: port
                ]
            }
            
        case ProxyType.socks.rawValue:
            if let host = defaults.string(forKey: UserDefaultsKeys.socksProxyHost),
               let port = defaults.object(forKey: UserDefaultsKeys.socksProxyPort) as? Int,
               isValidProxy(host: host, port: port) {
                config.connectionProxyDictionary = [
                    kCFNetworkProxiesSOCKSEnable: true,
                    kCFNetworkProxiesSOCKSProxy: host,
                    kCFNetworkProxiesSOCKSPort: port
                ]
            }
            
        case ProxyType.system.rawValue:
            fallthrough
        default:
            // Use system proxy settings (default behavior)
            break
        }
    }
    
    /// Validate proxy host and port
    /// - Parameters:
    ///   - host: Proxy hostname
    ///   - port: Proxy port
    /// - Returns: True if valid
    @objc
    static func isValidProxy(host: String, port: Int) -> Bool {
        // Track validity changes for notification
        struct State {
            static var wasValid = true
        }
        
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        
        // Validate port range and host
        guard port > 0 && port <= 65535 && !trimmedHost.isEmpty else {
            return false
        }
        
        // Check if host is resolvable
        guard let host = Host(name: trimmedHost), host.address != nil else {
            return false
        }
        
        let isValid = true
        
        if isValid != State.wasValid {
            NotificationCenter.default.post(
                name: .proxyValidityChanged,
                object: nil,
                userInfo: ["isValid": isValid]
            )
            State.wasValid = isValid
        }
        
        return isValid
    }
}

// MARK: - Host Validation Helper

/// Helper class for validating hostnames using NSHost
private class Host {
    let address: String?
    
    init?(name: String) {
        // NSHost is deprecated but still functional for hostname resolution
        let nsHost = Foundation.Host(name: name)
        self.address = nsHost.address
        
        // Return nil if host couldn't be resolved
        if self.address == nil {
            return nil
        }
    }
}
