# kb-smalltalk

GNU Smalltalk implementation of the `kb` kanban tool.

**Part of the 'Language Choice as Superpowerresearch' research spike.**

## What This Is

A text-first, CLI kanban board tool. Same spec implemented in 6 languages to evaluate which languages give AI agents the best leverage. GNU Smalltalk tests the hypothesis that message-passing OO with a postcard-sized grammar gives agents superior abstraction power.

## The Spec

See [SPEC.md](./SPEC.md) for the full specification. Key points:

- **Text-first:** The data file is the source of truth — human-readable, git-diffable, agent-friendly
- **CLI interface:** `kb add`, `kb move`, `kb ls`, `kb board`, `kb show`, etc.
- **Methodology-agnostic:** Lanes and flow, not Scrum opinions
- **Format freedom:** If Smalltalk suggests a more natural data format, propose it
- **Extension exercise:** After core works, add `blocked` status (auto-derived from deps) and `kb blocked` command

## Runtime

- **Language:** GNU Smalltalk (`gst`)
- **Dependencies:** Standard library only
- **Run:** `gst kb.st -- <command> [args]`

## Why Smalltalk

- Everything is an object, everything is a message — maps directly to domain entities
- Grammar fits on a postcard — minimal context cost for the agent
- Live, reflective system — natural inspectability
- The image model (in Pharo) is a serializable world — relevant to agent state management

## Status

- [ ] Core: parser, serializer, internal model
- [ ] CLI: add, move, ls, board, show
- [ ] Extension: blocked status + kb blocked command
- [ ] Evaluation notes captured
