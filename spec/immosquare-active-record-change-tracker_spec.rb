require "spec_helper"

##============================================================##
## bundle exec rspec spec/immosquare-active-record-change-tracker_spec.rb
##============================================================##
RSpec.describe(ImmosquareActiveRecordChangeTracker) do
  let(:history) { ImmosquareActiveRecordChangeTracker::HistoryRecord }

  describe("tracking par défaut") do
    it("log un événement create avec les attributs renseignés") do
      article = DefaultArticle.create!(:title => "Hello", :content => "World")
      record  = history.last

      expect(record.event).to(eq("create"))
      expect(record.recordable).to(eq(article))
      expect(record.data).to(have_key("title"))
      expect(record.data["title"].last).to(eq("Hello"))
      expect(record.data["content"].last).to(eq("World"))
    end

    it("log un événement update avec uniquement le diff") do
      article = DefaultArticle.create!(:title => "Hello", :content => "World")
      article.update!(:title => "Hi")
      record = history.where(:event => "update").last

      expect(record.data).to(eq({"title" => ["Hello", "Hi"]}))
    end

    it("exclut created_at et updated_at par défaut") do
      DefaultArticle.create!(:title => "Hello")
      record = history.last

      expect(record.data).not_to(have_key("created_at"))
      expect(record.data).not_to(have_key("updated_at"))
    end

    it("ne crée aucune entrée quand previous_changes est vide") do
      article = DefaultArticle.create!(:title => "Hello")
      expect { article.save! }.not_to(change { history.count })
    end

    it("supprime l'historique au hard destroy (pas de paranoia)") do
      article = DefaultArticle.create!(:title => "Hello")
      article.update!(:title => "Hi")
      expect(history.where(:recordable_type => "DefaultArticle", :recordable_id => article.id).count).to(eq(2))

      article.destroy!
      expect(history.where(:recordable_type => "DefaultArticle", :recordable_id => article.id).count).to(eq(0))
    end
  end

  describe("option :only") do
    it("ne tracke que les attributs listés") do
      OnlyArticle.create!(:title => "Hello", :content => "World", :views => 5)
      record = history.last

      expect(record.data.keys).to(eq(["title"]))
    end
  end

  describe("option :except") do
    it("exclut les attributs listés en plus de created_at/updated_at") do
      ExceptArticle.create!(:title => "Hello", :views => 5)
      record = history.last

      expect(record.data).to(have_key("title"))
      expect(record.data).not_to(have_key("views"))
      expect(record.data).not_to(have_key("created_at"))
    end
  end

  describe("bloc modifier") do
    it("capture le modifier renvoyé par le bloc") do
      author = Author.create!(:name => "Alice")
      Thread.current[:test_modifier] = author

      ModifierArticle.create!(:title => "Hello")

      expect(history.last.modifier).to(eq(author))
    end

    it("stocke un modifier null si le bloc retourne nil") do
      Thread.current[:test_modifier] = nil
      ModifierArticle.create!(:title => "Hello")

      expect(history.last.modifier).to(be_nil)
    end
  end

  describe(".kept_in_db?") do
    it("retourne false quand le modèle n'utilise pas acts_as_paranoid") do
      expect(DefaultArticle.kept_in_db?).to(eq(false))
    end

    it("retourne true quand le modèle utilise acts_as_paranoid") do
      expect(ParanoidArticle.kept_in_db?).to(eq(true))
    end
  end

  describe("filtre des valeurs identiques") do
    ##============================================================##
    ## Cible directement la branche line ~128 :
    ## changes_to_save.reject {|_k, v| v[0] == v[1] }.
    ## On stub previous_changes pour simuler le cas "true → 1"
    ## après typecast Rails (impossible à reproduire de façon
    ## déterministe avec un update! sur sqlite).
    ##============================================================##
    it("n'enregistre pas un changement quand l'ancienne et la nouvelle valeur sont égales") do
      article = DefaultArticle.create!(:title => "Hello")
      history.delete_all

      allow(article).to(receive(:previous_changes).and_return({"published" => [1, 1]}))
      article.send(:save_change_history)

      expect(history.count).to(eq(0))
    end
  end

  describe("intégration paranoia") do
    it("log un événement destroy au soft-delete et conserve l'historique create/update") do
      article = ParanoidArticle.create!(:title => "Hello")
      article.update!(:title => "Hi")
      article.destroy

      records = history.where(:recordable_type => "ParanoidArticle", :recordable_id => article.id)
      expect(records.pluck(:event)).to(match_array(["create", "update", "destroy"]))
    end

    it("supprime tout l'historique au really_destroy!") do
      article = ParanoidArticle.create!(:title => "Hello")
      article.update!(:title => "Hi")
      article.really_destroy!

      expect(history.where(:recordable_type => "ParanoidArticle", :recordable_id => article.id).count).to(eq(0))
    end
  end

  describe("intégration Globalize (stubs)") do
    ##============================================================##
    ## Globalize n'est pas chargée dans la suite ; on simule la
    ## surface utilisée par save_change_history (translations +
    ## translated_attribute_names) pour valider le merge des diffs
    ## de traduction dans data.
    ##============================================================##
    it("merge les changements de traductions dans data, indexés par locale") do
      article          = DefaultArticle.create!(:title => "Hello")
      fake_translation = Struct.new(:locale, :previous_changes).new(:fr, {"title" => ["Bonjour", "Salut"]})
      history.delete_all

      article.define_singleton_method(:translated_attribute_names) { [:title] }
      article.define_singleton_method(:translations) { [fake_translation] }

      article.update!(:content => "World")

      ##============================================================##
      ## data passe par JSON (serialize :data, :coder => JSON), donc
      ## les symboles deviennent des strings au round-trip.
      ##============================================================##
      record = history.last
      expect(record.data["title"]["fr"]).to(eq(["Bonjour", "Salut"]))
    end

    it("ignore les changements de traduction où old et new sont blank (nil ↔ \"\")") do
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
