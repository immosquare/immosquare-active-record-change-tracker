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
  ##============================================================##
  ## 2026-09-11: json 3 requires keyword arguments, while
  ## ActiveSupport::JSON.decode still calls JSON.parse(json, options)
  ## positionally. Deserializing a HistoryRecord `data` column then
  ## raises ArgumentError and the whole suite goes down. Drop this pin
  ## as soon as activesupport ships a version passing those options as
  ## keywords (nothing beyond 8.1.3.1 as of this date).
  ##============================================================##
  gem "json",      "< 3"
  gem "paranoia"
  gem "rspec"
  gem "simplecov",      :require => false
  gem "simplecov-lcov", :require => false
  gem "sqlite3"
end
