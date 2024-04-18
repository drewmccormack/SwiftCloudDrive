import XCTest
@testable import SwiftCloudDrive

final class CloudDriveTests: XCTestCase {
    
    var drive: CloudDrive!
    let dir1: RootRelativePath = .init(path: "Hi/There")
    
    override func setUp() async throws {
        let tempDirPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
        let url = URL(fileURLWithPath: tempDirPath, isDirectory: true)
        drive = try await CloudDrive(storage: .localDirectory(rootURL: url))
        try await super.setUp()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        try FileManager.default.removeItem(at: drive.rootDirectory)
    }
    
    func testDirectoryCreateAndRemove() async throws {
        var exists = try await drive.directoryExists(at: dir1)
        XCTAssertFalse(exists)
        
        try await drive.createDirectory(at: dir1)
        exists = try await drive.directoryExists(at: dir1)
        XCTAssertTrue(exists)
        
        do {
            try await drive.removeFile(at: dir1) // Should fail
            XCTFail()
        } catch {
            XCTAssertTrue(true)
        }
        
        try await drive.removeDirectory(at: dir1)
    }
    
    func testFileReadWriteFile() async throws {
        let data = "Hi".data(using: .utf8)!
        try await drive.writeFile(with: data, at: .root.appending("Direct"))
        let readData = try await drive.readFile(at: .root.appending("Direct"))
        XCTAssertEqual(data, readData)
        try await drive.removeFile(at: .root.appending("Direct"))
    }
    
    func testUploadAndDownload() async throws {
        let data = "Hi".data(using: .utf8)!
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("CloudTempFile")
        try data.write(to: tempFile)
        
        try await drive.upload(from: tempFile, to: .root.appending("CloudTempFile"))
        
        let tempFileDown = FileManager.default.temporaryDirectory.appendingPathComponent("tempdown")
        try? FileManager.default.removeItem(at: tempFileDown)
        try await drive.download(from: .root.appending("CloudTempFile"), toURL: tempFileDown)
        
        let loadData = try Data(contentsOf: tempFileDown)
        XCTAssertEqual(loadData, data)
    }
    
}
