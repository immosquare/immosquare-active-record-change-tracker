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

then Generate the migration to create the `application_record_histories` table:


```bash
rails generate immosquare_active_record_change_tracker:install
```

Then run the migration :

```bash
rails db:migrate
```

### Usage

To enable history tracking for a model, add `track_application_record` to your model

```ruby
class YourModel < ApplicationRecord
  track_application_record

  # rest of your model code...
end
```

By default, changes to all attributes (except `created_at` and `updated_at`) will be tracked.
You can specify options to include or exclude specific attributes:

- **Exclude certain attributes** :

  ```ruby
  class YourModel < ApplicationRecord
    track_application_record(except: [:attribute1, :attribute2])
  end
  ```

 This will track changes to all attributes except `:attribute1` and `:attribute2`.

- **Include only certain attributes** :

  ```ruby
  class YourModel < ApplicationRecord
    track_application_record(only: [:attribute3, :attribute4])
  end
  ```

  This will track changes only to `:attribute3` and `:attribute4`.



## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/IMMOSQUARE/immosquare-active-record-change-tacker](https://github.com/IMMOSQUARE/immosquare-active-record-change-tacker). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant code of conduct](https://www.contributor-covenant.org/version/2/0/code_of_conduct/).

## License

The gem is available as open-source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
