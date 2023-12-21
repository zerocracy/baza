<img src="https://www.zerocracy.com/logo.svg" width="92px" height="92px"/>

[![EO principles respected here](https://www.elegantobjects.org/badge.svg)](https://www.elegantobjects.org)
[![DevOps By Rultor.com](http://www.rultor.com/b/zerocracy/baza)](http://www.rultor.com/p/zerocracy/baza)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![rake](https://github.com/zerocracy/baza/actions/workflows/rake.yml/badge.svg)](https://github.com/zerocracy/baza/actions/workflows/rake.yml)
[![PDD status](http://www.0pdd.com/svg?name=zerocracy/baza)](http://www.0pdd.com/p?name=zerocracy/baza)
[![Test Coverage](https://img.shields.io/codecov/c/github/zerocracy/baza.svg)](https://codecov.io/github/zerocracy/baza?branch=master)

This is the place where all bots meet.

## Architecture

There are a few modules:

  * Farm --- multi-threaded executor of Docker-based bots
  * Pit --- project management Git (storage of artifacts)
  * Netbout --- message hub where bots talk to each other

A bot can:

  * Suggest an update to XML model (in Xembly)
  * Suggest a contribution to the reality (in REAC)
  * Make a contribution to the reality
  * Update the XML model
  * Discuss the intent (update and/or contribution)

The following bots are "show makers":

  * GitHubMan: loads current data through GitHub API
  * ScopeMan: forecasts the WBS 
  * CostMan: estimates cost (hours and money)
  * TimeMan: estimates time
  * PeopleMan: suggests 
  * IntMan: suggests CRs, approves baseline
  * CommMan: delivers messages to staff

## Reality Contribution Language (REAC)

Here is a toy example:

```
ENTER tacit;
FIND PM;
TELL "how are you?";
```

Most obivious types of contribution to reality:

  * Add a new milestone to the project
  * Re-assign a few tasks to another milestone
  * Assign a task to a programmer
  * Create a new task
  * Close a task as "completed"
  * Submit a pull request with a piece of code
  * Suggest to a PM that a programmer must be kicked out
  * Kick out a programmer, revoke access to the repo
  * Submit a comment to a line of code in a pull request
  * Inform stakeholders about SPI/CPI metrics
  * Present a new candidate for project baseline
  * Remind a programmer that a task must be completed faster
  * Put a label on a few taks
  * Send a payment to a programmer

## How to contribute

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
