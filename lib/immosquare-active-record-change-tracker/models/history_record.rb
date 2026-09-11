module ImmosquareActiveRecordChangeTracker
  ##============================================================##
  ## The model is deliberately not named ApplicationRecordHistory, to
  ## avoid clashing with the module name.
  ##============================================================##
  class HistoryRecord < ::ActiveRecord::Base

    self.table_name = "active_record_change_trackers"

    belongs_to :recordable, :polymorphic => true
    belongs_to :modifier,   :polymorphic => true, :optional => true
    serialize(:data, :coder => JSON)

  end
end
