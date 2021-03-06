require 'rubyserial'

module BetterShow
  # Implementation of ANSI/VT100 commands => http://odroid.com/dokuwiki/doku.php?id=en:show_using
  # Some code logic used from https://github.com/Matoking/SHOWtime/blob/master/context.py

  class ScreenContext
    include BetterShow

    class ColorError < RuntimeError
    end

    # General
    attr_accessor :device
    attr_accessor :buffered_write
    attr_reader :buffer

    # @param port Serialport
    # @param buffered All functions will be buffered => use flush to transmit to device
    def initialize(port: "/dev/ttyUSB0", buffered: true)
      @device = Serial.new port, 500000, 8

      @buffered_write = buffered
      @buffer = []

      @characters_on_current_row = 0
      @orientation = Screen::HORIZONTAL
      @text_size = 2
      @foreground_color = :white
      @background_color = :black

      # on button callbacks
      @button_0_pressed_callback = nil
      @button_1_pressed_callback = nil
      @button_2_pressed_callback = nil

      @button_0_released_callback = nil
      @button_1_released_callback = nil
      @button_2_released_callback = nil

      @callback_thread = nil

      # Create dynamic functions
      create_vt100_functions!

      # Create button event callbacks
      create_button_events!
    end

    def create_vt100_functions!
      # VT100 FUNCTIONS
      # SIMPLE
      define_vt100_function :new_line, "\n"
      define_vt100_function :carriage_return, "\r"

      define_vt100_function :cursor_down, "\eD"
      define_vt100_function :cursor_down_row_one, "\eE"
      define_vt100_function :cursor_up, "\eM"
      define_vt100_function :reset_lcd, "\ec"
      define_vt100_function :erase_screen, "\e[2J"

      define_vt100_function :save_cursor_position, "\e[s"
      define_vt100_function :restore_cursor_position, "\e[u"
    end

    def create_button_events!
      define_button_event :button_0, :pressed
      define_button_event :button_0, :released
      define_button_event :button_1, :pressed
      define_button_event :button_1, :released
      define_button_event :button_2, :pressed
      define_button_event :button_2, :released
    end

    # Used in tests for comparing command sequence
    def virtual_device
      buffer.join
    end

    # Disconnect to ODROID-SHOW
    def restore_defaults
      set_text_size(2)
      set_rotation(Screen::ROTATION_NORTH)
      carriage_return
      set_backlight_brightness_pwm(255)
      set_foreground_color(:white)
      set_background_color(:black)
      flush! if buffered_write
    end

    # Writes string to device
    # @param str String to write_raw_sequence
    def write_text(str)
      # Serial port can not process more then 20 chars once
      str_chunks = split_string_into_chunks(str, 20)
      str_chunks.each do |chunk|
        write_raw_sequence(chunk)
      end

      @characters_on_current_row += str.length
      @characters_on_current_row = @characters_on_current_row % get_columns if (@characters_on_current_row >= get_columns)
    end

    # Prints provided text to screen and fills the
    # rest of the line with empty space to prevent
    # overlapping text
    # @param str String to write_raw_sequence
    def write_line(str)
      write_text(str.ljust(get_columns - @characters_on_current_row))
    end

    # Writes string to buffer if buffered mode, else directly to device
    # @param command_str Commandsequence
    def write_raw_sequence(command_str)
      if buffered_write
        @buffer << command_str
      else
        write_to_device!(command_str)
      end
    end

    # Erase specified amount of rows starting from a specified row
    def erase_rows(start=0, rows=10)
      cursor_to_home
      (0...start).each do
        linebreak
      end

      columns = get_columns
      (start...rows).each do
        write_raw_sequence("".ljust(get_columns+1))
      end
    end

    # Returns the amount of columns, depending on the current text size
    def get_columns
      if @orientation == Screen::HORIZONTAL
        Screen::HEIGHT / (@text_size * 6)
      else
        Screen::WIDTH / (@text_size * 6)
      end
    end

    # Returns the amount of rows, depending on the current text size
    def get_rows
      if @orientation == Screen::HORIZONTAL
        Screen::WIDTH / (@text_size * 8)
      else
        Screen::HEIGHT / (@text_size * 8)
      end
    end

    # EXTENDED
    def keyboard_arrow_up(position)
      write_raw_sequence("\e[%dA" % position)
    end

    def keyboard_arrow_down(position)
      write_raw_sequence("\e[%dB" % position)
    end

    def keyboard_arrow_right(position)
      write_raw_sequence("\e[%dC" % position)
    end

    def keyboard_arrow_left(position)
      write_raw_sequence("\e[%dD" % position)
    end

    # Set cursor to x, y
    def set_cursor_position(x, y)
      write_raw_sequence("\e[%d;%dH" % [x, y])
    end

    # Set backlight PWM 0 - 255
    def set_backlight_brightness_pwm(pwm)
      write_raw_sequence("\e[%dq" % pwm)
    end

    # Set backlight per Percentage 0 - 100%
    # Result will be rounded
    def set_backlight_brightness_percent(percent)
      write_raw_sequence("\e[%dq" % (2.55 * percent))
    end

    # Set cursor to 0,0
    def cursor_to_home
      write_raw_sequence("\e[H")
      # Glitches if not set again
      set_foreground_color(@foreground_color)
      set_background_color(@background_color)
      @characters_on_current_row = 0
    end

    # Sets foreground color for following text
    def set_foreground_color(color_sym)
      raise ColorError, "Invalid color: #{color_sym}" unless ANSI::Color.color_exists?(color_sym)

      write_raw_sequence("\e[%d%dm" % [ANSI::Color::COLOR_MODES[:foreground], ANSI::Color::COLORS[color_sym]])
      @foreground_color = color_sym
    end

    # Sets background color for following text
    def set_background_color(color_sym)
      raise ColorError, "Invalid color: #{color_sym}" unless ANSI::Color.color_exists?(color_sym)

      write_raw_sequence("\e[%d%dm" % [ANSI::Color::COLOR_MODES[:background], ANSI::Color::COLORS[color_sym]])
      @background_color = color_sym
    end

    # Set rotation of Display
    def set_rotation(rotation)
      write_raw_sequence("\e[%sr" % rotation)

      if rotation % 2 == 0
        @orientation = Screen::VERTICAL
      else
        @orientation = Screen::HORIZONTAL
      end
    end

    # Set text size
    def set_text_size(size)
      write_raw_sequence("\e[%ss" % size)
      @text_size = size
    end

    # New line
    def linebreak
      carriage_return
      new_line
      @characters_on_current_row = 0
    end

    # Draw dot at x,y
    def draw_dot(x, y)
      write_raw_sequence("\e[%d;%dx" % [x, y])
    end

    # Draws an RGB 565 image
    def draw_image(image_path, offset_x = 0, offset_y = 0, width = 240, height = 320)
      if @orientation == Screen::VERTICAL
        props = [offset_x, offset_y, width, height]
      else
        props = [offset_x, offset_y, height, width]
      end

      write_raw_sequence("\e[%d;%d,%d;%di" % props)
      write_raw_sequence(File.binread(image_path))
    end

    # Reset screen full
    def reset_screen
      reset_lcd
      erase_screen
      cursor_to_home
    end

    # Resets internal buffer
    def clear_buffer!
      @buffer.clear if buffered_write
    end

    # CALLBACKS
    # Starts thread if not started
    # Thread looks every 200 ms for an button event send via serial port
    def start_button_event_thread
      unless @callback_thread
        @callback_thread = Thread.new do
          loop {
            button_state = @device.read(2)
            if button_state.length == 2
              button = Button::BUTTON_NAME_MAP[button_state[0]]
              event = Button::BUTTON_EVENT_NAME_MAP[button_state[1]]

              callback = instance_variable_get("@#{button}_#{event}_callback")
              callback.call if callback
            end
            sleep(0.2)
          }
        end
      end
    end

    # DEVICE FUNCTIONS
    # Flushes buffer => writes to device
    def flush!
      write_to_device!
    end

    # @param str Commandsequence (if nil buffer will be written)
    def write_to_device!(str=nil)
      command_str = str ? str : buffer
      if command_str.kind_of? String
        @device.write command_str
        sleep(command_str.length * 0.006)
      else
        command_str.each do |command|
          @device.write command
          sleep(command.length * 0.006)
        end
        clear_buffer!
      end
    end

    private
    # Splits string into chunks => ["abcd", "efgh", "123"]
    def split_string_into_chunks(str, chunk_size)
      arr = []
      temp_str = str.dup
      until temp_str.empty?
        arr << temp_str.slice!(0...chunk_size)
      end
      arr
    end

    # Generic function definition for VT100 Functions
    def define_vt100_function(function_name, sequence)
      define_singleton_method(function_name) do
        write_raw_sequence(sequence)
      end
    end

    # defines button event callback and expects a block
    # method name like on_button_0_pressed
    def define_button_event(button, event)
      define_singleton_method("on_#{button.to_s}_#{event.to_s}") do |&block|
        self.instance_variable_set("@#{button.to_s}_#{event.to_s}_callback", block)
        start_button_event_thread
      end
    end
  end
end
