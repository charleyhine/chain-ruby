## chain-ruby

Chain's official Ruby SDK.

## Install

```bash
$ gem install chain-ruby
```

```ruby
require 'chain'
```

## Quick Start

```ruby
require 'chain'
Chain.get_address('17x23dNjXJLzGMev6R63uyRhMWP1VHawKc')
```

## API Key
By default, chain-ruby uses Chain's demo API key. You can get an API key by signing up at https://chain.com. You can use your API key by setting it on the Chain module.

```ruby
Chain.api_key = 'YOUR-KEY'
```

## Documentation

The Chain API Documentation is available at [https://chain.com/docs/ruby](https://chain.com/docs/ruby)

## Publishing a Rubygem

Be sure to bump the version.

```bash
$ gem build chain-ruby.gemspec
$ gem push chain-ruby-VERSION.gem
```
