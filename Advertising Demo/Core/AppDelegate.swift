//
//  AppDelegate.swift
//  Advertising Demo
//
//  Created by TCode on 18/05/2020.
//  Copyright © 2020 CrowdConnected. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UIApplication.shared.registerForRemoteNotifications()
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _,_ in
            UNUserNotificationCenter.current().delegate = self
        }
          
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
//        print("Hast la vista")
//        scheduleLocalNotification()
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Received notification \(userInfo)")
    }
    
    private func scheduleLocalNotification() {
        let content = UNMutableNotificationContent()
        content.body = "To keep yourself secure, please relaunch the app."
               
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "willTerminate.relaunch.please", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

