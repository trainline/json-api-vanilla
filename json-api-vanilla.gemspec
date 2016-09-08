# Copyright © Trainline.com Limited. All rights reserved. See LICENSE.txt in the project root for license information.
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'json-api-vanilla/version'

Gem::Specification.new do |s|
  s.name        = 'json-api-vanilla'
  s.license     = 'Apache-2.0'
  s.version     = JSON::Api::Vanilla::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Thaddée Tyl']
  s.email       = ['thaddee.tyl@gmail.com']
  s.homepage    = 'http://github.com/trainline/json-api-vanilla'
  s.summary     = %q{Deserialize JSON API formats into vanilla Ruby objects.}
  s.description = %q{Given a JSON API string, we parse it and return a document that can be browsed — as if the objects defined in the file were plain old Ruby objects.}
  s.files       = `git ls-files`.split("\n")
end
