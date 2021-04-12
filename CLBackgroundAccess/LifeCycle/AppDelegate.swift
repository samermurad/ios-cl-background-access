//
//  AppDelegate.swift
//  CLBackgroundAccess
//
//  Created by Samer Murad on 10.04.21.
//

import UIKit
import UserNotifications
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        print("Terminating")
    }
}

/// Convenience AppWide Simple Alert
extension AppDelegate {
    func alert(_ title: String, _ msg: String? = nil) {
        DispatchQueue.main.async {
            let cnt = UIAlertController(title: title, message: msg, preferredStyle: .alert)
            cnt.addAction(UIAlertAction(title: "Ok", style: .default, handler: { [weak cnt] act in
                cnt?.dismiss(animated: true, completion: nil)
            }))
            
            guard let vc = AppDelegate.topViewController() else { return }

            vc.present(cnt, animated: true, completion: nil)
        }
    }
}

/// Convenience Methods to get AppDelegate instance and app's top ViewController
extension AppDelegate {
    static var current: AppDelegate {
        get {
            return UIApplication.shared.delegate as! AppDelegate
        }
    }

    class func topViewController(_ base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {

        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }

        if let tab = base as? UITabBarController {
            let moreNavigationController = tab.moreNavigationController

            if let top = moreNavigationController.topViewController, top.view.window != nil {
                return topViewController(top)
            } else if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }

        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }

        return base
    }
}

// MARK: UISceneSession Lifecycle
extension AppDelegate {
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
