# IMMO SQUARE Active Record Change Tracker

This extension allows you to automatically track changes to your ActiveRecord models. It records changes to specified attributes whenever a record is saved.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'immosquare-active-record-change-tracker'
```

Then execute:

```bash
$ bundle install
```

Or install it yourself:

```bash
$ gem install immosquare-active-record-change-tracker
```

then Generate the migration to create the `active_record_change_trackers` table:


```bash
rails generate immosquare_active_record_change_tracker:install
```

```ruby
create_table(:active_record_change_trackers) do |t|
  t.references(:recordable, :polymorphic => true, :foreign_key => false, :index => false, :null => false)
  t.references(:modifier, :polymorphic => true, :foreign_key => false, :index => false, :null => true)
  t.text(:data, :null => false, :limit => 4_294_967_295)
  t.datetime(:created_at, :null => false)
end
add_index(:active_record_change_trackers, [:recordable_type, :recordable_id])
add_index :active_record_change_trackers, [:modifier_type, :modifier_id]
```

Then run the migration :

```bash
rails db:migrate
```

### Usage

To enable history tracking for a model, add `track_active_record_changes` to your model

```ruby
class YourModel < ApplicationRecord
  track_active_record_changes

  # rest of your model code...
end
```

By default, changes to all attributes (except `created_at` and `updated_at`) will be tracked.
You can specify options to include or exclude specific attributes:

- **Exclude certain attributes** :

  ```ruby
  class YourModel < ApplicationRecord
    track_active_record_changes(except: [:attribute1, :attribute2])
  end
  ```

 This will track changes to all attributes except `:attribute1` and `:attribute2`.

- **Include only certain attributes** :

  ```ruby
  class YourModel < ApplicationRecord
    track_active_record_changes(only: [:attribute3, :attribute4])
  end
  ```

  This will track changes only to `:attribute3` and `:attribute4`.



## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/IMMOSQUARE/immosquare-active-record-change-tacker](https://github.com/IMMOSQUARE/immosquare-active-record-change-tacker). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant code of conduct](https://www.contributor-covenant.org/version/2/0/code_of_conduct/).

## License

The gem is available as open-source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
