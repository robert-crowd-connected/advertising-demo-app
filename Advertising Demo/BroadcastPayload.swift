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
    
    static let broadcastId = "broadcast".data(using: .utf8)!
    
    func broadcastPayload() -> BroadcastPayload? {
        return BroadcastPayload(messageData: BroadcastPayloadGenerator.broadcastId)
    }
}

struct BroadcastPayload {
    static let length: Int = 14
    
    let txPower: Int8 = 0
    let messageData: Data
        
    func data(txDate: Date = Date()) -> Data {
        var payload = Data()
        
        payload.append(messageData)
        payload.append(txPower.networkByteOrderData)
        payload.append(Int32(txDate.timeIntervalSince1970).networkByteOrderData)
        
        return payload
    }
}

struct IncomingBroadcastPayload: Equatable, Codable {
    let cryptogram: Data
    let txPower: Int8
    let transmissionTime: Int32
    
    init(data: Data) {
        self.cryptogram = data.subdata(in: 0..<9)
        self.txPower = data.subdata(in: 9..<10).to(type: Int8.self)!
        self.transmissionTime = Int32(bigEndian: data.subdata(in: 10..<14).to(type: Int32.self)!)
        
        let id = String(data: cryptogram, encoding: .utf8) ?? "undecoded"
        print("Received broadcast payload - cryptogram \(id) txPower \(self.txPower) transmissionTime \(self.transmissionTime)")
    }
}
