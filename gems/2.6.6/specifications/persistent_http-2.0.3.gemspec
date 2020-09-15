# -*- encoding: utf-8 -*-
# stub: persistent_http 2.0.3 ruby lib

Gem::Specification.new do |s|
  s.name = "persistent_http".freeze
  s.version = "2.0.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Brad Pardee".freeze]
  s.date = "2018-12-20"
  s.description = "Persistent HTTP connections using a connection pool".freeze
  s.email = ["bradpardee@gmail.com".freeze]
  s.homepage = "http://github.com/bpardee/persistent_http".freeze
  s.rubygems_version = "3.1.3".freeze
  s.summary = "Persistent HTTP connections using a connection pool".freeze

  s.installed_by_version = "3.1.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<gene_pool>.freeze, [">= 1.3"])
  else
    s.add_dependency(%q<gene_pool>.freeze, [">= 1.3"])
  end
end
