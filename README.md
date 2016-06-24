# Easy Sockets

Over and over I see developers struggling to implement basic sockets with featues available on rubie's socket stdlib.

With easy socket gem, you can implement TCP, UDP and Unix sockets with the following features:

  - Reliable and safe timeouts ([why not use ruby timeout stdlib](http://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/) ).
  - Receiving big (more than 16384 bytes) response messages in a non blocking way.
  - Option to enable custome message (line) separators.
  
I also strongly recommend [the following book](http://www.jstorimer.com/products/working-with-tcp-sockets) if you want to learn more about sockets.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'easy_sockets'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install easy_sockets

## Usage

TODO: pending.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosortiz/easy_sockets.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

