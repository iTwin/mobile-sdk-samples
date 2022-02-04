/*---------------------------------------------------------------------------------------------
* Copyright (c) Bentley Systems, Incorporated. All rights reserved.
* See LICENSE.md in the project root for license terms and full copyright notice.
*--------------------------------------------------------------------------------------------*/

import UIKit
import WebKit
import ITwinMobile
import PromiseKit
import UniformTypeIdentifiers
import ShowTime

/// This app's `ITMApplication` sub-class that handles the messages coming from the web view.
class ModelApplication: ITMApplication {
    /// Registers query handlers.
    required init() {
        super.init()
        ITMApplication.logger = PrintLogger()
        registerQueryHandler("didFinishLaunching") { () -> Promise<()> in
            self.itmMessenger.frontendLaunchSuceeded()
            return Promise.value(())
        }
        registerQueryHandler("loading") { () -> Promise<()> in
            self.webView.isHidden = false
            return Promise.value(())
        }
        registerQueryHandler("reload") { () -> Promise<()> in
            self.webView.reload()
            return Promise.value(())
        }
        registerQueryHandler("getBimDocuments") { () -> Promise<[String]> in
            if #available(iOS 14.0, *) {
                return Promise.value(DocumentHelper.getDocumentsWith(extension: UTType.bim_iModel.preferredFilenameExtension!))
            } else {
                return Promise.value(DocumentHelper.getDocumentsWith(extension: "bim"))
            }
        }
        
        var showtimeEnabled = false
        if let configData = configData {
            extractConfigDataToEnv(configData: configData, prefix: "ITMSAMPLE_");
            showtimeEnabled = configData.isYes("ITMSAMPLE_SHOWTIME_ENABLED")
        }
        if !showtimeEnabled {
            ShowTime.enabled = ShowTime.Enabled.never
        }
    }
    
    /// Called when the `ITMViewController` will appear.
    ///
    /// Adds our DocumentPicker component to the native UI collection.
    /// - Parameter viewController: The view controller.
    override func viewWillAppear(viewController: ITMViewController) {
        super.viewWillAppear(viewController: viewController)
        viewController.itmNativeUI?.addComponent(DocumentPicker(viewController: viewController, itmMessenger: ITMViewController.application.itmMessenger))
    }
      
    override func getUrlHashParams() -> String {
        var hashParams = ""
        if let configData = configData {
            // Other characters are probably OK in a hash parameter, but we want to play it safe.
            // Note: CharactersSet.alphanumerics includes non-ASCII Unicode letters, so we can't start with that and then add a few symbols.
            let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.")
            if let tokenServerUrl = configData["ITMSAMPLE_TOKEN_SERVER_URL"] as? String,
               let encodedTokenServerUrl = tokenServerUrl.addingPercentEncoding(withAllowedCharacters: allowedCharacters),
               let tokenServerIdToken = configData["ITMSAMPLE_TOKEN_SERVER_ID_TOKEN"] as? String,
               let encodedTokenServerIdToken = tokenServerIdToken.addingPercentEncoding(withAllowedCharacters: allowedCharacters) {
                hashParams += "&tokenServerUrl=\(encodedTokenServerUrl)"
                hashParams += "&tokenServerIdToken=\(encodedTokenServerIdToken)"
            }
            if configData.isYes("ITMSAMPLE_DEBUG_I18N") {
                hashParams += "&debugI18n=YES"
            }
            if configData.isYes("ITMSAMPLE_LOW_RESOLUTION") {
                hashParams += "&lowResolution=YES"
            }
        }
        return hashParams
    }
}
