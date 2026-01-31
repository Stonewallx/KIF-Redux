#===============================================================================
# KIF Redux Overworld Menu - Quick Access Menu System
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file provides:
# - Overworld Menu with customizable button trigger
# - Submenu registration system for other mods
# - Party view display
# - Weather box integration (if Weather System present)
# - Page-based organization with R button switching
#
# Originally standalone mod, now integrated into KIFR.
# External mods can still use OverworldMenu.register() API.
#===============================================================================

#===============================================================================
# Priority Configuration - Edit priorities here
#===============================================================================
# Lower priority = appears first in menu
# Edit the numbers below to reorder menu items
# Registered mods will automatically appear even if not listed here
#===============================================================================
module OverworldMenuConfig
  PRIORITIES = {
    # Framework built-ins
    :time          => 10,   # Time changer
    :options       => 999,  # Options (always last before page number)
    
    
    # Add your custom mod priorities here:
    # :my_custom_mod => 25,
  }
  
  # Get priority for a submenu (returns configured priority or falls back to registration priority)
  def self.get_priority(key, default = 99)
    PRIORITIES[key] || default
  end
end

#===============================================================================
# Submenu Registration System
#===============================================================================
module OverworldMenu
  @registry = []
  @pending_registrations = []
  
  # Register a submenu to appear in the Overworld Menu
  # @param key [Symbol] Unique identifier for this submenu
  # @param config [Hash] Configuration options:
  #   - :label [String] Display name in menu
  #   - :handler [Proc] Proc that handles the menu action, receives (screen) as parameter
  #   - :priority [Integer] Optional ordering (lower = appears first), default 100
  #   - :condition [Proc] Optional availability check, default always true
  #   - :exit_on_select [Boolean] Optional, whether to exit menu after selection, default false
  def self.register(key, config)
    # Validate required fields
    unless key.is_a?(Symbol)
      echoln "[OverworldMenu] Error: key must be a Symbol, got #{key.class}"
      KIFRSettings.debug_log("OverworldMenu: Registration failed - key must be Symbol, got #{key.class}") if defined?(KIFRSettings)
      return
    end
    
    unless config[:label].is_a?(String)
      echoln "[OverworldMenu] Error: :label must be a String for key #{key}"
      KIFRSettings.debug_log("OverworldMenu: Registration failed for #{key} - label must be String") if defined?(KIFRSettings)
      return
    end
    
    unless config[:handler].is_a?(Proc)
      echoln "[OverworldMenu] Error: :handler must be a Proc for key #{key}"
      KIFRSettings.debug_log("OverworldMenu: Registration failed for #{key} - handler must be Proc") if defined?(KIFRSettings)
      return
    end
    
    # Check if already registered
    if @registry.any? { |r| r[:key] == key }
      echoln "[OverworldMenu] Warning: key #{key} already registered, skipping duplicate"
      KIFRSettings.debug_log("OverworldMenu: Warning - #{key} already registered, skipping duplicate") if defined?(KIFRSettings)
      return
    end
    
    # Get priority from config first, then registration, then default
    registration_priority = config[:priority] || 99
    final_priority = OverworldMenuConfig.get_priority(key, registration_priority)
    
    # Build registration entry
    entry = {
      key: key,
      label: config[:label],
      handler: config[:handler],
      priority: final_priority,
      condition: config[:condition] || proc { true },
      exit_on_select: config[:exit_on_select] || false
    }
    
    @registry << entry
    
    # Sort by priority (lower = first)
    @registry.sort_by! { |r| r[:priority] }
    
    echoln "[OverworldMenu] Registered submenu: #{key} (\"#{config[:label]}\") at priority #{entry[:priority]}"
  end
  
  # Get all registered submenus
  def self.registry
    @registry ||= []
  end
  
  # Check if a submenu is available based on its condition
  def self.available?(key)
    entry = @registry.find { |r| r[:key] == key }
    return false unless entry
    entry[:condition].call rescue false
  end
  
  # Get available submenus for display
  def self.available_submenus
    @registry.select { |r| r[:condition].call rescue false }
  end
  
  # Show all registered priorities (for debugging/configuration)
  def self.show_priorities
    echoln "=== Overworld Menu Priorities ==="
    @registry.each do |entry|
      available = entry[:condition].call rescue false
      status = available ? "[AVAILABLE]" : "[HIDDEN]"
      echoln "#{entry[:priority].to_s.rjust(3)} - #{entry[:label].ljust(15)} (#{entry[:key]}) #{status}"
    end
    echoln "================================="
  end
  
  # Clear registry (for testing)
  def self.clear_registry
    @registry = []
  end
end

#===============================================================================
# Settings Storage & Menu
#===============================================================================
module OverworldMenuSettings
  @pending = []

  def self.get(key)
    ensure_defaults
    if defined?(KIFRSettings)
      KIFRSettings.get(key)
    else
      case key
      when :overworld_menu_enabled then true
      when :overworld_menu_button then Input::JUMPUP
      end
    end
  end

  def self.set(key, value)
    if defined?(KIFRSettings)
      KIFRSettings.set(key, value)
    end
  end

  def self.ensure_defaults
    if defined?(KIFRSettings)
      KIFRSettings.set_default(:overworld_menu_enabled, true)
      KIFRSettings.set_default(:overworld_menu_button, 0) # Index into BUTTON_OPTIONS - Z/(X)
      KIFRSettings.set_default(:overworld_menu_party_view, true)
      KIFRSettings.set_default(:overworld_menu_weather_box, true)
      KIFRSettings.set_default(:overworld_menu_pages, 2) # Number of pages (1-5)
      
      # Initialize page assignments for all registered submenus
      OverworldMenu.registry.each do |entry|
        page_key = "overworld_menu_page_#{entry[:key]}".to_sym
        KIFRSettings.set_default(page_key, 1) # Default to page 1
      end
    end
  end
  
  # Button options for cycling display
  BUTTON_OPTIONS = [
    [Input::ACTION, "Z / (X)"],
    [Input::AUX1, "Q / (L)"],
    [Input::AUX2, "W / (R)"],
    [Input::SPECIAL, "D / (RS)"],
    [Input::JUMPUP, "A / (Y)"],
    [Input::JUMPDOWN, "S / (LS)"],
    [[Input::AUX1, Input::AUX2], "Q + W"],
    [[Input::AUX1, Input::ACTION], "Q + Z"],
    [[Input::AUX2, Input::ACTION], "W + Z"],
    [[Input::AUX1, Input::JUMPUP], "Q + A"],
    [[Input::AUX2, Input::JUMPUP], "W + A"],
    [[Input::AUX1, Input::JUMPDOWN], "Q + S"],
    [[Input::AUX2, Input::JUMPDOWN], "W + S"],
    [[Input::SPECIAL, Input::ACTION], "D + Z"],
    [[Input::JUMPUP, Input::ACTION], "A + Z"],
    [[Input::JUMPDOWN, Input::ACTION], "S + Z"]
  ]
  
  def self.get_button_index
    idx = get(:overworld_menu_button)
    return idx.is_a?(Integer) ? idx : 0 # Default to ACTION Z/(X) (index 0)
  end
  
  def self.set_button_index(idx)
    set(:overworld_menu_button, idx.clamp(0, BUTTON_OPTIONS.length - 1))
  end
  
  def self.get_button_from_index(idx)
    BUTTON_OPTIONS[idx.clamp(0, BUTTON_OPTIONS.length - 1)][0]
  end
  
  def self.get_current_button
    get_button_from_index(get_button_index)
  end

  # Removed - Button configuration now in OverworldMenuSettingsScene

  def self.get_button_display_name
    idx = get_button_index
    BUTTON_OPTIONS[idx.clamp(0, BUTTON_OPTIONS.length - 1)][1]
  end

  def self.try_pending
    return if @pending.empty?
    left = @pending.dup
    @pending.clear
    left.each do |pr|
      begin
        pr.call
      rescue
      end
    end
  end

  def self.button_name(button_or_combo)
    if button_or_combo.is_a?(Array)
      names = button_or_combo.map { |btn| single_button_name(btn) }
      return names.join(" + ")
    else
      return single_button_name(button_or_combo)
    end
  end
  
  def self.single_button_name(button_constant)
    case button_constant
    when Input::ACTION then "Z / (X)"
    when Input::AUX1 then "Q / (L)"
    when Input::AUX2 then "W / (R)"
    when Input::SPECIAL then "D / (RS)"
    when Input::JUMPUP then "A / (Y)"
    when Input::JUMPDOWN then "S / (LS)"
    when Input::UP then "Up"
    when Input::DOWN then "Down"
    when Input::LEFT then "Left"
    when Input::RIGHT then "Right"
    else "?"
    end
  end

  # Removed - Button configuration now in OverworldMenuSettingsScene
  
  def self.buttons_equal?(a, b)
    if a.is_a?(Array) && b.is_a?(Array)
      return a.sort == b.sort
    elsif !a.is_a?(Array) && !b.is_a?(Array)
      return a == b
    else
      return false
    end
  end
  
  def self.check_trigger(button_or_combo)
    if button_or_combo.is_a?(Array)
      return button_or_combo.all? { |btn| Input.press?(btn) } && 
             button_or_combo.any? { |btn| Input.trigger?(btn) }
    else
      return Input.trigger?(button_or_combo)
    end
  end
end

# Button configuration integrated into OverworldMenuSettingsScene

#===============================================================================
# Scene for Overworld Menu
#===============================================================================
class OverworldMenuScene
  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 100000  # Higher than Weather Box (99999) to ensure menu is always on top
    @sprites = {}
    @sprites["cmdwindow"] = Window_CommandPokemon.new([])
    @sprites["cmdwindow"].visible = false
    @sprites["cmdwindow"].viewport = @viewport
    
    # Create party overview display
    create_party_display
    
    # Create weather box if Weather System mod is present
    create_weather_box
    
    pbSEPlay("GUI menu open")
  end
  
  def create_party_display
    return unless $Trainer && $Trainer.party
    return unless OverworldMenuSettings.get(:overworld_menu_party_view)
    
    # 2x3 grid layout - moderate size for left side
    slot_width = 160
    slot_height = 110
    start_x = 15
    start_y = 60
    
    $Trainer.party.each_with_index do |pkmn, i|
      break if i >= 6
      
      col = i % 2
      row = i / 2
      
      x_pos = start_x + (col * slot_width)
      y_pos = start_y + (row * slot_height)
      
      # Shiny star icon 
      if pkmn.shiny? && !pkmn.egg?
        begin
          @sprites["party_shiny_#{i}"] = Sprite.new(@viewport)
          @sprites["party_shiny_#{i}"].bitmap = Bitmap.new("Graphics/11a_Overworld Menu/UI/Party View/shiny")
          @sprites["party_shiny_#{i}"].x = x_pos + 15
          @sprites["party_shiny_#{i}"].y = y_pos + 47
          @sprites["party_shiny_#{i}"].zoom_x = 0.2
          @sprites["party_shiny_#{i}"].zoom_y = 0.2
        rescue
        end
      end
      
      # Held item icon
      if pkmn.item && pkmn.item != :NONE && !pkmn.egg?
        @sprites["party_item_#{i}"] = ItemIconSprite.new(x_pos + slot_width - 40, y_pos + 56, pkmn.item, @viewport)
        @sprites["party_item_#{i}"].zoom_x = 0.5
        @sprites["party_item_#{i}"].zoom_y = 0.5
      end
      
      # Pokemon icon sprite (centered horizontally to match HP bar)
      @sprites["party_pkmn_#{i}"] = PokemonIconSprite.new(pkmn, @viewport)
      @sprites["party_pkmn_#{i}"].setOffset(PictureOrigin::Center)
      @sprites["party_pkmn_#{i}"].x = x_pos + slot_width / 2 + 5
      @sprites["party_pkmn_#{i}"].y = y_pos + 40
      @sprites["party_pkmn_#{i}"].zoom_x = 1.0
      @sprites["party_pkmn_#{i}"].zoom_y = 1.0
      
      # Info overlay
      @sprites["party_info_#{i}"] = Sprite.new(@viewport)
      @sprites["party_info_#{i}"].bitmap = Bitmap.new(slot_width - 10, slot_height - 10)
      @sprites["party_info_#{i}"].x = x_pos
      @sprites["party_info_#{i}"].y = y_pos
      
      bitmap = @sprites["party_info_#{i}"].bitmap
      
      unless pkmn.egg?
        # HP Bar
        hp_percent = pkmn.hp.to_f / pkmn.totalhp.to_f
        bar_width = 110
        bar_height = 6
        bar_x = (slot_width - 10 - bar_width) / 2
        bar_y = 68
        
        # HP Bar background
        bitmap.fill_rect(bar_x, bar_y, bar_width, bar_height, Color.new(50, 50, 50))
        
        # HP Bar fill
        bar_color = if hp_percent > 0.5
          Color.new(64, 200, 64)
        elsif hp_percent > 0.25
          Color.new(255, 200, 64)
        else
          Color.new(255, 64, 64)
        end
        
        fill_width = (bar_width * hp_percent).to_i
        bitmap.fill_rect(bar_x, bar_y, fill_width, bar_height, bar_color)
        
        # Level text on the left
        bitmap.font.size = 14
        bitmap.font.bold = true
        level_text = "Lv. #{pkmn.level}"
        pbDrawShadowText(bitmap, 15, bar_y + 3, 100, bar_height + 2, level_text,
                        Color.new(255, 255, 255), Color.new(0, 0, 0), 0)
        
        # HP Text overlay
        hp_text = "#{pkmn.hp}/#{pkmn.totalhp}"
        pbDrawShadowText(bitmap, bar_x + 42, bar_y + 3, bar_width, bar_height + 2, hp_text,
                        Color.new(255, 255, 255), Color.new(0, 0, 0), 1)
        
        # Status condition icon (same logic as party screen)
        status_id = -1
        if pkmn.fainted?
          status_id = GameData::Status::DATA.keys.length / 2
        elsif pkmn.status != :NONE
          status_id = GameData::Status.get(pkmn.status).id_number
        elsif pkmn.pokerusStage == 1
          status_id = GameData::Status::DATA.keys.length / 2 + 1
        end
        status_id -= 1
        
        if status_id >= 0
          begin
            statuses_bitmap = AnimatedBitmap.new("Graphics/Pictures/statuses")
            status_rect = Rect.new(0, 16 * status_id, 44, 16)
            # Create a scaled down sprite for the status icon
            status_sprite = Sprite.new(@viewport)
            status_sprite.bitmap = Bitmap.new(44, 16)
            status_sprite.bitmap.blt(0, 0, statuses_bitmap.bitmap, status_rect)
            status_sprite.x = x_pos + bar_x - 44 + 50 + 30 + 7
            status_sprite.y = y_pos + bar_y + 9
            status_sprite.zoom_x = 0.6
            status_sprite.zoom_y = 0.6
            @sprites["party_status_#{i}"] = status_sprite
            statuses_bitmap.dispose
          rescue
          end
        end
      else
        # Egg indicator
        bitmap.font.size = 18
        bitmap.font.bold = true
        pbDrawShadowText(bitmap, 0, 58, slot_width - 10, 24, "EGG",
                        Color.new(255, 255, 255), Color.new(0, 0, 0), 1)
      end
    end
  end

  def create_weather_box
    # Only create if the setting is enabled
    return unless OverworldMenuSettings.get(:overworld_menu_weather_box)
    
    return unless defined?(WeatherSystem)
    
    begin
      @sprites["weather_box"] = Sprite.new(@viewport)
      @sprites["weather_box"].bitmap = Bitmap.new("Graphics/12_Weather System/Weather Box/Box")
      @sprites["weather_box"].z = 99999
      
      # Position 8 pixels left of the bottom right party view sprite right edge
      party_slot_right_edge = 15 + (1 * 160) + 160
      party_slot_bottom_row_y = 60 + (2 * 110)
      
      @sprites["weather_box"].x = party_slot_right_edge - 8
      @sprites["weather_box"].y = party_slot_bottom_row_y
      
      # Get current weather and draw icon on top right of box
      current_weather = $game_screen.weather_type rescue :None
      weather_icon_path = "Graphics/12_Weather System/Weather Box/#{current_weather}"
      
      begin
        weather_icon = Bitmap.new(weather_icon_path)
        # Draw icon on top right of the box
        box_width = @sprites["weather_box"].bitmap.width
        icon_x = box_width - weather_icon.width - 6  
        icon_y = 6  
        @sprites["weather_box"].bitmap.blt(icon_x, icon_y, weather_icon, Rect.new(0, 0, weather_icon.width, weather_icon.height))
      rescue
      end
      
      # Draw season info if seasons are enabled
      if WeatherSystem.respond_to?(:seasons_enabled?) && WeatherSystem.seasons_enabled?
        create_season_text_sprite
      end
    rescue => e
    end
  end

  def pbShowCommands(commands, start_index = 0, is_submenu = false)
    # Hide party sprites when showing submenus
    hide_party_sprites if is_submenu
    
    ret = -1
    cmdwindow = @sprites["cmdwindow"]
    cmdwindow.commands = commands
    cmdwindow.index = start_index
    # Limit visible items to 8 for scrolling
    max_visible_items = 8
    if commands.length > max_visible_items
      cmdwindow.resizeToFit(commands[0, max_visible_items])
    else
      cmdwindow.resizeToFit(commands)
    end
    cmdwindow.x = Graphics.width - cmdwindow.width
    cmdwindow.y = 0
    cmdwindow.visible = true
    configured_button = OverworldMenuSettings.get_current_button
    frame_count = 0
    loop do
      cmdwindow.update
      Graphics.update
      Input.update
      
      frame_count += 1
      if frame_count >= 60
        update_weather_box
        frame_count = 0
      end
      
      if Input.trigger?(Input::AUX2)  # R button for page switch
        ret = :page_switch
        break
      elsif Input.trigger?(Input::BACK) || OverworldMenuSettings.check_trigger(configured_button)
        ret = -1
        Input.update  
        break
      elsif Input.trigger?(Input::USE)
        ret = cmdwindow.index
        break
      end
    end
    cmdwindow.visible = false
    
    # Show party sprites again when exiting submenus
    show_party_sprites if is_submenu
    
    return ret
  end
  
  def create_season_text_sprite
    return unless @sprites["weather_box"]
    
    # Get current season
    season = WeatherSystem.current_season
    
    # Get season abbreviation
    season_abbr = case season
    when :Spring then "SPR"
    when :Summer then "SUM"
    when :Fall, :Autumn then "AUT"
    when :Winter then "WIN"
    else "???"
    end
    
    # Get time until next season from Weather System
    time_remaining = WeatherSystem.time_until_next_season
    if time_remaining
      days_remaining = time_remaining[:days]
      hours_remaining = time_remaining[:hours]
      season_text = "#{season_abbr} (#{days_remaining}d #{hours_remaining}h)"
    else
      # Manual season mode - no time display
      season_text = "#{season_abbr}"
    end
    
    # Create text sprite
    @sprites["season_text"] = Sprite.new(@viewport)
    @sprites["season_text"].bitmap = Bitmap.new(100, 25)
    @sprites["season_text"].bitmap.font.size = 17
    @sprites["season_text"].bitmap.font.bold = true
    @sprites["season_text"].z = 100000
    
    # Position relative to weather box
    @sprites["season_text"].x = @sprites["weather_box"].x + @sprites["weather_box"].bitmap.width - 105
    @sprites["season_text"].y = @sprites["weather_box"].y + @sprites["weather_box"].bitmap.height - 32
    
    # Draw text
    pbDrawShadowText(@sprites["season_text"].bitmap, 0, 0, 100, 25, season_text,
                    Color.new(255, 255, 255), Color.new(0, 0, 0), 2)
  rescue
    # Silently fail
  end
  
  def update_weather_box
    return unless @sprites["season_text"]
    return unless OverworldMenuSettings.get(:overworld_menu_weather_box)
    return unless defined?(WeatherSystem)
    return unless WeatherSystem.respond_to?(:seasons_enabled?) && WeatherSystem.seasons_enabled?
    
    begin
      # Get current season
      season = WeatherSystem.current_season
      
      # Get season abbreviation
      season_abbr = case season
      when :Spring then "SPR"
      when :Summer then "SUM"
      when :Fall, :Autumn then "AUT"
      when :Winter then "WIN"
      else "???"
      end
      
      # Get time until next season from Weather System
      time_remaining = WeatherSystem.time_until_next_season
      if time_remaining
        days_remaining = time_remaining[:days]
        hours_remaining = time_remaining[:hours]
        season_text = "#{season_abbr} (#{days_remaining}d #{hours_remaining}h)"
      else
        # Manual season mode - no time display
        season_text = "#{season_abbr}"
      end
      
      # Clear and redraw text
      @sprites["season_text"].bitmap.clear
      pbDrawShadowText(@sprites["season_text"].bitmap, 0, 0, 100, 25, season_text,
                      Color.new(255, 255, 255), Color.new(0, 0, 0), 2)
    rescue
      # Silently fail if update fails
    end
  end

  def pbEndScene
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  def hide_party_sprites
    return unless @sprites
    @sprites.keys.select { |k| k.start_with?("party_") || k == "weather_box" || k == "season_text" }.each do |key|
      @sprites[key].visible = false if @sprites[key]
    end
  end
  
  def show_party_sprites
    return unless @sprites
    @sprites.keys.select { |k| k.start_with?("party_") || k == "weather_box" || k == "season_text" }.each do |key|
      @sprites[key].visible = true if @sprites[key]
    end
  end
end

#===============================================================================
# Menu Handler for Overworld Menu
#===============================================================================
class OverworldMenuHandler
  def initialize(scene)
    @scene = scene
  end

  def pbStartMenu
    begin
      KIFRSettings.debug_log("OverworldMenu: Opening Overworld Menu") if defined?(KIFRSettings)
      # Load settings from file to ensure latest values
      begin
        if defined?(KIFRSettings) && KIFRSettings.respond_to?(:load_from_file)
          KIFRSettings.load_from_file
        end
      rescue
      end
      
      @scene.pbStartScene
    $game_temp.in_menu = true
    
    # Clear input buffer to prevent immediate close from same button press that opened menu
    Input.update  
    
    # Lower Weather Box z-index so menu appears on top
    @original_weather_box_z = nil
    if defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:weather_system_transition_sprite)
      data = $PokemonGlobal.weather_system_transition_sprite
      if data && data[:sprite]
        @original_weather_box_z = data[:sprite].z
        data[:sprite].z = 1000  # Put it behind the menu
      end
    end

    current_page = 1
    max_pages = OverworldMenuSettings.get(:overworld_menu_pages) || 2
    max_pages = max_pages.clamp(1, 5)
    last_indices = {}
    (1..5).each { |p| last_indices[p] = 0 }
    
    loop do
      # Build menu items based on current page
      items = build_menu_items(current_page, max_pages)
      commands = items[:commands]
      handlers = items[:handlers]
      
      last_index = last_indices[current_page] || 0
      last_index = 0 if last_index >= commands.length
      
      command = @scene.pbShowCommands(commands, last_index)
      
      # Check for page switch (R button)
      if command == :page_switch
        # Cycle through pages based on max_pages setting
        current_page = (current_page % max_pages) + 1
        next
      end
      
      if command == -1
        pbPlayCancelSE
        break
      end
      
      if command >= 0 && command < handlers.length
        # Save last index for current page
        last_indices[current_page] = command
        
        pbPlayDecisionSE
        
        # Hide party view and weather box before executing handler
        @scene.hide_party_sprites if @scene.respond_to?(:hide_party_sprites)
        
        # Execute handler
        result = handlers[command].call
        
        # Show party view and weather box again after handler completes
        @scene.show_party_sprites if @scene.respond_to?(:show_party_sprites)
        
        # Exit menu if handler returned :exit_menu
        break if result == :exit_menu
      end
    end
    
    # Save settings to file
    begin
      if defined?(KIFRSettings) && KIFRSettings.respond_to?(:save_to_file)
        KIFRSettings.save_to_file
      end
    rescue
    end
    
    # Restore Weather Box z-index
    if @original_weather_box_z && defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:weather_system_transition_sprite)
      data = $PokemonGlobal.weather_system_transition_sprite
      if data && data[:sprite]
        data[:sprite].z = @original_weather_box_z
      end
    end
    
    @scene.pbEndScene
    $game_temp.in_menu = false  
    # Clear input to prevent accidental interactions (like surfing) immediately after closing menu
    Input.update
    KIFRSettings.debug_log("OverworldMenu: Overworld Menu closed") if defined?(KIFRSettings)
    rescue => e
      KIFRSettings.debug_log("OverworldMenu: Error in Overworld Menu: #{e.class} - #{e.message}") if defined?(KIFRSettings)
      KIFRSettings.debug_log("OverworldMenu: Backtrace: #{e.backtrace.first(5).join('\n')}") if defined?(KIFRSettings)
      @scene.hide_party_sprites if @scene.respond_to?(:hide_party_sprites)
      pbMessage("An error occurred in Overworld Menu.")
      @scene.show_party_sprites if @scene.respond_to?(:show_party_sprites)
    ensure
      $game_temp.in_menu = false if defined?($game_temp)
    end
  end
  
  def build_menu_items(page, max_pages = 2)
    commands = []
    handlers = []
    
    # Get all available submenus from registry
    available_submenus = OverworldMenu.available_submenus
    
    # Filter by page assignment
    available_submenus.each do |entry|
      # Skip the options entry - it will be added at the end
      next if entry[:key] == :options
      
      page_key = "overworld_menu_page_#{entry[:key]}".to_sym
      assigned_page = OverworldMenuSettings.get(page_key) || 1
      assigned_page = assigned_page.clamp(1, max_pages)
      
      # Include if it belongs to the current page
      if assigned_page == page
        commands << entry[:label]
        
        # Wrap handler to provide screen context and handle exit
        handlers << proc do
          begin
            KIFRSettings.debug_log("OverworldMenu: Executing handler for submenu: #{entry[:key]}") if defined?(KIFRSettings)
            result = entry[:handler].call(self)
            KIFRSettings.debug_log("OverworldMenu: Handler for #{entry[:key]} completed with result: #{result.inspect}") if defined?(KIFRSettings)
            entry[:exit_on_select] ? :exit_menu : result
          rescue => e
            echoln "[OverworldMenu] Error executing handler for #{entry[:key]}: #{e.message}"
            KIFRSettings.debug_log("OverworldMenu: Error executing handler for #{entry[:key]}: #{e.class} - #{e.message}") if defined?(KIFRSettings)
            KIFRSettings.debug_log("OverworldMenu: Backtrace: #{e.backtrace.first(5).join('\n')}") if defined?(KIFRSettings)
            # Hide party/weather before showing error dialog
            @scene.hide_party_sprites if @scene.respond_to?(:hide_party_sprites)
            pbMessage("An error occurred. Please check the logs.")
            # Show party/weather after dialog
            @scene.show_party_sprites if @scene.respond_to?(:show_party_sprites)
            nil
          end
        end
      end
    end
    
    # Empty pages just show Options and page number (no message needed)
    
    # Always add Options as the last item before page number
    options_entry = available_submenus.find { |e| e[:key] == :options }
    if options_entry
      commands << options_entry[:label]
      handlers << proc do
        begin
          KIFRSettings.debug_log("OverworldMenu: Executing handler for submenu: options") if defined?(KIFRSettings)
          result = options_entry[:handler].call(self)
          KIFRSettings.debug_log("OverworldMenu: Handler for options completed with result: #{result.inspect}") if defined?(KIFRSettings)
          options_entry[:exit_on_select] ? :exit_menu : result
        rescue => e
          echoln "[OverworldMenu] Error executing handler for options: #{e.message}"
          KIFRSettings.debug_log("OverworldMenu: Error executing handler for options: #{e.class} - #{e.message}") if defined?(KIFRSettings)
          @scene.hide_party_sprites if @scene.respond_to?(:hide_party_sprites)
          pbMessage("An error occurred. Please check the logs.")
          @scene.show_party_sprites if @scene.respond_to?(:show_party_sprites)
          nil
        end
      end
    end
    
    # Add page number indicator at the bottom (non-interactive)
    if max_pages > 1
      commands << "- Page #{page} -"
      handlers << proc { nil } # Non-interactive, does nothing
    end
    
    return { commands: commands, handlers: handlers }
  end



  def show_change_time_menu(parent_index = 0)
    commands = ["Morning", "Afternoon", "Evening", "Night"]
    last_index = 0
    
    loop do
      command = @scene.pbShowCommands(commands, last_index)
      
      if command == :page_switch
        next
      elsif command == -1  
        return false
      elsif command >= 0 && command < 4
        last_index = command
        pbPlayDecisionSE
        target_hour = case command
          when 0 then 5    # Morning
          when 1 then 14   # Afternoon
          when 2 then 17   # Evening
          when 3 then 20   # Night
        end
        advance_overworld_time(target_hour)
        return true
      end
    end
  end
  
  def advance_overworld_time(target_hour)
    if defined?(UnrealTime)
      current_time = pbGetTimeNow
      current_hour = current_time.hour
      current_min = current_time.min
      current_sec = current_time.sec
      
      current_seconds = current_hour * 3600 + current_min * 60 + current_sec
      target_seconds = target_hour * 3600
      
      seconds_to_add = target_seconds - current_seconds
      
      if seconds_to_add <= 0
        seconds_to_add += 24 * 3600  # Add one full day
      end
      
      UnrealTime.add_seconds(seconds_to_add)
    end
  end
end

#===============================================================================
# Press configured button/combo to open the Overworld Menu
#===============================================================================
Events.onMapUpdate += proc { |_sender, _e|
  next if !$Trainer
  next if $game_temp.in_menu || $game_temp.in_battle || $game_temp.message_window_showing
  next if $game_player.moving?
  
  enabled = OverworldMenuSettings.get(:overworld_menu_enabled)
  next unless enabled
  
  button_or_combo = OverworldMenuSettings.get_current_button
  
  if OverworldMenuSettings.check_trigger(button_or_combo)
    scene = OverworldMenuScene.new
    screen = OverworldMenuHandler.new(scene)
    screen.pbStartMenu
  end
}

#===============================================================================
# Built-in Submenu Registrations
#===============================================================================

# Time (built-in)
OverworldMenu.register(:time, {
  label: "Time",
  handler: proc { |screen|
    result = screen.show_change_time_menu(0)
    result ? :exit_menu : nil
  },
  priority: 20,
  condition: proc { true },
  exit_on_select: false
})

# Options (built-in) - Opens the game's Options menu
OverworldMenu.register(:options, {
  label: "Options",
  handler: proc { |screen|
    begin
      KIFRSettings.debug_log("OverworldMenu: Opening Options from Overworld Menu") if defined?(KIFRSettings)
      # Close the Overworld Menu scene first
      scene = screen.instance_variable_get(:@scene)
      scene.pbEndScene if scene
      $game_temp.in_menu = false
      
      # Now open Options menu
      pbFadeOutIn {
        opt_scene = PokemonOption_Scene.new
        screen_obj = PokemonOptionScreen.new(opt_scene)
        screen_obj.pbStartScreen
      }
      KIFRSettings.debug_log("OverworldMenu: Options opened successfully") if defined?(KIFRSettings)
      # Return exit to prevent menu loop from continuing
      :exit_menu
    rescue => e
      KIFRSettings.debug_log("OverworldMenu: Error opening Options: #{e.class} - #{e.message}") if defined?(KIFRSettings)
      KIFRSettings.debug_log("OverworldMenu: Backtrace: #{e.backtrace.first(3).join('\n')}") if defined?(KIFRSettings)
      screen.instance_variable_get(:@scene).hide_party_sprites if screen.instance_variable_get(:@scene).respond_to?(:hide_party_sprites)
      pbMessage("An error occurred opening Options.")
      screen.instance_variable_get(:@scene).show_party_sprites if screen.instance_variable_get(:@scene).respond_to?(:show_party_sprites)
      :exit_menu
    end
  },
  priority: 999, # High priority so it sorts to the end (but code handles placement)
  condition: proc { true },
  exit_on_select: true
})



#===============================================================================
# Mod Settings Scene
#===============================================================================
class OverworldMenuSettingsScene < PokemonOption_Scene
  # ModSettingsSpacing no longer needed - KIFR handles spacing automatically
  
  # Menu Transition Fix: Skip fade-in to avoid double-fade
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    # Enabled Toggle
    options << EnumOption.new(
      _INTL("Enabled"),
      [_INTL("Off"), _INTL("On")],
      proc { OverworldMenuSettings.get(:overworld_menu_enabled) ? 1 : 0 },
      proc { |value| OverworldMenuSettings.set(:overworld_menu_enabled, value == 1) },
      _INTL("Enable or disable the Overworld Menu system.")
    )
    
    # Open Button Configuration - Cycling option
    options << EnumOption.new(
      _INTL("Open Button"),
      OverworldMenuSettings::BUTTON_OPTIONS.map { |b| b[1] },
      proc { OverworldMenuSettings.get_button_index },
      proc { |value| OverworldMenuSettings.set_button_index(value) },
      _INTL("Select which button or button combination opens the Overworld Menu.")
    )
    
    # Pages Configuration - How many pages to use (1-5)
    options << EnumOption.new(
      _INTL("Pages"),
      ["1", "2", "3", "4", "5"],
      proc { (OverworldMenuSettings.get(:overworld_menu_pages) || 2) - 1 },
      proc { |value| OverworldMenuSettings.set(:overworld_menu_pages, value + 1) },
      _INTL("Set how many pages the Overworld Menu should have (1-5).")
    )
    
    # Party View Toggle
    options << EnumOption.new(
      _INTL("Party View"),
      [_INTL("Off"), _INTL("On")],
      proc { OverworldMenuSettings.get(:overworld_menu_party_view) ? 1 : 0 },
      proc { |value| OverworldMenuSettings.set(:overworld_menu_party_view, value == 1) },
      _INTL("Show party Pokémon sprites in the Overworld Menu.")
    )
    
    # Weather Box Toggle
    options << EnumOption.new(
      _INTL("Weather Box"),
      [_INTL("Off"), _INTL("On")],
      proc { OverworldMenuSettings.get(:overworld_menu_weather_box) ? 1 : 0 },
      proc { |value| OverworldMenuSettings.set(:overworld_menu_weather_box, value == 1) },
      _INTL("Display weather information box in the Overworld Menu.")
    )
    
    # Page Assignment Options for Registered Submenus (excluding Options which is always last)
    OverworldMenu.registry.each do |entry|
      next if entry[:key] == :options # Options is always shown, not configurable
      
      page_key = "overworld_menu_page_#{entry[:key]}".to_sym
      max_pages = OverworldMenuSettings.get(:overworld_menu_pages) || 2
      page_choices = (1..5).map { |n| _INTL("Page #{n}") }
      
      options << EnumOption.new(
        _INTL("#{entry[:label]} Page"),
        page_choices,
        proc { 
          val = OverworldMenuSettings.get(page_key) || 1
          (val - 1).clamp(0, 4)
        },
        proc { |value| OverworldMenuSettings.set(page_key, value + 1) },
        _INTL("Assign #{entry[:label]} to a page in the Overworld Menu (1-5).")
      )
    end
    
    return options
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create title (invisible initially)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Overworld Menu Settings"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    
    # Create double row description box (96px)
    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 96, Graphics.width, 96, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].visible = false
    
    # Build options and window
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = false
    
    # Apply color theme
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    # Initialize option values
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0)
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
    optionsWindow.setSkin(PokemonOption_Scene.get_kifr_windowskin)
    optionsWindow.nameBaseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    optionsWindow.nameShadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    optionsWindow.selBaseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    optionsWindow.selShadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    optionsWindow.viewport = @viewport
    optionsWindow.visible = true
    return optionsWindow
  end
end

#===============================================================================
# KIFR Settings Registration
#===============================================================================
# Register Overworld Menu settings in KIFR Settings Interface category
if defined?(KIFRSettings)
  KIFRSettings.register(:overworld_menu_settings, {
    name: "Overworld Menu",
    type: :button,
    description: "Configure Overworld Menu display options and page assignments",
    on_press: proc {
      pbFadeOutIn {
        scene = OverworldMenuSettingsScene.new
        screen = PokemonOptionScreen.new(scene)
        screen.pbStartScreen
      }
    },
    category: "Interface",
    searchable: [
      "overworld", "menu", "party view", "weather box", "dexnav",
      "page assignment", "ovm", "custom menu", "submenu"
    ]
  })
  
  KIFRSettings.debug_log("OverworldMenu: KIFR Overworld Menu v1.0.0 loaded")
end
