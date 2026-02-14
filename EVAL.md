# kb-smalltalk — Evaluation

## Quantitative

| Metric | Value |
|--------|-------|
| Lines of code | 617 |
| Token economy (solution) | ~5,250 tokens (21KB) |
| Token economy (process) | ~15,000 tokens (2 sessions, minimal debugging) |
| Abstraction density | 8.8% (54 methods / 617 LOC across 3 classes) |
| Iteration count | ~3 rounds (core, CLI wiring, extension) |
| Extension cost (tokens) | ~1,500 tokens (~30 LOC for blocked feature) |
| Extension cost (LOC) | ~30 (isBlocked:, blockedItems, blockingDeps:, cmdBlocked, board marker) |
| Error recovery cost | Low — minimal debugging needed |

## Qualitative

| Dimension | Notes |
|-----------|-------|
| Naturalness of fit | Strong. Domain entities (Item, Store, Cli) map directly to classes. Message-passing feels natural for commands like `item moveTo: lane`. The OO model matches the domain well — items *are* objects with behavior, not data bags. |
| Composability | Good. Methods are small and composable. `isBlocked:` builds on `find:`, `blockedItems` builds on `isBlocked:`, `blockingDeps:` reuses the same pattern. The extension exercise required only additive changes. |
| Readability (agent) | High. Smalltalk's keyword messages are self-documenting: `store addItem: aType title: aTitle options: opts` reads like prose. The postcard grammar means the agent never needs to recall complex syntax rules. |
| Readability (human) | Moderate. The message-passing style is readable once you grasp `object message` and `object keyword: arg`. The `[block]` syntax for closures and `#()` for arrays may trip up non-Smalltalkers. Overall more readable than most languages for this domain. |
| Format expressiveness | Kept the strawman format. GNU Smalltalk doesn't strongly suggest an alternative — it lacks the syntactic sugar that Lisp (s-exprs) or Forth (DSL) would naturally push toward. The YAML-like format works fine. |
| Surprise factor | GNU Smalltalk's standard library is more limited than expected. String manipulation required manual helpers (splitComma:, indentOf:, isPrefix:of:). The `trimSeparators` method name is non-obvious. Positive surprise: the single-file solution is clean and cohesive despite the language's image-based heritage. |
| Library pain | Moderate. No regex, no YAML/JSON parser, no argument parsing library. Had to write string splitting, prefix matching, and option parsing by hand. The `FileStream` API is workable but dated. These are all solvable but add LOC. |
| Self-extension quality | Excellent. Adding `blocked` required: 3 query methods on KbStore (~15 LOC), 1 CLI command (~15 LOC), and a 2-line marker in `cmdBoard`. All built on existing abstractions (`find:`, `items`, `select:`). Zero duplication. |

## Agent-readiness

| Dimension | Notes |
|-----------|-------|
| Context pressure | Low. At 617 LOC in a single file with 3 well-separated classes, the entire codebase fits comfortably in context. Smalltalk's concise syntax helps — equivalent Python or Go would be 2-3x longer. |
| Toolability | Good. The CLI is straightforward to invoke from scripts or other agents. The text file format is trivially parseable. However, GNU Smalltalk doesn't offer a REPL-as-API the way Pharo does. |
| Inspectability | Limited in GNU Smalltalk (no live image). The text file *is* the inspectable state. An agent can read kb.txt directly, which is arguably better than needing to query a running process. |
| Grammar-in-context cost | Very low. Smalltalk's grammar fits in ~200 tokens. An agent needs to know: unary messages, keyword messages, binary messages, blocks, cascades, and assignment. That's it. This is a genuine advantage over Go, Python, or Rust. |

## Session Log

Implementation completed in ~3 rounds across 2 sessions. Key observations:

1. **Single-file cohesion**: The entire solution lives in one 617-line file with clean class boundaries. GNU Smalltalk's class definition syntax (`Object subclass: Foo [...]`) keeps everything self-contained.

2. **Accessor boilerplate**: Smalltalk requires explicit getter/setter methods for every field. This accounts for ~30 LOC that would be implicit in Python or Go. GNU Smalltalk lacks Pharo's `slots:` shorthand.

3. **String handling tax**: The biggest friction point. Splitting strings, checking prefixes, and parsing options all required manual implementation. A language with regex or better string libraries would save ~60 LOC.

4. **Extension was trivial**: The blocked feature took ~30 LOC and touched only additive code. The existing abstractions (`find:`, collection protocol, `select:`) composed perfectly. This validates Smalltalk's claim of extensibility.

5. **Format decision**: Kept the spec's strawman format rather than proposing a Smalltalk-native one. Unlike Lisp or Forth, Smalltalk doesn't have a syntax that doubles as a data format. The YAML-like text format is fine.
