//
//  ViewController.swift
//  official-app
//
//  Created by Botao Hu on 12/1/20.
//

import UIKit
import CoreNFC

class ViewController: UIViewController {
    
    @IBOutlet weak var button: UIButton!
    
    var session: NFCReaderSession?
    
    @IBAction func scanTapped2(_ sender: Any) {
        
        print("pressed")
        
        
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        session =  NFCTagReaderSession.init(pollingOption: [.iso14443], delegate: self)
        // Do any additional setup after loading the view.
        
    }
}


extension ViewController: NFCTagReaderSessionDelegate {
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        
    }
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            return
        }
        var uid = ""
        let ndefTag: NFCNDEFTag
        switch tag {
        case let .iso7816(tag):
            ndefTag = tag
        case let .feliCa(tag):
            ndefTag = tag
        case let .iso15693(tag):
            ndefTag = tag
        case let .miFare(tag):
            ndefTag = tag
            uid = tag.identifier.base64EncodedString()
            print(tag.identifier.base64EncodedString())
        @unknown default:
            session.invalidate(errorMessage: "not supported tag")
            return
        }
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }
            
            ndefTag.queryNDEFStatus { status, _, error in
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: error?.localizedDescription ?? "not supported tag")
                default:
                    ndefTag.readNDEF { message, error in
                        if let message = message {
                            for record in message.records {
                                if record.typeNameFormat == .nfcWellKnown {
                                    if let uri = record.wellKnownTypeURIPayload() {
                                        print(uri)
                                        if let userDefaults = UserDefaults(suiteName: "group.com.holoi.holokit") {
                                            userDefaults.setValue(uid, forKey: "nfc_uid")
                                            userDefaults.setValue(uri, forKey: "nfc_url")
                                        }
                                    }
                                }
                            }
                            session.invalidate()
                        } else {
                            session.invalidate(errorMessage: error?.localizedDescription ?? "not supported tag")
                        }
                    }
                }
            }
        }
        
    }
    
}

