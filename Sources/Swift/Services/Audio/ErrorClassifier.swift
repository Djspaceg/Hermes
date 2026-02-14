//
//  ErrorClassifier.swift
//  Hermes
//
//  Classifies network errors as retriable or non-retriable for audio streaming resilience.
//  Used by AudioStreamer to determine whether to attempt in-place reconnection or fail immediately.
//

import Foundation

// MARK: - NetworkErrorCategory

/// Categorizes errors into retriable (transient) and non-retriable (permanent) for retry decisions
enum NetworkErrorCategory {
    /// Transient error — should attempt reconnection
    case retriable
    /// Permanent error — should fail immediately without retrying
    case nonRetriable
}

// MARK: - ErrorClassifier

/// Pure value-type utility that categorizes network errors.
/// No state, no side effects — just classification logic.
struct ErrorClassifier {

    // MARK: - POSIX Error Codes

    /// POSIX error codes considered retriable (transient network conditions)
    private static let retriablePOSIXCodes: Set<Int32> = [
        50,  // ENETDOWN — network is down
        54,  // ECONNRESET — connection reset by peer
        61,  // ECONNREFUSED — connection refused
        65,  // EHOSTUNREACH — no route to host
    ]

    // MARK: - Error Classification

    /// Classifies a generic `Error` as retriable or non-retriable.
    ///
    /// Checks for POSIX errors, DNS failures, TLS/SSL failures, and CFNetwork timeouts.
    /// Errors that don't match any known retriable pattern are treated as non-retriable.
    ///
    /// - Parameter error: The error to classify
    /// - Returns: `.retriable` for transient network errors, `.nonRetriable` otherwise
    static func classify(_ error: Error) -> NetworkErrorCategory {
        let nsError = error as NSError

        // POSIX domain errors
        if nsError.domain == NSPOSIXErrorDomain {
            return retriablePOSIXCodes.contains(Int32(nsError.code)) ? .retriable : .nonRetriable
        }

        // CFNetwork / NSURLError domain errors
        if nsError.domain == NSURLErrorDomain {
            return classifyCFNetworkError(nsError.code)
        }

        // NSStream errors that wrap POSIX codes
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == "kCFErrorDomainCFNetwork" {
            // Check underlying error
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                return classify(underlying)
            }
        }

        return .nonRetriable
    }

    // MARK: - HTTP Status Classification

    /// Classifies an HTTP status code as retriable or non-retriable.
    ///
    /// - 5xx server errors → retriable
    /// - 408 Request Timeout → retriable
    /// - 429 Too Many Requests → retriable
    /// - Other 4xx client errors → non-retriable
    /// - All other codes → non-retriable
    ///
    /// - Parameter statusCode: The HTTP response status code
    /// - Returns: `.retriable` for transient server errors, `.nonRetriable` otherwise
    static func classifyHTTPStatus(_ statusCode: Int) -> NetworkErrorCategory {
        switch statusCode {
        case 408, 429:
            return .retriable
        case 500...599:
            return .retriable
        case 400...499:
            return .nonRetriable
        default:
            return .nonRetriable
        }
    }

    // MARK: - Private Helpers

    /// Classifies NSURLError domain codes into retriable/non-retriable categories.
    private static func classifyCFNetworkError(_ code: Int) -> NetworkErrorCategory {
        switch code {
        // DNS failures
        case NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed:
            return .retriable

        // TLS/SSL failures
        case NSURLErrorSecureConnectionFailed,
             NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasUnknownRoot,
             NSURLErrorServerCertificateNotYetValid,
             NSURLErrorClientCertificateRejected,
             NSURLErrorClientCertificateRequired:
            return .retriable

        // Timeout
        case NSURLErrorTimedOut:
            return .retriable

        // Connection failures
        case NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorCannotConnectToHost:
            return .retriable

        default:
            return .nonRetriable
        }
    }
}
