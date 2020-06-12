//
//  EIDKeyManager.swift
//  Advertising Demo
//
//  Created by TCode on 12/06/2020.
//  Copyright © 2020 CrowdConnected. All rights reserved.
//

import Foundation
import CommonCrypto

class EIDKeyManager {

    public static let eidLength = 16 // in .utf8
    
    private static var secret = "32104fe42a533890b"
    private static var k = 8
    private static var clockOffset = 30000
    
    static func setup(secret: String, k: Int, clockOffSet: Int) {
        self.secret = secret
        self.k = k
        self.clockOffset = clockOffSet
    }
    
    static func generateEIDData() -> Data? {
        return generateEIDString()?.data(using: .utf8)
    }
    
    static func generateEIDString() -> String? {
        let timeCounter = Int(Date().timeIntervalSince1970)
        
        if let tempKey = generateTempKey(timeCounter: timeCounter) {
            let rotationIndexTimeCounter = getRotationIndex(time: timeCounter)
            
            if let tempEID = generateTempEID(timeCounter: rotationIndexTimeCounter, tempKey: tempKey) {
                
                let trimmedEID = extract(from: tempEID, limit: 8)
                return convertDataToHexString(trimmedEID)
                
            } else {
                print("Failed to generate temp eid")
                return nil
            }
        } else {
            print("Failed to generate temp key")
            return nil
        }
    }
    
    private static func generateTempKey(timeCounter: Int) -> Data? {
        var tempKeyArray: [UInt8] = [UInt8]()
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        tempKeyArray.append(255)
        tempKeyArray.append(0)
        tempKeyArray.append(0)
        
        let firstShift = UInt8 ((timeCounter >> 24) & 255)
        let secondShift = UInt8 ((timeCounter >> 16) & 255)
        
        tempKeyArray.append(firstShift)
        tempKeyArray.append(secondShift)
        
        let tempKeyData = tempKeyArray.withUnsafeBufferPointer {Data(buffer: $0)}
        
        let secretKey = secret.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))! as Data
        return AESEncryption(value: tempKeyData, key: secretKey, trimKeyLength: true)
    }
    
    private static func getRotationIndex(time: Int) -> Int {
        return (time >> k) << k
    }
    
    private static func generateTempEID(timeCounter: Int, tempKey: Data) -> Data? {
        var tempEIDArray: [UInt8] = [UInt8]()
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(0)
        tempEIDArray.append(UInt8(k))
        
        let firstShift = UInt8 ((timeCounter >> 24) & 255)
        let secondShift = UInt8 ((timeCounter >> 16) & 255)
        let thirdShift = UInt8 ((timeCounter >> 8) & 255)
        let forthShift = UInt8 (timeCounter & 255)
        
        tempEIDArray.append(firstShift)
        tempEIDArray.append(secondShift)
        tempEIDArray.append(thirdShift)
        tempEIDArray.append(forthShift)
        
        let tempEIDData = tempEIDArray.withUnsafeBufferPointer {Data(buffer: $0)}
        return AESEncryption(value: tempEIDData, key: tempKey)
    }
    
    private static func AESEncryption(value: Data, key: Data, trimKeyLength: Bool = false) -> Data? {
        let keyData: NSData! = key as NSData
        let data: NSData! = value as NSData
        
        let cryptData    = NSMutableData(length: Int(data.length) + kCCBlockSizeAES128)!
        
        let keyLength              = trimKeyLength ? size_t(kCCKeySizeAES128) : key.count
        let operation: CCOperation = UInt32(kCCEncrypt)
        let algoritm:  CCAlgorithm = UInt32(kCCAlgorithmAES128)
        let options:   CCOptions   = UInt32(kCCOptionECBMode + kCCOptionPKCS7Padding)
        
        var numBytesEncrypted :size_t = 0
        
        let cryptStatus = CCCrypt(operation,
                                  algoritm,
                                  options,
                                  keyData.bytes, keyLength,
                                  nil,
                                  data.bytes, data.length,
                                  cryptData.mutableBytes, cryptData.length,
                                  &numBytesEncrypted)
        
        if UInt32(cryptStatus) == UInt32(kCCSuccess) {
            cryptData.length = Int(numBytesEncrypted)
            return cryptData as Data
        }
        return nil
    }
    
    public static func convertDataToHexString(_ data: Data?) -> String? {
        return data == nil ? nil : data!.map{ String(format:"%02x", $0) }.joined()
    }
    
    public static func extract(from data: Data, limit: Int) -> Data? {
        guard data.count > 0 else {
            return nil
        }
        
        return data.subdata(in: 0..<limit)
    }
}
