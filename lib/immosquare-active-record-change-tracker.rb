##============================================================##
## Rails
##============================================================##
require_relative "immosquare-active-record-change-tracker/railtie"
require_relative "generators/immosquare-active-record-change-tracker/install/install_generator"


module ImmosquareActiveRecordChangeTracker
  extend ActiveSupport::Concern

  module ClassMethods
    ##============================================================##
    ## Can be improved with other gems like paranoia
    ##============================================================##
    def kept_in_db
      paranoid?
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
      ## Ajouter :dependent => :destroy si acts_as_paranoid n'est pas utilisé
      ## on se base sur paranoia_column car acts_as_paranoid répond true
      ## sur tous les modèles du temps que la gem est incluse
      ##============================================================##
      association_options[:dependent] = :destroy if !kept_in_db

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
      after_real_destroy(:delete_all_change_histories) if paranoid?
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
      history_options = self.class.history_options

      ##============================================================##
      ## Récupérer les champs à observer
      ##============================================================##
      changes_to_save =
        if history_options[:only].present?
          previous_changes.slice(*history_options[:only].map(&:to_s))
        else
          excluded_fields = history_options[:except] || []
          excluded_fields += [:created_at, :updated_at]
          previous_changes.except(*excluded_fields.uniq.map(&:to_s))
        end

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

      ##============================================================##
      ## Récupération du modificateur en exécutant le bloc s'il est défini
      ##============================================================##
      modifier = history_options[:modifier_block]&.call

      ##============================================================##
      ## Gestion de l'événement (create ou update)
      ##============================================================##
      event = previously_new_record? ? "create" : "update"

      ##============================================================##
      ## On crée un enregistrement dans la table d'historique
      ##============================================================##
      ImmosquareActiveRecordChangeTracker::HistoryRecord.create!(
        :recordable => self,
        :modifier   => modifier,
        :data       => changes_to_save,
        :event      => event,
        :created_at => DateTime.now
      )
    end

    ##============================================================##
    ## Stocker l'événement destroy que si la classe est paranoïaque
    ## Si on supprime définitivement de la db, on ne stocke pas l'historique
    ## de suppression
    ##============================================================##
    def delete_change_history
      return if !self.class.kept_in_db

      ##============================================================##
      ## Récupéreration du modificateur en exécutant le bloc s'il est défini
      ##============================================================##
      modifier = history_options[:modifier_block]&.call

      ##============================================================##
      ## On crée un enregistrement dans la table d'historique
      ##============================================================##
      ImmosquareActiveRecordChangeTracker::HistoryRecord.create!(
        :recordable => self,
        :modifier   => modifier,
        :data       => nil,
        :event      => "destroy",
        :created_at => DateTime.now
      )
    end
  end
end
