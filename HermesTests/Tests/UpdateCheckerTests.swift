//
//  UpdateCheckerTests.swift
//  HermesTests
//
//  Tests for UpdateChecker version comparison and GitHub release parsing.
//

import XCTest
@testable import Hermes

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
