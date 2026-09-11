require "spec_helper"

##============================================================##
## bundle exec rspec spec/immosquare-active-record-change-tracker_spec.rb
##============================================================##
RSpec.describe(ImmosquareActiveRecordChangeTracker) do
  let(:history) { ImmosquareActiveRecordChangeTracker::HistoryRecord }

  describe("default tracking") do
    it("logs a create event with the assigned attributes") do
      article = DefaultArticle.create!(:title => "Hello", :content => "World")
      record  = history.last

      expect(record.event).to(eq("create"))
      expect(record.recordable).to(eq(article))
      expect(record.data).to(have_key("title"))
      expect(record.data["title"].last).to(eq("Hello"))
      expect(record.data["content"].last).to(eq("World"))
    end

    it("logs an update event holding the diff only") do
      article = DefaultArticle.create!(:title => "Hello", :content => "World")
      article.update!(:title => "Hi")
      record = history.where(:event => "update").last

      expect(record.data).to(eq({"title" => ["Hello", "Hi"]}))
    end

    it("excludes created_at and updated_at by default") do
      DefaultArticle.create!(:title => "Hello")
      record = history.last

      expect(record.data).not_to(have_key("created_at"))
      expect(record.data).not_to(have_key("updated_at"))
    end

    it("writes no row when previous_changes is empty") do
      article = DefaultArticle.create!(:title => "Hello")
      expect { article.save! }.not_to(change { history.count })
    end

    it("deletes the history on a hard destroy (no paranoia)") do
      article = DefaultArticle.create!(:title => "Hello")
      article.update!(:title => "Hi")
      expect(history.where(:recordable_type => "DefaultArticle", :recordable_id => article.id).count).to(eq(2))

      article.destroy!
      expect(history.where(:recordable_type => "DefaultArticle", :recordable_id => article.id).count).to(eq(0))
    end
  end

  describe(":only option") do
    it("tracks the listed attributes only") do
      OnlyArticle.create!(:title => "Hello", :content => "World", :views => 5)
      record = history.last

      expect(record.data.keys).to(eq(["title"]))
    end
  end

  describe(":except option") do
    it("excludes the listed attributes on top of created_at/updated_at") do
      ExceptArticle.create!(:title => "Hello", :views => 5)
      record = history.last

      expect(record.data).to(have_key("title"))
      expect(record.data).not_to(have_key("views"))
      expect(record.data).not_to(have_key("created_at"))
    end
  end

  describe("modifier block") do
    it("captures the modifier returned by the block") do
      author = Author.create!(:name => "Alice")
      Thread.current[:test_modifier] = author

      ModifierArticle.create!(:title => "Hello")

      expect(history.last.modifier).to(eq(author))
    end

    it("stores a null modifier when the block returns nil") do
      Thread.current[:test_modifier] = nil
      ModifierArticle.create!(:title => "Hello")

      expect(history.last.modifier).to(be_nil)
    end
  end

  describe(".kept_in_db?") do
    it("returns false when the model does not use acts_as_paranoid") do
      expect(DefaultArticle.kept_in_db?).to(eq(false))
    end

    it("returns true when the model uses acts_as_paranoid") do
      expect(ParanoidArticle.kept_in_db?).to(eq(true))
    end
  end

  describe("identical value filtering") do
    ##============================================================##
    ## Targets the changes_to_save.reject {|_k, v| v[0] == v[1] }
    ## branch directly.
    ## previous_changes is stubbed to simulate the "true -> 1" case
    ## after the Rails typecast, which cannot be reproduced
    ## deterministically with an update! on sqlite.
    ##============================================================##
    it("does not record a change whose old and new values are equal") do
      article = DefaultArticle.create!(:title => "Hello")
      history.delete_all

      allow(article).to(receive(:previous_changes).and_return({"published" => [1, 1]}))
      article.send(:save_change_history)

      expect(history.count).to(eq(0))
    end
  end

  describe("paranoia integration") do
    it("logs a destroy event on soft-delete and keeps the create/update history") do
      article = ParanoidArticle.create!(:title => "Hello")
      article.update!(:title => "Hi")
      article.destroy

      records = history.where(:recordable_type => "ParanoidArticle", :recordable_id => article.id)
      expect(records.pluck(:event)).to(match_array(["create", "update", "destroy"]))
    end

    it("deletes the whole history on really_destroy!") do
      article = ParanoidArticle.create!(:title => "Hello")
      article.update!(:title => "Hi")
      article.really_destroy!

      expect(history.where(:recordable_type => "ParanoidArticle", :recordable_id => article.id).count).to(eq(0))
    end
  end

  describe("Globalize integration (stubbed)") do
    ##============================================================##
    ## Globalize is not loaded in the suite: the surface
    ## save_change_history relies on (translations +
    ## translated_attribute_names) is faked, to check that translation
    ## diffs are merged into data.
    ##============================================================##
    it("merges translation changes into data, indexed by locale") do
      article          = DefaultArticle.create!(:title => "Hello")
      fake_translation = Struct.new(:locale, :previous_changes).new(:fr, {"title" => ["Bonjour", "Salut"]})
      history.delete_all

      article.define_singleton_method(:translated_attribute_names) { [:title] }
      article.define_singleton_method(:translations) { [fake_translation] }

      article.update!(:content => "World")

      ##============================================================##
      ## data goes through JSON (serialize :data, :coder => JSON), so
      ## symbols come back as strings after the round-trip.
      ##============================================================##
      record = history.last
      expect(record.data["title"]["fr"]).to(eq(["Bonjour", "Salut"]))
    end

    it("ignores translation changes where old and new are blank (nil <-> \"\")") do
      article          = DefaultArticle.create!(:title => "Hello")
      fake_translation = Struct.new(:locale, :previous_changes).new(:fr, {"title" => [nil, ""]})
      history.delete_all

      article.define_singleton_method(:translated_attribute_names) { [:title] }
      article.define_singleton_method(:translations) { [fake_translation] }

      article.update!(:content => "World")

      record = history.last
      expect(record.data).not_to(have_key("title"))
    end
  end
end
