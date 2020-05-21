//
//  BLEExtension.swift
//  Advertising Demo
//
//  Created by TCode on 21/05/2020.
//  Copyright © 2020 CrowdConnected. All rights reserved.
//

import Foundation
import CoreBluetooth

extension Sequence where Iterator.Element == CBService {
    func colocatorIdService() -> CBService? {
        return first(where: {$0.uuid == colocatorServiceUUID})
    }
}

extension Sequence where Iterator.Element == CBCharacteristic {
    func colocatorIdCharacteristic() -> CBCharacteristic? {
        return first(where: {$0.uuid == colocatorIdCharacteristicUUID})
    }
}

extension Sequence where Iterator.Element == CBCharacteristic {
    func keepaliveCharacteristic() -> CBCharacteristic? {
        return first(where: {$0.uuid == keepaliveCharacteristicUUID})
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
