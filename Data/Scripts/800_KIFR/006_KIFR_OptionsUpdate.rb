#===============================================================================
# KIF Redux Options Update - Window_PokemonOption Patches
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file patches Window_PokemonOption to support KIFR's custom drawing
# and input handling. This allows mods that use Window_PokemonOption directly
# to benefit from KIFR's spacing, category headers, and button handling.
#
# Loads AFTER base classes but BEFORE the compatibility alias layer (999).
#===============================================================================

#===============================================================================
# KIFRSectionHeaderOption - Section header for PIF Settings menus
# Displays as [ NAME ] centered with KIFR category color
#===============================================================================
class KIFRSectionHeaderOption
  attr_reader :name
  
  def initialize(name)
    @name = name
  end
  
  def get
    return 0
  end
  
  def set(value)
  end
  
  def values
    return [@name]
  end
  
  # Required by Window_PokemonOption for left/right input
  def next(current)
    return current  # Non-interactive, no change
  end
  
  def prev(current)
    return current  # Non-interactive, no change
  end
end

#===============================================================================
# Window_PokemonOption - Add missing setter methods and custom drawing
# This patches the base window class for mod compatibility
#===============================================================================
if defined?(Window_PokemonOption)
  class Window_PokemonOption
    # Add accessor flags for custom drawing behavior
    attr_accessor :modsettings_menu, :use_color_theme
    
    # Add options accessor for KIFR header replacement
    attr_accessor :options
    
    # Add selBaseColor= setter (mods expect this but base class only has getter)
    unless method_defined?(:selBaseColor=)
      def selBaseColor=(value)
        @selBaseColor = value
      end
    end
    
    # Add selShadowColor= setter (mods expect this but base class only has getter)
    unless method_defined?(:selShadowColor=)
      def selShadowColor=(value)
        @selShadowColor = value
      end
    end
    
    # Patch drawItem to use KIFR custom drawing when modsettings_menu is set
    # This allows mods using Window_PokemonOption to get the same spacing behavior
    unless method_defined?(:kifr_compat_original_drawItem)
      alias kifr_compat_original_drawItem drawItem
      
      def drawItem(index, _count, rect)
        # Check for KIFRSectionHeaderOption FIRST (works for all menus)
        if index < @options.length
          opt = @options[index]
          if opt.is_a?(KIFRSectionHeaderOption)
            kifr_draw_section_header(opt, index, rect)
            return
          end
        end
        
        # Only use custom drawing if modsettings_menu flag is set
        # and we have options at this index
        if @modsettings_menu && index < @options.length
          option = @options[index]
          
          # Handle special option types
          case option
          when SpacerOption
            return  # Draw nothing for spacers
          when KIFRCategoryHeaderOption
            kifr_compat_draw_category_header(option, index, rect)
            return
          when SearchResultOption
            kifr_compat_draw_search_result(option, index, rect)
            return
          end
          
          # Use KIFR custom drawing for standard options
          kifr_compat_draw_option_with_spacing(index, _count, rect)
        else
          # Use original drawing
          kifr_compat_original_drawItem(index, _count, rect)
        end
      end
    end
    
    # Draw section header (centered with brackets and category color)
    def kifr_draw_section_header(option, index, rect)
      return if respond_to?(:dont_draw_item) && dont_draw_item(index)
      rect = drawCursor(index, rect)
      
      # Get KIFR category color
      category_theme_idx = 3
      begin
        category_theme_idx = $PokemonSystem.kifr_category_theme if $PokemonSystem.kifr_category_theme
      rescue
      end
      
      theme = nil
      if defined?(COLOR_THEMES)
        theme_key = COLOR_THEMES.keys[category_theme_idx]
        theme = COLOR_THEMES[theme_key] if theme_key
      end
      
      # Format with brackets: [ NAME ]
      header_text = "[ " + option.name + " ]"
      text_width = self.contents.text_size(header_text).width
      x_pos = (rect.width - text_width) / 2
      
      if theme && theme[:base]
        base_color = theme[:base]
        shadow_color = theme[:shadow]
      else
        base_color = @selBaseColor
        shadow_color = @selShadowColor
      end
      
      pbDrawShadowText(self.contents, x_pos, rect.y, rect.width, rect.height, header_text,
                       base_color, shadow_color)
    end
    
    # Custom drawing with proper spacing (matches Window_KIFR_Option behavior)
    def kifr_compat_draw_option_with_spacing(index, _count, rect)
      return if respond_to?(:dont_draw_item) && dont_draw_item(index)
      rect = drawCursor(index, rect)
      
      option = @options[index]
      optionname = option.name
      optionwidth = rect.width * 12 / 20  # 60% for label, 40% for value
      
      # ButtonOptions get full width
      if option.is_a?(ButtonOption)
        optionwidth = rect.width
      end
      
      # Draw option name
      pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height, optionname,
                       @nameBaseColor, @nameShadowColor)
      
      # Draw value based on option type
      if option.is_a?(EnumOption) || option.is_a?(ButtonsOption)
        kifr_compat_draw_enum(option, index, rect, optionwidth)
      elsif option.is_a?(NumberOption)
        kifr_compat_draw_number(option, index, rect, optionwidth)
      elsif option.is_a?(StoneSliderOption)
        kifr_compat_draw_stone_slider(option, index, rect, optionwidth)
      elsif option.is_a?(SliderOption)
        kifr_compat_draw_slider(option, index, rect, optionwidth)
      end
    end
    
    # Draw EnumOption with cycling arrows: < Choice >
    def kifr_compat_draw_enum(option, index, rect, optionwidth)
      return unless option.values && option.values.length > 0
      
      # Check for color display options
      if option.respond_to?(:name) && defined?(COLOR_THEMES) &&
         (option.name == _INTL("Menu Color") || option.name == _INTL("Category Color"))
        optionvalue = self[index] || 0
        value = option.values[optionvalue]
        theme_key = COLOR_THEMES.keys[optionvalue]
        theme = COLOR_THEMES[theme_key] if theme_key
        
        # Center in the slider bar area (matches slider positioning)
        fixed_bar_length = 108
        bar_x = optionwidth + rect.x + 10
        bar_center = bar_x + (fixed_bar_length / 2)
        value_width = self.contents.text_size(value).width
        xpos = bar_center - (value_width / 2)
        
        if theme && theme[:base] && theme[:shadow]
          pbDrawShadowText(self.contents, xpos, rect.y, value_width + 20, rect.height, value,
                           theme[:base], theme[:shadow])
        else
          pbDrawShadowText(self.contents, xpos, rect.y, value_width + 20, rect.height, value,
                           @selBaseColor, @selShadowColor)
        end
        return
      end
      
      # Use cycling arrow display for all enum options
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
    
    # Draw NumberOption
    def kifr_compat_draw_number(option, index, rect, optionwidth)
      value = _INTL("Type {1}/{2}", option.optstart + self[index],
                    option.optend - option.optstart + 1)
      pbDrawShadowText(self.contents, optionwidth + rect.x, rect.y, optionwidth, rect.height, value,
                       @selBaseColor, @selShadowColor)
    end
    
    # Draw StoneSliderOption
    def kifr_compat_draw_stone_slider(option, index, rect, optionwidth)
      fixed_bar_length = 108
      min_val, max_val = option.optstart, option.optend
      current_val = [[self[index], min_val].max, max_val].min
      range = [max_val - min_val, 1].max
      percentage = (current_val - min_val).to_f / range
      
      bar_x = optionwidth + rect.x + 10
      bar_y = rect.y - 2 + rect.height / 2
      
      self.contents.fill_rect(bar_x, bar_y, fixed_bar_length, 4, self.baseColor)
      tick_x = bar_x + (percentage * (fixed_bar_length - 8)).round
      self.contents.fill_rect(tick_x, bar_y - 6, 8, 16, @selBaseColor)
      
      # Use display formatter if available
      if option.respond_to?(:format_value)
        display_val = option.format_value(current_val)
      else
        display_val = sprintf("%d", current_val)
      end
      pbDrawShadowText(self.contents, bar_x + fixed_bar_length + 8, rect.y, 80, rect.height,
                       display_val, @selBaseColor, @selShadowColor)
    end
    
    # Draw SliderOption
    def kifr_compat_draw_slider(option, index, rect, optionwidth)
      sliderlength = [rect.width * 8 / 20 - self.contents.text_size(sprintf(" %d", option.optend)).width, 108].min
      xpos = optionwidth + rect.x
      bar_y = rect.y - 2 + rect.height / 2
      
      self.contents.fill_rect(xpos, bar_y, sliderlength, 4, self.baseColor)
      tick_pos = (sliderlength - 8) * (option.optstart + self[index]) / option.optend
      self.contents.fill_rect(xpos + tick_pos, rect.y - 8 + rect.height / 2, 8, 16, @selBaseColor)
      
      pbDrawShadowText(self.contents, xpos + sliderlength + 8, rect.y, 80, rect.height,
                       sprintf("%d", option.optstart + self[index]), @selBaseColor, @selShadowColor)
    end
    
    # Draw category header (centered)
    def kifr_compat_draw_category_header(option, index, rect)
      return if respond_to?(:dont_draw_item) && dont_draw_item(index)
      rect = drawCursor(index, rect)
      
      category_theme_idx = ($PokemonSystem.kifr_category_theme rescue 3) || 3
      theme_key = defined?(COLOR_THEMES) ? COLOR_THEMES.keys[category_theme_idx] : nil
      theme = theme_key ? COLOR_THEMES[theme_key] : nil
      
      optionname = option.format(self[index])
      text_width = self.contents.text_size(optionname).width rescue rect.width
      x_pos = (rect.width - text_width) / 2
      
      base_color = (theme && theme[:base]) ? theme[:base] : @nameBaseColor
      shadow_color = (theme && theme[:shadow]) ? theme[:shadow] : @nameShadowColor
      pbDrawShadowText(self.contents, x_pos, rect.y, rect.width, rect.height, optionname,
                       base_color, shadow_color)
    end
    
    # Draw search result (centered)
    def kifr_compat_draw_search_result(option, index, rect)
      kifr_compat_draw_category_header(option, index, rect)  # Same display behavior
    end
    
    # Patch update method to handle category headers and button options
    unless method_defined?(:kifr_compat_original_update)
      alias kifr_compat_original_update update
      
      def update
        oldindex = self.index
        
        # Let parent handle standard input
        kifr_compat_original_update
        
        # Only add custom handling if modsettings_menu flag is set
        return unless @modsettings_menu
        
        dorefresh = (self.index != oldindex)
        
        # Handle USE button for special option types
        if self.active && self.index < @options.length
          current_option = @options[self.index]
          
          if Input.trigger?(Input::USE)
            if current_option.is_a?(KIFRCategoryHeaderOption)
              # Toggle category collapse state
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
  end
  
  KIFRSettings.debug_log("Window_PokemonOption patched with KIFR custom drawing") if defined?(KIFRSettings)
end
