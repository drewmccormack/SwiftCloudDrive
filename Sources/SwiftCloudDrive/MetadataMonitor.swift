//
//  MetadataMonitor.swift
//  
//
//  Created by Drew McCormack on 10/06/2022.
//

import Foundation
import os

/// Monitors changes to the metadata, to trigger downloads of new files or updates.
class MetadataMonitor {
    
    let rootDirectory: URL
    let fileManager: FileManager = .init()
    
    var changeHandler: (([RootRelativePath])->Void)?
    
    private var metadataQuery: NSMetadataQuery?
    
    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoringMetadata() {
        let predicate: NSPredicate
        #if os(iOS)
            predicate = NSPredicate(format: "%K = FALSE AND %K = FALSE AND %K BEGINSWITH %@", NSMetadataUbiquitousItemIsDownloadedKey, NSMetadataUbiquitousItemIsDownloadingKey, NSMetadataItemPathKey, rootDirectory.path)
        #else
            predicate = NSPredicate(format: "%K != %@ AND %K = FALSE AND %K BEGINSWITH %@", NSMetadataUbiquitousItemDownloadingStatusKey, NSMetadataUbiquitousItemDownloadingStatusCurrent, NSMetadataUbiquitousItemIsDownloadingKey, NSMetadataItemPathKey, rootDirectory.path)
        #endif
        
        metadataQuery = NSMetadataQuery()
        guard let metadataQuery else { fatalError() }
        
        metadataQuery.notificationBatchingInterval = 5.0
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        metadataQuery.predicate = predicate
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMetadataNotification(_:)), name: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMetadataNotification(_:)), name: .NSMetadataQueryDidUpdate, object: metadataQuery)

        metadataQuery.start()
    }
    
    func stopMonitoring() {
        guard let metadataQuery else { return }
        metadataQuery.disableUpdates()
        metadataQuery.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: metadataQuery)
        self.metadataQuery = nil
    }
    
    @objc private nonisolated func handleMetadataNotification(_ notif: Notification) {
        Task {
            await initiateDownloads()
        }
    }
    
    private func initiateDownloads() async {
        guard let metadataQuery else { return }
        
        metadataQuery.disableUpdates()
        
        guard let results = metadataQuery.results as? [NSMetadataItem] else { return }
        for item in results {
            do {
                try resolveConflicts(for: item)
                guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
                try fileManager.startDownloadingUbiquitousItem(at: url)
            } catch {
                os_log("Failed to handle cloud metadata")
            }
        }
        
        // Get the file URLs, to wait for them below.
        let urls = results.compactMap { item in
            item.value(forAttribute: NSMetadataItemURLKey) as? URL
        }
        
        metadataQuery.enableUpdates()
        
        // Query existence of each file. This uses the file coordinator, and will
        // wait until they are available
        for url in urls {
            _ = try? await fileManager.fileExists(coordinatingAccessAt: url)
        }
        
        // Inform observer
        if !urls.isEmpty {
            let rootLength = rootDirectory.standardized.path.count
            let relativePaths: [RootRelativePath] = urls.map { url in
                let path = String(url.standardized.path.dropFirst(rootLength))
                return RootRelativePath(path: path)
            }
            await MainActor.run {
                changeHandler?(relativePaths)
            }
        }
    }
    
    private func resolveConflicts(for item: NSMetadataItem) throws {
        guard
            let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
            let inConflict = item.value(forAttribute: NSMetadataUbiquitousItemHasUnresolvedConflictsKey) as? Bool else {
            throw Error.invalidMetadata
        }
        guard inConflict else { return }
        
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var versionError: Swift.Error?
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { newURL in
            do {
                try NSFileVersion.removeOtherVersionsOfItem(at: newURL)
            } catch {
                versionError = error
            }
        }
        
        guard versionError == nil else { throw versionError! }
        guard coordinatorError == nil else { throw Error.foundationError(coordinatorError!) }
        
        let conflictVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url)
        conflictVersions?.forEach { $0.isResolved = true }
    }
    
}
