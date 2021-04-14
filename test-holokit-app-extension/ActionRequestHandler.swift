//
//  ActionRequestHandler.swift
//  nfcverification
//
//  Created by Botao Hu on 12/1/20.
//

import UIKit
import MobileCoreServices

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {

    var extensionContext: NSExtensionContext?
    
    func beginRequest(with context: NSExtensionContext) {
        // Do not call super in an Action extension with no user interface
        let item = NSExtensionItem()
        
        if let userDefaults = UserDefaults(suiteName: "group.com.holoi.holokit") {
            let nfc_uid = userDefaults.string(forKey: "nfc_uid")
            let nfc_url = userDefaults.string(forKey: "nfc_url")
            
            item.userInfo = ["nfc_uid": nfc_uid, "nfc_url": nfc_url]
        }
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
    

}
