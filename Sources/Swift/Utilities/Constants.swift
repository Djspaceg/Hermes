//
//  Constants.swift
//  Hermes
//
//  Type-safe Swift constants migrated from HermesConstants.h
//  Objective-C code continues to use HermesConstants.h macros
//

import Foundation

// MARK: - Proxy Type

/// Proxy configuration type for network connections
enum ProxyType: Int, CaseIterable {
    case system = 0
    case http = 1
    case socks = 2
    
    var displayName: String {
        switch self {
        case .system: return "System Proxy"
        case .http: return "HTTP Proxy"
        case .socks: return "SOCKS Proxy"
        }
    }
}

// MARK: - Audio Quality

/// Audio streaming quality setting
enum AudioQuality: Int, CaseIterable {
    case high = 0
    case medium = 1
    case low = 2
    
    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

// MARK: - Station Sort Order

/// Station list sorting options
enum StationSortOrder: Int, CaseIterable {
    case dateAscending = 0
    case dateDescending = 1
    case nameAscending = 2
    case nameDescending = 3
    
    var displayName: String {
        switch self {
        case .dateAscending: return "Date (Oldest First)"
        case .dateDescending: return "Date (Newest First)"
        case .nameAscending: return "Name (A-Z)"
        case .nameDescending: return "Name (Z-A)"
        }
    }
}

// MARK: - Objective-C Compatibility

/// Objective-C compatible wrapper for Swift constants
/// Use this class when Objective-C code needs access to Swift-defined constants
/// Note: For UserDefaults keys, use UserDefaultsKeys.swift directly
@objc(HermesSwiftConstants)
@objcMembers
final class HermesSwiftConstants: NSObject {
    
    // MARK: Proxy Types
    static let proxyTypeSystem: Int = ProxyType.system.rawValue
    static let proxyTypeHTTP: Int = ProxyType.http.rawValue
    static let proxyTypeSOCKS: Int = ProxyType.socks.rawValue
    
    // MARK: Audio Quality
    static let audioQualityHigh: Int = AudioQuality.high.rawValue
    static let audioQualityMedium: Int = AudioQuality.medium.rawValue
    static let audioQualityLow: Int = AudioQuality.low.rawValue
    
    // MARK: Station Sort Order
    static let sortDateAscending: Int = StationSortOrder.dateAscending.rawValue
    static let sortDateDescending: Int = StationSortOrder.dateDescending.rawValue
    static let sortNameAscending: Int = StationSortOrder.nameAscending.rawValue
    static let sortNameDescending: Int = StationSortOrder.nameDescending.rawValue
    
    private override init() {
        super.init()
    }
}
