//
//  ViewController.swift
//  test-star-tracking
//
//  Created by Botao Hu on 7/8/22.
//

import UIKit
import Metal
import MetalKit
import ARKit
import CoreMotion
import os.signpost

extension MTKView : RenderDestinationProvider {
}

class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate {
    
    var session: ARSession!
    var renderer: Renderer!
    
    var motionManager = CMMotionManager()
    var motionQueue = OperationQueue()
    
    let logHandler = OSLog(subsystem: "com.holoi.xr.holokit.test-star", category: .pointsOfInterest)
    var frameCnt: Int = 0
    var previousPresentedTime: CFTimeInterval = 0.0
    var frameRate: Double = 0.0
    var addedPresentedHandler = false

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        session = ARSession()
        session.delegate = self
        
        // Set the view to use the default device
        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self
            
            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }
            
            // Configure the renderer to draw to the view
            renderer = Renderer(session: session, metalDevice: view.device!, renderDestination: view)
            
            renderer.drawRectResized(size: view.bounds.size, drawableSize: view.drawableSize)
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        motionQueue.qualityOfService = .userInteractive
        motionManager.gyroUpdateInterval = 1 / 100.0
        motionManager.startGyroUpdates(to: motionQueue) { [self] (data, error) in
          //  ARFusion_addGyrMeasurement(data.rotationRate.x, data.rotationRate.y, data.rotationRate.z)
            
            
            os_signpost(.begin, log: logHandler, name: "gyro", "gyro for frameCnt=%d, eventtime=%f, systemtime=%f", self.frameCnt, data?.timestamp ?? 0, ProcessInfo.processInfo.systemUptime )
           
            
            os_signpost(.end, log: logHandler, name: "gyro")
            
        }
        
        motionManager.accelerometerUpdateInterval = 1 / 100.0
        motionManager.startAccelerometerUpdates(to: motionQueue) { [self]  (data, error) in
           // ARFusion_addAccMeasurement(data.acceleration.x, data.acceleration.y, data.acceleration.z)
            
            
            os_signpost(.begin, log: logHandler, name: "accel", "accel for frameCnt=%d, eventtime=%f, systemtime=%f", self.frameCnt, data?.timestamp ?? 0, ProcessInfo.processInfo.systemUptime )
           
            
            os_signpost(.end, log: logHandler, name: "accel")
            
        }
        
        

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        session.pause()
    }
    
    @objc
    func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Create anchor using the camera's current position
        if let currentFrame = session.currentFrame {
            
            // Create a transform with a translation of 0.2 meters in front of the camera
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -0.2
            let transform = simd_mul(currentFrame.camera.transform, translation)
            
            // Add a new anchor to the session
            let anchor = ARAnchor(transform: transform)
            session.add(anchor: anchor)
        }
    }
    
    // MARK: - MTKViewDelegate
    
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size, drawableSize: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        
        os_signpost(.begin, log: logHandler, name: "drawcall", "begin processing for frameCnt=%d, systemtime=%f", frameCnt, ProcessInfo.processInfo.systemUptime)
        print("[drawcall begin] current at \(ProcessInfo.processInfo.systemUptime)");

              
        if let cd = view.currentDrawable {
            os_signpost(.begin, log: logHandler, name: "currentDrawable", "before presented frameCnt=%d, cd.drawableID=%d, systemtime=%f", frameCnt, cd.drawableID, ProcessInfo.processInfo.systemUptime)
            
            cd.addPresentedHandler({ [weak self] drawable in
                guard let strongSelf = self else {
                    return
                }
                //let presentationDuration = drawable.presentedTime - strongSelf.previousPresentedTime
                //strongSelf.frameRate = 1.0/presentationDuration
                /* ... */
                strongSelf.previousPresentedTime = drawable.presentedTime
                
                os_signpost(.end, log: strongSelf.logHandler, name: "currentDrawable", "presented frameCnt=%d, cd.drawableID=%d, systemtime=%f, presentedTime=%f",strongSelf.frameCnt, cd.drawableID, ProcessInfo.processInfo.systemUptime, drawable.presentedTime)

                print("[presentedTime] current at \(ProcessInfo.processInfo.systemUptime)");

            })
        }
        
        renderer.update()
        
        os_signpost(.end, log: logHandler, name: "drawcall", "finished processing for frameCnt=%d", frameCnt)
        print("[drawcall end] current at \(ProcessInfo.processInfo.systemUptime)");


        
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
       // matrix_float3x3 camMat = frame.camera.intrinsics;
        
//        ARFusion_addArKit(frame.camera.transform, frame.timestamp)

        frameCnt += 1
        os_signpost(.begin, log: logHandler, name: "ar session", "begin ar session for frameCnt=%d, frametime=%f, systemtime=%f", frameCnt, frame.timestamp, ProcessInfo.processInfo.systemUptime )
        
        print("[arkit session] current with sensor time at \(ProcessInfo.processInfo.systemUptime), \(frame.timestamp)");

        let projection = session.currentFrame!.camera.projectionMatrix
        let yScale = projection[1,1]
        let yFov = 2 * atan(1/yScale) // in radians
        let yFovDegrees = yFov * 180/Float.pi
        let imageResolution = session.currentFrame!.camera.imageResolution
        let xFov = yFov * Float(imageResolution.width / imageResolution.height)
        let xFovDegrees = xFov * 180/Float.pi
       // print(xFovDegrees, yFovDegrees)

      //  self.handTracker.processVideoFrame(frame.capturedImage)
        os_signpost(.end, log: logHandler, name: "ar session", "begin ar session for frameCnt=%d", frameCnt)
        
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
