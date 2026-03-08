# frozen_string_literal: true

require_relative "lib/lxdb/version"

Gem::Specification.new do |spec|
  spec.name = "lxdb"
  spec.version = Lxdb::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Lldb eXtended DeBugger - An enhanced debugger, built on lldb-ruby"
  spec.description = "A powerful, feature-rich debugger for CTF/Pwn, binary analysis, and C/C++ development. Built on top of lldb-ruby with colorful context display, heap inspection, and more."
  spec.homepage = "https://github.com/ydah/lxdb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("{lib,exe,themes}/**/*") + %w[Gemfile Rakefile lxdb.gemspec]
  spec.bindir = "exe"
  spec.executables = ["lxdb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "curses", "~> 1.4"
  spec.add_dependency "lldb", "~> 0.1"
  spec.add_dependency "logger"
  spec.add_dependency "reline", "~> 0.3"
end
