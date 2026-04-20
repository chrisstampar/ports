import XCTest
@testable import PortsLib

final class ProjectResolverTests: XCTestCase {
    private let resolver = ProjectResolver()
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PortsTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - package.json

    func testPackageJSON() {
        let json = #"{"name": "my-cool-app", "version": "1.0.0"}"#
        try! json.write(to: tempDir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertEqual(name, "my-cool-app")
    }

    func testPackageJSONEmpty() {
        let json = #"{"version": "1.0.0"}"#
        try! json.write(to: tempDir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        // No "name" field; should fall back to directory name
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertNotNil(name)
    }

    // MARK: - Cargo.toml

    func testCargoToml() {
        let toml = """
        [package]
        name = "my-rust-app"
        version = "0.1.0"
        """
        try! toml.write(to: tempDir.appendingPathComponent("Cargo.toml"), atomically: true, encoding: .utf8)
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertEqual(name, "my-rust-app")
    }

    func testCargoTomlWithDependencies() {
        let toml = """
        [package]
        name = "server-app"
        version = "0.1.0"

        [dependencies]
        name = "should-not-match"
        """
        try! toml.write(to: tempDir.appendingPathComponent("Cargo.toml"), atomically: true, encoding: .utf8)
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertEqual(name, "server-app")
    }

    // MARK: - go.mod

    func testGoMod() {
        let mod = """
        module github.com/user/my-go-service

        go 1.21
        """
        try! mod.write(to: tempDir.appendingPathComponent("go.mod"), atomically: true, encoding: .utf8)
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertEqual(name, "my-go-service")
    }

    // MARK: - pyproject.toml

    func testPyproject() {
        let toml = """
        [project]
        name = "my-python-api"
        version = "1.0.0"
        """
        try! toml.write(to: tempDir.appendingPathComponent("pyproject.toml"), atomically: true, encoding: .utf8)
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertEqual(name, "my-python-api")
    }

    func testPyprojectPoetry() {
        let toml = """
        [tool.poetry]
        name = "poetry-app"
        version = "0.1.0"
        """
        try! toml.write(to: tempDir.appendingPathComponent("pyproject.toml"), atomically: true, encoding: .utf8)
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertEqual(name, "poetry-app")
    }

    // MARK: - .git fallback

    func testGitFallback() {
        let gitDir = tempDir.appendingPathComponent(".git")
        try! FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertEqual(name, tempDir.lastPathComponent)
    }

    // MARK: - Parent directory walk

    func testWalksParentDirectories() {
        let json = #"{"name": "parent-project"}"#
        try! json.write(to: tempDir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        let subDir = tempDir.appendingPathComponent("src/components")
        try! FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let name = resolver.findProjectName(startingAt: subDir.path)
        XCTAssertEqual(name, "parent-project")
    }

    // MARK: - Cache

    func testCacheInvalidation() {
        let pid: Int32 = 99999
        let json = #"{"name": "cached-app"}"#
        try! json.write(to: tempDir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        // Manually cache a value by resolving (we test via the public interface)
        resolver.invalidateCache(for: [pid])
        // After invalidation, re-resolve should work fresh
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertEqual(name, "cached-app")
    }

    // MARK: - No project markers

    func testFallsBackToDirectoryName() {
        // No manifest files, no .git
        let name = resolver.findProjectName(startingAt: tempDir.path)
        XCTAssertEqual(name, tempDir.lastPathComponent)
    }
}
