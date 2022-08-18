require_relative "lib/log_sense/version"

Gem::Specification.new do |spec|
  spec.name          = "log_sense"
  spec.version       = LogSense::VERSION
  spec.authors       = ["Adolfo Villafiorita"]
  spec.email         = ["adolfo@shair.tech"]

  spec.summary       = %q{Generate analytics for Apache and Rails log file.}
  spec.description   = %q{Generate analytics in HTML, txt, and SQLite format for Apache and Rails log files.}
  spec.homepage      = "https://github.com/shair-tech/log_sense/log_sense"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.9")

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/shair-tech/log_sense/"
  spec.metadata["changelog_uri"] = "https://github.com/shair-tech/log_sense/blob/main/CHANGELOG.org"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "browser"
  spec.add_dependency "ipaddr"
  spec.add_dependency "iso_country_codes"
  spec.add_dependency "sqlite3"
  spec.add_dependency "terminal-table"

  spec.add_development_dependency "debug"
  spec.add_development_dependency "minitest"
end
