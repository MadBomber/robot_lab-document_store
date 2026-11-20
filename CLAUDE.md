# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Gem Does

`robot_lab-document_store` provides a thread-safe, in-memory semantic document store for RobotLab. Documents are embedded and retrieved by cosine similarity. It uses `fastembed` (BAAI/bge-small-en-v1.5) when available, and falls back to a lightweight TF-IDF word-frequency embedder when fastembed is not installed.

## Commands

```bash
bundle exec rake test        # Run full test suite
ruby -Ilib:test test/<file>  # Run a single test file
```

## Architecture

The gem is a single class: `RobotLab::DocumentStore` (`lib/robot_lab/document_store.rb`).

### Key Methods

```ruby
store = RobotLab::DocumentStore.new                  # fastembed model chosen automatically
store = RobotLab::DocumentStore.new(model_name: "...") # override fastembed model

store.store(:key, "text")           # embed and store; replaces existing key
store.search("query", limit: 5)     # returns Array<{key:, text:, score:}>
store.size                          # Integer
store.keys                          # Array<Symbol>
store.empty?                        # Boolean
store.delete(:key)                  # remove one document
store.clear                         # remove all documents
```

Search results are sorted by score descending (clamped to 0.0–1.0). The fastembed model is initialised lazily on the first `store` call (`search` on an empty store returns `[]` without embedding) — the ONNX model file is downloaded then cached locally.

### Embedding Paths

**Fastembed path** (when `fastembed` gem is installed):
- `passage_embed` for stored documents, `query_embed` for search queries — asymmetric embedding (same model; fastembed prepends `"passage: "` / `"query: "` to the text)
- Dense float vectors, cosine similarity computed inline

**Fallback TF-IDF path** (when fastembed is absent):
- Stop-word filtered, Porter-style stemmed word frequency vectors
- Sparse `Hash{String => Float}` L2-normalised vectors
- `sparse_cosine` for similarity — no semantic understanding, lexical overlap only
- Good for development and testing without downloading ONNX models

### Thread Safety

All reads and writes to `@documents` are protected by a `Mutex`. Lazy creation of the fastembed model is guarded by a separate `@model_mutex` (double-checked in `fastembed_model`, built by `build_fastembed_model`) so concurrent first calls load it once. Embedding calls themselves run outside both locks and rely on `Fastembed::TextEmbedding` being safe to call concurrently.

### Integration with robot_lab Memory

When `robot_lab-document_store` is loaded alongside `robot_lab`, the Memory class gains:
```ruby
memory.store_document(:key, text)
memory.search_documents("query", limit: 5)
memory.document_keys
memory.delete_document(:key)
```

## Key Constraints

- Documents are stored entirely in memory — the store does not persist across process restarts.
- Keys are coerced to `Symbol`. Storing under the same key replaces the previous document.
- The TF-IDF fallback has no semantic understanding — "car" and "automobile" will not match. Use fastembed for production.
- `FASTEMBED_AVAILABLE` is set at load time and cannot be changed at runtime.

## Testing

- Minitest with SimpleCov (`minimum_coverage line: 95, branch: 75` enforced)
- `DocumentStoreTest` runs against the real fastembed model (downloaded on first run, then cached); set `ROBOT_LAB_SKIP_EMBEDDINGS=true` to skip those tests
- The TF-IDF fallback path is tested through a `DocumentStoreFallback` subclass that sets `@using_fastembed = false`
- Model-init thread safety and score clamping are tested without the real model (`CountingStore` overrides `build_fastembed_model`)
- Coverage: 98.93% line / 95.83% branch
