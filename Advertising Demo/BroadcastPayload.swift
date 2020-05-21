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
    
    static let broadcastId = "Mock broadcast ID output".data(using: .utf8)!
    
    func broadcastPayload() -> BroadcastPayload? {
        return BroadcastPayload(messageData: BroadcastPayloadGenerator.broadcastId)
    }
}

struct BroadcastPayload {
    static let ukISO3166CountryCode: Int16 = 826
    
    let txPower: Int8 = 0
    let messageData: Data
        
    func data(txDate: Date = Date()) -> Data {
        var payload = Data()
        
        payload.append(BroadcastPayload.ukISO3166CountryCode.networkByteOrderData)
        payload.append(messageData)
        payload.append(txPower.networkByteOrderData)
        payload.append(Int32(txDate.timeIntervalSince1970).networkByteOrderData)
        
        return payload
    }
}

struct IncomingBroadcastPayload: Equatable, Codable {
    let countryCode: Int16
    let cryptogram: Data
    let txPower: Int8
    let transmissionTime: Int32
    
    init(data: Data) {
        self.countryCode = Int16(bigEndian: data.subdata(in: 0..<2).to(type: Int16.self)!)
        self.cryptogram = data.subdata(in: 2..<108)
        self.txPower = data.subdata(in: 108..<109).to(type: Int8.self)!
        self.transmissionTime = Int32(bigEndian: data.subdata(in: 109..<113).to(type: Int32.self)!)
    }
}

extension FixedWidthInteger {
    var networkByteOrderData: Data {
        var mutableSelf = self.bigEndian // network byte order
        return Data(bytes: &mutableSelf, count: MemoryLayout.size(ofValue: mutableSelf))
    }
}

// from https://stackoverflow.com/a/38024025/17294
// CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/
extension Data {

    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }

    func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return value
    }
}
