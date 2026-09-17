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

        let authenticationGeneration = beginManualCredentialAuthentication()
        return authenticateWithoutCredentialRecoveryCoordination(
            user,
            password: password,
            request: req,
            authenticationGeneration: authenticationGeneration
        )
    }

    internal func authenticateRecoveredCredentials(
        _ user: String,
        password: String,
        request: PandoraRequest,
        token: PandoraCredentialRecoveryToken
    ) -> Bool? {
        guard let authenticationGeneration = beginAutomaticCredentialAuthentication(token: token) else {
            return nil
        }
        return authenticateWithoutCredentialRecoveryCoordination(
            user,
            password: password,
            request: request,
            authenticationGeneration: authenticationGeneration
        )
    }

    private func authenticateWithoutCredentialRecoveryCoordination(
        _ user: String,
        password: String,
        request req: PandoraRequest?,
        authenticationGeneration: UInt64
    ) -> Bool {
        let started = doUserLogin(
            username: user,
            password: password,
            authenticationGeneration: authenticationGeneration
        ) { [weak self] _ in
            guard let self,
                  self.completeCredentialAuthenticationIfCurrent(authenticationGeneration) else {
                return
            }
            
            // Only send the pandoraDidAuthenticate notification if there is no request to retry
            if req == nil {
                self.postNotification(
                    "PandoraDidAuthenticateNotification",
                    authenticationGeneration: authenticationGeneration
                )
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
                newRequest.authenticationGeneration = authenticationGeneration
                
                _ = self.sendRequest(newRequest)
            }
        }
        if !started {
            finishCredentialAuthentication(authenticationGeneration)
        }
        return started
    }
    
    /// Perform user login
    internal func doUserLogin(
        username: String,
        password: String,
        authenticationGeneration: UInt64,
        callback: @escaping ([String: Any]) -> Void
    ) -> Bool {
        guard isAuthenticationGenerationCurrent(authenticationGeneration) else {
            return false
        }
        if partnerId == nil {
            // Get partner ID then reinvoke this method
            return doPartnerLogin(authenticationGeneration: authenticationGeneration) { [weak self] in
                guard let self else { return }
                if !self.doUserLogin(
                    username: username,
                    password: password,
                    authenticationGeneration: authenticationGeneration,
                    callback: callback
                ) {
                    self.finishCredentialAuthentication(authenticationGeneration)
                }
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
        loginRequest.authenticationGeneration = authenticationGeneration
        
        loginRequest.callback = { [weak self] respDict in
            guard let self else { return }
            guard let result = respDict["result"] as? [String: Any] else {
                self.finishCredentialAuthentication(authenticationGeneration)
                return
            }
            var shouldRelogin = false
            let applied = self.performIfAuthenticationGenerationCurrent(
                authenticationGeneration
            ) {
                self.userAuthToken = result["userAuthToken"] as? String
                self.userId = result["userId"] as? String

                if let subscriberStatus = result["isSubscriber"] as? NSNumber {
                    self.cachedSubscriberStatus = subscriberStatus
                } else {
                    NSLog("Warning: no key isSubscriber, assuming non-subscriber.")
                    self.cachedSubscriberStatus = NSNumber(value: false)
                }
                NSLog("Subscriber status: \(self.cachedSubscriberStatus ?? 0)")

                if let deviceDict = self.device,
                   let deviceUsername = deviceDict["username"] as? String,
                   self.cachedSubscriberStatus?.boolValue == true &&
                    deviceUsername != "pandora one" {
                    shouldRelogin = true
                    self.device = PandoraDevice.desktop.toDictionary()
                    self.resetAuthenticationState()
                }
            }
            guard applied else {
                return
            }

            if shouldRelogin {
                NSLog("Subscriber detected, re-logging-in...")
                if !self.doUserLogin(
                    username: username,
                    password: password,
                    authenticationGeneration: authenticationGeneration,
                    callback: callback
                ) {
                    self.finishCredentialAuthentication(authenticationGeneration)
                }
                return
            }
            
            NSLog("Logged in as \(username).")
            callback(respDict)
        }
        
        return sendRequest(loginRequest)
    }
    
    /// Perform partner login to get sync time and partner auth token
    internal func doPartnerLogin(
        authenticationGeneration: UInt64,
        callback: @escaping () -> Void
    ) -> Bool {
        var deviceDictionary: [AnyHashable: Any]?
        guard performIfAuthenticationGenerationCurrent(
            authenticationGeneration,
            operation: {
                startTime = UInt64(currentTime)
                deviceDictionary = device
            }
        ) else {
            return false
        }
        NSLog("Getting partner ID...")

        guard let deviceDict = deviceDictionary else { return false }
        
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
        request.authenticationGeneration = authenticationGeneration
        
        request.callback = { [weak self] dict in
            guard let self else { return }
            guard let result = dict["result"] as? [String: Any] else {
                NSLog("Partner login callback: No result in response")
                self.finishCredentialAuthentication(authenticationGeneration)
                return
            }

            let applied = self.performIfAuthenticationGenerationCurrent(
                authenticationGeneration
            ) {
                self.partnerAuthToken = result["partnerAuthToken"] as? String
                self.partnerId = result["partnerId"] as? String

                NSLog("Partner login: partnerId=\(self.partnerId ?? "nil"), partnerAuthToken=\(self.partnerAuthToken ?? "nil")")

                if let syncTimeString = result["syncTime"] as? String,
                   let syncData = self.decryptString(syncTimeString) {
                    let bytes = [UInt8](syncData)
                    if bytes.count > 4 {
                        let digitBytes = bytes[4...].filter { $0 >= 48 && $0 <= 57 }

                        if let syncString = String(bytes: digitBytes, encoding: .utf8),
                           !syncString.isEmpty {
                            self.syncTime = UInt64(syncString) ?? 0
                        }
                    }
                }

                NSLog("Partner login: startTime set to \(self.currentTime)")
            }
            guard applied else {
                return
            }
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
        invalidateAutomaticCredentialRecovery {
            resetAuthenticationState()
        }
    }

    internal func resetAuthenticationState() {
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
