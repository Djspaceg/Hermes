//
//  PandoraAuth.swift
//  Hermes
//
//  Authentication functionality extracted from PandoraClient
//

import Foundation

// MARK: - PandoraAuth

/// Handles Pandora API authentication (partner and user login)
extension PandoraClient {
    
    // MARK: - Authentication
    
    /// Authenticate with Pandora
    /// - Parameters:
    ///   - user: Username
    ///   - password: Password
    ///   - req: Optional request to retry after authentication
    /// - Returns: true if request was sent
    func authenticate(_ user: String!, password: String!, request req: PandoraRequest?) -> Bool {
        guard let user = user, let password = password else { return false }
        
        return doUserLogin(username: user, password: password) { [weak self] dict in
            guard let self = self else { return }
            
            // Only send the pandoraDidAuthenticate notification if there is no request to retry
            if req == nil {
                self.postNotification("PandoraDidAuthenticateNotification")
            } else if let req = req {
                NSLog("Retrying request...")
                guard let newRequest = req.copy() as? PandoraRequest else { return }
                
                // Update the request dictionary with new User Auth Token & Sync Time
                var updatedRequest = newRequest.request
                updatedRequest["userAuthToken"] = self.userAuthToken
                updatedRequest["syncTime"] = self.syncTimeNumber
                newRequest.request = updatedRequest
                
                // Also update the properties on the request used to build the request URL
                newRequest.userId = self.userId ?? ""
                newRequest.authToken = self.userAuthToken ?? ""
                newRequest.partnerId = self.partnerId ?? ""
                
                _ = self.sendRequest(newRequest)
            }
        }
    }
    
    /// Perform user login
    internal func doUserLogin(username: String, password: String, callback: @escaping ([String: Any]) -> Void) -> Bool {
        if partnerId == nil {
            // Get partner ID then reinvoke this method
            return doPartnerLogin { [weak self] in
                _ = self?.doUserLogin(username: username, password: password, callback: callback)
            }
        }
        
        let loginRequest = PandoraRequest()
        loginRequest.request = [
            "loginType": "user",
            "username": username,
            "password": password,
            "partnerAuthToken": partnerAuthToken ?? "",
            "syncTime": syncTimeNumber,
            "returnIsSubscriber": true
        ]
        loginRequest.method = "auth.userLogin"
        loginRequest.partnerId = partnerId ?? ""
        loginRequest.authToken = partnerAuthToken ?? ""
        
        loginRequest.callback = { [weak self] respDict in
            guard let self = self,
                  let result = respDict["result"] as? [String: Any] else { return }
            
            self.userAuthToken = result["userAuthToken"] as? String
            self.userId = result["userId"] as? String
            
            if let subscriberStatus = result["isSubscriber"] as? NSNumber {
                self.cachedSubscriberStatus = subscriberStatus
            } else {
                NSLog("Warning: no key isSubscriber, assuming non-subscriber.")
                self.cachedSubscriberStatus = NSNumber(value: false)
            }
            NSLog("Subscriber status: \(self.cachedSubscriberStatus ?? 0)")
            
            // Check if subscriber and need to re-login with desktop device
            if let deviceDict = self.device,
               let deviceUsername = deviceDict["username"] as? String,
               self.cachedSubscriberStatus?.boolValue == true && deviceUsername != "pandora one" {
                NSLog("Subscriber detected, re-logging-in...")
                self.device = PandoraDevice.desktop.toDictionary()
                self.logoutNoNotify()
                _ = self.doUserLogin(username: username, password: password, callback: callback)
                return
            }
            
            NSLog("Logged in as \(username).")
            callback(respDict)
        }
        
        return sendRequest(loginRequest)
    }
    
    /// Perform partner login to get sync time and partner auth token
    internal func doPartnerLogin(callback: @escaping () -> Void) -> Bool {
        NSLog("Getting partner ID...")
        startTime = UInt64(currentTime)
        
        guard let deviceDict = device else { return false }
        
        let request = PandoraRequest()
        request.request = [
            "username": deviceDict["username"] ?? "",
            "password": deviceDict["password"] ?? "",
            "deviceModel": deviceDict["deviceid"] ?? "",
            "version": pandoraAPIVersion,
            "includeUrls": true
        ]
        request.method = "auth.partnerLogin"
        request.encrypted = false
        
        request.callback = { [weak self] dict in
            guard let self = self,
                  let result = dict["result"] as? [String: Any] else {
                NSLog("Partner login callback: No result in response")
                return
            }
            
            self.partnerAuthToken = result["partnerAuthToken"] as? String
            self.partnerId = result["partnerId"] as? String
            
            NSLog("Partner login: partnerId=\(self.partnerId ?? "nil"), partnerAuthToken=\(self.partnerAuthToken ?? "nil")")
            
            if let syncTimeString = result["syncTime"] as? String,
               let syncData = self.decryptString(syncTimeString) {
                // The sync time is at offset 4 in the decrypted data
                let bytes = [UInt8](syncData)
                if bytes.count > 4 {
                    // Extract only digit characters (ASCII 48-57 = '0'-'9')
                    // This filters out padding and non-numeric bytes
                    let digitBytes = bytes[4...].filter { $0 >= 48 && $0 <= 57 }
                    
                    if let syncString = String(bytes: digitBytes, encoding: .utf8), !syncString.isEmpty {
                        self.syncTime = UInt64(syncString) ?? 0
                    }
                }
            }
            
            NSLog("Partner login: startTime set to \(self.currentTime)")
            callback()
        }
        
        return sendRequest(request)
    }
    
    /// Log out and clear all state
    func logout() {
        logoutNoNotify()
        
        for station in _stations {
            Station.removeStation(station)
        }
        _stations.removeAll()
        
        postNotification("PandoraDidLogOutNotification")
        
        // Always assume non-subscriber until API says otherwise
        cachedSubscriberStatus = nil
        device = PandoraDevice.android.toDictionary()
    }
    
    /// Log out without posting notification
    func logoutNoNotify() {
        userAuthToken = nil
        partnerAuthToken = nil
        partnerId = nil
        userId = nil
        syncTime = 0
        startTime = 0
    }
    
    /// Check if user is authenticated
    func isAuthenticated() -> Bool {
        return userAuthToken != nil && cachedSubscriberStatus != nil
    }
    
    // MARK: - Async/Await Authentication
    
    /// Authenticate with Pandora using async/await
    /// - Parameters:
    ///   - username: Pandora username
    ///   - password: Pandora password
    /// - Throws: PandoraError on failure
    func authenticate(username: String, password: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let bridge = NotificationContinuation<Void>()
            
            bridge.observe(
                success: .pandoraDidAuthenticate,
                error: .pandoraDidError,
                continuation: continuation,
                onSuccess: { _ in () },
                onError: { notification in
                    let errorMessage = notification.userInfo?["err"] as? String ?? "Authentication failed"
                    let code = notification.userInfo?["code"] as? Int
                    
                    if let code = code, let pandoraError = PandoraError.from(code: code) {
                        return pandoraError
                    }
                    return PandoraError.apiError(code: code ?? 0, message: errorMessage)
                }
            )
            
            if !self.authenticate(username, password: password, request: nil) {
                bridge.cancel(continuation: continuation, error: PandoraError.networkError(HTTPClientError.invalidResponse))
            }
        }
    }
}
