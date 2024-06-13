import XCTest
@testable import SwiftCloudDrive

final class CloudDriveTests: XCTestCase {

    var drive: CloudDrive!
    let dir1: RootRelativePath = .init(path: "Hi/There")

    override func setUp() async throws {
        let tempDirPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
        let url = URL(fileURLWithPath: tempDirPath, isDirectory: true)
        drive = try CloudDrive(storage: .localDirectory(rootURL: url))
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        try FileManager.default.removeItem(at: drive.rootDirectory)
    }

    func testDirectoryCreateAndRemove() throws {
        var exists = try drive.directoryExists(at: dir1)
        XCTAssertFalse(exists)

        try drive.createDirectory(at: dir1)
        exists = try drive.directoryExists(at: dir1)
        XCTAssertTrue(exists)

        do {
            try drive.removeFile(at: dir1) // Should fail
            XCTFail()
        } catch {
            XCTAssertTrue(true)
        }

        try drive.removeDirectory(at: dir1)
    }

    func testFileReadWriteFile() throws {
        let data = "Hi".data(using: .utf8)!
        try drive.writeFile(with: data, at: .root.appending("Direct"))
        let readData = try drive.readFile(at: .root.appending("Direct"))
        XCTAssertEqual(data, readData)
        try drive.removeFile(at: .root.appending("Direct"))
    }

    func testUploadAndDownload() throws {
        let data = "Hi".data(using: .utf8)!
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("CloudTempFile")
        try data.write(to: tempFile)

        try drive.upload(from: tempFile, to: .root.appending("CloudTempFile"))

        let tempFileDown = FileManager.default.temporaryDirectory.appendingPathComponent("tempdown")
        try? FileManager.default.removeItem(at: tempFileDown)
        try drive.download(from: .root.appending("CloudTempFile"), toURL: tempFileDown)

        let loadData = try Data(contentsOf: tempFileDown)
        XCTAssertEqual(loadData, data)
    }

}
