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
    @IBOutlet weak var beaconsScannerLabel: UILabel!
    
    @IBOutlet weak var txLabel: UILabel!
    @IBOutlet weak var uuidsLabel: UILabel!
    @IBOutlet weak var serviceDataLabel: UILabel!
    
    private var central: CBCentralManager?
    private var peripheral: CBPeripheralManager?
    
    private var beaconScanner: BluetoothBeaconsManager?
    private var broadcaster: BLEBroadcaster?
    private var scanner: BLEScanner?
    
    private var queue = DispatchQueue(label: "ColocatorBroadcaster")
    public private(set) var stateObserver: BluetoothStateObserving = BluetoothStateObserver(initialState: .unknown)
    
    let centralRestoreIdentifier: String = "ColocatorCentralRestoreIdentifier"
    let peripheralRestoreIdentifier: String = "ColocatorPeripheralRestoreIdentifier"
    
    var changeIdentityTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    @IBAction func actionStartBeaconsScan(_ sender: Any) {
        beaconScanner = BluetoothBeaconsManager()
        beaconScanner?.startMonitoringRegion()
        beaconsScannerLabel.text = "Monitoring region..."
    }
    
    @IBAction func actionStopBeaconsScan(_ sender: Any) {
        beaconScanner?.stopMonitoringRegion()
        beaconsScannerLabel.text = "Turned Off"
    }
    
    @IBAction func actionStartAdvertising(_ sender: Any) {
//        EIDKeyManager.setup(secret: <#T##String#>, k: <#T##Int#>, clockOffSet: <#T##Int#>)
        
        let newEID = EIDKeyManager.generateEIDString()
        print(newEID ?? " Failed to generate EID")
        advertisingStatusLabel.text = newEID
    }
    
    
    @IBAction func actionStartScanning(_ sender: Any) {
        if broadcaster == nil {
            broadcaster = BLEBroadcaster()
            peripheral = CBPeripheralManager(delegate: broadcaster,
                                             queue: queue,
                                             options: [CBPeripheralManagerOptionRestoreIdentifierKey: peripheralRestoreIdentifier])
        }
        
        scanner = BLEScanner(broadcaster: broadcaster!, queue: queue)
        central = CBCentralManager(delegate: scanner,
                                   queue: queue,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(true),
                                             CBCentralManagerOptionRestoreIdentifierKey: centralRestoreIdentifier,
                                             CBCentralManagerOptionShowPowerAlertKey: NSNumber(false)])
        
        scanner?.stateDelegate = self.stateObserver
        scanningStatusLabel.text = "Scanning..."
    }
    
    @IBAction func actionStopScanning(_ sender: Any) {
        central?.stopScan()
        central = nil
        scanner = nil
        scanningStatusLabel.text = "Turned Off"
    }
    
    @objc private func updateBroadcastID() {
        broadcaster?.updateIdentity()
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
