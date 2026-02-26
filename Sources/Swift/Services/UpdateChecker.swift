//
//  UpdateChecker.swift
//  Hermes
//
//  Checks GitHub Releases for newer versions of Hermes and presents
//  an update dialog to the user.
//

import AppKit
import Combine

// MARK: - GitHub Release Model

/// Represents a release fetched from the GitHub Releases API.
struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let prerelease: Bool
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case prerelease
        case assets
    }

    /// The version string stripped of any leading "v" prefix.
    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}

/// A downloadable asset attached to a GitHub release.
struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

// MARK: - Update Checker Errors

enum UpdateCheckerError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noReleaseFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid update URL."
        case .networkError(let e): return e.localizedDescription
        case .decodingError(let e): return e.localizedDescription
        case .noReleaseFound:      return "No release information found."
        }
    }
}

// MARK: - Update Checker

/// Checks GitHub Releases for new versions of Hermes and notifies the user.
///
/// Automatic checks respect `SettingsManager.automaticUpdateChecks` and
/// `SettingsManager.updateCheckInterval`.  Manual "Check for Updates…"
/// invocations bypass the interval gate.
@MainActor
final class UpdateChecker: ObservableObject {

    // MARK: - Singleton

    static let shared = UpdateChecker()

    // MARK: - Published State

    @Published private(set) var isChecking = false
    @Published private(set) var updateAvailable = false
    @Published private(set) var latestRelease: GitHubRelease?

    // MARK: - Constants

    private let githubAPIURL =
        "https://api.github.com/repos/Djspaceg/Hermes/releases/latest"

    private let lastCheckKey = "HermesLastUpdateCheck"

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Perform an automatic update check if the configured interval has elapsed
    /// and automatic checks are enabled.  Does nothing if the interval has not
    /// yet passed.
    func checkForUpdatesIfNeeded() {
        let settings = SettingsManager.shared
        guard settings.automaticUpdateChecks else { return }

        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        let elapsed = Date().timeIntervalSince1970 - lastCheck
        guard elapsed >= settings.updateCheckInterval else { return }

        Task { await performCheck(userInitiated: false) }
    }

    /// Perform an unconditional update check, regardless of the configured
    /// interval.  Called when the user explicitly selects "Check for Updates…".
    func checkForUpdatesNow() {
        Task { await performCheck(userInitiated: true) }
    }

    // MARK: - Private Helpers

    private func performCheck(userInitiated: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        // Record the check time before the network call so that a failed check
        // does not result in an immediate retry on the next launch.
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: lastCheckKey
        )

        do {
            let release = try await fetchLatestRelease()
            let currentVersion = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "0.0.0"

            let hasUpdate = UpdateChecker.isNewerVersion(release.version, than: currentVersion)
            latestRelease = release
            updateAvailable = hasUpdate

            if hasUpdate {
                presentUpdateAlert(release: release)
            } else if userInitiated {
                presentUpToDateAlert(currentVersion: currentVersion)
            }

            NotificationCenter.default.post(
                name: .updateCheckDidComplete,
                object: nil,
                userInfo: ["updateAvailable": hasUpdate]
            )
        } catch {
            if userInitiated {
                presentErrorAlert(error: error)
            }
            NotificationCenter.default.post(
                name: .updateCheckDidFail,
                object: nil,
                userInfo: ["error": error]
            )
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: githubAPIURL) else {
            throw UpdateCheckerError.invalidURL
        }

        var request = URLRequest(url: url)
        // GitHub recommends setting the Accept header for the REST API.
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let session = URLSession(configuration: .ephemeral)
        let data: Data
        do {
            let (responseData, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw UpdateCheckerError.noReleaseFound
            }
            data = responseData
        } catch let error as UpdateCheckerError {
            throw error
        } catch {
            throw UpdateCheckerError.networkError(error)
        }

        do {
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw UpdateCheckerError.decodingError(error)
        }
    }

    // MARK: - Version Comparison

    /// Returns `true` when `candidate` is strictly newer than `installed`.
    ///
    /// Compares dot-separated integer components, padding with zeros where
    /// component counts differ (e.g. "2.1" vs "2.1.0").
    static func isNewerVersion(_ candidate: String, than installed: String) -> Bool {
        let lhs = versionComponents(candidate)
        let rhs = versionComponents(installed)
        let count = max(lhs.count, rhs.count)
        for i in 0..<count {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func versionComponents(_ version: String) -> [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }

    // MARK: - Alerts

    private func presentUpdateAlert(release: GitHubRelease) {
        let displayVersion = release.version
        let releaseName = release.name.flatMap { $0.isEmpty ? nil : $0 } ?? "v\(displayVersion)"

        let alert = NSAlert()
        alert.messageText = "A new version of Hermes is available!"
        alert.informativeText =
            "\(releaseName) is now available.\n\n" +
            (release.body.flatMap { $0.isEmpty ? nil : $0 } ?? "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func presentUpToDateAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Hermes is up to date."
        alert.informativeText = "You have the latest version (\(currentVersion))."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not check for updates."
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
