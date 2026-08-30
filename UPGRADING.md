# SwiftSoup fork changes

Local changes to the vendored SwiftSoup. Re-apply these after any upstream merge; each is also
marked in the source with `// wangqi modified YYYY-MM-DD`.

## 2026-08-30 — `HtmlTreeBuilderState.swift`: `<input>` is a void element in `InBody`

`Tag.emptyTags` already lists `input`, but the "in body" insertion mode had no branch for it, so it
fell through to the generic `tb.insert(startTag)` and was pushed onto the stack of open elements.
No `</input>` ever arrives, so **every following sibling became its child**.

On a real search page one hidden `<input>` at the top of the form owned all 54 KB of the document's
text. Because callers legitimately strip `input` as noise, a single `select("input").remove()` then
deleted the whole page: body text went 60,777 → 1,757 characters, and the page converted to an empty
string with no error and no log line.

It is also what made that page look like a stack-overflow risk: the mis-nesting inflated recursion
depth in `MarkdownConverter.processTag` far beyond the page's real nesting (15 levels), which is
what `maxRecursionDepth` was originally raised to work around.

Fixed in both dispatch paths (the `tagId` switch and the name-slice chain), matching jsoup's
`case "input"`: reconstruct formatting elements, `insertEmpty`, and clear `framesetOk` unless
`type=hidden`.

**Regression tests:** `HTML2MarkdownTests.testVoidInputDoesNotSwallowFollowingSiblings` and
`testRemovingVoidInputsDoesNotDeleteTheDocument` (`testcases/libs/`).

---

## Known, deliberately NOT fixed — `<form>` is not pushed onto the stack in `InBody`

The three `InBody` sites call `insertForm(startTag, false)`; jsoup passes `true`. The element is
inserted but never becomes the current node, so **a form's children are parented to the form's
parent** and the form itself comes out empty. (`false` is correct at the two `InTable` sites, where
jsoup also keeps the form off the stack.)

This was fixed and then **reverted on purpose**. `form` is in
`MarkdownConverter.defaultIgnoringTags`, so `cleanDocument` runs `select("form").remove()`. While
the tree is wrong that call removes an empty shell and costs nothing; with a correct tree it deletes
the entire subtree. Auditing the callers, that would silently empty:

* every ASP.NET WebForms page (`<form runat="server">` wraps the whole body), search-result pages,
  forum/thread pages, wiki edit views — via `HTMLFileReader` → `markdownify`;
* survey and feedback marketing emails — via `apps/email/pipeline/ParseUnit.swift`;
* Knowledge Wiki URL ingest, which has an `isEmpty` guard and would skip the source silently;
* polymarket.com, whose plugin keeps `form` in its ignore set.

Only `AnnaArchivePlugin` opts `form` back in, and `Options.extraIgnoringTags` can add but never
subtract, so no other caller can protect itself.

**The correct fix is not `onStack: true` on its own.** It is to make `cleanDocument` *unwrap* a form
(retag it to `div`) rather than `remove()` it, keeping `input`/`button`/`select`/`textarea` removal
as it is — and then push the form onto the stack. That is a behaviour change for every HTML caller
and needs its own change, its own golden review, and a decision about `PolymarketPlugin`.
