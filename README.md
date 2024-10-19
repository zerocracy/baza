# Zerocracy Meeting Point

[![EO principles respected here](https://www.elegantobjects.org/badge.svg)](https://www.elegantobjects.org)
[![DevOps By Rultor.com](http://www.rultor.com/b/zerocracy/baza)](http://www.rultor.com/p/zerocracy/baza)

[![rake](https://github.com/zerocracy/baza/actions/workflows/rake.yml/badge.svg)](https://github.com/zerocracy/baza/actions/workflows/rake.yml)
[![PDD status](http://www.0pdd.com/svg?name=zerocracy/baza)](http://www.0pdd.com/p?name=zerocracy/baza)
[![Test Coverage](https://img.shields.io/codecov/c/github/zerocracy/baza.svg)](https://codecov.io/github/zerocracy/baza?branch=master)

This is the place where all judges meet.

Its usage is explained in the
[zerocracy/judges-action](https://github.com/zerocracy/judges-action)
repository.

## How to Contribute

Read [these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure your build is green before you contribute
your pull request. You will need to have
[Ruby](https://www.ruby-lang.org/en/) 3.2+,
and
[Bundler](https://bundler.io/) installed. Then:

```bash
bundle update
bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.

You can also run the website locally:

```bash
bundle exec rake run
```

Then, you should be able to open it at `http://localhost:4567/`.

In order to run "live" tests, which will connect, for exampe, to AWS resources,
you must have a YAML config file, similar to the one provided during the
deployment. Then, when the file is ready, run it like this:

```bash
bundle exec rake -- --live=/path/to/yaml/file.yml
```

If you need to run just one "live" test, try this, for example:

```bash
RACK_LIVE_YAML_FILE=/path/to/yaml/file.yml bundle exec ruby test/base/test_ec2.rb -n test_live_gc
```

Should work.

## Postgres prerequisite

### Option 1: Using pgsql task

```bash
# Install postgres locally
sudo apt-get update
sudo apt-get install -y libpq-dev postgresql-client postgresql
sudo ln -s "$(realpath /usr/lib/postgresql/*/bin/initdb)" /usr/local/bin/initdb
sudo ln -s "$(realpath /usr/lib/postgresql/*/bin/postgres)" /usr/local/bin/postgres
# Run pgsql task
bundle exec rake pgsql
```

### Option 2: Using external postgres installation

```bash
mkdir -p target
cp pgsql-config.yml.example target/pgsql-config.yml
```

Adjust `target/pgsql-config.yml` with the configuration of your postgres installation.
