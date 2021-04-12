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

// MARK: - Declerations & IBs
class ViewController: BusableController {
    
    // MARK: long processing
    var longTaskdId: LongProcessSimulator.JobId?
    var didEnterBgWhileProcessing: Bool = false
    // MARK: Subs
    var subs: BusableController.Subs = [:]
    override var SubscriptionEvents: BusableController.Subs {
        get { return self.subs }
    }
    
    // MARK: IBOutlets
    @IBOutlet weak var locLabel: UILabel!
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
}

// MARK: - Life Cycle
extension ViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupBus()
        self.updateLocationLabel(withState: LocationManager.shared.state)
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
            .LocationManagerStateChange: self.locationManagerStateChange(notification:),
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
        if !gps.isHasAccess() && self.didEnterBgWhileProcessing {
            self.updateHintLabel(setHidden: false, setText: WARNING_HINT_TEXT)
        } else if gps.state == .Monitoring {
            gps.stopMonitoring()
        }
    }
    
    private func locationManagerStateChange(notification: Notification) {
        if let state = notification.userInfo?["state"] as? LocationManager.State {
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
        self.longTaskdId = lpSim.tick(
            times: 200,
            withRandomIntervals: [0.3, 0.7, 1],
            block: self.simluationTick(progress:total:isDone:)
        )
        self.updateHintLabel(setHidden: false, setText: INITIAL_HINT_TEXT)
    }
    
    func stopSim() {
        guard self.isSimulating() else {
            DispatchQueue.main.async { AppDelegate.current.alert("Error", "No Task Running") }
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
        let pS = "\(Int(p * 100.0))%"
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
        return self.longTaskdId == nil // returning true cancels run
    }
}
// MARK: - UI Updates
extension ViewController {

    func updateLocationLabel(withState state: LocationManager.State) {
        self.locLabel.text = "Location Updates are \(state)"
    }

    func updateProgressViews(progress: Float) {
        let pS = "\(Int(progress * 100.0))%"
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
            print("WARN: updateHintLabel was called without paramters, this is a noop, use the setHidden or setText to dismiss message")
            return
        }
    }
}
