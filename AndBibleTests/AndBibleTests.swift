import XCTest
import BibleCore
@testable import BibleUI

final class AndBibleTests: XCTestCase {
    func testAppPreferenceRegistryHasDefinitionForAllKeys() {
        let keys = AppPreferenceKey.allCases
        XCTAssertEqual(keys.count, 35)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(AppPreferenceRegistry.definitions.count, keys.count)

        for key in keys {
            XCTAssertEqual(AppPreferenceRegistry.definition(for: key).key, key)
        }
    }

    func testCriticalPreferenceDefaultsMatchParityContract() {
        XCTAssertEqual(AppPreferenceRegistry.stringDefault(for: .nightModePref3), "system")
        XCTAssertEqual(AppPreferenceRegistry.stringDefault(for: .toolbarButtonActions), "default")
        XCTAssertEqual(AppPreferenceRegistry.stringDefault(for: .bibleViewSwipeMode), "CHAPTER")
        XCTAssertEqual(AppPreferenceRegistry.intDefault(for: .fontSizeMultiplier), 100)
        XCTAssertEqual(AppPreferenceRegistry.boolDefault(for: .openLinksInSpecialWindowPref), true)
        XCTAssertEqual(AppPreferenceRegistry.boolDefault(for: .enableBluetoothPref), true)
    }

    func testActionPreferencesUseActionShape() {
        let actionKeys: [AppPreferenceKey] = [
            .discreteHelp,
            .openLinks,
            .crashApp,
        ]

        for key in actionKeys {
            let definition = AppPreferenceRegistry.definition(for: key)
            if case .action = definition.storage {
                // expected
            } else {
                XCTFail("Expected .action storage for \(key.rawValue)")
            }
            if case .action = definition.valueType {
                // expected
            } else {
                XCTFail("Expected .action valueType for \(key.rawValue)")
            }
            XCTAssertNil(definition.defaultValue)
        }
    }

    func testCSVSetEncodingAndDecodingRoundTrip() {
        let encoded = AppPreferenceRegistry.encodeCSVSet(["  KJV  ", "", "ESV", "KJV", "  "])
        XCTAssertEqual(encoded, "ESV,KJV,KJV")
        XCTAssertEqual(AppPreferenceRegistry.decodeCSVSet(encoded), ["ESV", "KJV", "KJV"])
        XCTAssertEqual(AppPreferenceRegistry.decodeCSVSet(nil), [])
        XCTAssertEqual(AppPreferenceRegistry.decodeCSVSet(""), [])
    }

    func testStrongsQueryNormalizationHandlesLeadingZeroes() {
        let options = StrongsSearchSupport.normalizedQueryOptions(for: "H02022")
        XCTAssertEqual(
            options?.entryAttributeQueries,
            ["Word//Lemma./H02022", "Word//Lemma./H2022"]
        )
    }

    func testStrongsQueryNormalizationAcceptsDecoratedInput() {
        let options = StrongsSearchSupport.normalizedQueryOptions(for: "lemma:strong:g00123")
        XCTAssertEqual(
            options?.entryAttributeQueries,
            ["Word//Lemma./G00123", "Word//Lemma./G123"]
        )
    }

    func testParseVerseKeySupportsHumanReadableFormat() {
        let parsed = StrongsSearchSupport.parseVerseKey("I Samuel 2:3")
        XCTAssertEqual(parsed?.book, "I Samuel")
        XCTAssertEqual(parsed?.chapter, 2)
        XCTAssertEqual(parsed?.verse, 3)
    }

    func testParseVerseKeySupportsOsisFormat() {
        let parsed = StrongsSearchSupport.parseVerseKey("Gen.1.1")
        XCTAssertEqual(parsed?.book, "Genesis")
        XCTAssertEqual(parsed?.chapter, 1)
        XCTAssertEqual(parsed?.verse, 1)
    }

    func testParseVerseKeySupportsOsisFormatWithSuffix() {
        let parsed = StrongsSearchSupport.parseVerseKey("Gen.1.1!crossReference.a")
        XCTAssertEqual(parsed?.book, "Genesis")
        XCTAssertEqual(parsed?.chapter, 1)
        XCTAssertEqual(parsed?.verse, 1)
    }
}
