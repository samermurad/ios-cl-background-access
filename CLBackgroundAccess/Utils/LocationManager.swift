//
//  LocationManager.swift
//  CLBackgroundAccess
//
//  Created by Samer Murad on 10.04.21.
//

import Foundation
import CoreLocation
import UIKit

// MARK: Declarations
class LocationManager: NSObject {
    enum State {
        case Idle, PendingAccess, Monitoring
    }
    
    /// Singleton Object
    static let shared = LocationManager()
    
    private var _state: State = .Idle {
        didSet {
            Bus.shared.post(event: .LocationManagerStateChange, object: nil, userInfo: ["state": _state ])
        }
    }
    public var state: State {
        get { return _state }
    }
    private var manager: CLLocationManager!
    
    private override init() {
        super.init()
        manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        manager?.delegate = self
        manager?.allowsBackgroundLocationUpdates = true
        manager?.pausesLocationUpdatesAutomatically = false
        manager?.distanceFilter = kCLDistanceFilterNone
    }
    
    // cleanup
    deinit {
        self.stopMonitoring()
        self.manager.delegate = nil
        self.manager = nil
        print("Location Manager Killed")
    }
}

// MARK: - Main BL
extension LocationManager {
    
    func isHasAccess() -> Bool {
        var isHas = true
        let authStatus = self.manager.authorizationStatus
        if authStatus == .notDetermined || authStatus == .denied || authStatus == .restricted {
            isHas = false
        }
        return isHas
    }
    
    func requestAccess() {
        manager?.requestAlwaysAuthorization()
    }
    
    func startMonitoring() {
        guard self.isHasAccess() else {
            NSLog("WARN: App Doesnt have access to CorLocation, please call LocationManager.shared.isHasAccess() first")
            return
        }
        guard self.state == .Idle else {
            print("WARN: LocationManager already running")
            return
        }
        DispatchQueue.global().async {
            // Guard has location services
            guard CLLocationManager.locationServicesEnabled() else {
                DispatchQueue.main.async {
                    AppDelegate
                        .current
                        .alert("Error", "Location Services Must be enbaled, got to Settings -> Privacy -> Location Services to enable")
                }
                return
            }
            let authStatus = self.manager.authorizationStatus
            guard authStatus != .denied && authStatus != .restricted else {
                DispatchQueue.main.async {
                    AppDelegate.current.alert("Error", "App not allowed to use location")
                }
                return
            }
            self._state = .Monitoring
            self.manager?.startUpdatingLocation()
            self.manager.showsBackgroundLocationIndicator = true
        }
    }
    
    func stopMonitoring() {
        guard self.state != .Idle else {
            print("WARN: LocationManager already stopped")
            return
        }
        self.manager?.stopUpdatingLocation()
        self._state = .Idle
        self.manager.showsBackgroundLocationIndicator = false
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("locationManagerDidChangeAuthorization" , manager.authorizationStatus)
        Bus.shared.post(event: .LocationAuthUpdate, userInfo: ["status": manager.authorizationStatus, "state": self.state])
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Bus.shared.post(event: .LocationUpdate, userInfo: ["locations": locations, "state": self.state])
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case CLError.Code.denied:
                
                fallthrough
            default:
                print("locationManager: didFailWithError", clError)
            }
            // reset state
            self._state = .Idle
        }
    }
}


// MARK: CLAutorizationStatus pretty print
extension CLAuthorizationStatus: CustomStringConvertible {
    public var description: String {
        get {
            switch self {
                case .notDetermined: return ".notDetermined"
                case .denied: return ".denied"
                case .restricted: return ".restricted"
                case .authorizedAlways: return ".authorizedAlways"
                case .authorizedWhenInUse: return ".authorizedWhenInUse"
                default: return "CLAuthorizationStatus"
            }
        }
    }
    
}

