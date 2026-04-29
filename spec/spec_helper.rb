require "active_record"
require "paranoia"
require "immosquare-active-record-change-tracker"

##============================================================##
## ActiveRecord Railtie ne peut pas booter sans une Rails::Application.
## On déclenche manuellement le hook on_load qu'elle aurait dû lancer
## pour étendre AR::Base avec les ClassMethods de la gem.
##============================================================##
ActiveSupport.on_load(:active_record) do
  extend ImmosquareActiveRecordChangeTracker::ClassMethods

  require "immosquare-active-record-change-tracker/models/history_record"
end

##============================================================##
## On reproduit le défaut Rails 5+ d'une vraie app (config par défaut
## générée avec rails new). Sans ça, belongs_to_required_by_default
## reste à nil et un test qui sauvegarde un modifier=nil passe alors
## qu'il crasherait dans une app hôte.
##============================================================##
ActiveRecord::Base.belongs_to_required_by_default = true

##============================================================##
## SQLite en mémoire pour tester les callbacks et la persistance
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
