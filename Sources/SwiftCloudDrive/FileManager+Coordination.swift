//
//  FileManager+Coordination.swift
//  
//
//  Created by Drew McCormack on 08/06/2022.
//

import Foundation

/// Wrapper for FileManager with coordinated file access
public extension FileManager {
            
    func fileExists(coordinatingAccessAt fileURL: URL, presenter: NSFilePresenter? = nil) throws -> (exists: Bool, isDirectory: Bool) {
        var isDir: ObjCBool = false
        var exists: Bool = false
        try coordinate(readingItemAt: fileURL) { url in
            exists = fileExists(atPath: url.path, isDirectory: &isDir)
        }
        return (exists, isDir.boolValue)
    }
    
    func createDirectory(coordinatingAccessAt dirURL: URL, withIntermediateDirectories: Bool, presenter: NSFilePresenter? = nil) throws {
        try coordinate(writingItemAt: dirURL, options: .forMerging, presenter: presenter) { url in
            try createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
        }
    }
    
    func removeItem(coordinatingAccessAt dirURL: URL, presenter: NSFilePresenter? = nil) throws {
        try coordinate(writingItemAt: dirURL, options: .forDeleting, presenter: presenter) { url in
            try removeItem(at: url)
        }
    }
    
    func copyItem(coordinatingAccessFrom fromURL: URL, to toURL: URL, presenter: NSFilePresenter? = nil) throws {
        try coordinate(readingItemAt: fromURL, readOptions: [], writingItemAt: toURL, writeOptions: .forReplacing, presenter: presenter) { readURL, writeURL in
            try copyItem(at: readURL, to: writeURL)
        }
    }
    
    func contentsOfDirectory(coordinatingAccessAt dirURL: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions, presenter: NSFilePresenter? = nil) throws -> [URL] {
        var contentsURLs: [URL] = []
        try coordinate(readingItemAt: dirURL, presenter: presenter) { url in
            contentsURLs = try contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
        }
        return contentsURLs
    }
    
    func contentsOfFile(coordinatingAccessAt url: URL, presenter: NSFilePresenter? = nil) throws -> Data {
        var data: Data = .init()
        try coordinate(readingItemAt: url, presenter: presenter) { url in
            data = try Data(contentsOf: url)
        }
        return data
    }
    
    func write(_ data: Data, coordinatingAccessTo url: URL, presenter: NSFilePresenter? = nil) throws {
        try coordinate(writingItemAt: url, presenter: presenter) { url in
            try data.write(to: url)
        }
    }
    
    func updateFile(coordinatingAccessTo url: URL, presenter: NSFilePresenter? = nil, in block: (URL) throws -> Void) throws {
        try coordinate(writingItemAt: url, presenter: presenter) { url in
            try block(url)
        }
    }

    func readFile(coordinatingAccessTo url: URL, presenter: NSFilePresenter? = nil, in block: (URL) throws -> Void) throws {
        try coordinate(readingItemAt: url, presenter: presenter) { url in
            try block(url)
        }
    }
    
    private func execute(_ block: (URL) throws -> Void, onSecurityScopedResource url: URL) throws {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        try block(url)
    }
    
    private func coordinate(readingItemAt url: URL, options: NSFileCoordinator.ReadingOptions = [], presenter: NSFilePresenter? = nil, with block: (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var managerError: Swift.Error?
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        coordinator.coordinate(readingItemAt: url, options: options, error: &coordinatorError) { url in
            do {
                try execute(block, onSecurityScopedResource: url)
            } catch {
                managerError = error
            }
        }
        guard coordinatorError == nil else { throw coordinatorError! }
        guard managerError == nil else { throw managerError! }
    }
    
    private func coordinate(writingItemAt url: URL, options: NSFileCoordinator.WritingOptions = [], presenter: NSFilePresenter? = nil, with block: (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var managerError: Swift.Error?
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinatorError) { url in
            do {
                try execute(block, onSecurityScopedResource: url)
            } catch {
                managerError = error
            }
        }
        guard coordinatorError == nil else { throw coordinatorError! }
        guard managerError == nil else { throw managerError! }
    }
    
    private func coordinate(readingItemAt readURL: URL, readOptions: NSFileCoordinator.ReadingOptions = [], writingItemAt writeURL: URL, writeOptions: NSFileCoordinator.WritingOptions = [], presenter: NSFilePresenter? = nil, with block: (_ readURL: URL, _ writeURL: URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var managerError: Swift.Error?
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        coordinator.coordinate(readingItemAt: readURL, options: readOptions, writingItemAt: writeURL, options: writeOptions, error: &coordinatorError) { (read: URL, write: URL) in
            do {
                let shouldStopAccessingRead = read.startAccessingSecurityScopedResource()
                let shouldStopAccessingWrite = write.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessingRead {
                        read.stopAccessingSecurityScopedResource()
                    }
                    if shouldStopAccessingWrite {
                        write.stopAccessingSecurityScopedResource()
                    }
                }
                try block(read, write)
            } catch {
                managerError = error
            }
        }
        guard coordinatorError == nil else { throw coordinatorError! }
        guard managerError == nil else { throw managerError! }
    }
}
