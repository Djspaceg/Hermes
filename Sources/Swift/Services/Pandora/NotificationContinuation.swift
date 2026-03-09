//
//  NotificationContinuation.swift
//  Hermes
//
//  Concurrency-safe helper for bridging NotificationCenter to async/await
//

import Foundation
import Synchronization

/// Bridges NotificationCenter notifications to Swift concurrency continuations.
///
/// Encapsulates notification observer lifecycle in a class to avoid
/// Sendable warnings from mutable captures in `@Sendable` closures.
final class NotificationContinuation<T>: Sendable {
    private let observer = Mutex<NSObjectProtocol?>(nil)
    private let errorObserver = Mutex<NSObjectProtocol?>(nil)
    
    /// Observe a success notification and an error notification, resuming the continuation exactly once.
    ///
    /// - Parameters:
    ///   - successName: Notification name for the success case
    ///   - errorName: Notification name for the error case
    ///   - continuation: The checked throwing continuation to resume
    ///   - onSuccess: Closure to extract the return value from the success notification
    ///   - onError: Closure to extract an Error from the error notification
    func observe(
        success successName: Notification.Name,
        error errorName: Notification.Name,
        continuation: CheckedContinuation<T, Error>,
        onSuccess: @Sendable @escaping (Notification) -> T,
        onError: @Sendable @escaping (Notification) -> Error
    ) {
        let obs = NotificationCenter.default.addObserver(
            forName: successName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.removeObservers()
            continuation.resume(returning: onSuccess(notification))
        }
        observer.withLock { $0 = obs }
        
        let errObs = NotificationCenter.default.addObserver(
            forName: errorName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.removeObservers()
            continuation.resume(throwing: onError(notification))
        }
        errorObserver.withLock { $0 = errObs }
    }
    
    /// Remove observers and resume with a failure (used when the initiating call fails synchronously).
    func cancel(continuation: CheckedContinuation<T, Error>, error: Error) {
        removeObservers()
        continuation.resume(throwing: error)
    }
    
    private func removeObservers() {
        observer.withLock { obs in
            if let o = obs { NotificationCenter.default.removeObserver(o) }
            obs = nil
        }
        errorObserver.withLock { obs in
            if let o = obs { NotificationCenter.default.removeObserver(o) }
            obs = nil
        }
    }
    
    deinit {
        removeObservers()
    }
}
