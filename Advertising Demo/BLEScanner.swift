//
//  BLEScanner.swift
//  Advertising Demo
//
//  Created by TCode on 18/05/2020.
//  Copyright © 2020 CrowdConnected. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BLEScannerDelegate {
    func updatePConnectedPeripherals(to number: Int)
    func didReadAdvertisementData(txPower: Int?, uuids: Int?, totalMessages: Int)
}

protocol BTLEListenerStateDelegate {
    func btleListener(_ listener: BLEScanner, didUpdateState state: CBManagerState)
}

class BLEScanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var broadcaster: BLEBroadcaster
    var stateDelegate: BTLEListenerStateDelegate?
    var delegate: BLEScannerDelegate?
    
    // comfortably less than the ~10s background processing time Core Bluetooth gives us when it wakes us up
    private let keepaliveInterval: TimeInterval = 8.0
    
    private var lastKeepaliveDate: Date = Date.distantPast
    private var keepaliveValue: UInt8 = 0
    private var keepaliveTimer: DispatchSourceTimer?
    
    private let queue: DispatchQueue
    
    // Record of discovered android devices, to avoid connecting to the same Android device multiple times. Our Android code sets a Manufacturer field for this purpose.
    private var discoveredAndroidPeriManufacturerToUUIDMap = [Data: UUID]()
    
    var peripherals: [UUID: CBPeripheral] = [:] {
        didSet {
            delegate?.updatePConnectedPeripherals(to: peripherals.count)
        }
    }
    
    var peripheralsEIDs: [UUID: String] = [:]
    
    private var messagesReceived: Int = 0
    
    init(broadcaster: BLEBroadcaster, queue: DispatchQueue) {
        self.broadcaster = broadcaster
        self.queue = queue
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
//        print("Scanner restore state")
//        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
//            for peripheral in restoredPeripherals {
//                peripherals[peripheral.identifier] = peripheral
//                peripheral.delegate = self
//            }
//        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateDelegate?.btleListener(self, didUpdateState: central.state)
        
        switch central.state {
        case .poweredOn:
            print("Start scanning ...")
            
            for peripheral in peripherals.values {
                central.connect(peripheral)
            }
            
            let services = [colocatorServiceUUID]
            let options = [CBCentralManagerScanOptionAllowDuplicatesKey : true]
            central.scanForPeripherals(withServices: services, options: options)
            
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data { // Most probably Android Device
       
//            if !discoveredAndroidPeriManufacturerToUUIDMap.keys.contains(manufacturerData) {
                 
                    
            if let deviceEID = extractEIDFromManufacturerData(manufacturerData) {
                handleAndroidContactWith(deviceEID: deviceEID, RSSI: RSSI)
            } else {
                // Ignore
                // Probably a device not advertising through Colocator
            }
                    
//                peripherals[peripheral.identifier] = peripheral
//                central.connect(peripheral)
//
//                discoveredAndroidPeriManufacturerToUUIDMap.updateValue(peripheral.identifier, forKey: manufacturerData)
//            }
            
        } else { // Most probably iOS device. Connect to it
           if peripherals[peripheral.identifier] == nil || peripherals[peripheral.identifier]!.state != .connected {
                peripherals[peripheral.identifier] = peripheral
                central.connect(peripheral)
            }
            
            handleiOSContactWith(peripheral, RSSI: RSSI)
        }
        
        messagesReceived += 1
//        delegate?.didReadAdvertisementData(txPower: txPower, uuids: serviceUUIDs?.count , totalMessages: messagesReceived)
    }
    
    func getEIDForPeripheral(_ peripheral: CBPeripheral) -> String? {
         //TODO search in a dictionary of connected devices and extract the EID for the dev with peripheral.identifier
        // THE EID will be saved after received as identitycharactersitic value
        
        return peripheralsEIDs[peripheral.identifier]
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.readRSSI()
        peripheral.discoverServices([colocatorServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        central.connect(peripheral)
    }
    
// MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) { }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print(error ?? "unknown error")
            return
        }
        
        guard let services = peripheral.services, services.count > 0 else { return }
        guard let colocatorIDService = services.colocatorIdService() else { return }
        
        let characteristics = [colocatorIdCharacteristicUUID, keepaliveCharacteristicUUID]
        peripheral.discoverCharacteristics(characteristics, for: colocatorIDService)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print(error ?? "unknown error")
            return
        }
        
        guard let characteristics = service.characteristics, characteristics.count > 0 else { return }
       
        if let colocatorIdCharacteristic = characteristics.colocatorIdCharacteristic() {
            peripheral.readValue(for: colocatorIdCharacteristic)
            peripheral.setNotifyValue(true, for: colocatorIdCharacteristic)
        }
        
        if let keepaliveCharacteristic = characteristics.keepaliveCharacteristic() {
            peripheral.setNotifyValue(true, for: keepaliveCharacteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print(error ?? "unknown error")
            return
        }
        
        switch characteristic.value {
            
        case (let data?) where characteristic.uuid == colocatorIdCharacteristicUUID:
            if data.count == BroadcastPayload.length {
                print("Received identity payload \(data)")
                
                let EIDString = String(data: data, encoding: .utf8) ?? "undecoded" //TODO updat ethis to properly decode the EID
                peripheralsEIDs.updateValue(EIDString, forKey: peripheral.identifier)
            } else {
                print("Received identity payload with unexpected length\(data) ")
            }
            peripheral.readRSSI()
            
        case (let data?) where characteristic.uuid == keepaliveCharacteristicUUID:
            guard data.count == 1 else {
                print("Received invalid keepalive value \(data)")
                return
            }
            
            let keepaliveValue = data.withUnsafeBytes { $0.load(as: UInt8.self) }
            print("Received keepalive value \(keepaliveValue)")
            readRSSIAndSendKeepalive()
            
        case .none:
            print("characteristic \(characteristic) has no data")
            
        default:
            print("characteristic \(characteristic) has unknown uuid \(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else {
            print("error: \(error!)")
            return
        }
        readRSSIAndSendKeepalive()
        
        handleiOSContactWith(peripheral, RSSI: RSSI)
    }
    
    func handleiOSContactWith(_ peripheral: CBPeripheral, RSSI: NSNumber) {
        let time = Date()
        
        if let deviceEID = getEIDForPeripheral(peripheral) {
            print("iOS contact #\(messagesReceived) -  \(deviceEID)  \(RSSI)  \(time)")
        } else {
            print("No EID found for peripheral identifier \(peripheral.identifier)")
        }
    }
    
    func extractEIDFromManufacturerData(_ data: Data) -> String? {
        let eid = data.base64EncodedString() // more complex than this for sure
        return eid
    }
    
    func handleAndroidContactWith(deviceEID: String, RSSI: NSNumber) {
        let time = Date()
        print("Android contact #\(messagesReceived) -  \(deviceEID)  \(RSSI)  \(time)")
    }
    
    private func readRSSIAndSendKeepalive() {
        guard Date().timeIntervalSince(lastKeepaliveDate) > keepaliveInterval else {
            return
        }

        for peripheral in peripherals.values {
            peripheral.readRSSI()
        }
        
        lastKeepaliveDate = Date()
        keepaliveValue = keepaliveValue &+ 1 // note "&+" overflowing add operator, this is required
        let value = Data(bytes: &self.keepaliveValue, count: MemoryLayout.size(ofValue: self.keepaliveValue))
        keepaliveTimer = DispatchSource.makeTimerSource(queue: queue)
        keepaliveTimer?.setEventHandler {
            self.broadcaster.sendKeepalive(value: value)
        }
        keepaliveTimer?.schedule(deadline: DispatchTime.now() + keepaliveInterval)
        keepaliveTimer?.resume()
    }
}

