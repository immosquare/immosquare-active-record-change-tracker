ActiveRecord::Schema.define do
  ##============================================================##
  ## Table shipped by the gem (mirrors the generated migration)
  ##============================================================##
  create_table(:active_record_change_trackers, :force => true) do |t|
    t.references(:recordable, :polymorphic => true, :null => false, :index => true)
    t.references(:modifier,   :polymorphic => true, :null => true,  :index => true)
    t.string(:event, :limit => 10)
    t.text(:data)
    t.datetime(:created_at, :null => false)
  end

  ##============================================================##
  ## Fixture tables — one per scenario, to isolate the
  ## track_active_record_changes options, which are stored at the
  ## class level.
  ##============================================================##
  [:default_articles, :only_articles, :except_articles, :modifier_articles].each do |table_name|
    create_table(table_name, :force => true) do |t|
      t.string(:title)
      t.text(:content)
      t.integer(:views, :default => 0)
      t.boolean(:published, :default => false)
      t.timestamps
    end
  end

  ##============================================================##
  ## Table for the paranoid fixture (paranoia requires deleted_at)
  ##============================================================##
  create_table(:paranoid_articles, :force => true) do |t|
    t.string(:title)
    t.text(:content)
    t.datetime(:deleted_at)
    t.timestamps
  end

  create_table(:authors, :force => true) do |t|
    t.string(:name)
    t.timestamps
  end
end
