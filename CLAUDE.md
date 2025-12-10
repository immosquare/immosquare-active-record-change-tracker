# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Ruby gem that automatically tracks changes to ActiveRecord models. It records attribute changes (create/update/destroy events) to a polymorphic `active_record_change_trackers` table.

## Development Commands

```bash
# Install dependencies
bundle install

# Build the gem locally
gem build immosquare-active-record-change-tracker.gemspec

# Install local gem
gem install immosquare-active-record-change-tracker-*.gem
```

## Architecture

### Core Components

- **`lib/immosquare-active-record-change-tracker.rb`** - Main module with `ClassMethods` (adds `track_active_record_changes` to models) and `InstanceMethods` (callbacks for save/destroy)
- **`lib/.../railtie.rb`** - Rails integration that extends ActiveRecord with the module on load
- **`lib/.../models/history_record.rb`** - The `HistoryRecord` model that stores change data in `active_record_change_trackers` table
- **`lib/generators/.../install_generator.rb`** - Rails generator for creating the migration

### Key Design Decisions

1. **Polymorphic associations** - Uses `recordable` (the tracked model) and `modifier` (who made the change) as polymorphic references
2. **Paranoia gem compatibility** - Special handling for soft-delete: destroy events are recorded, `really_destroy!` cleans up all history
3. **Globalize support** - Automatically tracks changes to translated attributes with locale-specific change history
4. **Modifier via block** - Supports dynamic modifier resolution using `Current` attributes pattern

### Change Tracking Flow

1. Model calls `track_active_record_changes` with options (`:only`, `:except`, block for modifier)
2. Sets up `has_many :history_records` association and `after_save`/`after_destroy` callbacks
3. On save: compares `previous_changes`, filters based on options, creates `HistoryRecord` with event type (`create`/`update`)
4. On destroy: records `destroy` event only if model uses `acts_as_paranoid`

## Code Style

- Ruby hash syntax uses hashrockets (`:key => value`)
- Comments are often in French
- Required Ruby version: >= 3.2.6
