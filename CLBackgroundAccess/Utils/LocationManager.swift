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
    /// Alias to CLAuthorizationStatus, makes accessable throughout the project
    /// without importing the CoreLocation kit.
    typealias LocationAuthStatus = CLAuthorizationStatus
    enum State {
        case Idle, Monitoring
    }
    
    /// Singleton Object
    static let shared = LocationManager()
    
    private var _state: State = .Idle {
        didSet {
            /// Disptach State Change event
            Bus.shared.post(event: .LocationManagerStateChange, userInfo: ["state": _state ])
        }
    }
    public var state: State {
        get { return _state }
    }
    private var manager: CLLocationManager!
    
    private override init() {
        super.init()
        self.setup()
    }
    
    // cleanup
    deinit {
        self.teardown()
        print("Location Manager Killed")
    }
}

// MARK: - Life Cycle Setup
private extension LocationManager {
    func setup() {
        manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        manager?.delegate = self
        manager?.allowsBackgroundLocationUpdates = true
        manager?.pausesLocationUpdatesAutomatically = false
        manager?.distanceFilter = kCLDistanceFilterNone
    }
    
    func teardown() {
        self.stopMonitoring()
        self.manager.delegate = nil
        self.manager = nil
    }
}
// MARK: - Main BL
extension LocationManager {
    
    func isHasAccess() -> Bool {
        var isHas = true
        if let authStatus = self.manager?.authorizationStatus {
            if authStatus == .notDetermined || authStatus == .denied || authStatus == .restricted {
                isHas = false
            }
            return isHas
        }
        return false
    }
    
    func requestAccess() {
        manager?.requestAlwaysAuthorization()
    }
    
    func startMonitoring() {
        guard self.isHasAccess() else {
            print("WARN: App Doesnt have access to CoreLocation, please call LocationManager.shared.isHasAccess() first")
            return
        }
        guard self.state == .Idle else {
            print("WARN: LocationManager already running")
            return
        }
        
        // sned to global queue
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
            self._state = .Monitoring
            self.manager?.startUpdatingLocation()
            /// Optional:
            /// Only work if app has .authorizedAlways access,
            /// shows the blue indicator in the status bar,
            /// if app has .authorizedWhenInUse, the blue indicator on by default
            /// so we manually turn it on in any case to inform
            /// the user that we are working in the background
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
        /// turn off blue indicator
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
extension LocationManager.LocationAuthStatus: CustomStringConvertible {
    public var description: String {
        get {
            switch self {
                case .notDetermined: return "NotDetermined"
                case .denied: return "Denied"
                case .restricted: return "Restricted"
                case .authorizedAlways: return "AuthorizedAlways"
                case .authorizedWhenInUse: return "AuthorizedWhenInUse"
                default: return "CLAuthorizationStatus"
            }
        }
    }
    
}

