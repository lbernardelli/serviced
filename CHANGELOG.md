# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

### Added

- `Serviced::Service`: base class for service objects with typed, immutable
  inputs (backed by ActiveModel::Attributes), ActiveModel validations, and a
  mandatory Success/Failure return contract.
- `Serviced::Result` with `Serviced::Success` and `Serviced::Failure`:
  immutable result objects supporting predicates, `on_success`/`on_failure`
  callbacks, `and_then`/`map` chaining, and pattern matching.
- `Serviced::Flow`: composes services (or any callable) into a pipeline that
  threads an immutable context, with an optional single transaction.
- `Serviced::Query`: base class for query objects with the same typed,
  immutable inputs as a service. Returns an `ActiveRecord::Relation` (or a
  value) so results stay composable, ships safe SQL helpers (`quote`,
  `quote_column`, `sanitize`, `count_of`), and raises `Serviced::InvalidQuery`
  on invalid input.
- `Serviced::Typed`: shared concern providing typed, immutable, validatable
  attributes; included by both `Serviced::Service` and `Serviced::Query`.
  Inputs are isolated by default: value-like data (arrays, hashes, sets,
  strings) is captured as a deep-frozen snapshot at construction, while objects
  with identity (records) are shared by reference. Opt out per attribute with
  `isolate: false`.
- `Serviced.configure` with a pluggable `transaction_handler` (defaults to
  `ActiveRecord::Base.transaction` when ActiveRecord is available).
