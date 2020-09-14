Gem::Specification.new do |s|
  s.name        = 'futo-spec'
  s.version     = '0.1.2'
  s.date        = '2020-09-14'
  s.summary     = "Test engine using bullet points. Like you're writing on an envelope."
  s.description = "Write your test notes in bullet point format, then map to test engine actions. Like Cucumber, but * - >  instead of Gherkin."
  s.authors     = ["Sean Felipe Wolfe"]
  s.email       = 'sean@addlightness.tech'
  s.files       = Dir['lib/**/*.rb', 'lib/spec/*.futo', 'lib/spec/**/*.chizu'] + 'bin/futo'
  s.homepage    = 'https://rubygems.org/gems/futo-spec'
  s.license     = 'MIT'

  s.executables << 'futo'

  s.add_runtime_dependency 'paint', '~> 2.2'
  s.add_runtime_dependency 'apparition'
  s.add_runtime_dependency 'selenium-webdriver', '~> 3.1'
  s.add_runtime_dependency 'capybara', '~> 3.3'
  s.add_runtime_dependency 'rspec-expectations', '~> 3.9'
  s.add_development_dependency 'byebug', '~> 11.1'
end
