##============================================================##
## Rails
##============================================================##
require_relative "immosquare-active-record-change-tracker/railtie"
require_relative "generators/immosquare-active-record-change-tracker/install/install_generator"


module ImmosquareActiveRecordChangeTracker
  extend ActiveSupport::Concern

  module ClassMethods
    ##============================================================##
    ## True si le modèle hôte utilise paranoia (acts_as_paranoid).
    ## La gem paranoia est optionnelle : si elle n'est pas chargée,
    ## paranoid? n'existe pas — d'où le respond_to?.
    ##============================================================##
    def kept_in_db?
      respond_to?(:paranoid?) && paranoid?
    end

    def track_active_record_changes(options = {}, &modifier_block)
      ##============================================================##
      ## Inclut les méthodes d'instance nécessaires
      ##============================================================##
      include(ImmosquareActiveRecordChangeTracker::InstanceMethods)

      ##============================================================##
      ## Construire dynamiquement les options de l'association
      ##============================================================##
      association_options = {
        :as         => :recordable,
        :class_name => "ImmosquareActiveRecordChangeTracker::HistoryRecord"
      }

      ##============================================================##
      ## Ajouter :dependent => :destroy si acts_as_paranoid n'est pas utilisé.
      ## Avec paranoia on garde l'historique au soft-delete et on le
      ## nettoie via after_real_destroy.
      ##============================================================##
      association_options[:dependent] = :destroy if !kept_in_db?

      ##============================================================##
      ## Ajout de l'association has_many :history_records
      ##============================================================##
      has_many(:history_records, -> { order(:created_at => :desc) }, **association_options)

      ##============================================================##
      ## Stocker les options dans un attribut de classe
      ##============================================================##
      class_attribute(:history_options)
      self.history_options = options

      ##============================================================##
      ## Stocker le bloc du modificateur s'il est fourni
      ##============================================================##
      history_options[:modifier_block] = modifier_block if block_given?

      ##============================================================##
      ## Configure le callback after_save et after_destroy
      ##============================================================##
      after_save(:save_change_history)
      after_destroy(:delete_change_history)
      after_real_destroy(:delete_all_change_histories) if kept_in_db?
    end
  end

  module InstanceMethods
    private


    def delete_all_change_histories
      history_records.destroy_all
    end

    ##============================================================##
    ## Stocker les changements après un create ou save ou update
    ##============================================================##
    def save_change_history
      options = self.class.history_options

      ##============================================================##
      ## Récupérer les champs à observer
      ##============================================================##
      changes_to_save =
        if options[:only].present?
          previous_changes.slice(*options[:only].map(&:to_s))
        else
          excluded_fields = options[:except] || []
          excluded_fields += [:created_at, :updated_at]
          previous_changes.except(*excluded_fields.uniq.map(&:to_s))
        end

      ##============================================================##
      ## On regarde si jamais ce que l'on essaye de sauvegarder contient
      ## des valeurs identiques. Doit s'exécuter AVANT le merge Globalize :
      ## les entrées de traduction sont des hash {locale => diff} qui ne
      ## ressemblent pas à un [old, new] et casseraient l'indexation.
      ## ex: quand on met true dans un integer, rails le convertit
      ## automatiquement en 1 si le champ était déjà en bdd
      ## -> {"cellar"=>[1, 1]} ou {"cellar"=>[0, 0]}
      ##============================================================##
      changes_to_save = changes_to_save.reject {|_k, change_array| change_array[0] == change_array[1] }

      ##============================================================##
      ## Gestion de Globalize
      ##============================================================##
      if respond_to?(:translated_attribute_names)
        translated_attribute_names = send(:translated_attribute_names).map(&:to_sym)
        globalize_changes          = {}

        translations.each do |translation|
          locale = translation.locale.to_sym
          translation.previous_changes.each do |attribute, values|
            attribute = attribute.to_sym
            next if !attribute.in?(translated_attribute_names)

            old_value, new_value = values
            ##============================================================##
            ## On ne sauvegarde pas les changements si les valeurs sont identiques
            ## ou si on passe de nil à "" ou de "" à nil
            ##============================================================##
            next if old_value == new_value || (old_value.blank? && new_value.blank?)

            globalize_changes[attribute] ||= {}
            globalize_changes[attribute][locale] = [old_value, new_value]
          end
        end
        changes_to_save.merge!(globalize_changes)
      end

      ##============================================================##
      ## Si aucun changement à sauvegarder, on sort
      ##============================================================##
      return if changes_to_save.none?

      write_history_record(:event => previously_new_record? ? "create" : "update", :data => changes_to_save)
    end

    ##============================================================##
    ## Stocker l'événement destroy que si la classe est paranoïaque
    ## Si on supprime définitivement de la db, on ne stocke pas l'historique
    ## de suppression
    ##============================================================##
    def delete_change_history
      return if !self.class.kept_in_db?

      write_history_record(:event => "destroy", :data => nil)
    end

    ##============================================================##
    ## Écrit une entrée dans la table d'historique. Le modifier est
    ## résolu à la volée via le bloc passé à track_active_record_changes
    ## (souvent un Current.user/admin).
    ##============================================================##
    def write_history_record(event:, data:)
      ImmosquareActiveRecordChangeTracker::HistoryRecord.create!(
        :recordable => self,
        :modifier   => self.class.history_options[:modifier_block]&.call,
        :data       => data,
        :event      => event,
        :created_at => Time.current
      )
    end
  end
end
