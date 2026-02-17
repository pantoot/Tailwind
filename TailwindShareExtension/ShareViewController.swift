//
//  ShareViewController.swift
//  TailwindShareExtension
//
//  Receives FIT files from Magene and other apps, saves them for import by main app
//

import UIKit
import UniformTypeIdentifiers

/// Share Extension for receiving FIT files from other apps (like Magene)
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        print("📤 Share Extension: viewDidLoad")
        // Process the shared FIT file immediately
        handleSharedFile()
    }

    private func handleSharedFile() {
        print("📤 Share Extension: handleSharedFile")
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            print("📤 Share Extension: No attachments found")
            completeWithError("No file found")
            return
        }
        print("📤 Share Extension: Found \(attachments.count) attachments")

        // Look for FIT file or general file data
        for attachment in attachments {
            // Check for file URL type first
            if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                    if let error = error {
                        self?.completeWithError(error.localizedDescription)
                        return
                    }

                    if let url = item as? URL {
                        self?.processFITFile(at: url)
                    } else {
                        self?.completeWithError("Could not read file URL")
                    }
                }
                return
            }

            // Also check for general data type
            if attachment.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { [weak self] item, error in
                    if let error = error {
                        self?.completeWithError(error.localizedDescription)
                        return
                    }

                    if let url = item as? URL {
                        self?.processFITFile(at: url)
                    } else if let data = item as? Data {
                        self?.processFITData(data)
                    } else {
                        self?.completeWithError("Could not read file")
                    }
                }
                return
            }
        }

        completeWithError("No FIT file found in shared items")
    }

    private func processFITFile(at url: URL) {
        print("📤 Share Extension: processFITFile at \(url)")

        // Verify it's a FIT file
        guard url.pathExtension.lowercased() == "fit" else {
            print("📤 Share Extension: Not a FIT file: \(url.pathExtension)")
            completeWithError("Not a FIT file (.\(url.pathExtension))")
            return
        }

        // Copy to shared App Group container so main app can access it
        guard let sharedContainerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.rick.Tailwind")?
            .appendingPathComponent("SharedFIT") else {
            print("📤 Share Extension: Could not access App Group container")
            completeWithError("Could not access shared container")
            return
        }

        print("📤 Share Extension: Shared container: \(sharedContainerURL)")

        do {
            // Create directory if needed
            try FileManager.default.createDirectory(at: sharedContainerURL, withIntermediateDirectories: true)

            // Generate unique filename with timestamp
            let timestamp = Date().timeIntervalSince1970
            let destinationURL = sharedContainerURL.appendingPathComponent("ride_\(Int(timestamp)).fit")

            // Copy file to shared container
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("📤 Share Extension: Copied file to \(destinationURL)")

            // Save pending import info for main app to pick up
            savePendingImport(fileURL: destinationURL)

            // Open main app to complete import
            openMainApp(with: destinationURL)

        } catch {
            print("📤 Share Extension: Error: \(error)")
            completeWithError("Failed to save file: \(error.localizedDescription)")
        }
    }

    private func processFITData(_ data: Data) {
        // Save raw data to shared container
        guard let sharedContainerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.rick.Tailwind")?
            .appendingPathComponent("SharedFIT") else {
            completeWithError("Could not access shared container")
            return
        }

        do {
            try FileManager.default.createDirectory(at: sharedContainerURL, withIntermediateDirectories: true)

            let timestamp = Date().timeIntervalSince1970
            let destinationURL = sharedContainerURL.appendingPathComponent("ride_\(Int(timestamp)).fit")

            try data.write(to: destinationURL)

            savePendingImport(fileURL: destinationURL)
            openMainApp(with: destinationURL)

        } catch {
            completeWithError("Failed to save file: \(error.localizedDescription)")
        }
    }

    private func savePendingImport(fileURL: URL) {
        print("📤 Share Extension: savePendingImport: \(fileURL.path)")
        // Store in UserDefaults for app group so main app knows there's a pending import
        if let defaults = UserDefaults(suiteName: "group.com.rick.Tailwind") {
            var pending = defaults.stringArray(forKey: "pendingFITImports") ?? []
            pending.append(fileURL.path)
            defaults.set(pending, forKey: "pendingFITImports")
            defaults.synchronize()
            print("📤 Share Extension: Saved to pending imports, count: \(pending.count)")
        } else {
            print("📤 Share Extension: ERROR - Could not access App Group UserDefaults")
        }
    }

    private func openMainApp(with fileURL: URL) {
        print("📤 Share Extension: openMainApp")
        // Create a URL scheme to open the main app with the file path
        let encodedPath = fileURL.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "tailwind://import?file=\(encodedPath)"
        print("📤 Share Extension: URL string: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("📤 Share Extension: Could not create URL, completing anyway")
            completeSuccessfully()
            return
        }

        // Open the main app via URL scheme
        // Note: Share extensions can't directly call UIApplication.shared.open()
        // So we use the responder chain trick
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                print("📤 Share Extension: Found UIApplication, opening URL")
                application.open(url, options: [:]) { [weak self] success in
                    print("📤 Share Extension: URL open result: \(success)")
                    self?.completeSuccessfully()
                }
                return
            }
            responder = responder?.next
        }

        print("📤 Share Extension: Could not find UIApplication in responder chain")
        // If we can't open the app directly, just complete - the app will pick up
        // the pending import on next launch
        completeSuccessfully()
    }

    private func completeSuccessfully() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func completeWithError(_ message: String) {
        DispatchQueue.main.async {
            let error = NSError(domain: "TailwindShare", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            self.extensionContext?.cancelRequest(withError: error)
        }
    }
}
