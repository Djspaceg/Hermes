//
//  PandoraModels.swift
//  Hermes
//
//  Request/response models and error types extracted from PandoraClient
//

import Foundation

// MARK: - Constants

internal let pandoraAPIPath = "/services/json/"
internal let pandoraAPIVersion = "5"

// MARK: - Error Codes

internal let invalidSyncTime = 13
internal let invalidAuthToken = 1001
internal let invalidPartnerLogin = 1002
internal let invalidUsername = 1011
internal let invalidPassword = 1012
internal let noSeedsLeft = 1032

// MARK: - PandoraError

/// Errors that can occur during Pandora API operations
enum PandoraError: Error, LocalizedError {
    case invalidSyncTime
    case invalidAuthToken
    case invalidPartnerLogin
    case invalidUsername
    case invalidPassword
    case noSeedsLeft
    case networkError(Error)
    case apiError(code: Int, message: String)
    case encodingError
    case decodingError
    case notAuthenticated
    
    /// Create a PandoraError from an API error code
    static func from(code: Int) -> PandoraError? {
        switch code {
        case 13: return .invalidSyncTime
        case 1001: return .invalidAuthToken
        case 1002: return .invalidPartnerLogin
        case 1011: return .invalidUsername
        case 1012: return .invalidPassword
        case 1032: return .noSeedsLeft
        default: return nil
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidSyncTime:
            return "Bad sync time"
        case .invalidAuthToken:
            return "Invalid authentication token"
        case .invalidPartnerLogin:
            return "Invalid partner login"
        case .invalidUsername:
            return "Invalid username"
        case .invalidPassword:
            return "Invalid password"
        case .noSeedsLeft:
            return "Cannot remove all seeds"
        case .networkError(let error):
            return error.localizedDescription
        case .apiError(_, let message):
            return message
        case .encodingError:
            return "Failed to encode request"
        case .decodingError:
            return "Failed to decode response"
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
    
    /// Get error message for a Pandora error code
    static func message(for code: Int) -> String? {
        let lowErrors: [Int: String] = [
            0: "Internal Pandora error",
            1: "Pandora is in Maintenance Mode",
            2: "URL is missing method parameter",
            3: "URL is missing auth token",
            4: "URL is missing partner ID",
            5: "URL is missing user ID",
            6: "A secure protocol is required for this request",
            7: "A certificate is required for the request",
            8: "Parameter type mismatch",
            9: "Parameter is missing",
            10: "Parameter value is invalid",
            11: "API version is not supported",
            12: "Pandora is not available in this country",
            13: "Bad sync time",
            14: "Unknown method name",
            15: "Wrong protocol used"
        ]
        
        let highErrors: [Int: String] = [
            1000: "Read only mode",
            1001: "Invalid authentication token",
            1002: "Wrong user credentials",
            1003: "Listener not authorized",
            1004: "User not authorized",
            1005: "Station limit reached",
            1006: "Station does not exist",
            1007: "Complimentary period already in use",
            1008: "Call not allowed",
            1009: "Device not found",
            1010: "Partner not authorized",
            1011: "Invalid username",
            1012: "Invalid password",
            1013: "Username already exists",
            1014: "Device already associated to account",
            1015: "Upgrade, device model is invalid",
            1018: "Explicit PIN incorrect",
            1020: "Explicit PIN malformed",
            1023: "Device model invalid",
            1024: "ZIP code invalid",
            1025: "Birth year invalid",
            1026: "Birth year too young",
            1027: "Invalid country code",
            1028: "Invalid gender",
            1032: "Cannot remove all seeds",
            1034: "Device disabled",
            1035: "Daily trial limit reached",
            1036: "Invalid sponsor",
            1037: "User already used trial"
        ]
        
        if code < 16 {
            return lowErrors[code]
        } else if code >= 1000 && code <= 1037 {
            return highErrors[code]
        }
        return nil
    }
}

// MARK: - PandoraSearchResult

/// Search result from Pandora API
@objc(SwiftPandoraSearchResult)
@objcMembers
final class PandoraSearchResult: NSObject {
    var name: String = ""
    var value: String = ""
    
    override init() {
        super.init()
    }
    
    init(name: String, value: String) {
        self.name = name
        self.value = value
        super.init()
    }
}

// MARK: - PandoraRequest

/// Pandora API request object
@objc(SwiftPandoraRequest)
@objcMembers
final class PandoraRequest: NSObject, NSCopying {
    
    // MARK: URL Parameters
    
    /// Pandora API method to use
    var method: String = ""
    
    /// Auth token obtained from auth.userLogin (or auth.partnerLogin)
    var authToken: String = ""
    
    /// Partner id as obtained by auth.partnerLogin
    var partnerId: String = ""
    
    /// User id obtained from auth.userLogin
    var userId: String = ""
    
    // MARK: JSON Data
    
    var request: [String: Any] = [:]
    var response: NSMutableData = NSMutableData()
    
    // MARK: Internal Metadata
    
    var callback: (([String: Any]) -> Void)?
    var tls: Bool = true
    var encrypted: Bool = true
    
    // MARK: Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: NSCopying
    
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = PandoraRequest()
        copy.method = method
        copy.authToken = authToken
        copy.partnerId = partnerId
        copy.userId = userId
        copy.request = request
        copy.response = response.mutableCopy() as! NSMutableData
        copy.callback = callback
        copy.tls = tls
        copy.encrypted = encrypted
        return copy
    }
    
    // MARK: Description
    
    override var description: String {
        return "<\(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque()) \(method)>"
    }
}

// MARK: - Error Code Helper

extension PandoraClient {
    
    /// Get error message for a Pandora error code
    @objc static func string(forErrorCode code: Int) -> String? {
        return PandoraError.message(for: code)
    }
}
