# Changelog

## [0.3.1](https://github.com/anowacki/SeisRequests.jl/compare/v0.3.0...v0.3.1) - 2025-06-26

### Bugfixes
- Mitigate against HTTP CRLF injection


## [0.3.0](https://github.com/anowacki/SeisRequests.jl/compare/v0.2.3...v0.3.0) - 2025-01-22

### Breaking changes
- SeisRequests now saves sensor burial depth in the `station.meta.burial_depth`
  entry, rather than in `station.dep`.  This is for future compatibility with
  changes to Seis.jl.

