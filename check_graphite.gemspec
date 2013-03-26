# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "check_graphite/version"

Gem::Specification.new do |s|
  s.name        = "check_graphite"
  s.version     = CheckGraphite::VERSION
  s.authors     = ["Pierre-Yves Ritschard"]
  s.email       = ["pyr@spootnik.org"]
  s.homepage    = "https://github.com/pyr/check-graphite"
  s.summary     = %q{check_graphite}
  s.description = %q{check values from a graphite server}

  s.rubyforge_project = "check_graphite"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "nagios_check"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "fakeweb"
end
