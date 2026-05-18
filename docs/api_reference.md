# API Reference

All public methods of `RobotLab::DocumentStore`.

## Constructor

### `new(model_name: DEFAULT_MODEL)`

Creates a new, empty document store.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model_name` | `String` | `"BAAI/bge-small-en-v1.5"` | fastembed model name. Ignored when fastembed is unavailable. |

```ruby
# Default model
store = RobotLab::DocumentStore.new

# Custom model
store = RobotLab::DocumentStore.new(model_name: "BAAI/bge-base-en-v1.5")
```

The embedding model is initialised lazily — no download or computation happens
at construction time.

---

## Writing Documents

### `store(key, text) → self`

Embeds `text` and stores it under `key`. If a document already exists under that
key it is replaced. Embedding happens synchronously before the method returns.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `Symbol` \| `String` | Identifier for the document. Strings are converted to `Symbol` internally. |
| `text` | `String` | The document text to embed and store. |

**Returns:** `self` — supports method chaining.

```ruby
store.store(:readme,   File.read("README.md"))
     .store(:changelog, File.read("CHANGELOG.md"))
     .store(:guide,     File.read("GUIDE.md"))
```

---

## Searching

### `search(query, limit: 5) → Array<Hash>`

Embeds `query` and returns the `limit` most similar documents ranked by cosine
similarity score descending.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `query` | `String` | — | Natural-language search query. |
| `limit` | `Integer` | `5` | Maximum number of results to return. |

**Returns:** `Array` of result hashes, each containing:

| Key | Type | Description |
|-----|------|-------------|
| `:key` | `Symbol` | The document key |
| `:text` | `String` | The stored document text |
| `:score` | `Float` | Cosine similarity score, range `0.0..1.0` |

Results are sorted by `:score` descending (most similar first). Returns `[]` if
the store is empty.

```ruby
results = store.search("database connection pool exhausted", limit: 3)

results.each do |r|
  puts "#{r[:key].to_s.ljust(24)} score=#{r[:score].round(3)}"
  puts "  #{r[:text][0, 80]}…"
end
```

!!! tip "Score interpretation"
    Scores above `0.7` indicate strong semantic similarity. Scores below `0.3`
    typically indicate weak or no relationship. The exact thresholds depend on
    the model and your document corpus.

---

## Reading Metadata

### `size → Integer`

Returns the number of stored documents.

```ruby
store.size  # => 0
store.store(:a, "text")
store.size  # => 1
```

### `keys → Array<Symbol>`

Returns the keys of all stored documents in insertion order.

```ruby
store.store(:alpha, "…")
store.store(:beta,  "…")
store.keys  # => [:alpha, :beta]
```

### `empty? → Boolean`

Returns `true` if no documents are stored.

```ruby
store.empty?  # => true
store.store(:a, "text")
store.empty?  # => false
```

---

## Removing Documents

### `delete(key) → self`

Removes the document stored under `key`. No-op if the key does not exist.

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `Symbol` \| `String` | Key to remove. |

**Returns:** `self`.

```ruby
store.delete(:outdated_doc)
store.delete("also_works_with_strings")
```

### `clear → self`

Removes all stored documents.

**Returns:** `self`.

```ruby
store.clear
store.empty?  # => true
```

---

## Constants

### `DEFAULT_MODEL`

```ruby
RobotLab::DocumentStore::DEFAULT_MODEL  # => "BAAI/bge-small-en-v1.5"
```

The fastembed model used when no `model_name:` is specified.

### `STOP_WORDS`

A frozen `Set<String>` of common English words excluded from TF-IDF indexing
(`a`, `an`, `the`, `is`, `are`, …). Only relevant when fastembed is unavailable.

---

## Thread Safety

All public methods are thread-safe. An internal `Mutex` serialises access to
the document hash. You can safely share a single `DocumentStore` instance across
Puma threads, Sidekiq workers, or Ractor-based agents.

```ruby
# Safe: multiple threads can store and search concurrently
store = RobotLab::DocumentStore.new

threads = 10.times.map do |i|
  Thread.new { store.store(:"doc_#{i}", "Document #{i} text content") }
end
threads.each(&:join)

store.size  # => 10
```
