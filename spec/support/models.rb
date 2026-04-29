##============================================================##
## Modèles de tests — un par scénario pour isoler les options
## passées à track_active_record_changes (stockées via class_attribute).
##============================================================##
class Author < ActiveRecord::Base
end

class DefaultArticle < ActiveRecord::Base

  track_active_record_changes

end

class OnlyArticle < ActiveRecord::Base

  track_active_record_changes(:only => [:title])

end

class ExceptArticle < ActiveRecord::Base

  track_active_record_changes(:except => [:views])

end

class ModifierArticle < ActiveRecord::Base

  track_active_record_changes do
    Thread.current[:test_modifier]
  end

end

##============================================================##
## acts_as_paranoid AVANT track_active_record_changes :
## le tracker lit paranoid? au moment du macro-call.
##============================================================##
class ParanoidArticle < ActiveRecord::Base

  acts_as_paranoid
  track_active_record_changes

end
