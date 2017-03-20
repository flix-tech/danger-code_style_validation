# danger-code_style_validation

This plugin looks for code style violations for added lines and suggests patches.

It uses 'clang-format' and only checks `.h`, `.m` and `.mm` files

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
