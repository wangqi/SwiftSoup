# SwiftSoup: What's New (2.11.3+fork 4987c59 → 2.14.3 e7f85f4)

**Merged:** 2026-10-25 · **Upstream:** scinfu/SwiftSoup master (296 commits, 197 non-merge, 2.11.3 → 2.14.3)
**Integration doc:** `UPGRADING.md` (fork changes), memory `project_swiftsoup_void_input_fork_fix` ·
**Consumers:** `libs/HTML2Markdown.swift`, `libs/readers/plugins/*` (10), `apps/email/pipeline/EmailMarkdownPlugin.swift`,
`libs/ocr/assemble/OCRHTMLTableConverter.swift`, `libs/VideoDownloader.swift`

296 upstream commits, mostly correctness and performance work on the byte-slice parser, selector engine and
source-backed serialization. Upstream now ships its own versions of four of our five code patches (deep-nesting
release / dirty walk / serialization, malformed attribute names, void `<input>`). The one silent ship-blocker:
upstream #388 (8fcecf0) also pushes an `InBody` `<form>` onto the stack of open elements, which would make the
app's `select("form").remove()` delete the whole body of WebForms, search and survey-email pages. The fork holds
that one call at its old value. No app source change is required to compile.

---

## 1. Changes
| Commit / PR | What changed | Reaches the app? |
|---|---|---|
| 8fcecf0 #388 | `<input>` void in InBody (absorbs our 24c10dd); `<form>` pushed on stack (held back, see §3) | yes, every HTML parse |
| 7c9a40b #396, 0187a0d #466 | iterative `Node.deinit` teardown and bounded serialization frames (absorbs our 4987c59 Node part) | yes, deep pages no longer overflow |
| d33de7b #392 | malformed / empty-after-trim attribute names dropped, not trapped (absorbs our 4987c59 Attributes part) | yes, crash class |
| 639d64f, 52e2d14 | duplicate attribute names on a start tag: first wins (spec), parse errors bounded | `attr()` reads on malformed HTML |
| e826a53 | inherited whitespace preserved; normalized text getters aligned | `text()` output, markdown goldens |
| 86f39b6, 784569a, 8a08804, 70d3e01 | numeric refs normalized (HTML only), `&apos` needs `;`, nbsp serialization, bounded escaping | decoded text / `html()` |
| 7927eb0, 91c110b, 816bf66 | output settings honoured before raw-source reuse; edited fragments rebuilt | `html()` / `outerHtml()` after `remove()` |
| 502a481 | parser state reset per input | yes, reused parsers |
| f8898fd, ebbcc61, 9bbf537, 7a065ce | selector fixes (relative `:has`, detached trees, compound attribute fast path, escaped type selectors) | `select()` results |
| a2256e5, bbfed91 | CharacterReader bounds on truncated / malformed HTML | crash class |
| f9959ab | `Whitelist` default `URLWhitespaceMode` → `.allow` | no (app uses no `Cleaner`) |
| da47a07, 8429fd3, 7400d41 | `ElementQuery` protocol, `:containsData()`, `crossorigin` boolean | additive |
| 2333cd6 | macOS floor 10.15 → 12 | no (app is macOS 26) |

## 2. Public API
| Symbol | Change | Our usage / fix |
|---|---|---|
| `Package.swift` deps | LRUCache and swift-atomics removed (in-tree `LRUCache.swift`) | none imported by the app; LRUCache leaves `Package.resolved` on next resolve, swift-atomics stays (postgres-nio) |
| `ElementQuery.text()` | new no-arg overload = `text(trimAndNormaliseWhitespace: true)` | same result for our 28 `.text()` calls |
| `[UInt8]`/`ArraySlice` internals | many public-but-internal signatures now take `ByteSlice` | not used by the app |
| everything the app calls (`select`, `attr`, `text`, `remove`, `parents`, `wrap`, `getAttributes`, `previousElementSibling`, `childNodesCopy`, …) | unchanged signatures | no fix |

## 3. Conflicts and fork patches
| File | Resolution |
|---|---|
| `Sources/Attributes.swift` (2 hunks) | upstream taken; our empty-name drop absorbed by d33de7b. File identical to upstream. |
| `Sources/Node.swift` (3 hunks) | upstream taken; deinit (7c9a40b), `markSourceDirty` (upstream loop + dirty-root registration), `outerHtmlFast` (0187a0d). File identical to upstream. |
| `Sources/HtmlTreeBuilderState.swift` (auto-merged) | our two input blocks dropped: one was dead (upstream's `case .input` in the switch runs first), one shadowed upstream's equivalent name-slice branch. Three InBody `insertForm(startTag, true)` → `false`, marked `wangqi modified 2026-10-25`. |
| `.gitignore`, `Example/*` (15d60fa) | auto-merged, kept |
| `UPGRADING.md` (fork-only) | updated with this merge |

Markers OLD (4987c59): Attributes 2, HtmlTreeBuilderState 2, Node 3, UPGRADING 1. NEW: HtmlTreeBuilderState 3
(form hold), UPGRADING 2. Every drop is explained above.

## 4. Dependencies
Two dependencies removed upstream (LRUCache, swift-atomics). No dependency added or upgraded.

## 5. Risk assessment — 4 risks (0 high, 3 medium, 1 low)
### R1 — form hold diverges from upstream (MEDIUM)
**Problem:** upstream `FormElementTest` (form-children cases) fails on the fork by design, and a later upstream
change may assume the form is on the stack. **Verify:** `HTML2MarkdownTests` (`testVoidInputDoesNotSwallowFollowingSiblings`,
`testRemovingVoidInputsDoesNotDeleteTheDocument`), `HTML2MarkdownEmailTests`. **Status:** P10.
### R2 — text / entity output drift (MEDIUM)
**Problem:** e826a53, 86f39b6, 784569a, 8a08804 change `text()` and decoded output. **Verify:** `MarkdownAssemblerGoldenTests`,
`HTML2MarkdownTests`, `HTMLFileReaderTests`, `OCRHTMLTableConverterTests` vs `base-results.txt`. **Status:** P10.
### R3 — selector result changes (MEDIUM)
**Problem:** selector-engine fixes can change what reader plugins `select()`. **Verify:** `FileReaderRoutingTests`,
`MediaURLProcessorTests`, `ImageDescriptionFallbackTests`. **Status:** P10.
### R4 — Package.resolved churn (LOW)
**Problem:** LRUCache leaves the app's `Package.resolved`. **Verify:** app build resolves cleanly. **Status:** P5.

## 6. New models
Not applicable.

## 7. Opportunities (not built)
| Upstream feature | Consumer that would use it | Value |
|---|---|---|
| correct `<form>` tree (8fcecf0) + unwrap forms in `cleanDocument` | `HTML2Markdown` (readers, email, wiki ingest) | recovers form-wrapped page content; needs own change and a `PolymarketPlugin` decision (UPGRADING.md) |
| `ElementQuery` protocol | `HTML2Markdown` helpers that take Element or Elements | less duplication |
| `:containsData()` | reader plugins scraping inline JSON in `<script>` | simpler selectors |

## 8. Verification
`swift build` and `swift build --build-tests` OK. `swift test --filter 'AttributesTest|AttributeTest|NodeTest'`:
67 tests, 0 failures. `FormElementTest`: `testFormChildInputsAreDirectChildren` / `testFormChildrenTreeStructure`
fail (expected, form hold; the second force-unwraps and traps). App suites and app builds: run by the coordinator (P5/P10).
