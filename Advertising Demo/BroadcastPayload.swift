//
//  BroadcastPayload.swift
//  Advertising Demo
//
//  Created by TCode on 19/05/2020.
//  Copyright © 2020 CrowdConnected. All rights reserved.
//

import Foundation
import CommonCrypto

class BroadcastPayloadGenerator {
    
    
    static let randomEID = "EID-iOS-\(getRandomString())"
    static let generatedEID = randomEID.data(using: .utf8)!
    
    func broadcastPayload() -> BroadcastPayload? {
        return BroadcastPayload(EIDData: BroadcastPayloadGenerator.generatedEID)
    }
    
    static func getRandomString() -> String {
        return "\(Int.random(in: 100..<200))"
    }
}

struct BroadcastPayload {
    static let length: Int = 11
    let EIDData: Data
        
    func data() -> Data {
        return EIDData
    }
}

struct IncomingBroadcastPayload: Equatable, Codable {
    let EIDData: Data
    
    init(data: Data) {
        self.EIDData = data.subdata(in: 0..<12)
        let EID = String(data: EIDData, encoding: .utf8) ?? "undecoded"
        print("Received broadcast payload - EID \(EID)")
    }
}
