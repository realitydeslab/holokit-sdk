//
//  InterfaceController.swift
//  AppleWatchOCWatch Extension
//
//  Created by Yuchen on 2021/7/12.
//

import WatchKit
import Foundation
import WatchConnectivity
import CoreMotion
import HealthKit

class InterfaceController: WKInterfaceController, WCSessionDelegate {

    enum ChargingState {
        case up
        case nothing
        case down
    }
    
    @IBOutlet var startButton: WKInterfaceButton!
    @IBOutlet var stateLabel : WKInterfaceLabel!
    
    let motionManager = CMMotionManager()
    let deviceMotionUpdateInterval: TimeInterval = 0.016
    var wcSession: WCSession!
    var workoutSession: HKWorkoutSession?
    let healthStore = HKHealthStore()
    var currentChargingState: ChargingState!
    let actionCoolDownTime: Double! = 0.5
    var lastActionTime: Double! = Date().timeIntervalSince1970
//    let queue: OperationQueue = {
//        var queue = OperationQueue()
//        queue.name = "Download queue"
//        queue.qualityOfService = .userInteractive
//        return queue
//      }()
    
    @IBAction func startButtonTapped() {
        if (workoutSession != nil) {
            return
        }
        
        startButton.setTitle("Started")
        stateLabel.setText("Active")
        
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .mixedCardio
        workoutConfiguration.locationType = .indoor
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
        } catch {
            print("Failed to create workout session")
            return
        }
        workoutSession?.startActivity(with: Date())
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!) { [self] (data, error) in
                if (Date().timeIntervalSince1970 - self.lastActionTime < self.actionCoolDownTime) {
                    return
                }
                
                guard let acceleration: CMAcceleration = data?.userAcceleration else {
                    print("Invalid acceleration data")
                    return
                }
                guard let gravity: CMAcceleration = data?.gravity else {
                    print("Invalid gravity data")
                    return
                }
                
                // Handle accelerometer data
                //print(acceleration)
                if (acceleration.x < -5 && gravity.z < -0.85) {
                    print("fire")
                    self.lastActionTime = Date().timeIntervalSince1970
                    // Pass this event back to iOS app
                    let message = ["watch":0]
                    self.wcSession.sendMessage(message, replyHandler: nil, errorHandler: nil)
                } else if (acceleration.x < -2 && gravity.x > 0.8) {
                    print("cast shield")
                    let message = ["watch": 1]
                    self.wcSession.sendMessage(message, replyHandler: nil, errorHandler: nil)
                    self.lastActionTime = Date().timeIntervalSince1970
                }
                
                // Handle gravity data
                //print(gravity)
                if (gravity.x > 0.7) {
                    if (self.currentChargingState != .up) {
                        print("switched to up")
                        self.currentChargingState = .up
                        let message = ["watch":2]
                        self.wcSession.sendMessage(message, replyHandler: nil, errorHandler: nil)
                    }
                } else if (gravity.x < -0.7) {
                    if (self.currentChargingState != .down) {
                        print("switched to down")
                        self.currentChargingState = .down
                        let message = ["watch":3]
                        self.wcSession.sendMessage(message, replyHandler: nil, errorHandler: nil)
                    }
                } else {
                    if (self.currentChargingState != .nothing) {
                        print("switched to nothing")
                        self.currentChargingState = .nothing
                        let message = ["watch":4]
                        self.wcSession.sendMessage(message, replyHandler: nil, errorHandler: nil)
                    }
                }
            }
        }
//        motionManager.accelerometerUpdateInterval = 0.016
//        motionManager.startAccelerometerUpdates(to: queue) { (data, error) in
//            if let accelerometerData = data {
//                //print(accelerometerData)
//                if (accelerometerData.acceleration.x < -10) {
//                    print("fire")
//                    // TODO: pass this event back to iOS app
//                    let message = ["fire":true]
//                    self.wcSession.sendMessage(message, replyHandler: nil, errorHandler: nil)
//                }
//            }
//        }
    }
    
    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        super.awake(withContext: context)
        if (WCSession.isSupported()) {
            wcSession = WCSession.default
            wcSession.delegate = self
            wcSession.activate()
        }
        motionManager.deviceMotionUpdateInterval = deviceMotionUpdateInterval
        currentChargingState = .nothing
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        //print("willActivate")
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        //print("didDeactivate")
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("watch connecting to iPhone")
        if (activationState == .activated) {
            print("activated")
        } else if (activationState == .inactive) {
            print("inactive")
        } else if (activationState == .notActivated) {
            print("not activated")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("session reachability did change")
        print(session.isReachable)
    }
}
