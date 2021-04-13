//
//  ViewController.swift
//  CLBackgroundAccess
//
//  Created by Samer Murad on 10.04.21.
//

import UIKit

let INITIAL_HINT_TEXT = """
Enabling Location Servcies Allows the app to continue working in the background.
Otherwise your progress might be lost if you minimize the app while the process is running.
Consider giving the app access to your location to allow the processing to continue in the background.
"""

let WARNING_HINT_TEXT = """
App entered background while processing and was suspended.
Consider Giving the app access to your location to allow the processing to continue in the background.
"""

let DID_APP_ENTER_BG_WHILE_PROCESSING = "DID_APP_ENTER_BG_WHILE_PROCESSING"

// MARK: - Declerations & IBs
class ViewController: BusableController {
    
    // MARK: long processing
    // keeps track of the current running simulation
    var longTaskdId: LongProcessSimulator.JobId?
    
    var didEnterBgWhileProcessing: Bool = false {
        didSet {
            // save the didEnterBgWhileProcessing value on each change
            if self.didEnterBgWhileProcessing != oldValue {
                DispatchQueue.global().async { [unowned self] in
                    UserDefaults.standard.setValue(
                        self.didEnterBgWhileProcessing,
                        forKey: DID_APP_ENTER_BG_WHILE_PROCESSING
                    )
                    UserDefaults.standard.synchronize()
                }
            }
        }
    }
    // MARK: Subs
    /// are setup in the ViewController.setupBus method
    var subs: BusableController.Subs = [:]
    override var SubscriptionEvents: BusableController.Subs {
        get { return self.subs }
    }
    
    // MARK: IBOutlets
    @IBOutlet weak var locationAuthStatusLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progess: UIProgressView!
    @IBOutlet weak var locationOffHintLabel: UILabel!

    // MARK: IBActions
    @IBAction func requestLocationAccess(_ sender: Any) {
        LocationManager.shared.requestAccess()
    }
    
    @IBAction func startLongProcess(_ sender: Any) {
        self.startSim()
    }
    
    @IBAction func cancelLongProcess(_ sender: Any) {
        self.stopSim()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupBus()
        self.resetLongProcessViews()
        self.updateHintLabel(setHidden: true, setText: INITIAL_HINT_TEXT)
    }
}


// MARK: - Bus
extension ViewController {
    func setupBus() {
        self.subs = [
            .AppEnteredBackground: self.enteredBackground(_:),
            .AppEnteredForeground: self.enteredForeground(_:),
            .LocationAuthUpdate: self.locationAccessChanged(notification:),
        ]
    }
    
    private func enteredBackground(_: Notification) {
        print("VC: App entered background")
        let gps = LocationManager.shared
        if gps.isHasAccess() && isSimulating() { gps.startMonitoring() }
        self.didEnterBgWhileProcessing = isSimulating()
    }
    
    private func enteredForeground(_: Notification) {
        print("VC: App entered foreground")
        let gps = LocationManager.shared
        let cache = UserDefaults.standard
        self.didEnterBgWhileProcessing = cache.bool(forKey: DID_APP_ENTER_BG_WHILE_PROCESSING)
        if !gps.isHasAccess() && self.didEnterBgWhileProcessing {
            self.updateHintLabel(setHidden: false, setText: WARNING_HINT_TEXT)
        } else if gps.state == .Monitoring {
            gps.stopMonitoring()
        }
    }
    
    private func locationAccessChanged(notification: Notification) {
        let info = notification.userInfo
        if let state = info?["status"] as? LocationManager.LocationAuthStatus {
            DispatchQueue.main.async { [unowned self] in
                self.updateLocationLabel(withState: state)
            }
        }
    }
}
// MARK: - Long Process Sim
extension ViewController {
    func startSim() {
        guard !self.isSimulating() else {
            DispatchQueue.main.async {
                AppDelegate.current.alert("Error", "Task already running")
            }
            return
        }
        let lpSim = LongProcessSimulator.shared
        
        // Kickstart the long process simulation
        // for 2000 ticks, where each takes a random amount of time
        // between 0.3, 0.7 or 1 second.
        // block method gets call on each tick
        self.longTaskdId = lpSim.tick(
            times: 2000,
            withRandomIntervals: [0.3, 0.7, 1],
            block: self.simluationTick(progress:total:isDone:)
        )
        self.updateHintLabel(setHidden: false, setText: INITIAL_HINT_TEXT)
    }
    
    func stopSim() {
        guard self.isSimulating() else {
            DispatchQueue.main.async {
                AppDelegate.current.alert("Error", "No Task Running")
            }
            return
        }
        // cancel
        self.longTaskdId = nil
        self.updateHintLabel(setHidden: true, setText: nil)
    }
    
    func isSimulating() -> Bool {
        return self.longTaskdId != nil
    }
    
    func simluationTick(progress: Int64, total: Int64, isDone: Bool) -> Bool? {
        let p = Float(Float(progress) / Float(total))
        let pS = String(format: "%.2f%%", p * 100.0)
        print("Ticks: \(progress)/\(total) \(pS)")
        DispatchQueue.main.sync {
            self.updateProgressViews(progress: p)
        }

        if isDone {
            self.longTaskdId = nil
            DispatchQueue.main.sync {
                self.resetLongProcessViews()
            }
            LocationManager.shared.stopMonitoring()
        }
        return !self.isSimulating() // returning true cancels run
    }
}
// MARK: - UI Updates
extension ViewController {

    func updateLocationLabel(withState state: LocationManager.LocationAuthStatus) {
        self.locationAuthStatusLabel.text = "Location Access: \(state)"
    }

    func updateProgressViews(progress: Float) {
        let pS = String(format: "%.2f%%", progress * 100.0)
        self.progess.progress = progress
        self.progressLabel.text = pS
    }
    
    func resetLongProcessViews() {
        self.progess.progress = 0
        self.progressLabel.text = ""
    }
    
    func updateHintLabel(setHidden isHidden: Bool? = nil, setText text: String? = nil) {
        if let hide = isHidden {
            self.locationOffHintLabel.isHidden = hide
        }
        
        if let _ = text {
            self.locationOffHintLabel.text = text
        }
        
        guard text != nil || isHidden != nil  else {
            print("""
                WARN: updateHintLabel was called without paramters.
                This is a noop, use the setHidden or setText to dismiss message
                """
            )
            return
        }
    }
}
