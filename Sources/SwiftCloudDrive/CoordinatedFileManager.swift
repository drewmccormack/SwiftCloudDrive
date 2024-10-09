//
//  FileManager+Coordination.swift
//  
//
//  Created by Drew McCormack on 08/06/2022.
//

import Foundation

/// Wrapper for FileManager that offers async methods
/// These methods handle file coordination, which is quite useful
/// An actor will block during file coordination, which means that
/// there is no parallelism in this type. If you want to get parallelism (eg multiple threads)
/// you should make one of these managers for each file operation.
public actor CoordinatedFileManager {
    
    private(set) var presenter: (any NSFilePresenter)?
    
    private let fileManager = FileManager()
    
    public init(presenter: (any NSFilePresenter)? = nil) {
        self.presenter = presenter
    }
    
    public func fileExists(coordinatingAccessAt fileURL: URL) async throws -> (exists: Bool, isDirectory: Bool) {
        return try await coordinate(readingItemAt: fileURL, options: []) { [self] url -> (Bool, Bool) in
            var isDir: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
            return (exists, isDir.boolValue)
        }
    }
    
    public func createDirectory(coordinatingAccessAt dirURL: URL, withIntermediateDirectories: Bool) async throws {
        try await coordinate(writingItemAt: dirURL, options: .forMerging) { [self] url in
            try fileManager.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
        }
    }
    
    public func removeItem(coordinatingAccessAt dirURL: URL) async throws {
        try await coordinate(writingItemAt: dirURL, options: .forDeleting) { [self] url in
            try fileManager.removeItem(at: url)
        }
    }
    
    public func copyItem(coordinatingAccessFrom fromURL: URL, to toURL: URL) async throws {
        try await coordinate(readingItemAt: fromURL, readOptions: [], writingItemAt: toURL, writeOptions: .forReplacing) { readURL, writeURL in
            try fileManager.copyItem(at: readURL, to: writeURL)
        }
    }
    
    public func contentsOfDirectory(coordinatingAccessAt dirURL: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) async throws -> [URL] {
        return try await coordinate(readingItemAt: dirURL, options: []) { [self] url -> [URL] in
            return try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
        }
    }
    
    public func contentsOfFile(coordinatingAccessAt url: URL) async throws -> Data {
        return try await coordinate(readingItemAt: url, options: []) { url -> Data in
            return try Data(contentsOf: url)
        }
    }
    
    public func write(_ data: Data, coordinatingAccessTo url: URL) async throws {
        try await coordinate(writingItemAt: url, options: []) { url in
            try data.write(to: url)
        }
    }
    
    public func updateFile(coordinatingAccessTo url: URL, in block: @Sendable @escaping (URL) throws -> Void) async throws {
        try await coordinate(writingItemAt: url, options: []) { url in
            try block(url)
        }
    }
    
    public func readFile(coordinatingAccessTo url: URL, in block: @Sendable @escaping (URL) throws -> Void) async throws {
        try await coordinate(readingItemAt: url, options: []) { url in
            try block(url)
        }
    }
    
    private func coordinate<T>(readingItemAt url: URL, options: NSFileCoordinator.ReadingOptions = [], with block: @escaping (URL) throws -> T) async throws -> T {
        var coordinatorError: NSError?
        let result: T = try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator(filePresenter: presenter)
            coordinator.coordinate(readingItemAt: url, options: options, error: &coordinatorError) { url in
                do {
                    let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if shouldStopAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    let res = try block(url)
                    continuation.resume(returning: res)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let coordinatorError = coordinatorError {
                continuation.resume(throwing: coordinatorError)
            }
        }
        return result
    }
    
    private func coordinate<T>(writingItemAt url: URL, options: NSFileCoordinator.WritingOptions = [], with block: @escaping (URL) throws -> T) async throws -> T {
        var coordinatorError: NSError?
        let result: T = try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator(filePresenter: presenter)
            coordinator.coordinate(writingItemAt: url, options: options, error: &coordinatorError) { url in
                do {
                    let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if shouldStopAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    let res = try block(url)
                    continuation.resume(returning: res)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let coordinatorError = coordinatorError {
                continuation.resume(throwing: coordinatorError)
            }
        }
        return result
    }
    
    private func coordinate<T>(readingItemAt readURL: URL, readOptions: NSFileCoordinator.ReadingOptions = [], writingItemAt writeURL: URL, writeOptions: NSFileCoordinator.WritingOptions = [], with block: (_ readURL: URL, _ writeURL: URL) throws -> T) async throws -> T {
        var coordinatorError: NSError?
        let result: T = try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator(filePresenter: presenter)
            coordinator.coordinate(readingItemAt: readURL, options: readOptions, writingItemAt: writeURL, options: writeOptions, error: &coordinatorError) { (read: URL, write: URL) in
                do {
                    let res = try block(read, write)
                    continuation.resume(returning: res)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let coordinatorError = coordinatorError {
                continuation.resume(throwing: coordinatorError)
            }
        }
        return result
    }
}

