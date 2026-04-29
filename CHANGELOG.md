## [0.1.5] - 2026-04-28

### Fixed
- Avoid NoMethodError when the host app does not load paranoia: `kept_in_db?` now guards `paranoid?` with `respond_to?`.
- Preserve Globalize translation diffs that were silently dropped because the same-value filter ran after the Globalize merge.
- Allow a nil modifier without violating `belongs_to_required_by_default` by marking `belongs_to :modifier` as `:optional`.

### Changed
- Rename `kept_in_db` to `kept_in_db?` (predicate convention).
- Use `Time.current` instead of `DateTime.now` for history timestamps.
- Declare `activerecord` and `railties` (>= 6.1) as explicit runtime dependencies.

### Added
- RSpec test suite covering tracking, paranoia integration, and Globalize diffs.

## [0.1.4] - 2024-12-05
- Fix when inserting record with same values

## [0.1.3] - 2024-10-14
- improve paranoia integration

## [0.1.2] - 2024-10-14
- improve to only keep if paranoia gems are activated

## [0.1.1] - 2024-10-07
- Add has_many: :history_records to the model to get the history records

## [0.1.0] - 2024-09-30
- Initial release
