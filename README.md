# Baza

[![EO principles respected here](https://www.elegantobjects.org/badge.svg)](https://www.elegantobjects.org)
[![DevOps By Rultor.com](http://www.rultor.com/b/zerocracy/baza)](http://www.rultor.com/p/zerocracy/baza)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![rake](https://github.com/zerocracy/baza/actions/workflows/rake.yml/badge.svg)](https://github.com/zerocracy/baza/actions/workflows/rake.yml)
[![PDD status](http://www.0pdd.com/svg?name=zerocracy/baza)](http://www.0pdd.com/p?name=zerocracy/baza)
[![Test Coverage](https://img.shields.io/codecov/c/github/zerocracy/baza.svg)](https://codecov.io/github/zerocracy/baza?branch=master)

This is the place where all bots meet.

## How It Works

GitHub Action plugins (in the order of steps):

* `zerocracy/scan-action` — fetch events via GitHub API and put them into the factbase
* `zerocracy/push-action` — send factbase to Zerocracy
* `zerocracy/pull-action` — receieve updated factbase from Zerocracy
* `zerocracy/submit-action` — submit messages to GitHub issues
* `zerocracy/site-action` — generate static HTML site

The pipeline must start with a cache retrieval.

### Bots

Basic supervising bots:

* Reward for accepted bug report
* Reward for accepting bug report
* Reward for merged pull request (per line of code)
* Reward for reviewed pull request
* Reward architect for release made
* Punish architect for ignoring bug reports
* Punish for long merged pull request
* Punish for stale pull request
* Punish architect for lack of fresh releases
* Punish for rejected bug report
* Punish for rejected pull request

Basic interpreting bots:

* Events to accepted bug report
* Events to merged pull request
* Events to completed code review
* Events to completed release

Basic EVA bots:

* Scope points for pull requests and bug reports
* Time points for commits
* Cost points for hits of code
* Staff points for active contributions

Basic forecasting bots:

* Forecast scope points
* Forecast time points
* Forecast cost points

Risk bots:

* Identify risks
* Set probability and impact for risks
* Suggest plans

### Facts

There are facts in the factbase. Each fact has the following attributes:

* Time: ISO 8601
* Kind: string
* Seen-by: list of bot IDs
* Details: key-value map

Operation on the factbase (it's append-only, can't delete or modify):

* Select where (join by OR/AND):
  * kind eq ?
  * seen-by ?
  * not seen-by ?
* Insert new fact
* Attach "seen-by"

### Bots orchestration

When a new factbase arrives, a new AWS lambda is created.

## How to Contribute

Read [these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure your build is green before you contribute
your pull request. You will need to have 
[Ruby](https://www.ruby-lang.org/en/) 3.2+,
and
[Bundler](https://bundler.io/) installed. Then:

```bash
$ bundle update
$ bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.
