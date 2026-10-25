import Foundation
import XCTest
@testable import SwiftSoup

// A selector group whose branches lead with `*:not(:has(...))` ran Has over every element's subtree
// (O(n^2)) because the group bypassed indexed seeding; a downstream app's 10,000-span input took 80 s
// in a debug build. The group is now collected branch by branch. // wangqi modified 2026-10-25
final class SelectorGroupDeepNestingTest: XCTestCase {
    private let noiseGroup = """
      *:not(:has(h1,h2,h3))[class~=(?i)(nav|footer)],
      *:not(:has(h1,h2,h3))[id~=(?i)(nav|footer)]
      """

    func testGroupWithHasBranchesIsNotQuadraticOnDeepTree() throws {
        let depth = 5_000
        let html = "<html><body>" + String(repeating: "<span>", count: depth) + "X"
            + String(repeating: "</span>", count: depth) + "<p class=nav>N</p></body></html>"
        let doc = try SwiftSoup.parse(html)
        let started = Date()
        let found = try doc.select(noiseGroup)
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertEqual(found.size(), 1)
        XCTAssertEqual(found.first()?.tagName(), "p")
        // Before the fix this took about 20 s in a debug build; now it is milliseconds.
        XCTAssertLessThan(elapsed, 2, "selector group took \(elapsed)s on a \(depth)-deep tree")
    }

    func testGroupUnionKeepsDocumentOrderWithoutDuplicates() throws {
        let html = """
            <div id=nav class=footer><h2>keep</h2><span class=nav>a</span></div>
            <section id=footer><b class="nav footer">b</b></section>
            <p class=x>c</p><i id=nav2 class=nav>d</i>
            """
        let doc = try SwiftSoup.parse(html)
        let evaluator = try QueryParser.parse(noiseGroup)
        let root = try XCTUnwrap(doc.body())
        // Reference: the per-element Or.matches walk the group used before.
        var expected: [Element] = []
        for el in try root.getAllElements().array() where try evaluator.matches(root, el) {
            expected.append(el)
        }
        let actual = try root.select(noiseGroup).array()
        XCTAssertEqual(actual.map { ObjectIdentifier($0) }, expected.map { ObjectIdentifier($0) })
        XCTAssertEqual(actual.map { $0.tagName() }, ["span", "section", "b", "i"])
    }
}
