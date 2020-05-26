//
//  BluetoothBeaconsManager.swift
//  Advertising Demo
//
//  Created by TCode on 26/05/2020.
//  Copyright © 2020 CrowdConnected. All rights reserved.
//

import Foundation
import CoreBluetooth
import CoreLocation

class BluetoothBeaconsManager: NSObject, CLLocationManagerDelegate {
    
    internal let locationManager = CLLocationManager()
    let region = CLBeaconRegion(proximityUUID: UUID(uuidString: "2c2d41fb-d4c5-4a4d-a49a-e8fd5c256293")!, identifier: "CC_Beacons_Region")
    
    func startMonitoringRegion() {
        locationManager.requestAlwaysAuthorization()
        
        locationManager.delegate = self
        
        region.notifyEntryStateOnDisplay = true
        locationManager.startMonitoring(for: region)
        locationManager.startRangingBeacons(in: region)
    }
    
    func stopMonitoringRegion() {
        locationManager.stopMonitoring(for: region)
        locationManager.stopRangingBeacons(in: region)
    }
    
    // BeaconScannerDelegate
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
//        print("Beacon detected \(beacons[0])")
    }
}
