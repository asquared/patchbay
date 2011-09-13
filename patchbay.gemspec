Gem::Specification.new do |s|
    s.name              = "patchbay"
    s.version           = "0.0.1.pre3"
    s.date              = "2011-09-13"
    s.summary           = "Embed HTTP APIs in non-web apps easily"
    s.description       = <<EOT
Patchbay is the web framework for non-web apps. 
It's designed for simplicity, minimalism, and easy integration.
EOT
    s.authors           = ["Andrew Armenia"]
    s.email             = "andrew@asquaredlabs.com"
    s.files             = ["lib/patchbay.rb"]
    s.homepage          = "http://rubygems.org/gems/patchbay"

    s.add_runtime_dependency "rack", [">= 1.3.0"]
end
