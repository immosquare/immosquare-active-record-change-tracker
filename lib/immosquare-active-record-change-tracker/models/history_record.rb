module ImmosquareActiveRecordChangeTracker
  ##============================================================##
  ## On nome le modèle différemment que ApplicationRecordHistory
  ## pour éviter les conflits avec le nom du module.
  ##============================================================##
  class HistoryRecord < ::ActiveRecord::Base

    self.table_name = "active_record_change_trackers"

    belongs_to :recordable, :polymorphic => true
    belongs_to :modifier,   :polymorphic => true
    serialize :data, :coder => JSON

  end
end
