require "active_record"
require "paranoia"
require "immosquare-active-record-change-tracker"

##============================================================##
## The ActiveRecord railtie cannot boot without a Rails::Application,
## so the on_load hook it would have run is fired by hand to extend
## AR::Base with the gem ClassMethods.
##============================================================##
ActiveSupport.on_load(:active_record) do
  extend ImmosquareActiveRecordChangeTracker::ClassMethods

  require "immosquare-active-record-change-tracker/models/history_record"
end

##============================================================##
## Reproduce the Rails 5+ default of a real app (the configuration
## `rails new` generates). Without it belongs_to_required_by_default
## stays nil, and a spec saving modifier=nil would pass here while
## crashing inside a host app.
##============================================================##
ActiveRecord::Base.belongs_to_required_by_default = true

##============================================================##
## In-memory SQLite, to exercise the callbacks and the persistence
##============================================================##
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
ActiveRecord::Migration.verbose = false

require_relative "support/schema"
require_relative "support/models"

RSpec.configure do |config|
  config.expect_with(:rspec) do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with(:rspec) do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  ##============================================================##
  ## Reset complet de la DB entre chaque test
  ##============================================================##
  config.before(:each) do
    [
      DefaultArticle,
      OnlyArticle,
      ExceptArticle,
      ModifierArticle,
      ParanoidArticle,
      Author,
      ImmosquareActiveRecordChangeTracker::HistoryRecord
    ].each(&:delete_all)
    Thread.current[:test_modifier] = nil
  end
end
