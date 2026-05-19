## [Unreleased]

## [0.2.1] - 2026-05-19

### Added
- Full test suite covering fastembed path, TF-IDF fallback path, and cosine edge cases (27 tests, 44 assertions)
- SimpleCov branch coverage with thresholds (line: 95%, branch: 75%)
- `quality` Rake task: runs tests + coverage, RuboCop, and Flog in sequence
- Complete RBS type signatures in `sig/robot_lab/document_store.rbs`
- Example script `examples/01_basic_usage.rb` with companion Markdown documents

### Changed
- Development dependencies moved from gemspec to Gemfile (per `Gemspec/DevelopmentDependencies` cop)
- Example renamed from `26_document_store.rb` to `01_basic_usage.rb`
- Version synchronized with robot_lab core 0.2.1

### Fixed
- Model name in README and docs corrected to `BAAI/bge-small-en-v1.5` (was incorrectly listed as `bge-base`)
- `register_extension` call guarded with `defined?(RobotLab) && RobotLab.respond_to?(:register_extension)` so the file loads safely without robot_lab core
- Instance variable `@fastembed_model` renamed from `@model` to eliminate shadowing risk
- `FASTEMBED_AVAILABLE` constant moved into `DocumentStore` class (was at module level)
- `STOP_WORDS` constant moved before `private` keyword (was defined after it)
- `sparse_cosine` parameter names corrected to `vec_a`/`vec_b`; uses `each_value` for the second vector

## [0.1.0] - 2026-05-07

- Initial release
