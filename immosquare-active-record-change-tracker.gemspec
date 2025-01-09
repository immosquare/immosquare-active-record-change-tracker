require_relative "lib/immosquare-active-record-change-tracker/version"


Gem::Specification.new do |spec|
  spec.platform      = Gem::Platform::RUBY
  spec.license       = "MIT"
  spec.name          = "immosquare-active-record-change-tracker"
  spec.version       = ImmosquareActiveRecordChangeTracker::VERSION.dup

  spec.authors       = ["immosquare"]
  spec.email         = ["jules@immosquare.com"]
  spec.homepage      = "https://github.com/immosquare/immosquare-active-record-change-tracker"

  spec.summary       = "ActiveRecord Change Tracker"
  spec.description   = "A gem to track changes on ActiveRecord models"


  spec.files         = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = Gem::Requirement.new(">= 3.1.6")
end
