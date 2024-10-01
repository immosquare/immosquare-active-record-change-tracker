require "rails"

module ImmosquareActiveRecordChangeTracker
  class Railtie < Rails::Railtie

    initializer "immosquare_active_record_change_tracker.active_record" do
      ActiveSupport.on_load(:active_record) do
        ##============================================================##
        ## Pour ajouter une gestion de l'historique des modifications
        ##============================================================##
        extend ImmosquareActiveRecordChangeTracker::ClassMethods

        ##============================================================##
        ## Définir la classe HistoryRecord après le chargement d'ActiveRecord
        ##============================================================##
        require "immosquare-active-record-change-tracker/models/history_record"
      end
    end

  end
end
