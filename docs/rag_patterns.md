# RAG Patterns

Retrieval-Augmented Generation (RAG) is the practice of retrieving relevant
documents at query time and injecting them into an LLM prompt as context. This
gives the model access to private or up-to-date information without fine-tuning.

`DocumentStore` is the retrieval layer. The LLM call is your responsibility —
typically via `RobotLab` robots or the `ruby_llm` gem.

---

## Pattern 1 — Standalone Retrieval

The simplest pattern: build the store at startup, query it per-request.

```ruby
require "robot_lab/document_store"

# ── Build once at startup ────────────────────────────────────────────────────
store = RobotLab::DocumentStore.new

Dir["docs/**/*.md"].each do |path|
  key = File.basename(path, ".md").to_sym
  store.store(key, File.read(path))
end

puts "Loaded #{store.size} documents"

# ── Query per-request ────────────────────────────────────────────────────────
query = "How do I investigate a slow Postgres query?"
hits  = store.search(query, limit: 3)

context = hits.map.with_index(1) do |h, i|
  "## Document #{i}: #{h[:key]}\n\n#{h[:text]}"
end.join("\n\n---\n\n")

prompt = <<~PROMPT
  Answer the following question using only the provided documents.

  #{context}

  ---

  Question: #{query}
PROMPT

# Pass `prompt` to your LLM of choice
```

---

## Pattern 2 — RobotLab Memory Integration

When `robot_lab` core is loaded alongside this gem, `RobotLab::Memory` gains
three document-store methods automatically via `register_extension`.

```ruby
require "robot_lab"
require "robot_lab/document_store"

memory = RobotLab::Memory.new

# Store documents
memory.store_document(:runbook,   File.read("ops/runbook.md"))
memory.store_document(:postmortem, File.read("ops/postmortem.md"))

# List keys
memory.document_keys  # => [:runbook, :postmortem]

# Search
hits = memory.search_documents("database outage lock contention", limit: 2)
hits.each { |h| puts "#{h[:key]}  #{h[:score].round(3)}" }

# Remove
memory.delete_document(:postmortem)
```

!!! note
    `Memory#store_document` / `#search_documents` / `#delete_document` /
    `#document_keys` are only available when `robot_lab-document_store` is loaded
    before calling these methods.

---

## Pattern 3 — RobotLab Robot with RAG Context

Inject retrieved context directly into a robot's prompt:

```ruby
require "robot_lab"
require "robot_lab/document_store"

# ── Prepare store ────────────────────────────────────────────────────────────
store = RobotLab::DocumentStore.new
store.store(:api_guide,   File.read("docs/api.md"))
store.store(:error_codes, File.read("docs/errors.md"))
store.store(:changelog,   File.read("CHANGELOG.md"))

# ── Build robot ──────────────────────────────────────────────────────────────
robot = RobotLab.build(
  name: "support_agent",
  system_prompt: "You are a helpful support agent. Answer questions using only the context provided."
)

# ── Per-request RAG ──────────────────────────────────────────────────────────
def answer(robot, store, question)
  hits    = store.search(question, limit: 3)
  context = hits.map { |h| h[:text] }.join("\n\n---\n\n")

  robot.run(<<~PROMPT)
    Context documents:

    #{context}

    ---

    User question: #{question}
  PROMPT
end

result = answer(robot, store, "What changed in the last release?")
puts result.last_text_content
```

---

## Pattern 4 — Chunked Documents

For long documents, split into chunks before storing. Smaller chunks improve
retrieval precision because a single chunk covers a narrower topic.

```ruby
# Simple paragraph chunker
def chunk(text, max_words: 150)
  paragraphs = text.split(/\n{2,}/).map(&:strip).reject(&:empty?)
  chunks     = []
  buffer     = []
  word_count = 0

  paragraphs.each do |para|
    words = para.split.size
    if word_count + words > max_words && buffer.any?
      chunks << buffer.join("\n\n")
      buffer     = []
      word_count = 0
    end
    buffer     << para
    word_count += words
  end
  chunks << buffer.join("\n\n") if buffer.any?
  chunks
end

# Store with indexed chunk keys
store = RobotLab::DocumentStore.new

chunk("docs/runbook.md").each_with_index do |text, i|
  store.store(:"runbook_#{i}", text)
end
```

---

## Pattern 5 — Hybrid Key Filtering

Use `search` results alongside `keys` to build filtered views or verify coverage:

```ruby
# Find which documents were never retrieved (potential gaps in coverage)
all_keys     = store.keys.to_set
retrieved    = questions.flat_map { |q| store.search(q, limit: 3).map { |r| r[:key] } }.to_set
never_hit    = all_keys - retrieved

puts "Documents never retrieved: #{never_hit.to_a}"
```

---

## Tips

**Chunk size matters.** Chunks of 100–250 words typically give the best
recall/precision trade-off. Very long documents dilute the embedding signal;
very short chunks lose context.

**Limit and threshold.** Retrieve more than you need (`limit: 5`) then drop
results below a quality threshold (e.g., `score >= 0.4`) before building the
context string. This avoids injecting unrelated documents.

```ruby
hits = store.search(query, limit: 5).select { |r| r[:score] >= 0.4 }
```

**Re-embed on document update.** `store` replaces an existing key — calling it
again with updated text re-embeds and replaces the stored vector automatically.

**Persistent corpus.** `DocumentStore` is in-memory only. For a persistent
corpus, re-load documents from disk at startup. For production use cases that
need persistence, consider a dedicated vector database (pgvector, Qdrant, Weaviate).
