# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2025 Zerocracy
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

require 'haml_lint/rake_task'
require 'pgtk'
require 'pgtk/liquibase_task'
require 'pgtk/pgsql_task'
require 'pgtk/pool'
require 'qbash'
require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'rubygems'
require 'scss_lint/rake_task'
require 'shellwords'
require 'simplecov'
require 'xcop/rake_task'
require 'yaml'

ENV['RACK_RUN'] = 'true'

CLEAN.include 'coverage'
CLEAN.include 'target'

task default: %i[clean hypopg test benchmark dexter rubocop haml_lint scss_lint xcop config copyright]

Rake::TestTask.new(test: %i[pgsql liquibase]) do |t|
  Rake::Cleaner.cleanup_files(['coverage'])
  SimpleCov.start
  t.libs << 'lib' << 'test'
  t.pattern = 'test/**/test_*.rb'
  t.verbose = true
  t.warning = false
  t.options = ARGV.join(' ')
end

Rake::TestTask.new(benchmark: %i[pgsql liquibase]) do |t|
  t.libs << 'lib' << 'test'
  t.pattern = 'test/benchmark/bench_*.rb'
  t.verbose = true
  t.warning = false
end

HamlLint::RakeTask.new do |t|
  t.files = ['views/*.haml']
  t.quiet = false
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.fail_on_error = true
  t.requires << 'rubocop-rspec'
end

Pgtk::PgsqlTask.new(:pgsql) do |t|
  t.dir = 'target/pgsql'
  t.fresh_start = true
  t.quiet = true
  t.user = 'test'
  t.password = 'test'
  t.dbname = 'test'
  t.yaml = 'target/pgsql-config.yml'
  t.config = {
    log_min_duration_statement: 10,
    log_directory: File.absolute_path('./target'),
    logging_collector: 'on',
    log_filename: 'pgsql.log'
  }
end

Pgtk::LiquibaseTask.new(:liquibase) do |t|
  t.master = 'liquibase/master.xml'
  t.yaml = ['target/pgsql-config.yml', 'config.yml']
  t.quiet = true
  t.postgresql_version = '42.7.1'
  t.liquibase_version = '4.25.1'
end

Xcop::RakeTask.new(:xcop) do |t|
  t.license = 'LICENSE.txt'
  t.includes = ['**/*.xml', '**/*.xsl', '**/*.xsd', '**/*.html']
  t.excludes = ['target/**/*', 'coverage/**/*']
end

SCSSLint::RakeTask.new do |t|
  t.files = Dir.glob(['assets/scss/*.scss'])
end

desc 'Check the quality of config file'
task(:config) do
  f = 'config.yml'
  YAML.safe_load(File.open(f)).to_yaml if File.exist?(f)
end

task(hypopg: %i[pgsql liquibase]) do
  pgsql = Pgtk::Pool.new(
    Pgtk::Wire::Yaml.new(
      File.join(__dir__, 'target/pgsql-config.yml')
    )
  )
  pgsql.start(1)
  pgsql.exec('CREATE EXTENSION hypopg')
end

task(dexter: %i[hypopg benchmark]) do
  cfg = YAML.load_file(File.join(__dir__, 'target/pgsql-config.yml'))['pgsql']
  qbash(
    [
      'dexter',
      '-h', Shellwords.escape(cfg['host']),
      '-U', Shellwords.escape(cfg['user']),
      '-p', Shellwords.escape(cfg['port']),
      '-d', Shellwords.escape(cfg['dbname']),
      '--log-level=info',
      'target/pgsql.log'
    ],
    log: Loog::VERBOSE
  )
end

task(run: %i[pgsql liquibase]) do
  qbash("rerun -b 'RACK_ENV=test bundle exec ruby baza.rb'")
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
