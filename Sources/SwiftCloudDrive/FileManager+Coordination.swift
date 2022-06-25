//
//  FileManager+Coordination.swift
//  
//
//  Created by Drew McCormack on 08/06/2022.
//

import Foundation

/// Wrapper for FileManager that offers async mehods
/// These methods handle file coordination, which is quite useful
public extension FileManager {
            
    func fileExists(coordinatingAccessAt fileURL: URL) async throws -> (exists: Bool, isDirectory: Bool) {
        var isDir: ObjCBool = false
        var exists: Bool = false
        try coordinate(readingItemAt: fileURL) { url in
            exists = fileExists(atPath: url.path, isDirectory: &isDir)
        }
        return (exists, isDir.boolValue)
    }
    
    func createDirectory(coordinatingAccessAt dirURL: URL, withIntermediateDirectories: Bool) async throws {
        try coordinate(writingItemAt: dirURL, options: .forMerging) { url in
            try createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
        }
    }
    
    func removeItem(coordinatingAccessAt dirURL: URL) async throws {
        try coordinate(writingItemAt: dirURL, options: .forDeleting) { url in
            try removeItem(at: url)
        }
    }
    
    func copyItem(coordinatingAccessFrom fromURL: URL, to toURL: URL) async throws {
        try coordinate(readingItemAt: fromURL, readOptions: [], writingItemAt: toURL, writeOptions: .forReplacing) { readURL, writeURL in
            try copyItem(at: readURL, to: writeURL)
        }
    }
    
    func contentsOfDirectory(coordinatingAccessAt dirURL: URL) async throws -> [URL] {
        var contentsURLs: [URL] = []
        try coordinate(readingItemAt: dirURL) { url in
            contentsURLs = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        }
        return contentsURLs
    }
    
    func contentsOfFile(coordinatingAccessAt url: URL) async throws -> Data {
        var data: Data = .init()
        try coordinate(readingItemAt: url) { url in
            data = try Data(contentsOf: url)
        }
        return data
    }
    
    func write(_ data: Data, coordinatingAccessTo url: URL) async throws {
        try coordinate(writingItemAt: url) { url in
            try data.write(to: url)
        }
    }
    
    func updateFile(coordinatingAccessTo url: URL, in block: (URL) throws -> Void) async throws {
        try coordinate(writingItemAt: url) { url in
            try block(url)
        }
    }
    
    private func coordinate(readingItemAt url: URL, options: NSFileCoordinator.ReadingOptions = [], with block: (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var managerError: Swift.Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, options: options, error: &coordinatorError) { url in
            do {
                try block(url)
            } catch {
                managerError = error
            }
        }
        guard coordinatorError == nil else { throw coordinatorError! }
        guard managerError == nil else { throw managerError! }
    }
    
    private func coordinate(writingItemAt url: URL, options: NSFileCoordinator.WritingOptions = [], with block: (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var managerError: Swift.Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinatorError) { url in
            do {
                try block(url)
            } catch {
                managerError = error
            }
        }
        guard coordinatorError == nil else { throw coordinatorError! }
        guard managerError == nil else { throw managerError! }
    }
    
    private func coordinate(readingItemAt readURL: URL, readOptions: NSFileCoordinator.ReadingOptions = [], writingItemAt writeURL: URL, writeOptions: NSFileCoordinator.WritingOptions = [], with block: (_ readURL: URL, _ writeURL: URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var managerError: Swift.Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: readURL, options: readOptions, writingItemAt: writeURL, options: writeOptions, error: &coordinatorError) { (read: URL, write: URL) in
            do {
                try block(read, write)
            } catch {
                managerError = error
            }
        }
        guard coordinatorError == nil else { throw coordinatorError! }
        guard managerError == nil else { throw managerError! }
    }
}
