require 'better_show'

ctx = BetterShow::ScreenContext.new

ctx.erase_screen
ctx.restore_defaults
ctx.set_rotation(BetterShow::Screen::ROTATION_NORTH)
ctx.set_background_color(:white)
ctx.set_foreground_color(:red)
ctx.write_text("Hello World!!!")
ctx.flush!