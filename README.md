<img src="https://www.zerocracy.com/logo.svg" width="92px" height="92px"/>

[![EO principles respected here](https://www.elegantobjects.org/badge.svg)](https://www.elegantobjects.org)
[![DevOps By Rultor.com](http://www.rultor.com/b/zerocracy/baza)](http://www.rultor.com/p/zerocracy/baza)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![rake](https://github.com/zerocracy/baza/actions/workflows/rake.yml/badge.svg)](https://github.com/zerocracy/baza/actions/workflows/rake.yml)
[![PDD status](http://www.0pdd.com/svg?name=zerocracy/baza)](http://www.0pdd.com/p?name=zerocracy/baza)
[![Test Coverage](https://img.shields.io/codecov/c/github/zerocracy/baza.svg)](https://codecov.io/github/zerocracy/baza?branch=master)
[![Maintainability](https://api.codeclimate.com/v1/badges/51006993d98c150f21fc/maintainability)](https://codeclimate.com/github/zerocracy/baza/maintainability)
[![Hits-of-Code](https://hitsofcode.com/github/zerocracy/baza)](https://hitsofcode.com/view/github/zerocracy/baza)

This is the place where all robots meet.

## How to contribute

Read [these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure you build is green before you contribute
your pull request. You will need to have 
[Ruby](https://www.ruby-lang.org/en/) 3.2+,
and
[Bundler](https://bundler.io/) installed. Then:

```bash
$ bundle update
$ bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.

To run a single unit test you should first do this:

```bash
$ bundle exec rake run
```

And then, in another terminal (for example):

```bash
$ ruby test/test_baza.rb -n test_renders_pages
```

If you want to test it in your browser, open `http://localhost:9292`. If you
want to login as a test user, just open this: `http://localhost:9292?glogin=test`.

Should work.
