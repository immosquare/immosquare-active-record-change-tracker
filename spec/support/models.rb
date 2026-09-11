##============================================================##
## Test models — one per scenario, to isolate the options passed to
## track_active_record_changes, which are stored in a class_attribute.
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
## acts_as_paranoid must come BEFORE track_active_record_changes:
## the tracker reads paranoid? at macro-call time.
##============================================================##
class ParanoidArticle < ActiveRecord::Base

  acts_as_paranoid
  track_active_record_changes

end
