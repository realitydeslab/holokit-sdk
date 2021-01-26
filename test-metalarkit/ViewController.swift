//
//  ViewController.swift
//  test-metalarkit
//
//  Created by Botao Hu on 11/28/20.
//

import UIKit
import Metal
import MetalKit
import ARKit

extension MTKView : RenderDestinationProvider {
}

class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate, TrackerDelegate {
    
    var session: ARSession!
    var renderer: Renderer!
    let handTracker: HandTracker = HandTracker()!
    let handTrackingQueue = DispatchQueue(label: "handTrackingQueue", qos: .userInteractive, attributes: .concurrent)
    var landmarks: [[Landmark]]!
    var handedness: [Handedness]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        session = ARSession()
        session.delegate = self
        
        handTracker.startGraph()
        handTracker.delegate = self
        
    
        
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
        
        //configuration.frameSemantics = .sceneDepth
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
        renderer.update()
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        
        //handTrackingQueue.async {
        
            self.handTracker.processVideoFrame(pixelBuffer)
        //}
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
    
    
    func handTracker(_ handTracker: HandTracker!, didOutputLandmarks multiLandmarks: [[Landmark]]!) {
        self.landmarks = multiLandmarks
        
       
        
        if let currentFrame = session.currentFrame {
            
            for anchor in currentFrame.anchors {
                session.remove(anchor: anchor)
            }
            for landmarks in multiLandmarks {
                print("hi")
                for landmark in landmarks {
                    
                    var translation = matrix_identity_float4x4
                    translation.columns.3.z = -0.3
                    
                    //This transform represents a plane whose origin is in front of the camera. But it is in the x-z plane....
                    let planeOrigin = simd_mul(currentFrame.camera.transform, translation)
                    
                    
                    //We want the x-y plane, parralel to the screen, so we need to rotate in the x-axis
                    let xAxis = simd_float3(x: 1,
                                            y: 0,
                                            z: 0)
                    
                    let rotation = float4x4(simd_quatf(angle: 0.5 * .pi ,
                                                       axis: xAxis))
                    
                    let plane = simd_mul(planeOrigin, rotation)
                    
                    let x = CGFloat( landmark.x) * currentFrame.camera.imageResolution.width
                    let y = CGFloat( landmark.y) * currentFrame.camera.imageResolution.height
                    let screenPoint = CGPoint(x: x, y: y)
                                    
                    print(landmark.x, landmark.y, landmark.z)
                
                    
                   // print(screenPoint)
                  //  print(currentFrame.camera.imageResolution)
//                    
                    if let point3 = currentFrame.camera.unprojectPoint(screenPoint, ontoPlane: plane, orientation: .landscapeRight, viewportSize: currentFrame.camera.imageResolution) {
                      //  print(point3)
                       // point3.z = landmark.z / 80 - 0.4
                                        
                        var translation2 = matrix_identity_float4x4
                        translation2.columns.3.x = point3.x
                        translation2.columns.3.y = point3.y
                        translation2.columns.3.z = point3.z // landmark.z / 80 - 0.3
                        
    
                        let transform = simd_mul(currentFrame.camera.transform, translation2)

                        let anchor = ARAnchor(transform: transform)

                        session.add(anchor: anchor)
                        
                    }
                    //break
                }
            }
        }
        
        // Add a new anchor to the session
      
    }
    
    func handTracker(_ handTracker: HandTracker!, didOutputHandednesses handednesses: [Handedness]!) {
        self.handedness = handednesses
    }
    
    func handTracker(_ handTracker: HandTracker!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer!) {
        DispatchQueue.main.async {
            //self.imageView.image = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer))
        }
    }
}
