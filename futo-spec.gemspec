Gem::Specification.new do |s|
  s.name        = 'futo-spec'
  s.version     = '0.1.0'
  s.date        = '2020-05-16'
  s.summary     = "Bullet points driven test framework"
  s.description = "Write your test notes in bullet point format, then map to test engine actions"
  s.authors     = ["Sean Felipe Wolfe"]
  s.email       = 'sean@addlightness.tech'
  s.files       = [
    "lib/core.rb",
    "lib/spec/basics.futo",
    "lib/spec/edge_cases.futo"
  ]
  #s.executable  = 'futo'
  s.homepage    = 'https://rubygems.org/gems/futo-spec'
  s.license     = 'MIT'

  s.add_runtime_dependency 'paint', '~> 2.2'
end
