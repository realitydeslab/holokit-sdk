//
//  ViewController.swift
//  test-headtracking2
//
//  Created by Botao Hu on 11/28/20.
//

import UIKit
import Metal
import MetalKit
import ARKit
import CoreMotion
import MultipeerConnectivity
import NearbyInteraction
import os.signpost
import Foundation

extension MTKView : RenderDestinationProvider {
}

class ViewController: UIViewController {

    let kServiceIdentity = "com.aa"
    let kServiceType = "aasda"
    
    var arSession: ARSession!
    var renderer: Renderer!
    var motionManager = CMMotionManager()
    var motionQueue = OperationQueue()
    let handTracker: HandTracker = HandTracker()!
    let handTrackingQueue = DispatchQueue(label: "handTrackingQueue", qos: .userInteractive, attributes: .concurrent)
    var landmarks: [[Landmark]]!
    var handedness: [Handedness]!
     
    var niSession: NISession!
    var niPeerToken: NIDiscoveryToken?
    var sharedTokenWithPeer: Bool = false
    
    var mcSession: MCSession?
    var mcAdvertiser: MCNearbyServiceAdvertiser?
    var mcBrowser: MCNearbyServiceBrowser?
    var mcPeerID: MCPeerID?
    var frameCnt: Int = 0
    var previousPresentedTime: CFTimeInterval = 0.0
    var frameRate: Double = 0.0
    var addedPresentedHandler = false
    let logHandler = OSLog(subsystem: "com.holoi.xr.holokit.test-headtracking.test-headtracking2", category: .pointsOfInterest)
    var anchorCount: Int = 0
    
    
    override func viewDidLoad() {
        
//        if let userDefaults = UserDefaults(suiteName: "group.com.holoi.holokit") {
//            let nfc_uid = userDefaults.setValue("sss", forKey: String)(forKey: "nfc_uid")
//            let nfc_url = userDefaults.string(forKey: "nfc_url")
//            
//            item.userInfo = ["nfc_uid": nfc_uid, "nfc_url": nfc_url]
//        }
//
        
        
        super.viewDidLoad()
        
        // Set the view's delegate
        arSession = ARSession()
        arSession.delegate = self
        
        // Set hand Tracker
     //   handTracker.startGraph()
        handTracker.delegate = self
        
        // Set nearby
        niSession = NISession()
        niSession.delegate = self
        sharedTokenWithPeer = false
        
        startMultipeerSession()
        
        DispatchQueue.global(qos: .background).async {
      //      solve()
        }

        // Set the view to use the default device
        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self
            view.preferredFramesPerSecond = 120
            
            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }
            
            // Configure the renderer to draw to the view
            renderer = Renderer(session: arSession, metalDevice: view.device!, renderDestination: view)
            
            renderer.drawRectResized(size: view.bounds.size, drawableSize: view.drawableSize)
            
        }
        
        let anchor = ARAnchor(transform: simd_float4x4())
        arSession.add(anchor: anchor)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        
        

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Motion
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
        configuration.isCollaborationEnabled = true
        // Run the view's session
        arSession.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        arSession.pause()
    }
    
    @objc
    func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Create anchor using the camera's current position
        if let currentFrame = arSession.currentFrame {
            
            // Create a transform with a translation of 0.2 meters in front of the camera
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -0.2
            let transform = simd_mul(currentFrame.camera.transform, translation)
            
            // Add a new anchor to the session
            var anchorName = "my position is (100.102, 20.123, 221.111)"
            anchorCount = anchorCount + 1
            let anchor = ARAnchor(name: anchorName, transform: transform)
            
            arSession.add(anchor: anchor)
        }
    }
    
    func sendToAllPeers(_ data: Data) {
        guard let mcSession = self.mcSession,
              mcSession.connectedPeers.count > 0 && data.count > 0 
        else
        {
            return
        }
        
         do {
            try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
         } catch {
            print("*** error sending data to peers: \(error.localizedDescription)")
        }
     }

    
    func receivedData(_ data: Data, from peer: MCPeerID) {
     
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data) {
            arSession.update(with: collaborationData)
        }
    
        if let niDiscoveryToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
            let configuration = NINearbyPeerConfiguration(peerToken: niDiscoveryToken)
            niSession?.run(configuration)
        }
    }
    
    func shareTokenWithAllPeers() -> Void
    {
        guard let token = niSession?.discoveryToken,
            let _ = self.mcSession,
            let encodedData = try?  NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        else
        {
          fatalError("Ese token no se puede codificar. 😭")
        }
        
        print("send to all peers with ni token")
        sendToAllPeers(encodedData)

        sharedTokenWithPeer = true
    }
    
}

extension ViewController: MTKViewDelegate {
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
    
}

extension ViewController: ARSessionDelegate
{
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
       // matrix_float3x3 camMat = frame.camera.intrinsics;
        
//        ARFusion_addArKit(frame.camera.transform, frame.timestamp)
        let logHandler = OSLog(subsystem: "com.holoi.xr.holokit.test-headtracking.test-headtracking2", category: .pointsOfInterest)

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
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("an anchored was added");
        for anchor in anchors {
            print(anchor.name)
        }
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
    
    func session(_ session: ARSession, didOutputCollaborationData data:ARSession.CollaborationData) {
        if let collaborationDataEncoded = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true){
            self.sendToAllPeers(collaborationDataEncoded)
        }
    }
}

extension ViewController: NISessionDelegate
{
    /// La sesión no vale.
    /// Hay que iniciar otra.
    func session(_ session: NISession, didInvalidateWith error: Error) -> Void
    {
    }
    
    /// Se ha perdido la conexión con el otro dispositivo
    /// La sesión no vale, tenemos que crear otra.
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) -> Void
    {
    }
    
    /// Nuevos datos de distancia y dirección
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) -> Void
    {
        guard  let currentFrame = arSession.currentFrame else
        {
            return
        }
        
        for anchor in currentFrame.anchors {
            if anchor.name?.starts(with: "nearbyinteraction") ?? false {
                arSession.remove(anchor: anchor)
            }
        }
        for nearbyObject in nearbyObjects {
            if let direction = nearbyObject.direction,
               let distance = nearbyObject.distance
            {
                var translation = matrix_identity_float4x4
                
                translation.columns.3.x = direction.x * distance
                translation.columns.3.y = direction.y * distance
                translation.columns.3.z = direction.z * distance
                
                let transform = simd_mul(currentFrame.camera.transform, translation)
                
                
                print("nearbyinteraction")
                let arAnchor = ARAnchor(name: "nearbyinteraction-" + nearbyObject.discoveryToken.hash.description, transform: transform)
                
                arSession.add(anchor: arAnchor)
            }
        }
    }
    

}

extension ViewController: MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    func startMultipeerSession() {
        if mcSession == nil
        {
            mcPeerID = MCPeerID(displayName: UIDevice.current.name)
            
            mcSession = MCSession(peer: mcPeerID!,
                                  securityIdentity: nil,
                                  encryptionPreference: .required)
            
            mcSession?.delegate = self
            
            mcAdvertiser = MCNearbyServiceAdvertiser(peer: mcPeerID!, discoveryInfo: [ "identity" : kServiceIdentity], serviceType: kServiceType )
            mcAdvertiser?.delegate = self
            mcAdvertiser?.startAdvertisingPeer()
            
            mcBrowser = MCNearbyServiceBrowser(peer: mcPeerID!, serviceType: kServiceType)
            mcBrowser?.delegate = self
            mcBrowser?.startBrowsingForPeers()
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        receivedData(data, from: peerID)
    }

    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
      switch state {
      case .notConnected:
          print("*** estate: \(state)")
      case .connected:
          print("*** estate: \(state)")
          print("*** connected peerID: \(String(describing: peerID))")
          shareTokenWithAllPeers()
      case .connecting:
          print("*** estate: \(state)")
      @unknown default:
          fatalError()
      }
    }
      
      func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
      }
      
      func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
          certificateHandler(true)
      }
      
      func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
      }
      
      func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
      }
      
      public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let info = info,
              let identity = info["identity"],
              let mcSession = self.mcSession,
              (identity == self.kServiceIdentity)
        else
        {
            return
        }

        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 10)
      }
      
      public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
      }
      
      public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
          print("%@", "didNotStartBrowsingForPeers: \(error)")
      }
      
      func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
          invitationHandler(true, self.mcSession)
      }
      
      func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
          print("%@", "didNotStartAdvertisingPeer: \(error)")
      }
    
}

extension ViewController: TrackerDelegate {

   
    func handTracker(_ handTracker: HandTracker!, didOutputHandednesses handednesses: [Handedness]!) {
        
    }
    
    func handTracker(_ handTracker: HandTracker!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer!) {
        
    }

    func handTracker(_ handTracker: HandTracker!, didOutputLandmarks multiLandmarks: [[Landmark]]!) {
        self.landmarks = multiLandmarks
        
       
        
        if let currentFrame = arSession.currentFrame {
            
            for anchor in currentFrame.anchors {
                if anchor.name == "handtracking" {
                    arSession.remove(anchor: anchor)
                }
            }
            for landmarks in multiLandmarks {
                print("hi")
                for landmark in landmarks {
                    
                    print("hi")
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
                                    
                    print(landmark.x)
                    print(landmark.y)
                    print(landmark.z)

                    
                    print(screenPoint)
                    print(currentFrame.camera.imageResolution)
//
                    if let point3 = currentFrame.camera.unprojectPoint(screenPoint, ontoPlane: plane, orientation: .landscapeRight, viewportSize: currentFrame.camera.imageResolution) {
                        print(point3)
                       // point3.z = landmark.z / 80 - 0.4
                                        
                        var translation2 = matrix_identity_float4x4
                        translation2.columns.3.x = point3.x
                        translation2.columns.3.y = point3.y
                        translation2.columns.3.z = point3.z // landmark.z / 80 - 0.3
                        
    
                        let transform = simd_mul(currentFrame.camera.transform, translation2)

                        let anchor = ARAnchor(name: "handtracking", transform: transform)

                        arSession.add(anchor: anchor)
                        
                    }
                    //break
                }
            }
        }
        
        // Add a new anchor to the session
      
    }

}
