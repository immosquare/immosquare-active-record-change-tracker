##============================================================##
## Rails
##============================================================##
require_relative "immosquare-active-record-change-tracker/railtie"
require_relative "generators/immosquare-active-record-change-tracker/install/install_generator"


module ImmosquareActiveRecordChangeTracker
  extend ActiveSupport::Concern

  module ClassMethods
    ##============================================================##
    ## True when the host model uses paranoia (acts_as_paranoid).
    ## The paranoia gem is optional: when it is not loaded, paranoid?
    ## does not exist — hence the respond_to?.
    ##============================================================##
    def kept_in_db?
      respond_to?(:paranoid?) && paranoid?
    end

    def track_active_record_changes(options = {}, &modifier_block)
      ##============================================================##
      ## Pull in the instance methods the tracking relies on
      ##============================================================##
      include(ImmosquareActiveRecordChangeTracker::InstanceMethods)

      ##============================================================##
      ## Build the association options dynamically
      ##============================================================##
      association_options = {
        :as         => :recordable,
        :class_name => "ImmosquareActiveRecordChangeTracker::HistoryRecord"
      }

      ##============================================================##
      ## Add :dependent => :destroy unless acts_as_paranoid is in use.
      ## With paranoia the history survives a soft-delete and is cleaned
      ## up through after_real_destroy instead.
      ##============================================================##
      association_options[:dependent] = :destroy if !kept_in_db?

      ##============================================================##
      ## Declare the has_many :history_records association
      ##============================================================##
      has_many(:history_records, -> { order(:created_at => :desc) }, **association_options)

      ##============================================================##
      ## Keep the options in a class attribute
      ##============================================================##
      class_attribute(:history_options)
      self.history_options = options

      ##============================================================##
      ## Keep the modifier block when one is given
      ##============================================================##
      history_options[:modifier_block] = modifier_block if block_given?

      ##============================================================##
      ## Wire the after_save and after_destroy callbacks
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
    ## Record the changes after a create, save or update
    ##============================================================##
    def save_change_history
      options = self.class.history_options

      ##============================================================##
      ## Pick the fields to watch
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
      ## Drop entries whose old and new values are equal. This must run
      ## BEFORE the Globalize merge: translation entries are
      ## {locale => diff} hashes, which do not look like an [old, new]
      ## pair and would break the indexing.
      ## e.g. assigning true to an integer column already stored in the
      ## database: Rails casts it to 1
      ## -> {"cellar"=>[1, 1]} or {"cellar"=>[0, 0]}
      ##============================================================##
      changes_to_save = changes_to_save.reject {|_k, change_array| change_array[0] == change_array[1] }

      ##============================================================##
      ## Globalize support
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
            ## Skip changes whose values are equal, and those moving from
            ## nil to "" or from "" to nil
            ##============================================================##
            next if old_value == new_value || (old_value.blank? && new_value.blank?)

            globalize_changes[attribute] ||= {}
            globalize_changes[attribute][locale] = [old_value, new_value]
          end
        end
        changes_to_save.merge!(globalize_changes)
      end

      ##============================================================##
      ## Nothing left to record
      ##============================================================##
      return if changes_to_save.none?

      write_history_record(:event => previously_new_record? ? "create" : "update", :data => changes_to_save)
    end

    ##============================================================##
    ## Only record a destroy event for a paranoid class. A hard delete
    ## wipes the row for good, so there is no history to write.
    ##============================================================##
    def delete_change_history
      return if !self.class.kept_in_db?

      write_history_record(:event => "destroy", :data => nil)
    end

    ##============================================================##
    ## Write one row in the history table. The modifier is resolved on
    ## the fly through the block given to track_active_record_changes
    ## (usually a Current.user/admin).
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
