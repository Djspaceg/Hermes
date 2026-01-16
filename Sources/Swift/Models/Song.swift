//
//  Song.swift
//  Hermes
//
//  Modern Swift implementation of Song model
//

import Foundation

@objc(Song)
@objcMembers
final class Song: NSObject, Identifiable {
    // MARK: - Properties
    
    var artist: String
    var title: String
    var album: String
    var art: String?
    var stationId: String?
    var nrating: NSNumber?
    var albumUrl: String?
    var artistUrl: String?
    var titleUrl: String?
    var token: String?
    
    var highUrl: String?
    var medUrl: String?
    var lowUrl: String?
    
    var playDate: Date?
    
    // MARK: - Computed Properties
    
    var id: String { token ?? UUID().uuidString }
    
    @objc var playDateString: String? {
        guard let playDate = playDate else { return nil }
        return Self.dateFormatter.string(from: playDate)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    // MARK: - Initialization
    
    override init() {
        self.artist = ""
        self.title = ""
        self.album = ""
        super.init()
    }
    
    init(artist: String, title: String, album: String) {
        self.artist = artist
        self.title = title
        self.album = album
        super.init()
    }
    
    // MARK: - NSCoding (for backward compatibility with saved history)
    
    required init?(coder: NSCoder) {
        self.artist = coder.decodeObject(forKey: "artist") as? String ?? ""
        self.title = coder.decodeObject(forKey: "title") as? String ?? ""
        self.album = coder.decodeObject(forKey: "album") as? String ?? ""
        self.art = coder.decodeObject(forKey: "art") as? String
        self.highUrl = coder.decodeObject(forKey: "highUrl") as? String
        self.medUrl = coder.decodeObject(forKey: "medUrl") as? String
        self.lowUrl = coder.decodeObject(forKey: "lowUrl") as? String
        self.stationId = coder.decodeObject(forKey: "stationId") as? String
        self.nrating = coder.decodeObject(forKey: "nrating") as? NSNumber
        self.albumUrl = coder.decodeObject(forKey: "albumUrl") as? String
        self.artistUrl = coder.decodeObject(forKey: "artistUrl") as? String
        self.titleUrl = coder.decodeObject(forKey: "titleUrl") as? String
        self.token = coder.decodeObject(forKey: "token") as? String
        self.playDate = coder.decodeObject(forKey: "playDate") as? Date
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        let dict = toDictionary()
        for (key, value) in dict {
            coder.encode(value, forKey: key)
        }
    }
    
    // MARK: - Dictionary Conversion
    
    @objc func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "artist": artist,
            "title": title,
            "album": album
        ]
        
        if let art = art { dict["art"] = art }
        if let lowUrl = lowUrl { dict["lowUrl"] = lowUrl }
        if let medUrl = medUrl { dict["medUrl"] = medUrl }
        if let highUrl = highUrl { dict["highUrl"] = highUrl }
        if let stationId = stationId { dict["stationId"] = stationId }
        if let nrating = nrating { dict["nrating"] = nrating }
        if let albumUrl = albumUrl { dict["albumUrl"] = albumUrl }
        if let artistUrl = artistUrl { dict["artistUrl"] = artistUrl }
        if let titleUrl = titleUrl { dict["titleUrl"] = titleUrl }
        if let token = token { dict["token"] = token }
        if let playDate = playDate { dict["playDate"] = playDate }
        
        return dict
    }
    
    // MARK: - Station Reference
    
    @objc func station() -> Station? {
        guard let stationId = stationId else { return nil }
        return Station(forToken: stationId)
    }
    
    // MARK: - Equality
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Song else { return false }
        return token == other.token
    }
    
    override var hash: Int {
        return token?.hash ?? 0
    }
    
    // MARK: - Description
    
    override var description: String {
        return "<\(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque()) \(artist) - \(title)>"
    }
    
    // MARK: - AppleScript Support
    
    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appDesc = NSScriptClassDescription(for: type(of: NSApp)) else {
            return nil
        }
        
        return NSPropertySpecifier(
            containerClassDescription: appDesc,
            containerSpecifier: nil,
            key: "currentSong"
        )
    }
}

// MARK: - NSSecureCoding

extension Song: NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
}
