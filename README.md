# Prayertimes

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'prayertimes'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install prayertimes

## Usage
```
pt = Prayertimes::Calculate.new(method_name)
# or
pt = Prayertimes::Calculate.new

# to get prayer times
pt.getTimes(Time.now.asctime, [43, -80], -5) #note that must use .asctime to convert the time into a string

# to change method
pt.setMethod(method)
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/prayertimes/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
