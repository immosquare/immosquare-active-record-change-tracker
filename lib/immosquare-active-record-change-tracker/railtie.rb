require "rails"

module ImmosquareActiveRecordChangeTracker
  class Railtie < Rails::Railtie

    initializer "immosquare_active_record_change_tracker.active_record" do
      ActiveSupport.on_load(:active_record) do
        ##============================================================##
        ## Expose the change-tracking macro on every model
        ##============================================================##
        extend ImmosquareActiveRecordChangeTracker::ClassMethods

        ##============================================================##
        ## Define the HistoryRecord class once ActiveRecord is loaded
        ##============================================================##
        require "immosquare-active-record-change-tracker/models/history_record"
      end
    end

  end
end
