# Copyright © Trainline Limited, 2016. All rights reserved. See LICENSE.txt in the project root for license information.
$:.push File.expand_path("../lib", __FILE__)

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task default: :spec
