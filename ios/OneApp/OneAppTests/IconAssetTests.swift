import XCTest
@testable import OneClient

@MainActor
final class IconAssetTests: XCTestCase {
    func testEveryScopedOneIconKeyHasBundledAsset() {
        for key in OneIconAssetCatalog.scopedKeys {
            XCTAssertNotNil(
                OnePlatformImageLoader.image(for: key),
                "Missing bundled asset for \(key.rawValue)"
            )
        }
    }

    func testEveryUIOnlyIconKeyHasBundledAsset() {
        for key in OneIconAssetCatalog.uiKeys {
            XCTAssertNotNil(
                OnePlatformImageLoader.image(for: key),
                "Missing bundled UI asset for \(key.rawValue)"
            )
        }
    }

    func testPrimaryNavigationAndBrandAssetsLoad() {
        let keys: [OneIconKey] = [.brandMark, .today, .review, .finance, .settings]

        for key in keys {
            XCTAssertNotNil(
                OnePlatformImageLoader.image(for: key),
                "Expected primary UI asset for \(key.rawValue)"
            )
        }
    }

    func testOneClientSourceDoesNotUseSFSymbolShortcuts() throws {
        let sourceRoot = repoRoot()
            .appendingPathComponent("ios/OneClient/Sources/OneClient", isDirectory: true)
        let pattern = try NSRegularExpression(pattern: #"Image\s*\(\s*systemName:|Label\s*\([^)]*systemImage:"#)
        let fileManager = FileManager.default
        let files = fileManager.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        for file in files {
            let text = try String(contentsOf: file)
            let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = pattern.matches(in: text, range: fullRange)
            XCTAssertTrue(matches.isEmpty, "Found forbidden SF Symbol shortcut in \(file.path)")
        }
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
