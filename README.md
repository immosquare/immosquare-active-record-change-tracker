---
locale: en
tags:
  - app:immosquare-active-record-change-tracker
  - audience:technique
---

# immosquare Active Record Change Tracker

`immosquare-active-record-change-tracker` is an extension that automatically tracks changes to your ActiveRecord models: it records changes to specified attributes whenever a record is saved. This README is written for the Rails developer adding the gem to an application, and covers installing it and generating its migration, enabling tracking on a model with `track_active_record_changes` and its options, the security precautions the stored diffs call for, the behaviour with Globalize translations and with paranoia soft deletes, how to read a record's history, and how to run the gem's own test suite.

## Installing the gem and generating the migration

```ruby
gem "immosquare-active-record-change-tracker"
```

The install generator writes the migration that creates the `active_record_change_trackers` table and its two indexes:

```bash
rails generate immosquare_active_record_change_tracker:install

# create_table(:active_record_change_trackers) do |t|
#   t.references(:recordable, :polymorphic => true, :foreign_key => false, :index => false, :null => false)
#   t.references(:modifier, :polymorphic => true, :foreign_key => false, :index => false, :null => true)
#   t.string(:event, :null => true, :limit => 10)
#   t.text(:data, :null => true, :limit => 4_294_967_295)
#   t.datetime(:created_at, :null => false)
# end

# add_index(:active_record_change_trackers, [:recordable_type, :recordable_id])
# add_index(:active_record_change_trackers, [:modifier_type, :modifier_id])
```

Then run the migration :

```bash
rails db:migrate
```

## Enabling tracking on a model with `track_active_record_changes`

To enable history tracking for a model, add `track_active_record_changes` to your model

```ruby
class YourModel < ApplicationRecord
  track_active_record_changes

  # rest of your model code...
end
```

By default, changes to all attributes (except `created_at` and `updated_at`) will be tracked.
You can specify options to include or exclude specific attributes:

**Exclude certain attributes** :

```ruby
class YourModel < ApplicationRecord
  track_active_record_changes(except: [:attribute1, :attribute2])

  # rest of your model code...
end
```

This will track changes to all attributes except `:attribute1` and `:attribute2`.

**Include only certain attributes** :

```ruby
class YourModel < ApplicationRecord
  track_active_record_changes(only: [:attribute3, :attribute4])

  # rest of your model code...
end
```

This will track changes only to `:attribute3` and `:attribute4`.


**Specify a modifier using a block** :

The modifier can be specified by providing a block to track_active_record_changes, which allows you to capture dynamic context at the time changes are saved. (https://zainab-alshaikhli01.medium.com/activesupport-currentattributes-e3d43270207c)


```ruby
class YourModel < ApplicationRecord
  track_active_record_changes(except: [:attribute1]) do
    ## Your Logic to get the modifier
    Current.admin.present? ? Current.admin : Current.user
  end
  # rest of your model code...
end
```

## Security — filtering sensitive attributes and protecting `history_records`

`immosquare-active-record-change-tracker` stores the **before/after values** of every changed attribute in the `data` JSON column of `active_record_change_trackers`. Two things to keep in mind:

**1. Filter sensitive attributes.** By default, every attribute except `created_at` and `updated_at` is tracked. If you enable tracking on a model that holds sensitive data, those values will be persisted in plaintext (or as their stored representation) inside the history table.

Always exclude credentials, tokens and regulated PII explicitly:

```ruby
class User < ApplicationRecord
  track_active_record_changes(except: [
    :password_digest,
    :encrypted_password,
    :reset_password_token,
    :confirmation_token,
    :unlock_token,
    :remember_token,
    :api_token
  ])
end
```

The safer pattern is to use `only:` with an explicit allow-list of the attributes you actually want to audit, rather than relying on `except:` to remember every sensitive field.

**2. Protect access to `history_records`.** The gem does not enforce any authorization on the `history_records` association. Never expose it through an API, a serializer or an admin view without an access control layer — doing so leaks the full diff history of the record, including any field you forgot to exclude in step 1.

## Tracking translated attributes with Globalize

If your model uses [Globalize](https://github.com/globalize/globalize), the tracker automatically merges translation diffs into the `data` column, indexed by locale. No extra configuration is required — the tracker detects `translated_attribute_names` and reads `previous_changes` from each `Globalize::ActiveRecord::Translation` after save.

For a translated attribute, the stored diff is a hash keyed by locale instead of a flat `[old, new]` array:

```ruby
##============================================================##
## Untranslated attribute (regular column)
##============================================================##
record.data
# => {"title" => ["Hello", "Hi"]}

##============================================================##
## Translated attribute (Globalize)
##============================================================##
record.data
# => {"title" => {"fr" => ["Bonjour", "Salut"], "en" => ["Hello", "Hi"]}}
```

Translation changes where both the old and new values are blank (`nil ↔ ""`) are silently skipped — they would otherwise pollute the history with empty diffs every time a translation is saved without a real change.

## Deleting a tracked record — paranoia compatibility and declaration order

`immosquare-active-record-change-tracker` is compatible with the paranoia gem (https://github.com/rubysherpas/paranoia) :
 - If your model has `acts_as_paranoid`, then the deletion of a record will be recorded in the `active_record_change_trackers` table with the event `destroy`, and the records of `create` and `update` will be retained.
 - A really_destroy! command will completely delete the record from the  `active_record_change_trackers` table.
 - Without this gem, the deletion of a record will not be recorded in the `active_record_change_trackers` table, and the records of `create` and `update` will be deleted.

**Order matters with paranoia.** `acts_as_paranoid` must be declared **before** `track_active_record_changes`. The tracker reads `paranoid?` at macro-call time to decide between `dependent: :destroy` (hard cleanup) and `after_real_destroy` (paranoia-aware cleanup). If you call `track_active_record_changes` first, the tracker will treat the model as non-paranoid and hard-delete the history on every soft-delete.

```ruby
class YourModel < ApplicationRecord
  acts_as_paranoid                  # first
  track_active_record_changes       # then
end
```


## Accessing change history through the `history_records` association

Each model that includes `track_active_record_changes` automatically has access to its change history through the `history_records` association. The history records are ordered by `created_at` in descending order, meaning the most recent changes are listed first.

```ruby
class YourModel < ApplicationRecord
  track_active_record_changes
end

your_model_instance.history_records
```

Each `history_record` is an instance of `ImmosquareActiveRecordChangeTracker::HistoryRecord` (table `active_record_change_trackers`) and exposes:

| Attribute    | Type                | Description                                                                                                           |
| ------------ | ------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `recordable` | Polymorphic         | The tracked record (e.g. the `YourModel` instance).                                                                   |
| `modifier`   | Polymorphic (`nil`) | The author returned by the block passed to `track_active_record_changes`.                                             |
| `event`      | String              | One of `"create"`, `"update"`, `"destroy"`.                                                                           |
| `data`       | JSON                | Hash of `{attribute => [old, new]}` (or `{attribute => {locale => [...]}}` for Globalize). `nil` on `destroy` events. |
| `created_at` | Datetime            | Timestamp of the change (`Time.current` at write time).                                                               |

Changes where the old and new values are equal after typecast (e.g. `[1, 1]` when assigning `true` to an integer column already at `1`) are filtered out and never written.

To check whether a model is paranoia-aware from the tracker's point of view:

```ruby
YourModel.kept_in_db?  # => true if acts_as_paranoid is declared, false otherwise
```


## Running the specs and the development / test dependency split

The `immosquare-active-record-change-tracker` suite boots a real ActiveRecord against an in-memory SQLite database, so no service needs to be running:

```bash
bundle install
bundle exec rspec
```

Dependencies are split in two groups, and the split is load-bearing — each group holds a different kind of dependency, and only one of the two is installed on CI:

| Group         | Holds                                                              | Installed on CI |
| ------------- | ------------------------------------------------------------------ | --------------- |
| `development` | Editor and linter tooling (`ruby-lsp`, `immosquare-cleaner`, rake)  | No              |
| `test`        | What the specs need to run (`rspec`, `sqlite3`, `paranoia`, coverage) | Yes           |

Anything a spec requires belongs to `test`: the CI exports `BUNDLE_WITHOUT=development`, so a gem left in `development` is missing at run time.

## Coverage reports and the Jenkins continuous integration pipeline

Coverage is off by default — a plain `bundle exec rspec` stays fast and leaves no `coverage/` directory behind. Enable it with an environment variable:

```bash
COVERAGE=true bundle exec rspec
# => coverage/lcov.info  (LCOV, consumed by the CI)
# => coverage/index.html (HTML report)
```

`spec/coverage_helper.rb` starts SimpleCov before the library is loaded, which is why `.rspec` requires it **above** `spec_helper`. Reversing that order reports 0%.

`Jenkinsfile` drives the build through `bin/ci`, a two-step entry point that behaves identically on a laptop and on a build agent:

| Command       | Does                                                                     |
| ------------- | ------------------------------------------------------------------------ |
| `bin/ci init` | `bundle install` without the `development` group                          |
| `bin/ci test` | `bundle exec rspec`                                                      |

Everything specific to the build agent — RVM provisioning of the ruby in `.ruby-version`, bundler pinning — runs only when `JENKINS_WORKSPACE` is set. The pipeline exports `COVERAGE=true` and publishes `coverage/lcov.info` through the Jenkins coverage recorder.

## Contributing to the gem, and license

Bug reports and pull requests are welcome on GitHub at [https://github.com/immosquare/immosquare-active-record-change-tracker](https://github.com/immosquare/immosquare-active-record-change-tracker). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant code of conduct](https://www.contributor-covenant.org/version/2/0/code_of_conduct/).

The gem is available as open-source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
