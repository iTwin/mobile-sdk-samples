/*---------------------------------------------------------------------------------------------
* Copyright (c) Bentley Systems, Incorporated. All rights reserved.
* See LICENSE.md in the project root for license terms and full copyright notice.
*--------------------------------------------------------------------------------------------*/

import UIKit
import ITwinMobile
import UniformTypeIdentifiers

@available(iOS 14.0, *)
extension UTType {
    /// The UTType exported by this application (in Info.plist).
    static var bim_iModel = UTType(exportedAs: "com.bentley.bim-imodel")
}

extension ITMApplication {
    /// The parameters for an alert button used in `showAlert`
    struct AlertButtonParams {
        /// The string to display on the button.
        var label: String?
        
        /// The optional callback to run when the button is pressed.
        var handler: (() -> Void)?
    }
    
    /// Shows a modal alert dialog presented using `ITMApplication.topViewController`.
    /// - Parameters:
    ///   - title: The optional title shown at the top of the dialog.
    ///   - message: The message shown in the dialog.
    ///   - cancelButton: The optional parameters for the Cancel button. If nil, a cancel button will not be added. If the label is not specified, "Cancel" will be used.
    ///   - okButton: The optional parameters for the OK button. If nil or the label is nil, "OK" will be used.
    static func showAlert(title: String? = nil, message: String, cancelButton: AlertButtonParams? = nil, okButton: AlertButtonParams? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        
        alert.addAction(UIAlertAction(title: okButton?.label ?? "OK", style: .default, handler: { (action: UIAlertAction!) in
            okButton?.handler?()
        }))
        
        if let cancelButton = cancelButton {
            alert.addAction(UIAlertAction(title: cancelButton.label ?? "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
                cancelButton.handler?()
            }))
        }
        
        ITMApplication.topViewController?.present(alert, animated: true, completion: nil)
    }
    
    /// Shows a modal alert dialog by calling `showAlert`, asynchronously returning the result.
    /// - Parameters:
    ///   - title: The optional title shown at the top of the dialog.
    ///   - message: The message shown in the dialog.
    ///   - cancelLabel: The optional label for the cancel button. If nil, "Cancel" will be used.
    ///   - okLabel: The optional label for the OK button. If nil, "OK" will be used.
    /// - Returns: A boolean value when the user presses a button: OK (true) or Cancel (false).
    @discardableResult static func asyncAlert(title: String? = nil, message: String, cancelLabel: String? = nil, okLabel: String? = nil) async -> Bool {
        return await withCheckedContinuation { continuation in
            ITMApplication.showAlert(title: title, message: message,
                cancelButton: AlertButtonParams(label: cancelLabel) {
                    continuation.resume(returning: false)
                },
                okButton: AlertButtonParams(label: okLabel) {
                    continuation.resume(returning: true)
                })
        }
    }
}

/// A collection of static functions to help with picking documents and opening URL's.
class DocumentHelper {
    /// Gets files with a given extension in the documents directory.
    /// - Parameter matchExtension: The file extension to search for.
    /// - Returns: An array of file paths to the found documents, could be empty if none found.
    public static func getDocumentsWith(extension matchExtension: String) -> [String] {
        let fm = FileManager.default
        let lcMatchExtension = matchExtension.lowercased()
        let documentsDirs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if documentsDirs.count < 1 {
            return []
        }
        let documentsDir = documentsDirs[0]
        if let allDocuments = try? fm.contentsOfDirectory(atPath: documentsDir) {
            var bimDocuments: [String] = []
            let nsDocumentsDir = NSString(string: documentsDir)
            for document in allDocuments {
                let ext = NSString(string: document).pathExtension
                if ext.lowercased() == lcMatchExtension {
                    bimDocuments.append(nsDocumentsDir.appendingPathComponent(document))
                }
            }
            return bimDocuments
        }
        return []
    }

    /// Formulates a `URL` in the app's documents directory for the given source file.
    /// - Parameter srcUrl: The source URL that we will be opening/copying to this application.
    /// - Throws: `ITMError` if the documents directory cannot be determined.
    /// - Returns: The destination URL in the documents directory.
    public static func getDocumentsDestinationUrl(_ srcUrl: URL) throws -> URL {
        let documentsDirs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if documentsDirs.count < 1 {
            throw ITMError()
        }
        let destUrl = URL(fileURLWithPath: documentsDirs[0]).appendingPathComponent(srcUrl.lastPathComponent)
        return destUrl
    }
    
    /// Copies the given file from the source to the destination.
    ///
    /// The proper calls are made to access security scoped URL's.
    ///
    /// - Parameters:
    ///   - srcUrl: The URL of the file to copy.
    ///   - destUrl: The URL of the file destination.
    /// - Throws: If the copy fails.
    public static func copyExternalFile(srcUrl: URL, destUrl: URL) throws {
        let secure = srcUrl.startAccessingSecurityScopedResource()
        defer {
            if secure {
                srcUrl.stopAccessingSecurityScopedResource()
            }
        }
        try FileManager.default.copyItem(at: srcUrl, to: destUrl)
    }
    
    /// Prompts the user to replace the file if it already exists.
    /// - Parameter url: The file to check.
    /// - Throws: If the file exists and the user agrees to delete the file, but the removal fails, or if the user rejects deleting the file.
    public static func promptToReplaceFile(_ url: URL) async throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            return
        }
    
        if await !ITMApplication.asyncAlert(
            title: "Warning",
            message: "\(url.lastPathComponent) already exists in the application's documents. Do you want to replace it?",
            cancelLabel: "No",
            okLabel: "Yes") {
            throw ITMError()
        }
        try FileManager.default.removeItem(at: url)
    }
    
    /// Copies the input file into the documents directory, possibly prompting the user to replace the file
    /// if it already exists.
    /// - Parameter srcUrl: The file to copy.
    /// - Returns: The path to the copied file, or an empty string if it is not replaced by the user or an error occurs.
    public static func copyExternalFileIntoDocumentsWithPrompt(_ srcUrl: URL) async -> String {
        do {
            let destUrl = try getDocumentsDestinationUrl(srcUrl)
            try await promptToReplaceFile(destUrl)
            try copyExternalFile(srcUrl: srcUrl, destUrl: destUrl)
            return destUrl.path
        } catch {
            return ""
        }
    }
    
    /// Moves the input file to the documents directory.
    /// - Parameter srcUrl: The file to move.
    /// - Returns: The path to the moved file, or an empty string if it is not replaced by the user or an error occurs.
    public static func moveInboxFileIntoDocumentsWithPrompt(_ srcUrl: URL) async -> String {
        do {
            let destUrl = try getDocumentsDestinationUrl(srcUrl)
            try await promptToReplaceFile(destUrl)
            try FileManager.default.moveItem(at: srcUrl, to: destUrl)
            return destUrl.path
        } catch {
            return ""
        }
    }

    /// Opens the given Inbox file by copying it to the documents directory and sending a message to the web view.
    /// - Parameters:
    ///   - url: The file to copy and open.
    ///   - messenger: Optional messenger instance.
    ///   - query: Optional query message to send.
    public static func openInboxUrl(_ url: URL, messenger: ITMMessenger = ITMViewController.application.itmMessenger, query: String = "openModel") {
        Task {
            let path = await moveInboxFileIntoDocumentsWithPrompt(url)
            do {
                if !path.isEmpty {
                    try await messenger.query(query, path)
                } else {
                    // Try to remove the file from the Inbox if the move failed or the user cancelled
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                // Ignore
            }
        }
    }
}

/// An `ITMNativeUIComponent` sub-class that displays a document picker.
class DocumentPicker: ITMNativeUIComponent {
    private var coordinator: DocumentPickerCoordinator!
    
    /// Initializes with a view controller and messenger.
    /// - Parameters:
    ///   - itmNativeUI: The `ITMNativeUI` used to present the document picker.
    override init(itmNativeUI: ITMNativeUI) {
        super.init(itmNativeUI: itmNativeUI)
        queryHandler = itmMessenger.registerQueryHandler("chooseDocument", handleQuery)
    }
    
    /// The query handler for the "chooseDocument" query.
    /// - Throws: Throws if there is a problem.
    /// - Returns: The path to the file in the documents directory.
    private func handleQuery() async throws -> String {
        if let viewController = viewController {
            return await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    self.coordinator = DocumentPickerCoordinator(continuation)
                    let controller = self.makeUIViewController(coordinator: self.coordinator)
                    viewController.present(controller, animated: true, completion: nil)
                }
            }
        } else {
            throw ITMError(json: ["message": "No view controller"])
        }
    }
    
    /// Creates the `UIDocumentPickerViewController` that will be presented to the user.
    /// - Parameter coordinator: The coordinator that implements the `UIDocumentPickerDelegate` functions.
    /// - Returns: The controller instance.
    private func makeUIViewController(coordinator: DocumentPickerCoordinator) -> UIDocumentPickerViewController {
        let controller: UIDocumentPickerViewController
        if #available(iOS 14, *) {
            controller = UIDocumentPickerViewController(forOpeningContentTypes: [.bim_iModel], asCopy: false)
        } else {
            controller = UIDocumentPickerViewController(documentTypes: ["com.bentley.bim-imodel"], in: .open)
        }
        controller.allowsMultipleSelection = false
        controller.modalPresentationStyle = .fullScreen
        controller.delegate = coordinator
        return controller
    }
    
    /// Nested class that implements the `UIDocumentPickerDelegate` protocol.
    class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
        let continuation: CheckedContinuation<String, Never>
        
        /// Initializes with the given async continuation.
        /// - Parameter continuation: The continuation used when the user picks a file or cancels.
        init(_ continuation: CheckedContinuation<String, Never>) {
            self.continuation = continuation
        }
        
        /// Called when the user selects a file.
        ///
        /// Copies the file into the documents directory and resumes the continuation with the file's path.
        /// - Parameters:
        ///   - controller: The parent controller.
        ///   - urls: Picked file(s).
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            Task {
                let path = await DocumentHelper.copyExternalFileIntoDocumentsWithPrompt(urls[0])
                self.continuation.resume(returning: path)
            }
        }
        
        /// Called when the document picker is dismissed via the cancel button.
        ///
        /// Resumes the continuation with an empty string.
        /// - Parameter controller: The paren controller.
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            self.continuation.resume(returning: "")
        }
    }
}
