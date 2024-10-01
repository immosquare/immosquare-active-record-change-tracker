##============================================================##
## Rails
##============================================================##
require_relative "immosquare-active-record-change-tracker/railtie"
require_relative "generators/immosquare-active-record-change-tracker/install/install_generator"


module ImmosquareActiveRecordChangeTracker
  extend ActiveSupport::Concern

  module ClassMethods
    def track_active_record_changes(options = {}, &modifier_block)
      ##============================================================##
      ## Inclut les méthodes d'instance nécessaires
      ##============================================================##
      include(ImmosquareActiveRecordChangeTracker::InstanceMethods)

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
      ## Configure le callback after_save
      ##============================================================##
      after_save(:save_change_history)
      after_destroy(:delete_change_history)
    end
  end

  module InstanceMethods
    private

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
      ## Récupéreration du modificateur en exécutant le bloc s'il est défini
      ##============================================================##
      modifier = history_options[:modifier_block]&.call

      ##============================================================##
      ## Gestion de l'event
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
    ## Stocker l'évenement destroy
    ## Pas besoin de data, rien n'a changé.
    ##============================================================##
    def delete_change_history
      ##============================================================##
      ## Récupéreration du modificateur en exécutant le bloc s'il est défini
      ##============================================================##
      modifier = history_options[:modifier_block]&.call

      ##============================================================##
      ## Gestion de l'event
      ##============================================================##
      event = "destroy"

      ##============================================================##
      ## On crée un enregistrement dans la table d'historique
      ##============================================================##
      ImmosquareActiveRecordChangeTracker::HistoryRecord.create!(
        :recordable => self,
        :modifier   => modifier,
        :data       => {},
        :event      => event,
        :created_at => DateTime.now
      )
    end
  end
end
