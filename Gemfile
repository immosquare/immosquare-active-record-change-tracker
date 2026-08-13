source "https://rubygems.org"

gemspec

group :development do
  gem "bundler"
  gem "immosquare-cleaner"
  gem "rake"
  ##============================================================##
  ## Language Server Protocol : https://shopify.github.io/ruby-lsp/
  ##============================================================##
  gem "ruby-lsp"
end

##============================================================##
## Anything the specs need belongs here and not in :development,
## which the CI skips (cf. bin/ci). paranoia and sqlite3 are not
## dev comfort: the specs boot a real ActiveRecord against them.
##============================================================##
group :test do
  gem "paranoia"
  gem "rspec"
  gem "simplecov",      :require => false
  gem "simplecov-lcov", :require => false
  gem "sqlite3"
end
