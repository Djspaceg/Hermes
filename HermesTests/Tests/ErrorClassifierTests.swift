//
//  ErrorClassifierTests.swift
//  HermesTests
//
//  Property-based tests for ErrorClassifier
//  Feature: audio-stream-resilience, Property 4: Error classification correctness
//

import Testing
import Foundation
@testable import Hermes

// MARK: - Property 4: Error Classification Correctness

/// Property tests validating that error classification is correct and deterministic.
///
/// *For any* NSError with a POSIX domain and code in {50, 54, 61, 65}, the ErrorClassifier
/// SHALL return `.retriable`. *For any* HTTP status code in the 5xx range, or equal to 408
/// or 429, `classifyHTTPStatus` SHALL return `.retriable`. *For any* HTTP status code in the
/// 4xx range (excluding 408 and 429), `classifyHTTPStatus` SHALL return `.nonRetriable`.
/// The classification of any error SHALL be deterministic.
///
/// **Validates: Requirements 4.1, 4.2**
@Suite("ErrorClassifier Property Tests")
struct ErrorClassifierPropertyTests {

    // MARK: - Generators

    /// Retriable POSIX codes per the spec
    private static let retriablePOSIXCodes: [Int32] = [50, 54, 61, 65]

    /// Non-retriable POSIX codes — everything else in a reasonable range
    private static let nonRetriablePOSIXCodes: [Int32] = {
        let retriableSet: Set<Int32> = [50, 54, 61, 65]
        return (1...106).map { Int32($0) }.filter { !retriableSet.contains($0) }
    }()

    /// HTTP status codes that are retriable: 5xx + 408 + 429
    private static func randomRetriableHTTPStatus() -> Int {
        let pick = Int.random(in: 0...2)
        switch pick {
        case 0: return Int.random(in: 500...599)  // 5xx
        case 1: return 408                         // Request Timeout
        default: return 429                        // Too Many Requests
        }
    }

    /// HTTP 4xx codes that are non-retriable (excluding 408 and 429)
    private static func randomNonRetriable4xxStatus() -> Int {
        var code: Int
        repeat {
            code = Int.random(in: 400...499)
        } while code == 408 || code == 429
        return code
    }

    // MARK: - POSIX Error Classification

    @Test("Retriable POSIX codes classify as retriable")
    func retriablePOSIXCodesAreRetriable() {
        // Feature: audio-stream-resilience, Property 4: Error classification correctness
        // **Validates: Requirements 4.1, 4.2**

        for _ in 0..<100 {
            let code = Self.retriablePOSIXCodes.randomElement()!
            let error = NSError(domain: NSPOSIXErrorDomain, code: Int(code))
            let result = ErrorClassifier.classify(error)
            #expect(result == .retriable, "POSIX code \(code) should be retriable")
        }
    }

    @Test("Non-retriable POSIX codes classify as non-retriable")
    func nonRetriablePOSIXCodesAreNonRetriable() {
        // Feature: audio-stream-resilience, Property 4: Error classification correctness
        // **Validates: Requirements 4.1, 4.2**

        for _ in 0..<100 {
            let code = Self.nonRetriablePOSIXCodes.randomElement()!
            let error = NSError(domain: NSPOSIXErrorDomain, code: Int(code))
            let result = ErrorClassifier.classify(error)
            #expect(result == .nonRetriable, "POSIX code \(code) should be non-retriable")
        }
    }

    // MARK: - HTTP Status Classification

    @Test("5xx and 408/429 HTTP statuses classify as retriable")
    func retriableHTTPStatusesAreRetriable() {
        // Feature: audio-stream-resilience, Property 4: Error classification correctness
        // **Validates: Requirements 4.1, 4.2**

        for _ in 0..<100 {
            let status = Self.randomRetriableHTTPStatus()
            let result = ErrorClassifier.classifyHTTPStatus(status)
            #expect(result == .retriable, "HTTP \(status) should be retriable")
        }
    }

    @Test("4xx HTTP statuses (except 408, 429) classify as non-retriable")
    func nonRetriable4xxStatusesAreNonRetriable() {
        // Feature: audio-stream-resilience, Property 4: Error classification correctness
        // **Validates: Requirements 4.1, 4.2**

        for _ in 0..<100 {
            let status = Self.randomNonRetriable4xxStatus()
            let result = ErrorClassifier.classifyHTTPStatus(status)
            #expect(result == .nonRetriable, "HTTP \(status) should be non-retriable")
        }
    }

    // MARK: - Determinism

    @Test("Classification is deterministic — same error always produces same result")
    func classificationIsDeterministic() {
        // Feature: audio-stream-resilience, Property 4: Error classification correctness
        // **Validates: Requirements 4.1, 4.2**

        for _ in 0..<100 {
            // Random POSIX error
            let posixCode = Int.random(in: 1...106)
            let posixError = NSError(domain: NSPOSIXErrorDomain, code: posixCode)
            let first = ErrorClassifier.classify(posixError)
            let second = ErrorClassifier.classify(posixError)
            #expect(first == second, "POSIX \(posixCode) classification must be deterministic")

            // Random HTTP status
            let httpStatus = Int.random(in: 100...599)
            let httpFirst = ErrorClassifier.classifyHTTPStatus(httpStatus)
            let httpSecond = ErrorClassifier.classifyHTTPStatus(httpStatus)
            #expect(httpFirst == httpSecond, "HTTP \(httpStatus) classification must be deterministic")
        }
    }

    // MARK: - Boundary Coverage

    @Test("HTTP 408 and 429 are retriable despite being 4xx")
    func http408And429AreRetriable() {
        // Feature: audio-stream-resilience, Property 4: Error classification correctness
        // **Validates: Requirements 4.1, 4.2**

        #expect(ErrorClassifier.classifyHTTPStatus(408) == .retriable)
        #expect(ErrorClassifier.classifyHTTPStatus(429) == .retriable)
    }

    @Test("HTTP 5xx boundary values are retriable")
    func http5xxBoundariesAreRetriable() {
        // Feature: audio-stream-resilience, Property 4: Error classification correctness
        // **Validates: Requirements 4.1, 4.2**

        #expect(ErrorClassifier.classifyHTTPStatus(500) == .retriable)
        #expect(ErrorClassifier.classifyHTTPStatus(599) == .retriable)
    }

    @Test("HTTP 4xx boundary values (non-exception) are non-retriable")
    func http4xxBoundariesAreNonRetriable() {
        // Feature: audio-stream-resilience, Property 4: Error classification correctness
        // **Validates: Requirements 4.1, 4.2**

        #expect(ErrorClassifier.classifyHTTPStatus(400) == .nonRetriable)
        #expect(ErrorClassifier.classifyHTTPStatus(499) == .nonRetriable)
        #expect(ErrorClassifier.classifyHTTPStatus(404) == .nonRetriable)
        #expect(ErrorClassifier.classifyHTTPStatus(403) == .nonRetriable)
    }

    @Test("All four retriable POSIX codes are individually retriable")
    func allRetriablePOSIXCodesIndividually() {
        // Feature: audio-stream-resilience, Property 4: Error classification correctness
        // **Validates: Requirements 4.1, 4.2**

        for code in Self.retriablePOSIXCodes {
            let error = NSError(domain: NSPOSIXErrorDomain, code: Int(code))
            #expect(ErrorClassifier.classify(error) == .retriable, "POSIX \(code) must be retriable")
        }
    }
}


// MARK: - Unit Tests

/// Unit tests for ErrorClassifier covering specific known error codes.
/// These complement the property tests above by verifying exact, documented error codes.
///
/// _Requirements: 4.1, 4.2_
@Suite("ErrorClassifier Unit Tests")
struct ErrorClassifierUnitTests {

    // MARK: - POSIX Retriable Errors

    @Test("POSIX 54 (ECONNRESET) is retriable")
    func posix54IsRetriable() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: 54)
        #expect(ErrorClassifier.classify(error) == .retriable)
    }

    @Test("POSIX 61 (ECONNREFUSED) is retriable")
    func posix61IsRetriable() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: 61)
        #expect(ErrorClassifier.classify(error) == .retriable)
    }

    @Test("POSIX 65 (EHOSTUNREACH) is retriable")
    func posix65IsRetriable() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: 65)
        #expect(ErrorClassifier.classify(error) == .retriable)
    }

    @Test("POSIX 50 (ENETDOWN) is retriable")
    func posix50IsRetriable() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: 50)
        #expect(ErrorClassifier.classify(error) == .retriable)
    }

    // MARK: - HTTP Non-Retriable Errors

    @Test("HTTP 404 (Not Found) is non-retriable")
    func http404IsNonRetriable() {
        #expect(ErrorClassifier.classifyHTTPStatus(404) == .nonRetriable)
    }

    @Test("HTTP 403 (Forbidden) is non-retriable")
    func http403IsNonRetriable() {
        #expect(ErrorClassifier.classifyHTTPStatus(403) == .nonRetriable)
    }

    // MARK: - HTTP Retriable Errors

    @Test("HTTP 408 (Request Timeout) is retriable")
    func http408IsRetriable() {
        #expect(ErrorClassifier.classifyHTTPStatus(408) == .retriable)
    }

    @Test("HTTP 429 (Too Many Requests) is retriable")
    func http429IsRetriable() {
        #expect(ErrorClassifier.classifyHTTPStatus(429) == .retriable)
    }

    @Test("HTTP 500 (Internal Server Error) is retriable")
    func http500IsRetriable() {
        #expect(ErrorClassifier.classifyHTTPStatus(500) == .retriable)
    }

    @Test("HTTP 502 (Bad Gateway) is retriable")
    func http502IsRetriable() {
        #expect(ErrorClassifier.classifyHTTPStatus(502) == .retriable)
    }

    @Test("HTTP 503 (Service Unavailable) is retriable")
    func http503IsRetriable() {
        #expect(ErrorClassifier.classifyHTTPStatus(503) == .retriable)
    }
}
