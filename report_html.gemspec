# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'report_html/version'

Gem::Specification.new do |spec|
  spec.name          = "report_html"
  spec.version       = ReportHtml::VERSION
  spec.authors       = ["seoanezonjic"]
  spec.email         = ["seoanezonjic@hotmail.com"]

  spec.summary       = %q{Gem to build html interactive reports.}
  spec.description   = %q{iDEPRECATED PROJECT. MIGRATED TO PYTHON: https://github.com/seoanezonjic/py_report_html\n.Html reports based on erb, HTML5 and javascript libraries.}
  spec.homepage      = ""
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
#  if spec.respond_to?(:metadata)
#    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
#  else
#    raise "RubyGems 2.0 or newer is required to protect against " \
#      "public gem pushes."
#  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
 # spec.add_development_dependency "rspec", "~> 3.0"
end
