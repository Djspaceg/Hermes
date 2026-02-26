//
//  UpdateCheckerTests.swift
//  HermesTests
//
//  Tests for UpdateChecker version comparison and GitHub release parsing.
//

import XCTest
@testable import Hermes

// MARK: - Mock URL Protocol

/// Intercepts URLSession requests and returns a pre-configured stub response.
final class MockURLProtocol: URLProtocol {
    /// Set this before the test to control the response the mock returns.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Suite

final class UpdateCheckerTests: XCTestCase {

    // MARK: - Version Comparison

    func testIsNewerVersion_PatchBump_ReturnsTrue() {
        XCTAssertTrue(UpdateChecker.isNewerVersion("1.0.1", than: "1.0.0"))
    }

    func testIsNewerVersion_MinorBump_ReturnsTrue() {
        XCTAssertTrue(UpdateChecker.isNewerVersion("1.1.0", than: "1.0.9"))
    }

    func testIsNewerVersion_MajorBump_ReturnsTrue() {
        XCTAssertTrue(UpdateChecker.isNewerVersion("2.0.0", than: "1.9.9"))
    }

    func testIsNewerVersion_SameVersion_ReturnsFalse() {
        XCTAssertFalse(UpdateChecker.isNewerVersion("1.2.3", than: "1.2.3"))
    }

    func testIsNewerVersion_OlderCandidate_ReturnsFalse() {
        XCTAssertFalse(UpdateChecker.isNewerVersion("1.0.0", than: "1.0.1"))
    }

    func testIsNewerVersion_DifferentComponentCounts_ReturnsTrue() {
        // "2.1" should be treated as "2.1.0"
        XCTAssertTrue(UpdateChecker.isNewerVersion("2.1.1", than: "2.1"))
    }

    func testIsNewerVersion_DifferentComponentCounts_ReturnsFalse() {
        XCTAssertFalse(UpdateChecker.isNewerVersion("2.1", than: "2.1.1"))
    }

    func testIsNewerVersion_AlphanumericInstalledVersion_ParsesLeadingNumeric() {
        // "1.3.2d1" (current CFBundleShortVersionString format) is treated as "1.3.2"
        XCTAssertTrue(UpdateChecker.isNewerVersion("1.3.3", than: "1.3.2d1"))
        XCTAssertFalse(UpdateChecker.isNewerVersion("1.3.2", than: "1.3.2d1"))
        XCTAssertFalse(UpdateChecker.isNewerVersion("1.3.1", than: "1.3.2d1"))
    }

    // MARK: - Helpers

    /// Returns a URLSession whose requests are handled by MockURLProtocol.
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static let stubReleaseJSON: String = """
        {
            "tag_name": "v99.0.0",
            "name": "Hermes 99.0.0",
            "body": "Stub release notes.",
            "html_url": "https://github.com/Djspaceg/Hermes/releases/tag/v99.0.0",
            "prerelease": false,
            "assets": []
        }
        """

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        await MainActor.run {
            UpdateChecker.shared.session = URLSession(configuration: .ephemeral)
            UpdateChecker.shared.suppressAlerts = false
        }
        try await super.tearDown()
    }

    // MARK: - Notification Tests

    func testUpdateCheckDidComplete_UpdateAvailable_Notification() async throws {
        MockURLProtocol.requestHandler = { _ in
            let data = Self.stubReleaseJSON.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: URL(string: "https://api.github.com")!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, data)
        }
        await MainActor.run {
            UpdateChecker.shared.session = makeMockSession()
            UpdateChecker.shared.suppressAlerts = true
        }

        let expectation = XCTestExpectation(description: "updateCheckDidComplete posted")
        var receivedUserInfo: [AnyHashable: Any]?
        let token = NotificationCenter.default.addObserver(
            forName: .updateCheckDidComplete, object: nil, queue: nil
        ) { notification in
            receivedUserInfo = notification.userInfo
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await MainActor.run { UpdateChecker.shared.checkForUpdatesNow() }
        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertEqual(receivedUserInfo?["updateAvailable"] as? Bool, true)
    }

    func testUpdateCheckDidComplete_NoUpdate_Notification() async throws {
        // Respond with a version older than the installed app → updateAvailable = false.
        let oldReleaseJSON = """
            {
                "tag_name": "v0.0.1",
                "name": "Hermes 0.0.1",
                "body": null,
                "html_url": "https://github.com/Djspaceg/Hermes/releases/tag/v0.0.1",
                "prerelease": false,
                "assets": []
            }
            """
        MockURLProtocol.requestHandler = { _ in
            let data = oldReleaseJSON.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: URL(string: "https://api.github.com")!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, data)
        }
        await MainActor.run {
            UpdateChecker.shared.session = makeMockSession()
            UpdateChecker.shared.suppressAlerts = true
        }

        let expectation = XCTestExpectation(description: "updateCheckDidComplete posted")
        var receivedUserInfo: [AnyHashable: Any]?
        let token = NotificationCenter.default.addObserver(
            forName: .updateCheckDidComplete, object: nil, queue: nil
        ) { notification in
            receivedUserInfo = notification.userInfo
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await MainActor.run { UpdateChecker.shared.checkForUpdatesNow() }
        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertEqual(receivedUserInfo?["updateAvailable"] as? Bool, false)
    }

    func testUpdateCheckDidFail_Notification() async throws {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        await MainActor.run {
            UpdateChecker.shared.session = makeMockSession()
            UpdateChecker.shared.suppressAlerts = true
        }

        let expectation = XCTestExpectation(description: "updateCheckDidFail posted")
        var receivedUserInfo: [AnyHashable: Any]?
        let token = NotificationCenter.default.addObserver(
            forName: .updateCheckDidFail, object: nil, queue: nil
        ) { notification in
            receivedUserInfo = notification.userInfo
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await MainActor.run { UpdateChecker.shared.checkForUpdatesNow() }
        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertNotNil(receivedUserInfo?["error"])
    }

    // MARK: - GitHubRelease Decoding

    func testGitHubRelease_Decode_BasicFields() throws {
        let json = """
        {
            "tag_name": "v2.1.0",
            "name": "Hermes 2.1.0",
            "body": "Bug fixes and improvements.",
            "html_url": "https://github.com/Djspaceg/Hermes/releases/tag/v2.1.0",
            "prerelease": false,
            "assets": []
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)

        XCTAssertEqual(release.tagName, "v2.1.0")
        XCTAssertEqual(release.version, "2.1.0")
        XCTAssertEqual(release.name, "Hermes 2.1.0")
        XCTAssertEqual(release.body, "Bug fixes and improvements.")
        XCTAssertEqual(release.htmlUrl, "https://github.com/Djspaceg/Hermes/releases/tag/v2.1.0")
        XCTAssertFalse(release.prerelease)
        XCTAssertTrue(release.assets.isEmpty)
    }

    func testGitHubRelease_Decode_WithAssets() throws {
        let json = """
        {
            "tag_name": "v2.0.0",
            "name": "Hermes 2.0.0",
            "body": null,
            "html_url": "https://github.com/Djspaceg/Hermes/releases/tag/v2.0.0",
            "prerelease": false,
            "assets": [
                {
                    "name": "Hermes.zip",
                    "browser_download_url": "https://github.com/Djspaceg/Hermes/releases/download/v2.0.0/Hermes.zip"
                }
            ]
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)

        XCTAssertEqual(release.assets.count, 1)
        XCTAssertEqual(release.assets[0].name, "Hermes.zip")
        XCTAssertEqual(
            release.assets[0].browserDownloadUrl,
            "https://github.com/Djspaceg/Hermes/releases/download/v2.0.0/Hermes.zip"
        )
    }

    func testGitHubRelease_TagWithoutV_VersionUnchanged() throws {
        let json = """
        {
            "tag_name": "2.0.0",
            "name": "Hermes 2.0.0",
            "body": null,
            "html_url": "https://github.com/Djspaceg/Hermes/releases/tag/2.0.0",
            "prerelease": false,
            "assets": []
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.version, "2.0.0")
    }
}
