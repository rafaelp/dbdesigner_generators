spec = Gem::Specification.new do |s| 
  s.name = "rafaelp-dbdesigner_generators"
  s.version = "0.1.2"
  s.date     = "2009-09-20"
  s.author = "Rafael Lima"
  s.email = "contato@rafael.adm.br"
  s.homepage = "http://rafael.adm.br/opensource/dbdesigner_generators"
  s.platform = Gem::Platform::RUBY
  s.summary = "Generates ActiveRecord Migration files from a DB Designer 4 xml file."
  s.files    = [
    "MIT-LICENSE",
    "Rakefile",
		"README.mkdn",
		"rails_generators/dbdesigner_migration/USAGE",
		"rails_generators/dbdesigner_migration/dbdesigner_migration_generator.rb",
		"rails_generators/dbdesigner_migration/templates/dbdesigner_migration.rb"
  ]
  s.test_files = [
    "test/test_helper.rb",
    "test/dbdesigner_migration_generator_test.rb"
  ]
  s.require_paths = ["."]
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.mkdn"]
  s.add_dependency("activerecord", ["> 0.0.0"])
end
