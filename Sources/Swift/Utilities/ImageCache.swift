//
//  ImageCache.swift
//  Hermes
//
//  Modern async image loading with URLCache-based caching
//

import Foundation
import AppKit

/// Modern image cache using URLSession and URLCache for efficient image loading
@objc class ImageCache: NSObject {
    
    // MARK: - Singleton
    
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
    
    /// Load an image from a URL using async/await
    /// - Parameter url: The URL of the image to load
    /// - Returns: NSImage if successful, nil otherwise
    func loadImage(from url: URL) async -> NSImage? {
        do {
            let (data, _) = try await session.data(from: url)
            return NSImage(data: data)
        } catch {
            NSLog("ImageCache: Failed to load image from \(url): \(error)")
            return nil
        }
    }
    
    /// Load an image from a URL string using async/await
    /// - Parameter urlString: The URL string of the image to load
    /// - Returns: NSImage if successful, nil otherwise
    func loadImage(from urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else {
            NSLog("ImageCache: Invalid URL string: \(urlString)")
            return nil
        }
        return await loadImage(from: url)
    }
    
    // MARK: - Objective-C Compatibility (Callback-based)
    
    /// Load an image from a URL with a completion callback (for Objective-C compatibility)
    /// - Parameters:
    ///   - urlString: The URL string of the image to load
    ///   - completion: Callback with NSData (for compatibility with existing code)
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
    
    /// Clear all cached images
    @objc func clearCache() {
        cache.removeAllCachedResponses()
    }
    
    /// Cancel any pending requests for a URL (no-op for modern URLSession, kept for API compatibility)
    @objc func cancel(_ urlString: String) {
        // Modern URLSession handles cancellation automatically when tasks are deallocated
        // This method is kept for API compatibility but doesn't need to do anything
    }
}
