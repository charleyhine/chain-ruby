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

[RubyDoc](http://rubydoc.info/github/chain-engineering/chain-ruby/master/Chain)

## License

```
Copyright (c) <2014> <Chain Inc.>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
