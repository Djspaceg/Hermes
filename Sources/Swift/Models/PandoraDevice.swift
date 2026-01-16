//
//  PandoraDevice.swift
//  Hermes
//
//  Modern Swift implementation of Pandora device configurations
//

import Foundation

struct PandoraDevice {
    let username: String
    let password: String
    let deviceID: String
    let encryptKey: String
    let decryptKey: String
    let apiHost: String
    
    // MARK: - Device Configurations
    
    static let iPhone = PandoraDevice(
        username: "iphone",
        password: "P2E4FC0EAD3*878N92B2CDp34I0B1@388137C",
        deviceID: "IP01",
        encryptKey: "721^26xE22776",
        decryptKey: "20zE1E47BE57$51",
        apiHost: "tuner.pandora.com"
    )
    
    static let android = PandoraDevice(
        username: "android",
        password: "AC7IBG09A3DTSYM4R41UJWL07VLN8JI7",
        deviceID: "android-generic",
        encryptKey: "6#26FRL$ZWD",
        decryptKey: "R=U!LH$O2B#",
        apiHost: "tuner.pandora.com"
    )
    
    static let desktop = PandoraDevice(
        username: "pandora one",
        password: "TVCKIBGS9AO9TSYLNNFUML0743LH82D",
        deviceID: "D01",
        encryptKey: "2%3WCL*JU$MP]4",
        decryptKey: "U#IO$RZPAB%VX2",
        apiHost: "internal-tuner.pandora.com"
    )
    
    // MARK: - Dictionary Conversion (for Objective-C compatibility)
    
    func toDictionary() -> [String: String] {
        return [
            "username": username,
            "password": password,
            "deviceid": deviceID,
            "encrypt": encryptKey,
            "decrypt": decryptKey,
            "apihost": apiHost
        ]
    }
    
    init(username: String, password: String, deviceID: String, encryptKey: String, decryptKey: String, apiHost: String) {
        self.username = username
        self.password = password
        self.deviceID = deviceID
        self.encryptKey = encryptKey
        self.decryptKey = decryptKey
        self.apiHost = apiHost
    }
    
    init?(dictionary: [String: String]) {
        guard let username = dictionary["username"],
              let password = dictionary["password"],
              let deviceID = dictionary["deviceid"],
              let encryptKey = dictionary["encrypt"],
              let decryptKey = dictionary["decrypt"],
              let apiHost = dictionary["apihost"] else {
            return nil
        }
        
        self.username = username
        self.password = password
        self.deviceID = deviceID
        self.encryptKey = encryptKey
        self.decryptKey = decryptKey
        self.apiHost = apiHost
    }
}

// MARK: - Objective-C Bridge

@objc(PandoraDeviceBridge)
final class PandoraDeviceBridge: NSObject {
    @objc static func iPhone() -> [String: String] {
        return PandoraDevice.iPhone.toDictionary()
    }
    
    @objc static func android() -> [String: String] {
        return PandoraDevice.android.toDictionary()
    }
    
    @objc static func desktop() -> [String: String] {
        return PandoraDevice.desktop.toDictionary()
    }
}
