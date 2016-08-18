# BetterShow

Library for the ODROID-SHOW/ODROID-SHOW2 written in Ruby

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'better_show'
```

And then execute:

    $ bundle

Or install it yourself as (will be uploaded to RubyGems.org if release is stable):

    $ gem install better_show

## Usage

```ruby
require 'better_show'

@ctx = BetterShow::ScreenContext.new

@ctx.erase_screen
@ctx.set_rotation(BetterShow::Screen::ROTATION_NORTH)
@ctx.set_background_color(:black)
@ctx.set_foreground_color(:red)
@ctx.write_line("Hello World!")
@ctx.flush!
```
For other examples look at the examples directory.

## Supports
* [ODROID-SHOW](http://www.hardkernel.com/main/products/prdt_info.php?g_code=G139781817221)
* [ODROID-SHOW2](http://www.hardkernel.com/main/products/prdt_info.php?g_code=G141743018597)

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/api-walker/better_show.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

