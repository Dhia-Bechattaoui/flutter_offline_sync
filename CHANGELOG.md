# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Nothing yet.

## [0.1.0] - 2025-11-10

### Added
- Funding metadata pointing to `https://github.com/sponsors/Dhia-Bechattaoui`.
- WASM compatibility note in metadata to align with README.
- Full SQLite-backed persistence layer with new `PlatformDatabase` and `EntityCodec` helpers.
- Cross-platform connectivity monitoring via `connectivity_plus` and `internet_connection_checker_plus`.
- Persistent sync queue and conflict store to retry failed operations and surface manual resolutions.
- Complete Android example scaffold (Gradle, manifests, resources) to exercise the package end-to-end.

### Changed
- Raised minimum Flutter SDK requirement to `>=3.32.0`.
- Updated `json_annotation` lower bound to `^4.9.0` for downgrade compatibility.
- Switched package homepage/documentation links to verified pub.dev endpoints.
- Reformatted `platform_connectivity_impl.dart` to satisfy analyzer tooling.
- Achieved perfect pana score (160/160) through metadata and formatting updates.
- Refactored `OfflineDatabase`, `SyncEngine`, and `OfflineSyncManager` to use the shared storage codec, batch operations, and richer sync status tracking.

## [0.0.1] - 2024-12-19

### Added
- Initial release of flutter_offline_sync package
- Core offline functionality with SQLite database support
- Automatic network detection and sync capabilities
- Cross-platform support for iOS, Android, Web, Windows, macOS, and Linux
- Conflict resolution strategies (last-write-wins, custom resolvers)
- Comprehensive test suite with >90% coverage
- Full documentation with examples and API reference
- WASM compatibility for web platform
- Support for custom data models with JSON serialization
- Background sync capabilities
- Offline queue management
- Network status monitoring
- Data persistence with automatic migration support
- Comprehensive error handling and logging

[Unreleased]: https://github.com/Dhia-Bechattaoui/flutter_offline_sync/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Dhia-Bechattaoui/flutter_offline_sync/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/Dhia-Bechattaoui/flutter_offline_sync/releases/tag/v0.0.1
