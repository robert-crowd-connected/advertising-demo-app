//
//  ViewController.swift
//  Advertising Demo
//
//  Created by TCode on 18/05/2020.
//  Copyright © 2020 CrowdConnected. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {

    @IBOutlet weak var advertisingStatusLabel: UILabel!
    @IBOutlet weak var scanningStatusLabel: UILabel!
    
    @IBOutlet weak var txLabel: UILabel!
    @IBOutlet weak var uuidsLabel: UILabel!
    @IBOutlet weak var serviceDataLabel: UILabel!
    
    private var central: CBCentralManager?
    private var peripheral: CBPeripheralManager?
    
    private var broadcaster: BLEBroadcaster?
    private var scanner: BLEScanner?
    
    public var broadcastIdGenerator: BroadcastPayloadGenerator?
    
    private var queue = DispatchQueue(label: "ColocatorBroadcaster")
    public private(set) var stateObserver: BluetoothStateObserving = BluetoothStateObserver(initialState: .unknown)
    
    let centralRestoreIdentifier: String = "ColocatorCentralRestoreIdentifier"
    let peripheralRestoreIdentifier: String = "ColocatorPeripheralRestoreIdentifier"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        broadcastIdGenerator = BroadcastPayloadGenerator()
    }

    @IBAction func actionStartAdvertising(_ sender: Any) {
        if broadcaster == nil {
            broadcaster = BLEBroadcaster(idGenerator: broadcastIdGenerator!)
        }
        peripheral = CBPeripheralManager(delegate: broadcaster,
                                         queue: queue,
                                         options: [CBPeripheralManagerOptionRestoreIdentifierKey: peripheralRestoreIdentifier])
        
        advertisingStatusLabel.text = "Advertising..."
        
    }
    
    @IBAction func actionStopAdvertising(_ sender: Any) {
        peripheral?.stopAdvertising()
        peripheral = nil
        broadcaster = nil
        advertisingStatusLabel.text = "Turned Off"
    }
    
    @IBAction func actionStartScanning(_ sender: Any) {
        if broadcaster == nil {
            broadcaster = BLEBroadcaster(idGenerator: broadcastIdGenerator!)
        }
        if scanner == nil {
            scanner = BLEScanner(broadcaster: broadcaster!, queue: queue)
        }
        
        central = CBCentralManager(delegate: scanner,
                                   queue: queue,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(true),
                                             CBCentralManagerOptionRestoreIdentifierKey: centralRestoreIdentifier,
                                             CBCentralManagerOptionShowPowerAlertKey: NSNumber(false)])
        
        scanner?.delegate = self
        scanner?.stateDelegate = self.stateObserver
        scanningStatusLabel.text = "Scanning..."
    }
    
    @IBAction func actionStopScanning(_ sender: Any) {
        central?.stopScan()
        central = nil
        scanner = nil
        scanningStatusLabel.text = "Turned Off"
    }
}

extension ViewController: BLEScannerDelegate {
    func didReadAdvertisementData(txPower: Int?, uuids: Int?, totalMessages: Int?) {
        DispatchQueue.main.async {
            self.txLabel.text = txPower?.description
            self.uuidsLabel.text = uuids?.description
            self.serviceDataLabel.text = totalMessages?.description
//            print(totalMessages!)
//            print(Date())
        }
    }
    
    func updatePConnectedPeripherals(to number: Int) {
        DispatchQueue.main.async {
            self.scanningStatusLabel.text = "Connected peripherals \(number)"
        }
    }
    
    func btleListener(_ listener: BLEScanner, didFind broadcastPayload: IncomingBroadcastPayload, for peripheral: CBPeripheral) {
        print("payload ", broadcastPayload)
    }
    
    func btleListener(_ listener: BLEScanner, didReadRSSI RSSI: Int, for peripheral: CBPeripheral) {
//        print("rssi ", RSSI)
    }
    
    func btleListener(_ listener: BLEScanner, didReadTxPower txPower: Int, for peripheral: CBPeripheral) {
//        print("tx power ", txPower)
    }
}


protocol BluetoothStateObserving: BTLEListenerStateDelegate {
    func observe(_ callback: @escaping (CBManagerState) -> Action)
    func observeUntilKnown(_ callback: @escaping (CBManagerState) -> Void)
}

enum Action {
    case keepObserving
    case stopObserving
}

class BluetoothStateObserver: BluetoothStateObserving {
    
    private var callbacks: [(CBManagerState) -> Action]
    private var lastKnownState: CBManagerState
    
    init(initialState: CBManagerState) {
        callbacks = []
        lastKnownState = initialState
    }
        
    // Callback will be called immediately with the last known state and every time the state changes in the future.
    func observe(_ callback: @escaping (CBManagerState) -> Action) {
        if callback(lastKnownState) == .keepObserving {
            callbacks.append(callback)
        }
    }
    
    func observeUntilKnown(_ callback: @escaping (CBManagerState) -> Void) {
        observe { state in
            if state == .unknown {
                return .keepObserving
            } else {
                callback(state)
                return .stopObserving
            }
        }
    }

    // MARK: - BTLEListenerStateDelegate

    func btleListener(_ listener: BLEScanner, didUpdateState state: CBManagerState) {
        lastKnownState = state
        
        var callbacksToKeep: [(CBManagerState) -> Action] = []
        
        for entry in callbacks {
            if entry(lastKnownState) == .keepObserving {
                callbacksToKeep.append(entry)
            }
        }

        callbacks = callbacksToKeep
    }

}
