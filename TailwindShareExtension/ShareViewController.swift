import UIKit
import Social
import UniformTypeIdentifiers

/// Share Extension for receiving FIT files from other apps (like Magene)
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Process the shared FIT file
        handleSharedFile()
    }

    private func handleSharedFile() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            completeWithError("No file found")
            return
        }

        // Look for FIT file or general file data
        for attachment in attachments {
            // Check for FIT file type
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

            // Also check for file URL type
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
        }

        completeWithError("No FIT file found in shared items")
    }

    private func processFITFile(at url: URL) {
        // Verify it's a FIT file
        guard url.pathExtension.lowercased() == "fit" else {
            completeWithError("Not a FIT file")
            return
        }

        // Copy to shared App Group container so main app can access it
        let sharedContainerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.tailwind.app")?
            .appendingPathComponent("SharedFIT")

        do {
            // Create directory if needed
            if let containerURL = sharedContainerURL {
                try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

                // Generate unique filename
                let timestamp = Date().timeIntervalSince1970
                let destinationURL = containerURL.appendingPathComponent("ride_\(Int(timestamp)).fit")

                // Copy file
                try FileManager.default.copyItem(at: url, to: destinationURL)

                // Save pending import info
                savePendingImport(fileURL: destinationURL)

                // Open main app to complete import
                openMainApp(with: destinationURL)
            }
        } catch {
            completeWithError("Failed to save file: \(error.localizedDescription)")
        }
    }

    private func processFITData(_ data: Data) {
        // Save data to shared container
        let sharedContainerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.tailwind.app")?
            .appendingPathComponent("SharedFIT")

        do {
            if let containerURL = sharedContainerURL {
                try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

                let timestamp = Date().timeIntervalSince1970
                let destinationURL = containerURL.appendingPathComponent("ride_\(Int(timestamp)).fit")

                try data.write(to: destinationURL)

                savePendingImport(fileURL: destinationURL)
                openMainApp(with: destinationURL)
            }
        } catch {
            completeWithError("Failed to save file: \(error.localizedDescription)")
        }
    }

    private func savePendingImport(fileURL: URL) {
        // Store in UserDefaults for app group
        if let defaults = UserDefaults(suiteName: "group.com.tailwind.app") {
            var pending = defaults.stringArray(forKey: "pendingFITImports") ?? []
            pending.append(fileURL.path)
            defaults.set(pending, forKey: "pendingFITImports")
        }
    }

    private func openMainApp(with fileURL: URL) {
        // Create a URL scheme to open the main app
        // The main app will handle the import via onOpenURL
        let urlString = "tailwind://import?file=\(fileURL.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString) {
            // Use openURL to launch main app
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url, options: [:]) { [weak self] success in
                        if success {
                            self?.completeSuccessfully()
                        } else {
                            // Fallback: just complete and let user open app manually
                            self?.completeSuccessfully()
                        }
                    }
                    return
                }
                responder = responder?.next
            }
        }

        // Fallback
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
