class <%= "#{migration_name} < ActiveRecord::Migration#{migration_version}" %>

  def change
    create_table(:active_record_change_trackers) do |t|
      t.references(:recordable, :polymorphic => true, :foreign_key => false, :index => false, :null => false)
      t.references(:modifier, :polymorphic => true, :foreign_key => false, :index => false, :null => true)
      t.string(:event, :null => false, :limit => 10)
      t.text(:data, :null => false, :limit => 4_294_967_295)
      t.datetime(:created_at, :null => false)
    end

    add_index(:active_record_change_trackers, [:recordable_type, :recordable_id])
    add_index(:active_record_change_trackers, [:modifier_type, :modifier_id])
  end

end
