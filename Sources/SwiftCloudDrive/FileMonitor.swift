//
//  File.swift
//  
//
//  Created by Drew McCormack on 17/04/2024.
//

import Foundation
import os

/// Monitors changes to files using file presenter. Used to notifiy of changes
/// from remote devices.
class FileMonitor: NSObject, NSFilePresenter {
    let rootDirectory: URL
    var presentedItemURL: URL? { rootDirectory }

    /// Called when any file changes, is added, or removed
    var changeHandler: (([RootRelativePath])->Void)? {
        didSet {
            if oldValue == nil {
                NSFileCoordinator.addFilePresenter(self)
            }
        }
    }
    
    var conflictHandler: ((RootRelativePath)->Void)?

    lazy var presentedItemOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }
    
    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }
    
    func presentedSubitemDidAppear(at url: URL) {
        informOfChange(at: url)
    }
    
    func presentedSubitemDidChange(at url: URL) {
        informOfChange(at: url)
    }

    /// Should not really be needed, but there is some suggestion that deletions
    /// may be the same as moving to the trash, so we treat this as a deletion.
    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
        informOfChange(at: oldURL)
    }
    
    func presentedItemDidGain(_ version: NSFileVersion) {
        do {
            if version.isConflict {
                try resolveConflicts(for: version.url)
            }
            informOfChange(at: version.url)
        } catch {
            os_log("Failed to handle cloud metadata")
        }
    }
    
    private func relativePath(for url: URL) -> RootRelativePath {
        let rootLength = rootDirectory.standardized.path.count
        let path = String(url.standardized.path.dropFirst(rootLength))
        let rootRelativePath = RootRelativePath(path: path)
        return rootRelativePath
    }
    
    private func informOfChange(at url: URL) {
        let rootRelativePath = relativePath(for: url)
        changeHandler?([rootRelativePath])
    }
    
    private func resolveConflicts(for url: URL) throws {
        // Check if caller wants to handle conflicts
        if let conflictHandler {
            let rootRelativePath = relativePath(for: url)
            conflictHandler(rootRelativePath)
            return
        }
        
        let coordinator = NSFileCoordinator(filePresenter: self)
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

