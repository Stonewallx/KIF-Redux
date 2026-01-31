#===============================================================================
# KIF Redux Options - Option Types, Windows, and Settings Scenes
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file contains:
# - Custom option types (StoneSliderOption, SpacerOption, CustomRowEnumOption)
# - KIFRCategoryHeaderOption for collapsible categories
# - SearchResultOption for search display
# - Window_KIFR_Option with unified drawing logic
# - KIFRSettingsScene (main settings UI with search)
# - PresetSettingsScene (preset management UI)
# - Options menu hook (adds KIFR Settings button)
#===============================================================================

#===============================================================================
# OPTION TYPES
#===============================================================================

# StoneSliderOption - Supports negative values and custom intervals
# Unlike the base SliderOption, this stores actual values instead of offsets
class StoneSliderOption < Option
  include PropertyMixin if defined?(PropertyMixin)
  attr_reader :name, :optstart, :optend, :optinterval
  attr_accessor :display_formatter  # Optional proc to format display value

  def initialize(name, optstart, optend, optinterval, getProc, setProc, description = "")
    super(description) if defined?(super)
    @name = name
    @optstart = optstart
    @optend = optend
    @optinterval = optinterval
    @getProc = getProc
    @setProc = setProc
    @description = description
    @display_formatter = nil  # Default: no custom formatting
  end
  
  # Get formatted display string for a value
  def format_value(val)
    if @display_formatter
      @display_formatter.call(val)
    else
      val.to_s
    end
  end

  def get
    value = @getProc.call rescue @optstart
    # Clamp to valid range
    [[value, @optstart].max, @optend].min
  end

  def set(value)
    @setProc.call(value) if @setProc
  end

  def next(current)
    current += @optinterval
    current = @optend if current > @optend
    current
  end

  def prev(current)
    current -= @optinterval
    current = @optstart if current < @optstart
    current
  end

  # Generate array of all possible values (for compatibility)
  def values
    result = []
    val = @optstart
    while val <= @optend
      result.push(val.to_s)
      val += @optinterval
    end
    result
  end
  
  def description
    @description || ""
  end
end

# SpacerOption - Creates empty visual space for multi-row layouts
class SpacerOption < Option
  attr_reader :name
  
  def initialize
    @name = ""
    @description = ""
  end
  
  def get
    0
  end
  
  def set(value)
    # Do nothing - spacers are non-interactive
  end
  
  def values
    [""]
  end
  
  def next(current)
    current
  end
  
  def prev(current)
    current
  end
  
  def non_interactive?
    true
  end
  
  def description
    ""
  end
end

# ClickOnlyButtonOption - Button that only activates on Enter/C, not left/right
# Use this for buttons that perform significant actions (server launch, updates, etc.)
class ClickOnlyButtonOption < Option
  include PropertyMixin if defined?(PropertyMixin)
  attr_reader :name

  def initialize(name, selectProc, description = "")
    super(description) if defined?(super)
    @name = name
    @selectProc = selectProc
    @description = description
  end

  def get
    0
  end

  def set(value)
    # Only activate is called externally, not set
  end

  def next(current)
    # Do nothing on right arrow - return current without activating
    current
  end

  def prev(current)
    # Do nothing on left arrow
    current
  end

  def activate
    @selectProc.call if @selectProc
  end

  def values
    [""]
  end

  def description
    if @description.is_a?(Proc)
      @description.call
    else
      @description || ""
    end
  end
end

# CustomRowEnumOption - EnumOption with configurable items per row
class CustomRowEnumOption < EnumOption
  attr_accessor :items_per_row
  
  def initialize(name, options, getProc, setProc, description = "", items_per_row = 3)
    super(name, options, getProc, setProc, description)
    @items_per_row = items_per_row
  end
end

# SimpleCategoryHeaderOption - Non-collapsible category header with [HEADER] format
class SimpleCategoryHeaderOption < Option
  attr_reader :name
  
  def initialize(name, description = "")
    @name = name
    @description = description
  end
  
  def non_interactive?
    true
  end
  
  def get
    0
  end
  
  def set(value)
    # Do nothing - non-interactive
  end
  
  def format(value)
    "[#{@name}]"
  end
  
  def values
    [""]
  end
  
  def next(current)
    current
  end
  
  def prev(current)
    current
  end
  
  def description
    @description || ""
  end
end

# KIFRCategoryHeaderOption - Collapsible category headers
class KIFRCategoryHeaderOption < Option
  attr_reader :name
  attr_accessor :category_name
  
  def initialize(category_name, description = "")
    @name = category_name
    @category_name = category_name
    @description = description
  end
  
  def non_interactive?
    true
  end
  
  # Get current value (collapsed state: 0 = expanded, 1 = collapsed)
  def get
    KIFRSettings.category_collapsed?(@category_name) ? 1 : 0
  end
  
  # Set value (toggle collapsed state)
  def set(value)
    KIFRSettings.toggle_category(@category_name)
  end
  
  # Format display text with collapse indicator
  def format(value)
    # Check if this is a separator (contains only dashes)
    return @name if @name =~ /^-+$/
    
    indicator = value == 1 ? "+" : "-"
    "#{indicator} #{@name} #{indicator}"
  end
  
  def values
    [""]
  end
  
  def next(current)
    current
  end
  
  def prev(current)
    current
  end
  
  def description
    @description || ""
  end
end

# SearchResultOption - Displays search match count
class SearchResultOption < Option
  attr_reader :name
  attr_accessor :count
  
  def initialize
    @name = "Search Results"
    @count = 0
    @description = ""
  end
  
  def set_count(count)
    @count = count
  end
  
  def non_interactive?
    true
  end
  
  def get
    0
  end
  
  def set(value)
    # Read-only
  end
  
  def values
    [""]
  end
  
  def next(current)
    current
  end
  
  def prev(current)
    current
  end
  
  def format(value)
    "#{@count} matches found"
  end
  
  def description
    ""
  end
end

#===============================================================================
# WINDOW CLASS - Unified Drawing Logic
#===============================================================================

# Unified window class that handles all KIFR option types
class Window_KIFR_Option < Window_PokemonOption
  attr_accessor :use_color_theme, :modsettings_menu
  
  def initialize(options, x, y, width, height)
    super(options, x, y, width, height)
    @use_color_theme = true
    @modsettings_menu = true
  end
  
  # Apply the selected color theme
  def apply_color_theme(theme_index)
    return unless defined?(COLOR_THEMES)
    
    theme_key = COLOR_THEMES.keys[theme_index]
    return unless theme_key
    
    theme = COLOR_THEMES[theme_key]
    if theme && theme[:base] && theme[:shadow]
      @nameBaseColor = theme[:base]
      @nameShadowColor = theme[:shadow]
      @selBaseColor = theme[:base]
      @selShadowColor = theme[:shadow]
    end
    refresh
  end
  
  # Unified drawItem handling all option types with custom spacing
  # This implements the same spacing behavior as Mod Settings
  def drawItem(index, _count, rect)
    # Handle Confirm button (index == options length)
    if index == @options.length
      super(index, _count, rect)
      return
    end
    
    return if index > @options.length
    option = @options[index]
    return super(index, _count, rect) unless option
    
    # Handle special option types first
    case option
    when SpacerOption
      # Draw nothing for spacers - they just take up space
      return
      
    when KIFRCategoryHeaderOption
      draw_category_header(option, index, rect)
      return
      
    when SimpleCategoryHeaderOption
      draw_simple_category_header(option, index, rect)
      return
      
    when SearchResultOption
      draw_search_result(option, index, rect)
      return
    end
    
    # For all other options, use custom drawing with proper spacing
    # Only apply custom spacing if modsettings_menu flag is set
    unless @modsettings_menu
      return super(index, _count, rect)
    end
    
    kifr_draw_option_with_spacing(index, _count, rect)
  end
  
  # Main drawing method with custom spacing for all option types
  def kifr_draw_option_with_spacing(index, _count, rect)
    return if respond_to?(:dont_draw_item) && dont_draw_item(index)
    rect = drawCursor(index, rect)
    
    option = @options[index]
    optionname = option.name
    optionwidth = rect.width * 12 / 20  # 60% for label, 40% for value
    
    # ButtonOptions get full width (no value to display)
    if option.is_a?(ButtonOption)
      optionwidth = rect.width
    end
    
    # Draw the option name/label
    pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height, optionname,
                     @nameBaseColor, @nameShadowColor)
    
    # Now draw the value based on option type
    if option.is_a?(EnumOption) || option.is_a?(ButtonsOption)
      kifr_draw_enum_option(option, index, rect, optionwidth)
    elsif option.is_a?(NumberOption)
      kifr_draw_number_option(option, index, rect, optionwidth)
    elsif option.is_a?(StoneSliderOption)
      kifr_draw_stone_slider_option(option, index, rect, optionwidth)
    elsif option.is_a?(SliderOption)
      kifr_draw_slider_option(option, index, rect, optionwidth)
    end
    # ButtonOption has no value to draw
  end
  
  # Draw EnumOption with proper multi-row layout and spacing
  def kifr_draw_enum_option(option, index, rect, optionwidth)
    return unless option.values && option.values.length > 0
    
    # Check if this is a color display option (show value in its color)
    if option.respond_to?(:name) && 
       (option.name == _INTL("Menu Color") || option.name == _INTL("Category Color"))
      kifr_draw_color_enum(option, index, rect, optionwidth)
      return
    end
    
    # Use cycling arrow display for all enum options
    kifr_draw_cycling_enum(option, index, rect, optionwidth)
  end
  
  # Draw enum with cycling arrows: <- Choice ->
  # Arrows disappear at boundaries (first/last choice)
  # Centered on the slider bar area for visual consistency
  def kifr_draw_cycling_enum(option, index, rect, optionwidth)
    current_idx = self[index] || 0
    current_value = option.values[current_idx] || "???"
    num_values = option.values.length
    
    # Arrow characters (empty if at boundary)
    left_arrow = current_idx > 0 ? "<-" : "  "
    right_arrow = current_idx < (num_values - 1) ? "->" : "  "
    
    # Calculate widths (use "<-" for consistent spacing even when hidden)
    arrow_width = self.contents.text_size("<-").width
    value_width = self.contents.text_size(current_value).width
    spacing = 8  # Space between arrows and value
    
    # Total width of the cycling display
    total_width = arrow_width + spacing + value_width + spacing + arrow_width
    
    # Center in the slider bar area (matches slider positioning)
    fixed_bar_length = 108
    bar_x = optionwidth + rect.x + 10
    bar_center = bar_x + (fixed_bar_length / 2)
    start_x = bar_center - (total_width / 2)
    
    # Draw left arrow (only if not at first option)
    if current_idx > 0
      pbDrawShadowText(self.contents, start_x, rect.y, arrow_width + 4, rect.height,
                       left_arrow, @selBaseColor, @selShadowColor)
    end
    
    # Draw current value (highlighted)
    value_x = start_x + arrow_width + spacing
    pbDrawShadowText(self.contents, value_x, rect.y, value_width + 4, rect.height,
                     current_value, @selBaseColor, @selShadowColor)
    
    # Draw right arrow (only if not at last option)
    right_x = value_x + value_width + spacing
    if current_idx < (num_values - 1)
      pbDrawShadowText(self.contents, right_x, rect.y, arrow_width + 4, rect.height,
                       right_arrow, @selBaseColor, @selShadowColor)
    end
  end
  
  # Draw multi-row enum (4+ values) - now unused but kept for compatibility
  def kifr_draw_multirow_enum(option, index, rect, optionwidth, num_values)
    kifr_draw_cycling_enum(option, index, rect, optionwidth)
  end
  
  # Draw single-row enum (2-3 values) - now unused but kept for compatibility
  def kifr_draw_singlerow_enum(option, index, rect, optionwidth, num_values)
    kifr_draw_cycling_enum(option, index, rect, optionwidth)
  end
  
  # Draw color enum option (value shown in its actual color)
  # Centered on the slider bar area for visual consistency
  def kifr_draw_color_enum(option, index, rect, optionwidth)
    current_idx = self[index] || 0
    current_value = option.values[current_idx] || "???"
    num_values = option.values.length
    
    theme_key = COLOR_THEMES.keys[current_idx] if defined?(COLOR_THEMES)
    theme = COLOR_THEMES[theme_key] if theme_key && defined?(COLOR_THEMES)
    
    # Arrow characters (empty if at boundary)
    left_arrow = current_idx > 0 ? "<-" : "  "
    right_arrow = current_idx < (num_values - 1) ? "->" : "  "
    
    # Calculate widths (use "<-" for consistent spacing even when hidden)
    arrow_width = self.contents.text_size("<-").width
    value_width = self.contents.text_size(current_value).width
    spacing = 8  # Space between arrows and value
    
    # Total width of the cycling display
    total_width = arrow_width + spacing + value_width + spacing + arrow_width
    
    # Center in the slider bar area (matches slider positioning)
    fixed_bar_length = 108
    bar_x = optionwidth + rect.x + 10
    bar_center = bar_x + (fixed_bar_length / 2)
    start_x = bar_center - (total_width / 2)
    
    # Get colors for arrows (use theme color or default)
    arrow_base = (theme && theme[:base]) ? theme[:base] : @selBaseColor
    arrow_shadow = (theme && theme[:shadow]) ? theme[:shadow] : @selShadowColor
    
    # Draw left arrow (only if not at first option)
    if current_idx > 0
      pbDrawShadowText(self.contents, start_x, rect.y, arrow_width + 4, rect.height,
                       left_arrow, arrow_base, arrow_shadow)
    end
    
    # Draw current value in its theme color
    value_x = start_x + arrow_width + spacing
    if theme && theme[:base] && theme[:shadow]
      pbDrawShadowText(self.contents, value_x, rect.y, value_width + 4, rect.height,
                       current_value, theme[:base], theme[:shadow])
    else
      pbDrawShadowText(self.contents, value_x, rect.y, value_width + 4, rect.height,
                       current_value, @selBaseColor, @selShadowColor)
    end
    
    # Draw right arrow (only if not at last option)
    right_x = value_x + value_width + spacing
    if current_idx < (num_values - 1)
      pbDrawShadowText(self.contents, right_x, rect.y, arrow_width + 4, rect.height,
                       right_arrow, arrow_base, arrow_shadow)
    end
  end
  
  # Draw NumberOption
  def kifr_draw_number_option(option, index, rect, optionwidth)
    value = _INTL("Type {1}/{2}", option.optstart + self[index],
                  option.optend - option.optstart + 1)
    xpos = optionwidth + rect.x
    pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
                     @selBaseColor, @selShadowColor)
  end
  
  # Draw StoneSliderOption (supports negative values)
  def kifr_draw_stone_slider_option(option, index, rect, optionwidth)
    fixed_bar_length = 108
    
    min_val = option.optstart
    max_val = option.optend
    current_val = self[index]
    
    # Ensure value is within range
    current_val = [[current_val, min_val].max, max_val].min
    
    # Calculate tick position as percentage
    range = max_val - min_val
    range = 1 if range == 0
    percentage = (current_val - min_val).to_f / range
    
    # Position bar and tick
    bar_x = optionwidth + rect.x + 10
    bar_y = rect.y - 2 + rect.height / 2
    tick_width = 8
    tick_height = 16
    
    # Draw slider bar
    self.contents.fill_rect(bar_x, bar_y, fixed_bar_length, 4, self.baseColor)
    
    # Draw tick
    tick_x = bar_x + (percentage * (fixed_bar_length - tick_width)).round
    tick_y = bar_y - 6
    self.contents.fill_rect(tick_x, tick_y, tick_width, tick_height, @selBaseColor)
    
    # Draw current value (use display formatter if available)
    if option.respond_to?(:format_value)
      value = option.format_value(current_val)
    else
      value = sprintf("%d", current_val)
    end
    value_x = bar_x + fixed_bar_length + 8
    pbDrawShadowText(self.contents, value_x, rect.y, 80, rect.height, value,
                     @selBaseColor, @selShadowColor)
  end
  
  # Draw standard SliderOption (non-negative values only)
  def kifr_draw_slider_option(option, index, rect, optionwidth)
    # Calculate slider dimensions
    value_text = sprintf(" %d", option.optend)
    available_width = rect.width * 8 / 20
    sliderlength = available_width - self.contents.text_size(value_text).width
    sliderlength = [sliderlength, 108].min  # Cap at 108px
    
    xpos = optionwidth + rect.x
    bar_y = rect.y - 2 + rect.height / 2
    
    # Draw slider bar
    self.contents.fill_rect(xpos, bar_y, sliderlength, 4, self.baseColor)
    
    # Draw tick
    tick_pos = (sliderlength - 8) * (option.optstart + self[index]) / option.optend
    self.contents.fill_rect(xpos + tick_pos, rect.y - 8 + rect.height / 2, 8, 16, @selBaseColor)
    
    # Draw value
    value = sprintf("%d", option.optstart + self[index])
    pbDrawShadowText(self.contents, xpos + sliderlength + 8, rect.y, 80, rect.height, value,
                     @selBaseColor, @selShadowColor)
  end
  
  # Draw category header (centered, with theme color)
  def draw_category_header(option, index, rect)
    return if respond_to?(:dont_draw_item) && dont_draw_item(index)
    rect = drawCursor(index, rect)
    
    # Get category theme color
    category_theme_idx = $PokemonSystem.kifr_category_theme rescue 3
    category_theme_idx ||= 3  # Default Red
    theme_key = COLOR_THEMES.keys[category_theme_idx] if defined?(COLOR_THEMES)
    theme = COLOR_THEMES[theme_key] if theme_key && defined?(COLOR_THEMES)
    
    optionname = option.format(self[index])
    
    # Center the text
    text_width = self.contents.text_size(optionname).width rescue rect.width
    x_pos = (rect.width - text_width) / 2
    
    if theme && theme[:base] && theme[:shadow]
      pbDrawShadowText(self.contents, x_pos, rect.y, rect.width, rect.height, optionname,
                       theme[:base], theme[:shadow])
    else
      pbDrawShadowText(self.contents, x_pos, rect.y, rect.width, rect.height, optionname,
                       @nameBaseColor, @nameShadowColor)
    end
  end
  
  # Draw simple category header (non-collapsible, centered with brackets)
  def draw_simple_category_header(option, index, rect)
    return if respond_to?(:dont_draw_item) && dont_draw_item(index)
    rect = drawCursor(index, rect)
    
    # Get category theme color
    category_theme_idx = $PokemonSystem.kifr_category_theme rescue 3
    category_theme_idx ||= 3  # Default Red
    theme_key = COLOR_THEMES.keys[category_theme_idx] if defined?(COLOR_THEMES)
    theme = COLOR_THEMES[theme_key] if theme_key && defined?(COLOR_THEMES)
    
    optionname = option.format(self[index])  # Use format method for [HEADER] display
    
    # Center the text
    text_width = self.contents.text_size(optionname).width rescue rect.width
    x_pos = (rect.width - text_width) / 2
    
    if theme && theme[:base] && theme[:shadow]
      pbDrawShadowText(self.contents, x_pos, rect.y, rect.width, rect.height, optionname,
                       theme[:base], theme[:shadow])
    else
      pbDrawShadowText(self.contents, x_pos, rect.y, rect.width, rect.height, optionname,
                       @nameBaseColor, @nameShadowColor)
    end
  end
  
  # Draw search result count (centered, with theme color)
  def draw_search_result(option, index, rect)
    return if respond_to?(:dont_draw_item) && dont_draw_item(index)
    rect = drawCursor(index, rect)
    
    # Get category theme color
    category_theme_idx = $PokemonSystem.kifr_category_theme rescue 3
    category_theme_idx ||= 3
    theme_key = COLOR_THEMES.keys[category_theme_idx] if defined?(COLOR_THEMES)
    theme = COLOR_THEMES[theme_key] if theme_key && defined?(COLOR_THEMES)
    
    optionname = option.format(self[index])
    
    # Center the text
    text_width = self.contents.text_size(optionname).width rescue rect.width
    x_pos = (rect.width - text_width) / 2
    
    if theme && theme[:base] && theme[:shadow]
      pbDrawShadowText(self.contents, x_pos, rect.y, rect.width, rect.height, optionname,
                       theme[:base], theme[:shadow])
    else
      pbDrawShadowText(self.contents, x_pos, rect.y, rect.width, rect.height, optionname,
                       @nameBaseColor, @nameShadowColor)
    end
  end
  
  # Override update - parent class handles LEFT/RIGHT input for value changes
  # We only need to handle special cases like non-interactive options and USE button
  def update
    oldindex = self.index
    
    # Let parent handle all standard input (including LEFT/RIGHT value changes)
    super
    
    dorefresh = (self.index != oldindex)
    
    # Handle USE button for special option types (parent doesn't do this)
    if self.active && self.index < @options.length
      current_option = @options[self.index]
      
      if Input.trigger?(Input::USE)
        if current_option.is_a?(KIFRCategoryHeaderOption)
          # Toggle category collapse state - update both the option and window's value
          new_value = (self[self.index] == 0) ? 1 : 0
          self[self.index] = new_value
          dorefresh = true
          @mustUpdateOptions = true
        elsif current_option.is_a?(ButtonOption) || current_option.is_a?(ButtonsOption)
          current_option.activate if current_option.respond_to?(:activate)
          dorefresh = true
          @mustUpdateOptions = true
        end
      end
    end
    
    refresh if dorefresh
  end
end

#===============================================================================
# HELPER METHODS
#===============================================================================

# Apply color theme to a window
def apply_kifr_color_theme(window, theme_index)
  return unless window && defined?(COLOR_THEMES)
  theme_key = COLOR_THEMES.keys[theme_index]
  theme = COLOR_THEMES[theme_key]
  return unless theme
  
  window.nameBaseColor = theme[:base] if window.respond_to?(:nameBaseColor=)
  window.nameShadowColor = theme[:shadow] if window.respond_to?(:nameShadowColor=)
  begin
    window.instance_variable_set(:@selBaseColor, theme[:base])
    window.instance_variable_set(:@selShadowColor, theme[:shadow])
  rescue
  end
  window.refresh if window.respond_to?(:refresh)
end

# Auto-insert spacers - LEGACY FUNCTION (no longer needed with cycling arrows)
# Kept as pass-through for backward compatibility with mods that call it
def kifr_auto_insert_spacers(options)
  # With cycling arrow display, multi-row layouts no longer exist
  # Simply return options unchanged
  options
end

#===============================================================================
# COLORS & FRAME SETTINGS SCENE - Submenu for color and frame options
#===============================================================================

class ColorsFrameSettingsScene < PokemonOption_Scene
  # Skip fade-in to avoid double-fade (outer pbFadeOutIn handles transition)
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    theme_names = if defined?(COLOR_THEMES)
                    COLOR_THEMES.keys.map { |k| COLOR_THEMES[k][:name] }
                  else
                    [_INTL("Purple"), _INTL("Blue")]
                  end
    
    # Menu Color
    options << EnumOption.new(
      _INTL("Menu Color"), theme_names,
      proc { ($PokemonSystem.kifr_color_theme rescue 0) || 0 },
      proc { |value|
        $PokemonSystem.kifr_color_theme = value
        apply_kifr_color_theme(@sprites["option"], value) if @sprites && @sprites["option"]
      },
      _INTL("Choose the color theme applied to option menus."))
    
    # Category Color
    options << EnumOption.new(
      _INTL("Category Color"), theme_names,
      proc { ($PokemonSystem.kifr_category_theme rescue 3) || 3 },  # Default: Red (index 3)
      proc { |value|
        $PokemonSystem.kifr_category_theme = value
        @sprites["option"].refresh if @sprites && @sprites["option"]
      },
      _INTL("Choose the color theme used for categories."))
    
    # Global Frame
    options << NumberOption.new(
      _INTL("Global Frame"), 1, KIFR_WINDOWSKINS.length,
      proc { 
        $PokemonSystem.kifr_global_frame ||= 1
        $PokemonSystem.kifr_global_frame 
      },
      proc { |value|
        $PokemonSystem.kifr_global_frame = value
        skin_name = KIFR_WINDOWSKINS[value]
        skin_path = "Graphics/Windowskins/#{skin_name}"
        MessageConfig.pbSetSystemFrame(skin_path)
        if ($PokemonSystem.kifr_separate_speech || 0) == 0
          MessageConfig.pbSetSpeechFrame(skin_path)
        end
      })
    
    # Separate Speech toggle
    options << EnumOption.new(
      _INTL("Separate Speech"), [_INTL("Off"), _INTL("On")],
      proc { $PokemonSystem.kifr_separate_speech || 0 },
      proc { |value|
        $PokemonSystem.kifr_separate_speech = value
        if value == 0
          global_idx = $PokemonSystem.kifr_global_frame || 0
          skin_name = KIFR_WINDOWSKINS[global_idx]
          MessageConfig.pbSetSpeechFrame("Graphics/Windowskins/#{skin_name}")
        else
          speech_idx = $PokemonSystem.kifr_speech_frame || 0
          MessageConfig.pbSetSpeechFrame("Graphics/Windowskins/" + Settings::SPEECH_WINDOWSKINS[speech_idx])
        end
      },
      _INTL("Use a separate frame for speech/dialog boxes."))
    
    # Speech Frame
    options << NumberOption.new(
      _INTL("Speech Frame"), 1, Settings::SPEECH_WINDOWSKINS.length,
      proc { $PokemonSystem.kifr_speech_frame || 0 },
      proc { |value|
        $PokemonSystem.kifr_speech_frame = value
        if ($PokemonSystem.kifr_separate_speech || 0) == 1
          MessageConfig.pbSetSpeechFrame("Graphics/Windowskins/" + Settings::SPEECH_WINDOWSKINS[value])
        end
      })
    
    # Cursor Color
    options << NumberOption.new(
      _INTL("Cursor Color"), 1, SHOP_CURSOR_COLORS.length,
      proc { ($PokemonSystem.kifr_shop_cursor_color || 0) },
      proc { |value|
        $PokemonSystem.kifr_shop_cursor_color = value
      })
    
    return options
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Colors & Frame"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    
    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 96, Graphics.width, 96, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].visible = false
    
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = false
    
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0)
    end
    @sprites["option"].refresh
    
    @sprites.each { |k, s| s.visible = true if s }
    pbFadeInAndShow(@sprites)
  end
  
  def initOptionsWindow
    optionsWindow = Window_KIFR_Option.new(@PokemonOptions, 0,
                                             @sprites["title"].height, Graphics.width,
                                             Graphics.height - @sprites["title"].height - @sprites["textbox"].height)
    optionsWindow.setSkin(PokemonOption_Scene.get_kifr_windowskin)
    optionsWindow.nameBaseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    optionsWindow.nameShadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    optionsWindow.selBaseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    optionsWindow.selShadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    optionsWindow.viewport = @viewport
    optionsWindow.visible = true
    return optionsWindow
  end
  
  def pbOptions
    oldGlobalFrame = $PokemonSystem.kifr_global_frame || 0
    oldSpeechFrame = $PokemonSystem.kifr_speech_frame || 0
    oldSeparateSpeech = $PokemonSystem.kifr_separate_speech || 0
    oldShopCursor = $PokemonSystem.kifr_shop_cursor_color || 0
    
    pbActivateWindow(@sprites, "option") {
      loop do
        Graphics.update
        Input.update
        pbUpdate
        
        if @sprites["option"].mustUpdateOptions
          for i in 0...@PokemonOptions.length
            @PokemonOptions[i].set(@sprites["option"][i])
          end
          
          # Preview Global Frame changes
          newGlobalFrame = $PokemonSystem.kifr_global_frame || 0
          newSpeechFrame = $PokemonSystem.kifr_speech_frame || 0
          newSeparateSpeech = $PokemonSystem.kifr_separate_speech || 0
          
          if newGlobalFrame != oldGlobalFrame
            skin_name = KIFR_WINDOWSKINS[newGlobalFrame] || "KIFR Choice 1"
            @sprites["textbox"].setSkin("Graphics/Windowskins/#{skin_name}")
            @sprites["textbox"].text = _INTL("Global Frame {1}", newGlobalFrame + 1)
            oldGlobalFrame = newGlobalFrame
          elsif newSpeechFrame != oldSpeechFrame
            skin_name = Settings::SPEECH_WINDOWSKINS[newSpeechFrame] || Settings::SPEECH_WINDOWSKINS[0]
            @sprites["textbox"].setSkin("Graphics/Windowskins/#{skin_name}")
            @sprites["textbox"].text = _INTL("Speech Frame {1}", newSpeechFrame + 1)
            oldSpeechFrame = newSpeechFrame
          elsif newSeparateSpeech != oldSeparateSpeech
            if newSeparateSpeech == 1
              skin_name = Settings::SPEECH_WINDOWSKINS[newSpeechFrame] || Settings::SPEECH_WINDOWSKINS[0]
              @sprites["textbox"].setSkin("Graphics/Windowskins/#{skin_name}")
              @sprites["textbox"].text = _INTL("Separate Speech: ON")
            else
              skin_name = KIFR_WINDOWSKINS[newGlobalFrame] || "KIFR Choice 1"
              @sprites["textbox"].setSkin("Graphics/Windowskins/#{skin_name}")
              @sprites["textbox"].text = _INTL("Separate Speech: OFF")
            end
            oldSeparateSpeech = newSeparateSpeech
          end
          
          # Preview Cursor Color changes
          newShopCursor = $PokemonSystem.kifr_shop_cursor_color || 0
          if newShopCursor != oldShopCursor
            color_info = SHOP_CURSOR_COLORS[newShopCursor] rescue nil
            color_name = color_info ? color_info[:name] : "Blue"
            @sprites["textbox"].text = _INTL("Cursor Color: {1}", color_name)
            oldShopCursor = newShopCursor
          end
        end
        
        if Input.trigger?(Input::BACK)
          break
        elsif Input.trigger?(Input::USE)
          break if isConfirmedOnKeyPress
        end
      end
    }
  end
end

#===============================================================================
# KIFR SETTINGS SCENE - Main Settings UI with Search
#===============================================================================

class KIFRSettingsScene < PokemonOption_Scene
  attr_accessor :search_term
  
  def initialize
    super
    @search_term = ""
    # Reset all categories to collapsed when opening settings
    KIFRSettings.reset_all_categories
  end
  
  # Skip fade-in (outer pbFadeOutIn handles transition)
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def initOptionsWindow
    optionsWindow = Window_KIFR_Option.new(@PokemonOptions, 0,
                                           @sprites["title"].height, Graphics.width,
                                           Graphics.height - @sprites["title"].height - @sprites["textbox"].height)
    optionsWindow.setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    optionsWindow.viewport = @viewport
    optionsWindow.visible = true
    optionsWindow
  end

  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create title (invisible initially)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("KIFR Settings"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].visible = false
    
    # Create textbox (invisible initially)
    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].visible = false
    
    # Build options and window
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = false
    
    # Apply color theme BEFORE showing anything
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    # Initialize values
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0) rescue 0
    end
    @sprites["option"].refresh
    
    # Now show everything with fade
    @sprites.each { |k, s| s.visible = true if s }
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbGetOptions(inloadscreen = false)
    # Initialize all categories to collapsed state
    KIFR_CATEGORIES.each do |cat|
      name = cat[:name]
      KIFRSettings.initialize_category(name, true) unless name =~ /^-+$/
    end
    
    theme_names = if defined?(COLOR_THEMES)
                    COLOR_THEMES.keys.map { |k| COLOR_THEMES[k][:name] }
                  else
                    [_INTL("Purple"), _INTL("Blue")]
                  end
    
    # Define options by category
    options_by_category = {}
    
    # Interface category options
    options_by_category["Interface"] = [
      ButtonOption.new(_INTL("Colors & Frame"),
        proc {
          pbFadeOutIn {
            scene = ColorsFrameSettingsScene.new
            screen = PokemonOptionScreen.new(scene)
            screen.pbStartScreen
          }
        },
        _INTL("Configure menu colors, window frames, and cursor color.")),
      ButtonOption.new(_INTL("Overworld Menu"),
        proc {
          pbFadeOutIn {
            scene = OverworldMenuSettingsScene.new
            screen = PokemonOptionScreen.new(scene)
            screen.pbStartScreen
          }
        },
        _INTL("Configure Overworld Menu options.")),
      ButtonOption.new(_INTL("Save Tag"),
        proc { KIFR::SaveTags.set_tag if defined?(KIFR::SaveTags) },
        _INTL("Add a custom label to your save file."))
    ]
    
    # Debug & Developer category options
    options_by_category["Debug & Developer"] = [
      EnumOption.new(_INTL("Debug Mode"), [_INTL("Off"), _INTL("On")],
        proc { $DEBUG ? 1 : 0 },
        proc { |value| $DEBUG = (value == 1) },
        _INTL("Toggle debug mode and testing features.")),
      ButtonOption.new(_INTL("View Conflicts"),
        proc { pbFadeOutIn { show_conflict_viewer } },
        _INTL("Check for mod conflicts and compatibility issues.")),
      ButtonOption.new(_INTL("Save Delete Settings"),
        proc { pbFadeOutIn { save_delete_settings_menu } },
        _INTL("Manage saves - restore or permanently delete."))
    ]
    
    # Multiplayer category options
    options_by_category["Multiplayer"] = [
      ClickOnlyButtonOption.new(_INTL("Start MP Server"),
        proc {
          begin
            kifm_folder = File.join(Dir.pwd, "KIFM")
            kifm_path = File.join(kifm_folder, "launch_server.bat")
            
            if File.exist?(kifm_path)
              # Store current window handle BEFORE starting server
              game_hwnd = nil
              set_foreground = nil
              begin
                if defined?(Win32API)
                  get_foreground = Win32API.new('user32', 'GetForegroundWindow', '', 'L')
                  set_foreground = Win32API.new('user32', 'SetForegroundWindow', 'L', 'I')
                  game_hwnd = get_foreground.call
                end
              rescue
              end
              
              # Run the batch file minimized in background
              Dir.chdir(kifm_folder) do
                system("start /min \"\" \"launch_server.bat\"")
              end
              
              # Refocus on the game window immediately
              begin
                if game_hwnd && game_hwnd != 0 && set_foreground
                  set_foreground.call(game_hwnd)
                end
              rescue => e
                KIFRSettings.debug_log("Refocus error (non-critical): #{e.message}")
              end
              
              pbMessage(_INTL("Server started! Use the Multiplayer menu to connect."))
            else
              pbMessage(_INTL("Could not find launch_server.bat in KIFM folder."))
              KIFRSettings.debug_log("Start Server: File not found at #{kifm_path}")
            end
          rescue => e
            pbMessage(_INTL("Error: {1}", e.message))
            KIFRSettings.debug_log("Start Server error: #{e.message}")
          end
        },
        _INTL("Launch the Multiplayer server.")),
      ClickOnlyButtonOption.new(_INTL("Check for MP Update"),
        proc {
          begin
            # Check local version
            local_version = nil
            version_file = File.join(Dir.pwd, "Data", "Scripts", "659_Multiplayer", "002_Version.rb")
            
            if File.exist?(version_file)
              content = File.read(version_file)
              if content =~ /CURRENT_VERSION\s*=\s*["']([^"']+)["']/
                local_version = $1
              end
            end
            
            unless local_version
              pbMessage(_INTL("Could not find local Multiplayer version."))
              next
            end
            
            # Check online version (auto-continue message)
            msgwindow = pbCreateMessageWindow
            pbMessageDisplay(msgwindow, _INTL("Checking for Multiplayer updates..."), false)
            online_version = nil
            
            if defined?(HTTPLite)
              response = HTTPLite.get("https://raw.githubusercontent.com/skarreku/KIF-Multiplayer/main/version.txt")
              if response.is_a?(Hash) && response[:status] == 200
                online_version = response[:body].to_s.strip
              end
            end
            
            # Close the checking message
            pbDisposeMessageWindow(msgwindow)
            
            unless online_version
              pbMessage(_INTL("Could not fetch online version. Check your internet connection."))
              next
            end
            
            # Compare versions
            local_parts = local_version.split('.').map(&:to_i)
            online_parts = online_version.split('.').map(&:to_i)
            max_len = [local_parts.length, online_parts.length].max
            local_parts += [0] * (max_len - local_parts.length)
            online_parts += [0] * (max_len - online_parts.length)
            
            needs_update = false
            local_parts.each_with_index do |local_num, i|
              if local_num < online_parts[i]
                needs_update = true
                break
              elsif local_num > online_parts[i]
                break
              end
            end
            
            if needs_update
              # Offer to run the auto-updater
              if pbConfirmMessage(_INTL("Multiplayer update available!\n\nLocal: {1}\nOnline: {2}\n\nWould you like to run the auto-updater?", local_version, online_version))
                updater_path = File.join(Dir.pwd, "autoupdate_multiplayer.bat")
                if File.exist?(updater_path)
                  system("start \"\" \"#{updater_path}\"")
                  pbMessage(_INTL("Auto-updater started. Please restart the game after the update completes."))
                else
                  pbMessage(_INTL("Could not find autoupdate_multiplayer.bat in the game folder."))
                end
              end
            else
              pbMessage(_INTL("Multiplayer is up to date! Version: {1}", local_version))
            end
          rescue => e
            pbMessage(_INTL("Error checking for updates: {1}", e.message))
            KIFRSettings.debug_log("Check MP Update error: #{e.message}")
          end
        },
        _INTL("Check if a Multiplayer mod update is available."))
    ]
    
    # Economy category options
    options_by_category["Economy"] = [
      ButtonOption.new(_INTL("Economy Settings"),
        proc {
          pbFadeOutIn {
            scene = KIFR_EconomyScene.new
            screen = PokemonOptionScreen.new(scene)
            screen.pbStartScreen
          }
        },
        _INTL("Configure pricing, sales, money, and more.")),
      ButtonOption.new(_INTL("Kuray Shop"),
        proc {
          pbFadeOutIn {
            scene = KIFR_KurayShopSettingsScene.new
            screen = PokemonOptionScreen.new(scene)
            screen.pbStartScreen
          }
        },
        _INTL("Configure Kuray Shop options.")),
      ButtonOption.new(_INTL("Gift System"),
        proc {
          pbFadeOutIn {
            scene = KIFR_GiftSettingsScene.new
            screen = PokemonOptionScreen.new(scene)
            screen.pbStartScreen
          }
        },
        _INTL("View milestones, claimable gifts, and gift options.")),
      ButtonOption.new(_INTL("Economy Statistics"),
        proc {
          pbFadeOutIn {
            KIFR_EconomyStatisticsScene.show
          }
        },
        _INTL("View detailed economy statistics and analytics."))
    ]
    
    # Separator
    options_by_category["-----------------"] = []
    
    # Include KIFRDEV options if available (defined in 801_KIFRDEV)
    if defined?(KIFRDEV) && KIFRDEV.respond_to?(:settings_options)
      KIFRDEV.settings_options.each do |category, opts|
        options_by_category[category] ||= []
        options_by_category[category].concat(opts)
      end
    end
    
    # Build options with search filter
    options = build_options_list(options_by_category)
    
    # Add standalone buttons after separator
    options << ButtonOption.new(_INTL("Mod Manager"),
      proc { pbFadeOutIn { show_mod_updates_menu } },
      _INTL("Manage mods, updates, and configure mods."))
    
    options << ButtonOption.new(_INTL("Spritepacks"),
      proc { pbFadeOutIn { show_spritepacks_menu } },
      _INTL("Download spritepack files (PIF, KIF, KIFR)."))
    
    options << ButtonOption.new(_INTL("Save & Load Presets"),
      proc { pbFadeOutIn { show_preset_menu } },
      _INTL("Save or load KIFR configuration presets."))
    
    options
  end
  
  # Build options list with optional search filtering
  def build_options_list(options_by_category)
    options = []
    search_active = @search_term && !@search_term.empty?
    search_lower = search_active ? @search_term.downcase : ""
    
    if search_active
      # Search mode - filter and flatten
      match_count = 0
      
      options_by_category.each do |category_name, cat_options|
        next if category_name =~ /^-+$/  # Skip separators in search
        
        cat_options.each do |opt|
          name = opt.respond_to?(:name) ? opt.name.to_s : ""
          desc = opt.respond_to?(:description) ? opt.description.to_s : ""
          
          if name.downcase.include?(search_lower) || desc.downcase.include?(search_lower)
            options << opt
            match_count += 1
          end
        end
      end
      
      # Add search result count at top
      result_opt = SearchResultOption.new
      result_opt.set_count(match_count)
      options.unshift(result_opt)
    else
      # Normal mode - show categories
      KIFR_CATEGORIES.each do |cat|
        category_name = cat[:name]
        next unless options_by_category.key?(category_name)
        
        cat_options = options_by_category[category_name]
        
        # Skip empty categories (except separator)
        next if cat_options.empty? && category_name !~ /^-+$/
        
        # Add category header
        header = KIFRCategoryHeaderOption.new(_INTL(category_name))
        options << header
        
        # Add options if not collapsed
        unless KIFRSettings.category_collapsed?(category_name) || category_name =~ /^-+$/
          options.concat(cat_options)
        end
      end
    end
    
    options
  end
  
  def pbOptions
    oldSystemSkin = $PokemonSystem.frame
    oldTextSkin = $PokemonSystem.textskin
    oldGlobalFrame = $PokemonSystem.kifr_global_frame || 0
    oldSpeechFrame = $PokemonSystem.kifr_speech_frame || 0
    oldSeparateSpeech = $PokemonSystem.kifr_separate_speech || 0
    oldShopCursor = $PokemonSystem.kifr_shop_cursor_color || 0
    @should_exit = false
    
    pbActivateWindow(@sprites, "option") {
      loop do
        Graphics.update
        Input.update
        pbUpdate
        
        # Check exit flag (set by Back button callback)
        break if @should_exit
        
        # Handle search (Ctrl key)
        if Input.trigger?(Input::CTRL)
          if @search_term.empty?
            open_search
          else
            clear_search
          end
          next
        end
        
        if @sprites["option"].mustUpdateOptions
          current_option = @PokemonOptions[@sprites["option"].index]
          
          if current_option && current_option.is_a?(KIFRCategoryHeaderOption)
            # Toggle category
            old_state = current_option.get
            current_option.set(@sprites["option"][@sprites["option"].index])
            new_state = current_option.get
            
            if old_state != new_state
              rebuild_options_window
            end
          else
            # Update non-category options
            for i in 0...@PokemonOptions.length
              unless @PokemonOptions[i].is_a?(KIFRCategoryHeaderOption)
                @PokemonOptions[i].set(@sprites["option"][i])
              end
            end
          end
          
          # Preview Global Frame changes on the textbox
          newGlobalFrame = $PokemonSystem.kifr_global_frame || 0
          newSpeechFrame = $PokemonSystem.kifr_speech_frame || 0
          newSeparateSpeech = $PokemonSystem.kifr_separate_speech || 0
          
          if newGlobalFrame != oldGlobalFrame
            skin_name = KIFR_WINDOWSKINS[newGlobalFrame] || "KIFR Choice 1"
            skin_path = "Graphics/Windowskins/#{skin_name}"
            @sprites["textbox"].setSkin(skin_path)
            @sprites["textbox"].text = _INTL("Global Frame {1}", newGlobalFrame + 1)
            oldGlobalFrame = newGlobalFrame
          elsif newSpeechFrame != oldSpeechFrame
            # Preview Speech Frame changes
            skin_name = Settings::SPEECH_WINDOWSKINS[newSpeechFrame] || Settings::SPEECH_WINDOWSKINS[0]
            skin_path = "Graphics/Windowskins/#{skin_name}"
            @sprites["textbox"].setSkin(skin_path)
            @sprites["textbox"].text = _INTL("Speech Frame {1}", newSpeechFrame + 1)
            oldSpeechFrame = newSpeechFrame
          elsif newSeparateSpeech != oldSeparateSpeech
            # When toggling Separate Speech, show appropriate preview
            if newSeparateSpeech == 1
              # Show current speech frame
              skin_name = Settings::SPEECH_WINDOWSKINS[newSpeechFrame] || Settings::SPEECH_WINDOWSKINS[0]
              @sprites["textbox"].setSkin("Graphics/Windowskins/#{skin_name}")
              @sprites["textbox"].text = _INTL("Separate Speech: ON")
            else
              # Show global frame
              skin_name = KIFR_WINDOWSKINS[newGlobalFrame] || "KIFR Choice 1"
              @sprites["textbox"].setSkin("Graphics/Windowskins/#{skin_name}")
              @sprites["textbox"].text = _INTL("Separate Speech: OFF")
            end
            oldSeparateSpeech = newSeparateSpeech
          end
          
          # Preview Cursor Color changes
          newShopCursor = $PokemonSystem.kifr_shop_cursor_color || 0
          if newShopCursor != oldShopCursor
            color_info = SHOP_CURSOR_COLORS[newShopCursor] rescue nil
            color_name = color_info ? color_info[:name] : "Blue"
            @sprites["textbox"].text = _INTL("Cursor Color: {1}", color_name)
            oldShopCursor = newShopCursor
          end
        end
        
        # Check exit flag again after option updates
        break if @should_exit
        
        if Input.trigger?(Input::BACK)
          if !@search_term.empty?
            clear_search
          else
            break
          end
        elsif Input.trigger?(Input::USE)
          # Check if Confirm button selected
          break if isConfirmedOnKeyPress
          
          current_option = @PokemonOptions[@sprites["option"].index]
          # Handle button callbacks
          if current_option.is_a?(ButtonOption) && current_option.respond_to?(:callback) && current_option.callback
            current_option.callback.call
            break if @should_exit
          end
        end
      end
    }
  end
  
  # Rebuild options window after category toggle
  def rebuild_options_window
    current_index = @sprites["option"].index
    @PokemonOptions = pbGetOptions
    @sprites["option"].dispose if @sprites["option"]
    @sprites["option"] = initOptionsWindow
    
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0)
    end
    @sprites["option"].index = [current_index, @PokemonOptions.length - 1].min
    @sprites["option"].refresh
    pbActivateWindow(@sprites, "option")
  end
  
  # Open search input
  def open_search
    pbPlayDecisionSE
    @search_term = pbMessageFreeText(_INTL("Search settings:"), @search_term, false, 30) || ""
    @search_term = @search_term.strip
    rebuild_options_window
  end
  
  # Clear search
  def clear_search
    pbPlayDecisionSE
    @search_term = ""
    rebuild_options_window
  end
  
  # Preset management menu - opens scene
  def show_preset_menu
    scene = PresetMenuScene.new
    screen = PokemonOptionScreen.new(scene)
    screen.pbStartScreen
    
    # Re-apply theme after returning
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index) if @sprites && @sprites["option"]
  end
  
  # Mod Manager menu placeholder (will be expanded in UpdateSystem)
  def show_mod_updates_menu
    # This will be overridden/expanded by 003_KIFR_UpdateSystem.rb
    pbMessage(_INTL("Mod Manager loading...\n\nThis feature requires 003_KIFR_UpdateSystem.rb"))
  end
  
  def pbEndScene
    # Restore textbox to KIFR windowskin (preview may have changed it)
    if @sprites && @sprites["textbox"]
      @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    end
    # Save settings on exit
    KIFRSettings.save_to_file
    super
  end
end

# Screen wrapper
class KIFRSettingsScreen
  def initialize(scene)
    @scene = scene
  end
  
  def pbStartScreen(inloadscreen = false)
    @scene.pbStartScene(inloadscreen)
    @scene.pbOptions
    @scene.pbEndScene
  end
end

#===============================================================================
# PRESET MENU SCENE - Scene-based preset management
#===============================================================================
class PresetMenuScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create title (invisible initially)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Save & Load Presets"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].visible = false
    
    # Create textbox (invisible initially)
    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].visible = false
    
    # Build options and window
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = false
    
    # Apply color theme BEFORE showing anything
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    # Initialize values
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0) rescue 0
    end
    @sprites["option"].refresh
    
    # Now show everything
    @sprites.each { |k, s| s.visible = true if s }
    pbFadeInAndShow(@sprites)
  end
  
  def initOptionsWindow
    optionsWindow = Window_KIFR_Option.new(@PokemonOptions, 0,
                                           @sprites["title"].height, Graphics.width,
                                           Graphics.height - @sprites["title"].height - @sprites["textbox"].height)
    optionsWindow.setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    optionsWindow.viewport = @viewport
    optionsWindow.visible = true
    return optionsWindow
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    options << ButtonOption.new(_INTL("Save Current Settings"),
      proc { do_save_preset },
      _INTL("Save current settings as a new preset."))
    
    options << ButtonOption.new(_INTL("Load Preset"),
      proc { do_load_preset },
      _INTL("Load a previously saved preset."))
    
    options << ButtonOption.new(_INTL("Delete Preset"),
      proc { do_delete_preset },
      _INTL("Delete a saved preset."))
    
    options << ButtonOption.new(_INTL("Export Settings"),
      proc { do_export_settings },
      _INTL("Export settings to a file for backup or sharing."))
    
    options << ButtonOption.new(_INTL("Import Settings"),
      proc { do_import_settings },
      _INTL("Import settings from an exported file."))
    
    options
  end
  
  def pbOptions
    pbActivateWindow(@sprites, "option") {
      loop do
        Graphics.update
        Input.update
        pbUpdate
        
        if Input.trigger?(Input::BACK)
          break
        end
        
        if Input.trigger?(Input::USE)
          # Check if Confirm button selected
          break if isConfirmedOnKeyPress
          
          current = @sprites["option"].index
          option = @PokemonOptions[current]
          
          if option.is_a?(ButtonOption) && option.respond_to?(:callback) && option.callback
            option.callback.call
          end
        end
        
        # Update description
        current = @sprites["option"].index
        if current >= 0 && current < @PokemonOptions.length
          desc = @PokemonOptions[current].description rescue ""
          @sprites["textbox"].text = desc if @sprites["textbox"]
        end
      end
    }
  end
  
  def do_save_preset
    preset_name = pbMessageFreeText(_INTL("Enter preset name:"), "", false, 32)
    if preset_name && !preset_name.empty?
      if KIFRSettings.save_preset(preset_name)
        pbMessage(_INTL("Preset '{1}' saved!", preset_name))
      else
        pbMessage(_INTL("Failed to save preset."))
      end
    end
  end
  
  def do_load_preset
    presets = KIFRSettings.list_presets
    if presets.empty?
      pbMessage(_INTL("No presets found."))
    else
      preset_commands = presets + [_INTL("Cancel")]
      preset_choice = pbMessage(_INTL("Select preset:"), preset_commands, -1)
      
      if preset_choice >= 0 && preset_choice < presets.length
        if KIFRSettings.load_preset(presets[preset_choice])
          pbMessage(_INTL("Preset loaded!"))
          theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
          apply_kifr_color_theme(@sprites["option"], theme_index)
        else
          pbMessage(_INTL("Failed to load preset."))
        end
      end
    end
  end
  
  def do_delete_preset
    presets = KIFRSettings.list_presets
    if presets.empty?
      pbMessage(_INTL("No presets found."))
    else
      preset_commands = presets + [_INTL("Cancel")]
      preset_choice = pbMessage(_INTL("Select preset to delete:"), preset_commands, -1)
      
      if preset_choice >= 0 && preset_choice < presets.length
        if pbConfirmMessage(_INTL("Delete '{1}'?", presets[preset_choice]))
          if KIFRSettings.delete_preset(presets[preset_choice])
            pbMessage(_INTL("Preset deleted."))
          else
            pbMessage(_INTL("Failed to delete preset."))
          end
        end
      end
    end
  end
  
  def do_export_settings
    export_name = pbMessageFreeText(_INTL("Enter export name:"), "", false, 32)
    if export_name && !export_name.empty?
      if KIFRSettings.export_to_file(export_name)
        pbMessage(_INTL("Settings exported to '{1}.kifr'!", export_name))
      else
        pbMessage(_INTL("Failed to export settings."))
      end
    end
  end
  
  def do_import_settings
    exports = KIFRSettings.list_exports
    if exports.empty?
      pbMessage(_INTL("No export files found."))
    else
      export_commands = exports + [_INTL("Cancel")]
      export_choice = pbMessage(_INTL("Select file to import:"), export_commands, -1)
      
      if export_choice >= 0 && export_choice < exports.length
        if KIFRSettings.import_from_file(exports[export_choice])
          pbMessage(_INTL("Settings imported!"))
          theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
          apply_kifr_color_theme(@sprites["option"], theme_index)
        else
          pbMessage(_INTL("Failed to import settings."))
        end
      end
    end
  end
end

#===============================================================================
# OPTIONS MENU HOOK - Add KIFR Settings and Mod Settings buttons
#===============================================================================

if defined?(PokemonOption_Scene) && !defined?($kifr_options_hook_applied)
  $kifr_options_hook_applied = true

  class PokemonOption_Scene
    alias :kifr_original_pbGetOptions :pbGetOptions

    def pbGetOptions(*args)
      options = kifr_original_pbGetOptions(*args)
      
      # Find KIF Settings position
      insert_index = nil
      options.each_with_index do |opt, idx|
        begin
          if opt.respond_to?(:name) && opt.name == _INTL("KIF Settings")
            insert_index = idx + 1
            break
          end
        rescue
          next
        end
      end
      
      # Insert KIFR Settings button after KIF Settings
      kifr_button = ButtonOption.new(
        _INTL("KIFR Settings"),
        proc { open_kifr_settings_menu },
        _INTL("Configure KIF Redux UI and theme options.")
      )
      
      # Insert Mod Settings button (for registered mod options)
      mod_settings_button = ButtonOption.new(
        _INTL("Mod Settings"),
        proc { open_mod_settings_menu },
        _INTL("Configure individual mod options and settings.")
      )
      
      if insert_index
        options.insert(insert_index, kifr_button)
        options.insert(insert_index + 1, mod_settings_button)
      else
        options << kifr_button
        options << mod_settings_button
      end
      
      options
    end

    def open_kifr_settings_menu
      pbFadeOutIn {
        scene = KIFRSettingsScene.new
        screen = KIFRSettingsScreen.new(scene)
        screen.pbStartScreen
      }
    end
    
    def open_mod_settings_menu
      pbFadeOutIn {
        scene = ModSettingsScene.new
        screen = PokemonOptionScreen.new(scene)
        screen.pbStartScreen
      }
    end
    
    # Hook initOptionsWindow to enable KIFR custom drawing
    unless method_defined?(:kifr_hook_initOptionsWindow)
      alias_method :kifr_hook_initOptionsWindow, :initOptionsWindow
      
      def initOptionsWindow
        window = kifr_hook_initOptionsWindow
        # Enable KIFR custom drawing for cycling arrow display
        window.modsettings_menu = true if window.respond_to?(:modsettings_menu=)
        window
      end
    end
    
    # Apply KIFR theme to main Options menu before fade-in
    unless method_defined?(:kifr_theme_pbStartScene)
      alias_method :kifr_theme_pbStartScene, :pbStartScene
      
      def pbStartScene(*args)
        # Hide sprites initially by setting viewport invisible
        kifr_theme_pbStartScene(*args)
        
        # Apply KIFR color theme while sprites exist
        if @sprites && @sprites["option"]
          theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
          apply_kifr_color_theme(@sprites["option"], theme_index)
          @sprites["option"].refresh if @sprites["option"].respond_to?(:refresh)
        end
      end
      
      # Override pbFadeInAndShow to apply theme before showing
      alias_method :kifr_theme_pbFadeInAndShow, :pbFadeInAndShow
      
      def pbFadeInAndShow(sprites, visiblesprites = nil)
        # Apply color theme before fade-in
        if sprites && sprites["option"]
          theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
          apply_kifr_color_theme(sprites["option"], theme_index)
          sprites["option"].refresh if sprites["option"].respond_to?(:refresh)
        end
        kifr_theme_pbFadeInAndShow(sprites, visiblesprites)
      end
      
      # Hook pbEndScene to save ModSettingsMenu settings automatically
      # This ensures any scene that uses ModSettingsMenu.set will have changes persisted
      alias_method :kifr_save_pbEndScene, :pbEndScene
      
      def pbEndScene
        # Save ModSettingsMenu settings when ANY options scene exits
        # This catches scenes like OverworldMenuSettingsScene that don't override pbEndScene
        begin
          if defined?(KIFRSettings)
            KIFRSettings.save_to_file
          end
        rescue => e
          # Silently fail - don't break scene exit
        end
        kifr_save_pbEndScene
      end
    end
  end
end

#===============================================================================
# MOD SETTINGS SCENE - Shows all registered mod options
#===============================================================================
class ModSettingsScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def initialize
    super
    @search_term = ""
    # Reset all categories to collapsed when opening Mod Settings
    ModSettingsMenu.reset_all_categories
  end
  
  def initOptionsWindow
    optionsWindow = Window_KIFR_Option.new(@PokemonOptions, 0,
                                           @sprites["title"].height, Graphics.width,
                                           Graphics.height - @sprites["title"].height - @sprites["textbox"].height)
    optionsWindow.setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    optionsWindow.viewport = @viewport
    optionsWindow.visible = true
    optionsWindow.use_color_theme = true
    optionsWindow.modsettings_menu = true
    optionsWindow
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create title (invisible initially)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Mod Settings"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].visible = false
    
    # Create textbox (invisible initially)
    @sprites["textbox"] = pbCreateMessageWindow
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].letterbyletter = false
    @sprites["textbox"].visible = false
    
    # Build options
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = false
    
    # Apply color theme BEFORE showing anything
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    # Set initial values and refresh
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0)
    end
    @sprites["option"].refresh
    
    # Now show everything
    @sprites.each { |k, s| s.visible = true if s }
    pbFadeInAndShow(@sprites)
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    # Get all registered mod options grouped by category (from ModSettingsMenu, NOT KIFRSettings)
    registry_by_cat = ModSettingsMenu.registry_by_category
    
    # Initialize all categories to collapsed state when opening Mod Settings
    registry_by_cat.keys.each do |cat_name|
      ModSettingsMenu.initialize_category(cat_name, true)
    end
    
    if registry_by_cat.empty?
      # No mods registered - show a message
      options << ButtonOption.new(
        _INTL("No mods registered"),
        proc {},
        _INTL("No mods have registered settings. Mods can use ModSettingsMenu.register() to add options here.")
      )
      return options
    end
    
    # Build options by category (sorted by KIFR_CATEGORIES priority)
    sorted_categories = []
    KIFR_CATEGORIES.each do |cat_def|
      cat_name = cat_def[:name]
      next if cat_name =~ /^-+$/  # Skip separators
      sorted_categories << cat_name if registry_by_cat.key?(cat_name)
    end
    # Add any categories not in KIFR_CATEGORIES at the end
    registry_by_cat.keys.each do |cat_name|
      sorted_categories << cat_name unless sorted_categories.include?(cat_name)
    end
    
    sorted_categories.each do |category_name|
      registrations = registry_by_cat[category_name]
      next unless registrations && registrations.any?
      
      # Add category header
      options << KIFRCategoryHeaderOption.new(category_name, "")
      
      # Skip content if category is collapsed
      unless ModSettingsMenu.category_collapsed?(category_name)
        registrations.each do |reg|
          opt = build_option_from_registration(reg)
          options << opt if opt
        end
      end
    end
    
    options
  end
  
  # Convert a registration hash into an Option object
  def build_option_from_registration(reg)
    key = reg[:key]
    name = reg[:name] || key.to_s
    desc = reg[:description] || ""
    type = reg[:type] || :button
    
    case type
    when :button
      # Button that calls on_press
      callback = reg[:on_press] || proc {}
      ButtonOption.new(name, callback, desc)
      
    when :toggle
      # On/Off toggle
      EnumOption.new(name, [_INTL("Off"), _INTL("On")],
        proc { ModSettingsMenu.get(key, 0).to_i },
        proc { |value| ModSettingsMenu.set(key, value) },
        desc)
      
    when :enum
      # Multiple choice
      values = reg[:values] || [_INTL("Option 1")]
      EnumOption.new(name, values,
        proc { ModSettingsMenu.get(key, 0).to_i },
        proc { |value| ModSettingsMenu.set(key, value) },
        desc)
      
    when :slider
      # Slider with min/max/interval
      min = reg[:min] || 0
      max = reg[:max] || 100
      interval = reg[:interval] || 1
      StoneSliderOption.new(name, min, max, interval,
        proc { ModSettingsMenu.get(key, min).to_i },
        proc { |value| ModSettingsMenu.set(key, value) },
        desc)
      
    when :number
      # Number option
      min = reg[:min] || 0
      max = reg[:max] || 100
      NumberOption.new(name, min, max,
        proc { ModSettingsMenu.get(key, min).to_i },
        proc { |value| ModSettingsMenu.set(key, value) },
        desc)
      
    when :custom
      # Custom option object (already created)
      reg[:option_object]
      
    else
      # Unknown type - create as button
      ButtonOption.new(name, proc {}, desc)
    end
  end
  
  def pbOptions
    oldSystemSkin = $PokemonSystem.frame
    oldTextSkin = $PokemonSystem.textskin
    
    pbActivateWindow(@sprites, "option") {
      loop do
        Graphics.update
        Input.update
        pbUpdate
        
        if @sprites["option"].mustUpdateOptions
          current_option = @PokemonOptions[@sprites["option"].index]
          
          if current_option && current_option.is_a?(KIFRCategoryHeaderOption)
            # Toggle category
            old_state = current_option.get
            current_option.set(@sprites["option"][@sprites["option"].index])
            new_state = current_option.get
            
            if old_state != new_state
              rebuild_options_window
            end
          else
            # Update non-category options
            for i in 0...@PokemonOptions.length
              unless @PokemonOptions[i].is_a?(KIFRCategoryHeaderOption)
                @PokemonOptions[i].set(@sprites["option"][i])
              end
            end
          end
          
          # Note: Options menus always use KIFR Choice 1a, not affected by frame settings
        end
        
        if Input.trigger?(Input::BACK)
          break
        elsif Input.trigger?(Input::USE)
          # Check if Confirm button selected
          break if isConfirmedOnKeyPress
          
          current_option = @PokemonOptions[@sprites["option"].index]
          # Handle button callbacks
          if current_option.is_a?(ButtonOption) && current_option.respond_to?(:callback) && current_option.callback
            current_option.callback.call
          end
        end
      end
    }
  end
  
  def rebuild_options_window
    current_index = @sprites["option"].index
    @PokemonOptions = pbGetOptions
    @sprites["option"].dispose if @sprites["option"]
    @sprites["option"] = initOptionsWindow
    
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0)
    end
    @sprites["option"].index = [current_index, @PokemonOptions.length - 1].min
    @sprites["option"].refresh
    pbActivateWindow(@sprites, "option")
  end
end

#===============================================================================
# Shows colors in their actual colors
#===============================================================================
class Window_KIFR_Color < Window_PokemonOption
  def drawItem(index, _count, rect)
    # For Menu Theme (index 0) and Category Theme (index 1), draw with colored values
    if (index == 0 || index == 1) && @options[index]
      return if respond_to?(:dont_draw_item) && dont_draw_item(index)
      rect = drawCursor(index, rect)
      
      # Draw the option name (label) in normal menu colors
      optionname = @options[index].name
      optionwidth = rect.width * 12 / 20
      pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height, optionname,
                       @nameBaseColor, @nameShadowColor)
      
      # Get the current value and its theme
      optionvalue = self[index] || 0
      value = @options[index].values[optionvalue]
      theme_key = COLOR_THEMES.keys[optionvalue] if defined?(COLOR_THEMES)
      theme = COLOR_THEMES[theme_key] if theme_key && defined?(COLOR_THEMES)
      
      # Draw the value text in the color it represents
      if theme && theme[:base] && theme[:shadow]
        xpos = optionwidth + rect.x
        pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
                         theme[:base], theme[:shadow])
      else
        xpos = optionwidth + rect.x
        pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
                         @selBaseColor, @selShadowColor)
      end
    else
      super(index, _count, rect)
    end
  end
end

#===============================================================================
# KIFR COLOR SCENE - Color theme picker
#===============================================================================
class KIFRColorScene < PokemonOption_Scene
  # Skip fade-in to avoid double-fade
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def initOptionsWindow
    optionsWindow = Window_KIFR_Color.new(@PokemonOptions, 0,
                                          @sprites["title"].height, Graphics.width,
                                          Graphics.height - @sprites["title"].height - @sprites["textbox"].height)
    optionsWindow.viewport = @viewport
    optionsWindow.visible = true
    return optionsWindow
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    theme_names = if defined?(COLOR_THEMES)
                    COLOR_THEMES.keys.map { |k| COLOR_THEMES[k][:name] }
                  else
                    ["Purple", "Blue", "Green", "Red", "Orange", "Cyan", "Pink", "Yellow"]
                  end
    
    # Menu color theme
    opt = EnumOption.new(
      _INTL("Menu Theme"),
      theme_names,
      proc { ($PokemonSystem.kifr_color_theme rescue 0) || 0 },
      proc { |value| 
        $PokemonSystem.kifr_color_theme = value
        apply_color_theme(@sprites["option"], value) if @sprites && @sprites["option"]
      },
      _INTL("Choose the color theme for menu text")
    )
    options << opt
    
    # Category color theme
    opt2 = EnumOption.new(
      _INTL("Category Theme"),
      theme_names,
      proc { ($PokemonSystem.kifr_category_theme rescue 3) || 3 },
      proc { |value| 
        $PokemonSystem.kifr_category_theme = value
        @sprites["option"].refresh if @sprites && @sprites["option"]
      },
      _INTL("Choose the color theme for category headers")
    )
    options << opt2
    
    return options
  end
  
  def pbStartScene(inloadscreen = false)
    super
    
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("KIFR Colors"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin) if defined?(PokemonOption_Scene.get_kifr_windowskin)
    
    if @sprites["option"] && @sprites["option"].respond_to?(:modsettings_menu=)
      @sprites["option"].modsettings_menu = true
    end
    
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_color_theme(@sprites["option"], theme_index) if @sprites["option"]
    
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0)
    end
    @sprites["option"].refresh
    
    pbFadeInAndShow(@sprites) { pbUpdate }
  end
  
  def apply_color_theme(window, theme_index)
    return unless window && defined?(COLOR_THEMES)
    theme_key = COLOR_THEMES.keys[theme_index]
    return unless theme_key
    
    theme = COLOR_THEMES[theme_key]
    if theme && theme[:base] && theme[:shadow]
      window.nameBaseColor = theme[:base]
      window.nameShadowColor = theme[:shadow]
      window.selBaseColor = theme[:base]
      window.selShadowColor = theme[:shadow]
      window.refresh if window.respond_to?(:refresh)
    end
  end
end

#===============================================================================
# KIFR Color Option Button - Opens color scene
#===============================================================================
class KIFRColorOption < ButtonOption
  def initialize
    super(
      _INTL("KIFR Colors"),
      proc {
        pbFadeOutIn {
          scene = KIFRColorScene.new
          screen = PokemonOptionScreen.new(scene)
          screen.pbStartScreen
        }
      },
      _INTL("Customize the color theme for KIFR menus")
    )
  end
end

KIFRSettings.debug_log("KIFR Options module loaded")
