//
//  BLEBroadcaster.swift
//  Advertising Demo
//
//  Created by TCode on 18/05/2020.
//  Copyright © 2020 CrowdConnected. All rights reserved.
//

import Foundation
import CoreBluetooth

let colocatorServiceUUID = CBUUID(string: "FEAA")
let colocatorIdCharacteristicUUID = CBUUID(string: "31AF61DB-E873-4DC0-B37D-1863AFEBD24B")
let keepaliveCharacteristicUUID = CBUUID(string: "6287E717-DA7D-4FC8-9432-3736D5BFD87C")

class BLEBroadcaster: NSObject, CBPeripheralManagerDelegate  {
    
    private let advertismentDataLocalName = "Colocator"
    private let restoreIdentifierKey = "com.colocator.peripheral"
    
    var peripheralManager: CBPeripheralManager?
    let idGenerator: BroadcastPayloadGenerator
    
    enum UnsentCharacteristicValue {
        case keepalive(value: Data)
        case identity(value: Data)
    }
    var unsentCharacteristicValue: UnsentCharacteristicValue?
    var keepaliveCharacteristic: CBMutableCharacteristic?
    var identityCharacteristic: CBMutableCharacteristic?
    
    init(idGenerator: BroadcastPayloadGenerator) {
        self.idGenerator = idGenerator
    }
    
    func start() {
        print("Start broadcasting ...")
        
        if peripheralManager == nil {
            print("No PeripheralManager found yet")
            return
        }
        
        if peripheralManager?.isAdvertising ?? false {
            peripheralManager?.stopAdvertising()
        }
        
        let service = CBMutableService(type: colocatorServiceUUID, primary: true)

//        identityCharacteristic = CBMutableCharacteristic(
//            type: colocatorIdCharacteristicUUID,
//            properties: CBCharacteristicProperties([.read, .notify]),
//            value: nil,
//            permissions: .readable)

        keepaliveCharacteristic = CBMutableCharacteristic(
            type: keepaliveCharacteristicUUID,
            properties: CBCharacteristicProperties([.notify]),
            value: nil,
            permissions: .readable)

        service.characteristics = [keepaliveCharacteristic!]
        
        peripheralManager?.removeAllServices()
        peripheralManager?.add(service)
        
        peripheralManager?.startAdvertising([CBAdvertisementDataLocalNameKey: advertismentDataLocalName,
                                             CBAdvertisementDataServiceUUIDsKey: [colocatorServiceUUID],
                                             CBAdvertisementDataSolicitedServiceUUIDsKey: [colocatorServiceUUID]])
    }
    
    func sendKeepalive(value: Data) {
        print("send keep alive")
        
        guard let peripheral = self.peripheralManager else {
            print("peripheral shouldn't be nil")
            return
        }
        guard let keepaliveCharacteristic = self.keepaliveCharacteristic else {
            print("keepaliveCharacteristic shouldn't be nil")
            return
        }
        
        self.unsentCharacteristicValue = .keepalive(value: value)
        let success = peripheral.updateValue(value, for: keepaliveCharacteristic, onSubscribedCentrals: nil)
        if success {
            print("sent keepalive value: \(value.withUnsafeBytes { $0.load(as: UInt8.self) })")
            self.unsentCharacteristicValue = nil
        }
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            self.peripheralManager = peripheral
            start()
        default:
            break
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        print("Peripheral Manager will restore state ...\n")
        
        guard let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] else { return }
        
        for service in services {
            if let characteristics = service.characteristics {
                for characteristic in characteristics {
                    if characteristic.uuid == keepaliveCharacteristicUUID {
                        print("    retaining restored keepalive characteristic \(characteristic)")
                        self.keepaliveCharacteristic = (characteristic as! CBMutableCharacteristic)
                    } else if characteristic.uuid == colocatorIdCharacteristicUUID {
                        print("    retaining restored identity characteristic \(characteristic)")
                        self.identityCharacteristic = (characteristic as! CBMutableCharacteristic)
                    } else {
                        print("    restored characteristic \(characteristic)")
                    }
                }
            }
        }
        
        if let advertismentData = dict[CBPeripheralManagerRestoredStateAdvertisementDataKey] as? [String: Any] {
            let serviceUUIDs = advertismentData[CBAdvertisementDataServiceUUIDsKey] as? [NSObject] ?? []
            let localName = advertismentData[CBAdvertisementDataLocalNameKey] as? String ?? "missing"
            
            print("Restoring advertisement data:\n - Service UUIDs: \(serviceUUIDs)")
            print(" - Local Name: \(localName)")
        }
        
        print("\nPeripheral Manager \(peripheral.isAdvertising ? "is" : "is not") advertising\n")
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("Peripheral Manager ready to update subscription")

        let characteristic: CBMutableCharacteristic
        let value: Data

        switch unsentCharacteristicValue {
        case nil:
            assertionFailure("\(#function) no data to update")
            return

        case .identity(let identityValue) where self.identityCharacteristic != nil:
            value = identityValue
            characteristic = self.identityCharacteristic!

        case .keepalive(let keepaliveValue) where self.keepaliveCharacteristic != nil:
            value = keepaliveValue
            characteristic = self.keepaliveCharacteristic!

        default:
            assertionFailure("shouldn't happen")
            return
        }

        let success = peripheral.updateValue(value, for: characteristic, onSubscribedCentrals: nil)
        if success {
            print("\(#function) re-sent value \(value)")
            self.unsentCharacteristicValue = nil
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("Did receive read resuest \(request)")
        
        guard request.characteristic.uuid == colocatorIdCharacteristicUUID else {
            print("Peripheral Manager received a read for unexpected characteristic \(request.characteristic.uuid.uuidString)")
            return
        }
        
        guard let broadcastPayload = idGenerator.broadcastPayload()?.data() else {
            print("Peripheral Manager did receive read request. Responding to read request with empty payload")
            request.value = Data()
            peripheral.respond(to: request, withResult: .success)
            return
        }
        
        print("Peripheral Manager did receive read request. Responding to read request with \(broadcastPayload)")
        request.value = broadcastPayload
        peripheral.respond(to: request, withResult: .success)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("Writing Data")
        
        if let value = requests.first?.value {
            let val =  value.map{ String(format: "%02hhx", $0) }.joined()
            print(val)
        }
    }
}
