//
//  ViewController.swift
//  NFC-Swift-UID
//
//  Created by Yuchen on 2021/4/12.
//

import UIKit
import Metal
import MetalKit
import ARKit
import CoreNFC
import CryptoKit

extension MTKView : RenderDestinationProvider {
}

class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate, NFCTagReaderSessionDelegate {
    
    var session: ARSession!
    var renderer: Renderer!
    var readerSession: NFCTagReaderSession?
    var isNfcInitialized: Bool! = false
    var isUidQueried: Bool! = false
    var privateKeyRawValue: String! = "8d4b14f96b338b949c8b4de898d3748f40104835cff129bc54fea0164442bd01"
    var publicKeyRawValue: String! = "dfa65630f4e8a2429558e7bce61e89f321bd531af8bde64225a05894f8767246"
    var uid: String!
    let urlPrefix: String! = "https://holoi.com/holokit/holokitx?"
    let pid: String! = "HoloKitX"
    
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
        renderer.update()
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if (!isNfcInitialized) {
            GenerateNewKeyPair()
            self.readerSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
            self.readerSession?.alertMessage = "Put your iPhone onto the HoloKit."
            self.readerSession?.begin()
            isNfcInitialized = true
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
    
    // MARK: - NFCDelegate
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("Session began.")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("Tag detected.")
        if tags.count > 1 {
            session.alertMessage = "More than 1 tag detected. Please remove all tags and try again."
            session.invalidate()
        }
        let tag = tags.first!
        //print(type(of: tag))
        session.connect(to: tag) { (error) in
            if nil != error{
                session.invalidate(errorMessage: "Unable to connect to tag.")
            }
            if case let .iso7816(sTag) = tag {
                let UID = sTag.identifier.map{ String(format: "%.2hhx", $0) }.joined()
                //print(type(of: sTag))
                print("UID:", UID)
                self.uid = UID
                self.isUidQueried = true;
                //print(sTag.identifier)
                //session.alertMessage = "UID captured."
                //session.invalidate()
                self.GenerateNfcTagUrl()
                var str:String = "Farewell"
                var strToUint8:[UInt8] = [UInt8](str.utf8)
                
                sTag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                    guard error == nil else {
                        session.alertMessage = "Unable to query the NDEF status of tag."
                        session.invalidate()
                        return
                    }
                    switch ndefStatus {
                    case .notSupported:
                        session.alertMessage = "Tag is not NDEF compliant."
                        session.invalidate()
                    case .readOnly:
                        session.alertMessage = "Tag is read only."
                        session.invalidate()
                    case .readWrite:
                        sTag.writeNDEF(.init(records: [.init(format: .nfcWellKnown, type: Data([06]), identifier: Data([0x0C]), payload: Data(strToUint8))]), completionHandler: { (error: Error?) in
                            if nil != error {
                                session.alertMessage = "Write NDEF message fail: \(error!)"
                            } else {
                                session.alertMessage = "Write NDEF message successful."
                                print("Well done.")
                            }
                            session.invalidate()
                        })
                    @unknown default:
                        session.alertMessage = "Unknown NDEF tag status."
                        session.invalidate()
                    }
                })
            }
            
            
        }
    }
    
    // MARK: - CyptoKit
    
    func GenerateNewKeyPair() {
        let privateKey = Curve25519.Signing.PrivateKey()
        let privateKeyRawValueString = privateKey.rawRepresentation.map{ String(format: "%.2hhx", $0) }.joined()
        print("New private key raw value: " + privateKeyRawValueString)
        
        let publicKeyRawValueString = privateKey.publicKey.rawRepresentation.map{ String(format: "%.2hhx", $0) }.joined()
        print("New public key raw value: " + publicKeyRawValueString)
    }
    
    func GenerateSignature(content: String) -> String {
        let privateKey = try! Curve25519.Signing.PrivateKey(rawRepresentation: dataWithHexString(hex: self.privateKeyRawValue))
        let dataToSign = content.data(using: .utf8)!
        let signature = try! privateKey.signature(for: dataToSign)
        
        return signature.base64EncodedString()
    }
    
    func GenerateContent() -> String {
        let contentPrefix: String! = "content="
        let date = Date()
        let formatter = DateFormatter()
        formatter.timeZone = .current
        formatter.locale = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let formattedDate = formatter.string(from: date)
        let rawContent: String! = "uid=" + self.uid + "&pid=" + pid + "&date=" + formattedDate;
        print(rawContent)
        return ""
    }
    
    func dataWithHexString(hex: String) -> Data {
        var hex = hex
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        return data
    }
    
    func replace(myString: String, _ index: Int, _ newChar: Character) -> String {
        var chars = Array(myString)     // gets an array of characters
        chars[index] = newChar
        let modifiedString = String(chars)
        return modifiedString
    }
    
}

