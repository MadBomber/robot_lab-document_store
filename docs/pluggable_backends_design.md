# Pluggable Backend Architecture — Design Discussion

**Date:** 2026-05-14
**Status:** Parked — resume when time allows

## The Vision

`DocumentStore` should become an **abstract interface** that defines the storage contract but does not implement any backend itself. The gem ships with two concrete backends; applications supply their own.

### Backends shipping with the gem

| Class | Description |
|---|---|
| `DocumentStore::Memory` | In-memory store — essentially the current implementation (fastembed/TF-IDF). No persistence. |
| `DocumentStore::FileSystem` | File-backed store — YAML persistence, similar to `robot_lab-durable`'s current `Store` class. |

### Backends supplied by applications

Applications implement their own adapters (same interface) for:
- `DocumentStore::Redis`
- `DocumentStore::Database`
- Any other backend

All backend code lives in the application, not in this gem.

## Motivation

`robot_lab-durable` currently maintains its own `Store` class (YAML file-backed with file locking). Once `DocumentStore::FileSystem` exists, durable can drop its custom storage layer and delegate to it — keeping only its durable-specific concerns: `Entry` (confidence scoring), `Reflector` (session reflection), `Learning` (Robot mixin), and the LLM tools.

## Interface Contract

All backends must implement:

```ruby
store(key, text)       # embed and persist a document under key
search(query, limit:)  # return Array<Hash> sorted by score descending
                       #   each Hash: { key:, text:, score: }
delete(key)            # remove document by key; return self
clear                  # remove all documents; return self
size                   # Integer
keys                   # Array<Symbol>
empty?                 # Boolean
```

## Open Questions

1. **Search semantics differ across backends.**
   `Memory` uses embedding-based cosine similarity. `FileSystem` would use keyword matching (tokenize + stem, like durable's current approach). Should the interface treat these as equivalent, or should backends declare their search capability? Options:
   - Accept the difference — callers get whatever the backend can do.
   - Add a `#search_strategy` or `#semantic?` predicate to the base class.

2. **Structured vs raw text storage.**
   `DocumentStore` today stores raw text by key. `robot_lab-durable` stores structured `Entry` objects (confidence, category, domain, use_count). Two options:
   - `FileSystem` stores raw text; durable serializes/deserializes `Entry` fields into the text before storing.
   - `FileSystem` supports structured metadata alongside text (a `meta:` hash), which durable populates.

3. **Breaking change.** Refactoring `DocumentStore` from a concrete class to an abstract base is a breaking change — this is v0.2.0 territory.

## Rough Implementation Plan

1. Extract the current `DocumentStore` implementation into `DocumentStore::Memory`.
2. Define `DocumentStore` as an abstract base class with `NotImplementedError` stubs for each interface method.
3. Implement `DocumentStore::FileSystem` — port durable's `Store` (YAML, file locking, keyword search).
4. Update `robot_lab-durable` gemspec to add `robot_lab-document_store` as a dependency.
5. Replace `RobotLab::Durable::Store` with `DocumentStore::FileSystem` in durable's internals.
6. Bump `robot_lab-document_store` to v0.2.0; bump `robot_lab-durable` to v0.2.0.
