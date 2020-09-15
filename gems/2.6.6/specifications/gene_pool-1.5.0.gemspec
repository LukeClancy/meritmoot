# -*- encoding: utf-8 -*-
# stub: gene_pool 1.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "gene_pool".freeze
  s.version = "1.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Brad Pardee".freeze]
  s.date = "2019-02-14"
  s.description = "Threadsafe, performant library for managing pools of resources, such as connections.".freeze
  s.email = ["bradpardee@gmail.com".freeze]
  s.homepage = "http://github.com/bpardee/gene_pool".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.3".freeze
  s.summary = "Highly performant Ruby connection pooling library.".freeze

  s.installed_by_version = "3.1.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<concurrent-ruby>.freeze, [">= 1.0"])
  else
    s.add_dependency(%q<concurrent-ruby>.freeze, [">= 1.0"])
  end
end
