# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{cap-rightscale}
  s.version = "0.3.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Satoshi Ohki"]
  s.date = %q{2011-02-03}
  s.description = %q{Capistrano extension that maps RightScale parameters to Roles.}
  s.email = %q{roothybrid7@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "cap-rightscale.gemspec",
    "features/cap-rightscale.feature",
    "features/step_definitions/cap-rightscale_steps.rb",
    "features/support/env.rb",
    "lib/cap-rightscale.rb",
    "lib/cap-rightscale/configuration.rb",
    "lib/cap-rightscale/configuration/rightscale.rb",
    "lib/cap-rightscale/configuration/rightscale/resource.rb",
    "lib/cap-rightscale/recipes.rb",
    "lib/cap-rightscale/recipes/rightscale.rb",
    "lib/cap-rightscale/recipes/rightscale/cache.rb",
    "lib/cap-rightscale/utils/rs_utils.rb",
    "rsapiconfig.yml.sample",
    "spec/cap-rightscale_spec.rb",
    "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/roothybrid7/cap-rightscale}
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.5.0}
  s.summary = %q{Capistrano extension that maps RightScale parameters to Roles}
  s.test_files = [
    "spec/cap-rightscale_spec.rb",
    "spec/spec_helper.rb"
  ]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>, ["~> 2.3.0"])
      s.add_development_dependency(%q<cucumber>, [">= 0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.5.2"])
      s.add_development_dependency(%q<rcov>, [">= 0"])
      s.add_runtime_dependency(%q<capistrano>, ["> 2.4"])
      s.add_runtime_dependency(%q<rightresource>, ["> 0.3.4"])
    else
      s.add_dependency(%q<rspec>, ["~> 2.3.0"])
      s.add_dependency(%q<cucumber>, [">= 0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.5.2"])
      s.add_dependency(%q<rcov>, [">= 0"])
      s.add_dependency(%q<capistrano>, ["> 2.4"])
      s.add_dependency(%q<rightresource>, ["> 0.3.4"])
    end
  else
    s.add_dependency(%q<rspec>, ["~> 2.3.0"])
    s.add_dependency(%q<cucumber>, [">= 0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.5.2"])
    s.add_dependency(%q<rcov>, [">= 0"])
    s.add_dependency(%q<capistrano>, ["> 2.4"])
    s.add_dependency(%q<rightresource>, ["> 0.3.4"])
  end
end

