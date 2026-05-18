# robot_lab-document_store

Embedding-based semantic document search for the [RobotLab](https://github.com/MadBomber/robot_lab) LLM agent framework.

!!! warning "Under active development"
    APIs may change without notice until v1.0.

`RobotLab::DocumentStore` is a thread-safe, in-memory vector store. Store arbitrary text documents, then retrieve the most relevant ones by natural-language query — no keyword overlap required.

```ruby
require "robot_lab/document_store"

store = RobotLab::DocumentStore.new

store.store(:sidekiq_guide,   File.read("docs/sidekiq.md"))
store.store(:postgres_guide,  File.read("docs/postgres.md"))
store.store(:incident_report, File.read("docs/outage_2024.md"))

hits = store.search("Jobs keep piling up when Stripe is down", limit: 2)
hits.each { |r| puts "#{r[:key]}  score=#{r[:score].round(3)}" }
# => sidekiq_guide   score=0.847
# => incident_report score=0.612
```

## Features

| Feature | Detail |
|---------|--------|
| **Semantic search** | Cosine similarity over dense vector embeddings |
| **Asymmetric embedding** | Separate passage/query embeddings for higher recall |
| **Thread-safe** | Internal `Mutex` — safe for Puma, Sidekiq, Ractor workers |
| **Zero-config fallback** | TF-IDF word-frequency search when fastembed is unavailable |
| **Lazy model init** | ONNX model downloads on first use, cached locally |
| **RobotLab integration** | Drop-in via `Memory#store_document` / `Memory#search_documents` |

## Navigation

- [Getting Started](getting_started.md) — install, first run, fallback mode
- [API Reference](api_reference.md) — every public method documented
- [How It Works](how_it_works.md) — embeddings, cosine similarity, TF-IDF fallback
- [RAG Patterns](rag_patterns.md) — retrieval-augmented generation recipes
