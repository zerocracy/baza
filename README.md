# Zerocracy Meeting Point

[![EO principles respected here](https://www.elegantobjects.org/badge.svg)](https://www.elegantobjects.org)
[![DevOps By Rultor.com](http://www.rultor.com/b/zerocracy/baza)](http://www.rultor.com/p/zerocracy/baza)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

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
