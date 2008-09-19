spec = Gem::Specification.new do |s| 
  s.name = "dbdesigner_migration_generator"
  s.version = "0.1.1"
  s.date     = "2009-09-19"
  s.author = "Rafael Lima"
  s.email = "contato@rafael.adm.br"
  s.homepage = "http://rafael.adm.br"
  s.platform = Gem::Platform::RUBY
  s.summary = "Generates ActiveRecord Migration files from a DB Designer 4 xml file."
  s.files    = [
    "MIT-LICENSE",
    "Rakefile",
		"README.mkdn", 
		"dbdesigner_migration_generator.rb",
		"templates/dbdesigner_migration.rb"
  ]
  s.test_files = [
    "test/test_helper.rb",
    "test/dbdesigner_migration_generator_test.rb"
  ]
  s.require_path = "."
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.mkdn"]
  s.add_dependency("activerecord", ["> 0.0.0"])
end
