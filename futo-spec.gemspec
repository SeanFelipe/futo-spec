Gem::Specification.new do |s|
  s.name        = 'futo-spec'
  s.version     = '0.3.15'
  s.date        = '2020-09-21'
  s.summary     = "Test engine using bullet points. Like you're writing on an envelope."
  s.description = "Write your test notes in bullet point format, then map to test engine actions. Like Cucumber, but * - >  instead of Gherkin."
  s.authors     = ["Sean Felipe Wolfe"]
  s.email       = 'sean@addlightness.tech'
  s.files       = Dir[
                    'bin/futo',
                    'lib/**/*.rb',
                    'lib/futo-spec/spec/*.futo',
                    'lib/futo-spec/spec/**/*.chizu',
                  ]
  s.homepage    = 'https://rubygems.org/gems/futo-spec'
  s.license     = 'MIT'

  s.executables << 'futo'

  s.add_runtime_dependency 'paint', '~> 2.2'
  s.add_runtime_dependency 'rspec', '~> 3.9'
  s.add_runtime_dependency 'rspec-expectations', '~> 3.9'
  s.add_development_dependency 'byebug', '~> 11.1'
end
