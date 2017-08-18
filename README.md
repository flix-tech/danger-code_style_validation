# danger-code_style_validation

[![Build Status](https://travis-ci.org/flix-tech/danger-code_style_validation.svg?branch=master)](https://travis-ci.org/flix-tech/danger-code_style_validation)

This plugin uses 'clang-format' to look for code style violations in added
lines on the current MR / PR, and offers inline patches.
By default only Objective-C files, with extensions `.h`, `.m`, and `.mm` are
checked.

![Example](/doc/images/example.png)

## Installation

Add the following string to your Gemfile:

```ruby
gem 'danger-code_style_validation', :git => 'https://github.com/flix-tech/danger-code_style_validation.git'
```

## Usage

Inside your `Dangerfile` :

```ruby
code_style_validation.check
```

To check files with extensions other than the default ones:

```ruby
code_style_validation.check file_extensions: ['.hpp', '.cpp']
```

To ignore specific paths, use `ignore_file_patterns` :

```ruby
code_style_validation.check ignore_file_patterns: [/^Pods\//]
```

## Development

1. Clone this repo
2. Run `bundle install` to setup dependencies.
3. Run `bundle exec rake spec` to run the tests.
4. Use `bundle exec guard` to automatically have tests run as you make changes.
5. Make your changes.
