# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'rubygems'
require 'rake'
require 'rake/clean'
require 'yaml'

ENV['RACK_RUN'] = 'true'

# In order to use any of the following options, you must run rake like this:
#   rake -- --live=my.yml
# Pay attention to the double dash that splits "rake" and the list of options.
ARGV.each do |a|
  opt, value = a.split('=', 2)
  if opt == '--live'
    # It is used in test__helper.rb, in the "fake_live_cfg" function:
    ENV['RACK_LIVE_YAML_FILE'] = value
  end
end

task default: %i[clean test rubocop scss_lint xcop config copyright]

require 'rake/testtask'
Rake::TestTask.new(test: %i[pgsql liquibase]) do |test|
  Rake::Cleaner.cleanup_files(['coverage'])
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
  test.warning = false
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = true
  task.requires << 'rubocop-rspec'
end

require 'pgtk/pgsql_task'
Pgtk::PgsqlTask.new(:pgsql) do |t|
  t.dir = 'target/pgsql'
  t.fresh_start = true
  t.user = 'test'
  t.password = 'test'
  t.dbname = 'test'
  t.yaml = 'target/pgsql-config.yml'
end

require 'pgtk/liquibase_task'
Pgtk::LiquibaseTask.new(:liquibase) do |t|
  t.master = 'liquibase/master.xml'
  t.yaml = ['target/pgsql-config.yml', 'config.yml']
  t.quiet = true
  t.postgresql_version = '42.7.1'
  t.liquibase_version = '4.25.1'
end

require 'xcop/rake_task'
Xcop::RakeTask.new(:xcop) do |task|
  task.license = 'LICENSE.txt'
  task.includes = ['**/*.xml', '**/*.xsl', '**/*.xsd', '**/*.html']
  task.excludes = ['target/**/*', 'coverage/**/*']
end

require 'scss_lint/rake_task'
SCSSLint::RakeTask.new do |t|
  t.files = Dir.glob(['assets/scss/*.scss'])
end

desc 'Check the quality of config file'
task(:config) do
  f = 'config.yml'
  YAML.safe_load(File.open(f)).to_yaml if File.exist?(f)
end

task(run: %i[pgsql liquibase]) do
  `rerun -b "RACK_ENV=test bundle exec ruby baza.rb"`
end

task(:copyright) do
  sh "grep -q -r '2009-#{Date.today.strftime('%Y')}' \
    --include '*.yml' \
    --include '*.scss' \
    --include '*.haml' \
    --include '*.rb' \
    --include '*.txt' \
    --include 'Rakefile' \
    ."
end
