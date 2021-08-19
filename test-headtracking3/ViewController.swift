//
//  ViewController.swift
//  test-headtracking3
//
//  Created by Yuchen on 2021/8/19.
//

import UIKit
import Metal
import MetalKit
import ARKit
import os.signpost

extension MTKView : RenderDestinationProvider {
}

class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate {
    
    var session: ARSession!
    var renderer: Renderer!
    var frameCnt: Int = 0
    var previousPresentedTime: CFTimeInterval = 0.0
    let logHandler = OSLog(subsystem: "com.holoi.xr.holokit.test-headtracking.test-headtracking2", category: .pointsOfInterest)

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
            
            renderer.drawRectResized(size: view.bounds.size)
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
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
        renderer.drawRectResized(size: size)
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
     //   let logHandler = OSLog(subsystem: "com.holoi.xr.holokit.test-headtracking.test-headtracking2", category: .pointsOfInterest)

        frameCnt += 1
        os_signpost(.begin, log: logHandler, name: "ar session", "begin ar session for frameCnt=%d, frametime=%f, systemtime=%f", frameCnt, frame.timestamp, ProcessInfo.processInfo.systemUptime )
        print("\n");
        print("[arkit session] current time at \(ProcessInfo.processInfo.systemUptime), frame sensortime = \(frame.timestamp)");
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
