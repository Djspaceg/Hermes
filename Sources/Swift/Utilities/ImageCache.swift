//
//  ImageCache.swift
//  Hermes
//
//  Modern async image loading with URLCache-based caching
//

import Foundation
import AppKit

/// Efficient image cache using URLSession and URLCache for network image loading.
///
/// `ImageCache` provides a modern, async/await-based API for loading and caching images
/// from network URLs. It uses the built-in `URLCache` for automatic memory and disk caching,
/// eliminating the need for custom cache management.
///
/// ## Topics
///
/// ### Accessing the Cache
/// - ``shared``
///
/// ### Loading Images
/// - ``loadImage(from:)-8tq7w``
/// - ``loadImage(from:)-2b8dy``
/// - ``loadImageURL(_:callback:)``
///
/// ### Cache Management
/// - ``clearCache()``
/// - ``cancel(_:)``
///
/// ## Usage
///
/// ```swift
/// // Async/await (preferred)
/// if let image = await ImageCache.shared.loadImage(from: url) {
///     imageView.image = image
/// }
///
/// // Callback-based (for Objective-C compatibility)
/// ImageCache.shared.loadImageURL(urlString) { data in
///     if let data = data, let image = NSImage(data: data) {
///         imageView.image = image
///     }
/// }
/// ```
@objc class ImageCache: NSObject {
    
    // MARK: - Singleton
    
    /// Shared singleton instance
    ///
    /// Use this instance for all image loading operations to benefit from shared caching.
    @objc static let shared = ImageCache()
    
    // MARK: - Properties
    
    private let session: URLSession
    private let cache: URLCache
    
    // MARK: - Initialization
    
    private override init() {
        // Configure URLCache with reasonable limits
        let memoryCapacity = 50 * 1024 * 1024  // 50 MB
        let diskCapacity = 100 * 1024 * 1024   // 100 MB
        self.cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        
        // Configure URLSession with cache
        let config = URLSessionConfiguration.default
        config.urlCache = self.cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
        
        super.init()
    }
    
    // MARK: - Public API (Async/Await)
    
    /// Loads an image from a URL using async/await
    ///
    /// This method automatically uses cached data when available and fetches from the network
    /// when necessary. The cache policy is configured to return cached data if available,
    /// otherwise load from the network.
    ///
    /// - Parameter url: The URL of the image to load
    /// - Returns: An `NSImage` if successful, `nil` if the load fails or the data is invalid
    func loadImage(from url: URL) async -> NSImage? {
        do {
            let (data, _) = try await session.data(from: url)
            return NSImage(data: data)
        } catch {
            NSLog("ImageCache: Failed to load image from \(url): \(error)")
            return nil
        }
    }
    
    /// Loads an image from a URL string using async/await
    ///
    /// Convenience method that converts a string to a URL before loading.
    ///
    /// - Parameter urlString: The URL string of the image to load
    /// - Returns: An `NSImage` if successful, `nil` if the URL is invalid or the load fails
    func loadImage(from urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else {
            NSLog("ImageCache: Invalid URL string: \(urlString)")
            return nil
        }
        return await loadImage(from: url)
    }
    
    // MARK: - Objective-C Compatibility (Callback-based)
    
    /// Loads an image from a URL with a completion callback
    ///
    /// This method provides Objective-C compatibility using a callback-based API.
    /// For Swift code, prefer the async/await methods instead.
    ///
    /// - Parameters:
    ///   - urlString: The URL string of the image to load
    ///   - completion: Callback invoked with image data on success, or `nil` on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// ImageCache.shared.loadImageURL(artworkURL) { data in
    ///     if let data = data, let image = NSImage(data: data) {
    ///         self.artworkImage = image
    ///     }
    /// }
    /// ```
    @objc func loadImageURL(_ urlString: String, callback completion: @escaping (Data?) -> Void) {
        guard let url = URL(string: urlString) else {
            NSLog("ImageCache: Invalid URL string: \(urlString)")
            completion(nil)
            return
        }
        
        Task {
            do {
                let (data, _) = try await session.data(from: url)
                completion(data)
            } catch {
                NSLog("ImageCache: Failed to load image from \(url): \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Cache Management
    
    /// Clears all cached images from memory and disk
    ///
    /// Use this method to free up memory and disk space when needed,
    /// such as when receiving a memory warning.
    @objc func clearCache() {
        cache.removeAllCachedResponses()
    }
    
    /// Cancels any pending requests for a URL
    ///
    /// This method is kept for API compatibility with older code but is a no-op
    /// in the modern implementation. URLSession automatically handles cancellation
    /// when tasks are deallocated.
    ///
    /// - Parameter urlString: The URL string of the request to cancel
    @objc func cancel(_ urlString: String) {
        // Modern URLSession handles cancellation automatically when tasks are deallocated
        // This method is kept for API compatibility but doesn't need to do anything
    }
}
