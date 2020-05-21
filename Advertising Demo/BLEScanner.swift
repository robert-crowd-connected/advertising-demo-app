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
    func didReadAdvertisementData(txPower: Int?, uuids: Int?, totalMessages: Int?)
    
    func btleListener(_ listener: BLEScanner, didFind broadcastPayload: IncomingBroadcastPayload, for peripheral: CBPeripheral)
    func btleListener(_ listener: BLEScanner, didReadRSSI RSSI: Int, for peripheral: CBPeripheral)
    func btleListener(_ listener: BLEScanner, didReadTxPower txPower: Int, for peripheral: CBPeripheral)
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
    private let dateFormatter = ISO8601DateFormatter()
    
    private let queue: DispatchQueue
    
    var peripherals: [UUID: CBPeripheral] = [:] {
        didSet {
            delegate?.updatePConnectedPeripherals(to: peripherals.count)
        }
    }
    
    private var messagesReceived: Int = 0
    
    private var seenEddystoneCache = [String : [String : AnyObject]]()
    private var deviceIDCache = [UUID : NSData]()
    
    ///
    /// How long we should go without a beacon sighting before considering it "lost". In seconds.
    ///
    var onLostTimeout: Double = 15.0
    
    init(broadcaster: BLEBroadcaster, queue: DispatchQueue) {
        self.broadcaster = broadcaster
        self.queue = queue
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in restoredPeripherals {
                peripherals[peripheral.identifier] = peripheral
                peripheral.delegate = self
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateDelegate?.btleListener(self, didUpdateState: central.state)
        
        switch central.state {
        case .poweredOn:
            print("Central Manager update state to powered On. Start scanning")
            
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
        if peripherals[peripheral.identifier] == nil || peripherals[peripheral.identifier]!.state != .connected {
            central.connect(peripheral)
        }
        
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        if localName != nil {
//            print("- Local Name \(localName!)")
        }
        
        let manufData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData
        if manufData != nil {
//            let manufString = String(decoding: manufData!, as: UTF8.self)
//            print("- Manufacturer Data \(manufString)")
        }
        
        let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? NSData
        if serviceData != nil {
//            let serviceString = String(decoding: serviceData!, as: UTF8.self)
//            print("- Service Data \(serviceString)")
        }
        
        let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        if txPower != nil {
//            print("- Tx Power \(txPower!)")
        }
        
        let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool
        if isConnectable != nil {
//            print("- Is Connectable \(isConnectable!)")
        }
        
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [NSObject]
        if serviceUUIDs != nil {
//            print("- Service UUIDS \(serviceUUIDs!)")
        }
        
        let overflowUUIDs = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [NSObject]
        if overflowUUIDs != nil {
//            print("- Overflow UUIDS \(overflowUUIDs!)")
        }
        
        let solicitedUUIDs = advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [NSObject]
        if solicitedUUIDs != nil {
//            print("- Solicited UUIDS \(solicitedUUIDs!)")
        }
         
        if serviceUUIDs != nil || overflowUUIDs != nil { messagesReceived += 1 } else { print("no uuis received") }
        delegate?.didReadAdvertisementData(txPower: txPower, uuids: serviceUUIDs?.count , totalMessages: messagesReceived)
        
        print("")
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
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("Invalidate services for peripheral \(peripheral.identifier)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print(error ?? "unknown error")
            return
        }
        
        guard let services = peripheral.services, services.count > 0 else {
            print("No services discovered for peripheral \(peripheral.identifier)")
            return
        }
        
        guard let colocatorIDService = services.colocatorIdService() else {
            print("Colocator service not discovered for \(peripheral.identifier)")
            return
        }
        
        print("discovering characteristics for peripheral \(peripheral.identifier) with colocator service \(colocatorIDService)")
        
        let characteristics = [colocatorIdCharacteristicUUID, keepaliveCharacteristicUUID]
        peripheral.discoverCharacteristics(characteristics, for: colocatorIDService)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print(error ?? "unknown error")
            return
        }
        
        guard let characteristics = service.characteristics, characteristics.count > 0 else {
            print("no characteristics discovered for service \(service)")
            return
        }
        print("\(characteristics.count) \(characteristics.count == 1 ? "characteristic" : "characteristics") discovered for service \(service): \(characteristics)")
        
        
        if let colocatorIdCharacteristic = characteristics.colocatorIdCharacteristic() {
            print("reading colocatorId from colocator characteristic \(colocatorIdCharacteristic)")
            peripheral.readValue(for: colocatorIdCharacteristic)
            peripheral.setNotifyValue(true, for: colocatorIdCharacteristic)
        } else {
            print("colocatorid characteristic not discovered for peripheral \(peripheral.identifier)")
        }
        
        if let keepaliveCharacteristic = characteristics.keepaliveCharacteristic() {
            print("subscribing to keepalive characteristic \(keepaliveCharacteristic)")
            peripheral.setNotifyValue(true, for: keepaliveCharacteristic)
        } else {
            print("keepalive characteristic not discovered for peripheral \(peripheral.identifier)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print(error ?? "unknown error")
            return
        }
        
        switch characteristic.value {
            
        case (let data?) where characteristic.uuid == colocatorIdCharacteristicUUID:
//            if data.count == BroadcastPayload.length {
                print("read identity from peripheral \(peripheral.identifier): \(data)")
                delegate?.btleListener(self, didFind: IncomingBroadcastPayload(data: data), for: peripheral)
//            } else {
//                print("no identity ready from peripheral \(peripheral.identifier)")
//            }
            peripheral.readRSSI()
            
        case (let data?) where characteristic.uuid == keepaliveCharacteristicUUID:
            guard data.count == 1 else {
                print("invalid keepalive value \(data)")
                return
            }
            
            let keepaliveValue = data.withUnsafeBytes { $0.load(as: UInt8.self) }
            print("read keepalive value from peripheral \(peripheral.identifier): \(keepaliveValue)")
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

        print("Read RSSI \(RSSI) for peripheral \(peripheral.identifier)")
        
//        delegate?.btleListener(self, didReadRSSI: RSSI.intValue, for: peripheral)
        readRSSIAndSendKeepalive()
    }
    
//    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
//
//        print("Did receive read resuest \(request)")
//
//    }
//
//    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
//        print("Writing Data")
//
//        if let value = requests.first?.value {
//            let val =  value.map{ String(format: "%02hhx", $0) }.joined()
//            print(val)
//        }
//    }
    
    private func readRSSIAndSendKeepalive() {
        guard Date().timeIntervalSince(lastKeepaliveDate) > keepaliveInterval else {
            print("too soon, won't send keepalive (lastKeepalive = \(lastKeepaliveDate))")
            return
        }

        print("reading RSSI for \(peripherals.values.count) \(peripherals.values.count == 1 ? "peripheral" : "peripherals")")
        for peripheral in peripherals.values {
            peripheral.readRSSI()
        }
        
        print("scheduling keepalive")
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
