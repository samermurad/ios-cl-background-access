//
//  Bus.swift
//  CLBackgroundAccess
//
//  Created by Samer Murad on 10.04.21.
//

import Foundation
import UIKit

/// Convenience wrapper around NotificationCenter

// MARK: - Decleration
class Bus {
    typealias Unsubscriber = () -> Void
    static let shared = Bus()
    private init() {}
}

// MARK: - Subscribe / Post
extension Bus {
    /// Subscribe to an event, return an Unsubscriber method (call to remove sub)
    func on(event: Events, object: Any? = nil, queue: OperationQueue? = nil, cb: @escaping (Notification) -> Void) -> Unsubscriber {
        let center = NotificationCenter.default
        let notificationName = event.notifciationName()
        
        let observer = center.addObserver(forName: notificationName, object: object, queue: queue, using: cb)
        return {
            if object != nil {
                center.removeObserver(observer, name: notificationName, object: object)
            } else {
                center.removeObserver(observer)
            }
        }
    }
    
    /// Post event
    func post(event: Events, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        guard event.isManualPostSupported() else { return }
        let center = NotificationCenter.default
        print("Event dispatch:", event)
        center.post(name: event.notifciationName(), object: object, userInfo: userInfo)
    }
}

// MARK: - Events Enum
extension Bus {
    enum Events: String {
        // Location Events
        case LocationUpdate
        case LocationAuthUpdate
        case LocationManagerStateChange
        // Builtin Events
        case AppEnteredBackground
        case AppEnteredForeground
    }

}

// MARK: - Events enum Notification.Name support and system events guard
extension Bus.Events {
    func notifciationName() -> Notification.Name {
        switch self {
        case .AppEnteredBackground:
            return UIApplication.didEnterBackgroundNotification
        case .AppEnteredForeground:
            return UIApplication.willEnterForegroundNotification
        default:
            return Notification.Name(self.rawValue)
        }
    }
    
    func isManualPostSupported() -> Bool {
        let name = Notification.Name(self.rawValue)
        let actualNotificationName = self.notifciationName()
        let isSupported = name == actualNotificationName
        if !isSupported {
            print("WARN: Event \"", self, "\" Wrapps the System Event \"", actualNotificationName.rawValue, "\" And should not be posted manually")
        }
        return isSupported
    }
}
