import Foundation
import os

public protocol CloudDriveObserver {
    /// Called when the status of files changes in the drive
    func cloudDriveDidChange(_ cloudDrive: CloudDrive, rootRelativePaths: [RootRelativePath])
}

/// Easy to use Swift wrapper around iCloud Drive.
/// This class is greedy when it comes to data downloads, ie, it will
/// download any file it observes in iCloud that is descended from its
/// root directory. If you need partial downloading of files, this is not
/// a good solution, unless you can partition the data between root
/// directories, and setup an ensemble of CloudDrive objects to manage
/// the contents.
public class CloudDrive {
    
    /// Types of storage available
    public enum Storage {
        case iCloudContainer(containerIdentifier: String?)
        case localDirectory(rootURL: URL)
    }
    
    /// The type of storage used (eg iCloud, local)
    public let storage: Storage
        
    /// Pass in nil to get the default container. Eg. "iCloud.my.company.app"
    public var ubiquityContainerIdentifier: String? {
        if case let .iCloudContainer(id) = storage {
            return id
        } else {
            return nil
        }
    }
    
    /// The path of the directory for this drive, relative to the root of the iCloud container
    @available(*, deprecated, renamed: "relativePathToRoot")
    public var relativePathToRootInContainer: String {
        relativePathToRoot
    }
    
    /// The path of the directory for this drive, relative to the root of the drive
    public let relativePathToRoot: String
    
    /// Set this to receive notification of changes in the cloud drive
    public var observer: CloudDriveObserver?
    
    /// If the user is signed in to iCloud, this should be true. Otherwise false.
    /// When iCloud is not used, it is always true
    public var isConnected: Bool {
        switch storage {
        case .iCloudContainer:
            return fileManager.ubiquityIdentityToken != nil
        case .localDirectory:
            return true
        }
    }

    private let fileManager = FileManager()
    private let metadataMonitor: MetadataMonitor?
    public let rootDirectory: URL
    
    
    // MARK: Init
    
    /// Pass in the type of storage (eg iCloud container), and an optional path relative to the root directory where
    /// the drive will be anchored.
    public init(storage: Storage, relativePathToRoot: String = "") async throws {
        self.storage = storage
        self.relativePathToRoot = relativePathToRoot
        
        switch storage {
        case let .iCloudContainer(containerIdentifier):
            guard fileManager.ubiquityIdentityToken != nil else { throw Error.notSignedIntoCloud }
            guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else {
                throw Error.couldNotAccessUbiquityContainer
            }
            self.rootDirectory = containerURL.appendingPathComponent(relativePathToRoot, isDirectory: true)
            
            self.metadataMonitor = MetadataMonitor(rootDirectory: containerURL)
            self.metadataMonitor!.changeHandler = { [weak self] changedPaths in
                guard let self = self else { return }
                self.observer?.cloudDriveDidChange(self, rootRelativePaths: changedPaths)
            }
        case let .localDirectory(rootURL):
            try fileManager.createDirectory(atPath: rootURL.path, withIntermediateDirectories: true)
            self.rootDirectory = URL(fileURLWithPath: relativePathToRoot, isDirectory: true, relativeTo: rootURL)
            metadataMonitor = nil
        }
        
        try await performInitialSetup()
    }
    
    /// Pass in the container id, but also an optional root direcotry. All relative paths will then be relative to this root.
    public convenience init(ubiquityContainerIdentifier: String? = nil, relativePathToRootInContainer: String = "") async throws {
        try await self.init(storage: .iCloudContainer(containerIdentifier: ubiquityContainerIdentifier), relativePathToRoot: relativePathToRootInContainer)
    }
    
    
    // MARK: Setup

    private func performInitialSetup() async throws {
        try await setupRootDirectory()
        metadataMonitor?.startMonitoringMetadata()
    }
    
    private func setupRootDirectory() async throws {
        let (exists, isDirectory) = try await fileManager.fileExists(coordinatingAccessAt: rootDirectory)
        if exists {
            guard isDirectory else { throw Error.rootDirectoryURLIsNotDirectory }
        } else {
            try await fileManager.createDirectory(coordinatingAccessAt: rootDirectory, withIntermediateDirectories: true)
        }
    }
    
    
    // MARK: File Operations
    
    /// Returns whether the file exists. If it is a directory, returns false
    public func fileExists(at path: RootRelativePath) async throws -> Bool {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let fileURL = try path.fileURL(forRoot: rootDirectory)
        let result = try await fileManager.fileExists(coordinatingAccessAt: fileURL)
        return result.exists && !result.isDirectory
    }
    
    /// Returns whether the directory exists
    public func directoryExists(at path: RootRelativePath) async throws -> Bool {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let dirURL = try path.directoryURL(forRoot: rootDirectory)
        let result = try await fileManager.fileExists(coordinatingAccessAt: dirURL)
        return result.exists && result.isDirectory
    }
    
    /// Creates a directory in the cloud. Always creates intermediate directories if needed.
    public func createDirectory(at path: RootRelativePath) async throws {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let dirURL = try path.directoryURL(forRoot: rootDirectory)
        return try await fileManager.createDirectory(coordinatingAccessAt: dirURL, withIntermediateDirectories: true)
    }
    
    /// Returns the contents of a directory. It doesn't recurse into subdirectories
    public func contentsOfDirectory(at path: RootRelativePath, includingPropertiesForKeys keys: [URLResourceKey]? = nil, options mask: FileManager.DirectoryEnumerationOptions = []) async throws -> [URL] {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let dirURL = try path.directoryURL(forRoot: rootDirectory)
        return try await fileManager.contentsOfDirectory(coordinatingAccessAt: dirURL, includingPropertiesForKeys: keys, options: mask)
    }
    
    /// Removes a directory at the path passed
    public func removeDirectory(at path: RootRelativePath) async throws {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let dirURL = try path.directoryURL(forRoot: rootDirectory)
        let result = try await fileManager.fileExists(coordinatingAccessAt: dirURL)
        guard result.exists, result.isDirectory else { throw Error.invalidFileType }
        return try await fileManager.removeItem(coordinatingAccessAt: dirURL)
    }
    
    /// Removes a file at the path passed. If there is no file, or there is a directory, it gives an error
    public func removeFile(at path: RootRelativePath) async throws {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let fileURL = try path.fileURL(forRoot: rootDirectory)
        let result = try await fileManager.fileExists(coordinatingAccessAt: fileURL)
        guard result.exists, !result.isDirectory else { throw Error.invalidFileType }
        return try await fileManager.removeItem(coordinatingAccessAt: fileURL)
    }
    
    /// Copies a file from outside the container, into the container. If there is a file already at the destination
    /// it will give an error and fail.
    public func upload(from fromURL: URL, to path: RootRelativePath) async throws {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let toURL = try path.fileURL(forRoot: rootDirectory)
        try await fileManager.copyItem(coordinatingAccessFrom: fromURL, to: toURL)
    }
    
    /// Attempts to copy a file inside the container out to a file URL not in the cloud.
    public func download(from path: RootRelativePath, toURL: URL) async throws {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let fromURL = try path.fileURL(forRoot: rootDirectory)
        try await fileManager.copyItem(coordinatingAccessFrom: fromURL, to: toURL)
    }

    /// Copies within the container.
    public func copy(from source: RootRelativePath, to destination: RootRelativePath) async throws {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let sourceURL = try source.fileURL(forRoot: rootDirectory)
        let destinationURL = try destination.fileURL(forRoot: rootDirectory)
        try await fileManager.copyItem(coordinatingAccessFrom: sourceURL, to: destinationURL)
    }
    
    /// Reads the contents of a file in the cloud, returning it as data.
    public func readFile(at path: RootRelativePath) async throws -> Data {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let fileURL = try path.fileURL(forRoot: rootDirectory)
        return try await fileManager.contentsOfFile(coordinatingAccessAt: fileURL)
    }
    
    /// Writes the contents of a file. If the file doesn't exist, it will be created. If it already exists,
    /// it will be overwritten.
    public func writeFile(with data: Data, at path: RootRelativePath) async throws {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let fileURL = try path.fileURL(forRoot: rootDirectory)
        return try await fileManager.write(data, coordinatingAccessTo: fileURL)
    }

    /// Make any change to the file contents desired for the path given. Can be used for in-place updates.
    public func updateFile(at path: RootRelativePath, in block: (URL) throws -> Void) async throws {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let fileURL = try path.fileURL(forRoot: rootDirectory)
        try await fileManager.updateFile(coordinatingAccessTo: fileURL) { url in
            try block(url)
        }
    }

    /// As updateFile, but coordinated for reading.
    public func readFile(at path: RootRelativePath, in block: (URL) throws -> Void) async throws {
        guard isConnected else { throw Error.queriedWhileNotConnected }
        let fileURL = try path.fileURL(forRoot: rootDirectory)
        try await fileManager.readFile(coordinatingAccessTo: fileURL) { url in
            try block(url)
        }
    }
}
