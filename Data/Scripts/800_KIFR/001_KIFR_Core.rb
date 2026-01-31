#===============================================================================
# KIF Redux Core - Foundation Module
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This is the foundation module for KIF Redux. It provides:
# - Predefined categories for mod settings organization
# - Color themes for UI customization
# - Storage system for persistent settings
# - Debug logging to KIFR/KIFRDebug.txt in save folder
# - File persistence with atomic saves (KIFR/KIFR_Settings.kro)
# - Preset management (KIFR/Presets/)
#===============================================================================

# Predefined categories for organizing mod settings
# Mods should use these categories when registering their settings
# Categories are sorted by priority (lower = appears first)
KIFR_CATEGORIES = [
  {name: "Interface",          priority: 10,  description: "UI, menus, text speed, visual interface"},
  {name: "Major Systems",      priority: 20,  description: "Major features like seasons, weather, followers"},
  {name: "Quality of Life",    priority: 30,  description: "Convenience features, item management, shortcuts"},
  {name: "Battle Mechanics",   priority: 40,  description: "Battle mechanics, move changes, ability tweaks"},
  {name: "Economy",            priority: 50,  description: "Money, shops, pickup, loot, prizes"},
  {name: "Difficulty",         priority: 60,  description: "Nuzlocke, boss system, trainer control, challenge modes"},
  {name: "Encounters",         priority: 70,  description: "Wild encounters, hordes, randomizers, spawn rates"},
  {name: "Training & Stats",   priority: 80,  description: "EVs, IVs, experience, stat modifications"},
  {name: "Multiplayer",        priority: 85,  description: "Multiplayer features, co-op, online functionality"},
  {name: "Uncategorized",      priority: 900, description: "Settings without assigned categories"},
  {name: "Debug & Developer",  priority: 999, description: "Testing tools, debug options"},
  {name: "-----------------",  priority: 1000, description: "Separator"},
].freeze

#===============================================================================
# COLOR THEMES - UI Color Customization
#===============================================================================
# Available color themes for menu text and category headers
# Used by KIFR Settings and applied to Options menus
COLOR_THEMES = {
  purple: {
    name: "Purple",
    base: Color.new(168, 128, 228),
    shadow: Color.new(64, 44, 84)
  },
  blue: {
    name: "Blue",
    base: Color.new(88, 176, 248),
    shadow: Color.new(32, 64, 96)
  },
  green: {
    name: "Green",
    base: Color.new(120, 200, 120),
    shadow: Color.new(44, 76, 44)
  },
  red: {
    name: "Red",
    base: Color.new(240, 120, 120),
    shadow: Color.new(92, 44, 44)
  },
  orange: {
    name: "Orange",
    base: Color.new(248, 168, 88),
    shadow: Color.new(96, 64, 32)
  },
  cyan: {
    name: "Cyan",
    base: Color.new(88, 224, 224),
    shadow: Color.new(32, 84, 84)
  },
  pink: {
    name: "Pink",
    base: Color.new(248, 136, 192),
    shadow: Color.new(96, 52, 72)
  },
  yellow: {
    name: "Yellow",
    base: Color.new(240, 224, 88),
    shadow: Color.new(92, 84, 32)
  },
  white: {
    name: "White",
    base: Color.new(248, 248, 248),
    shadow: Color.new(72, 80, 88)
  },
  black: {
    name: "Black",
    base: Color.new(80, 80, 88),
    shadow: Color.new(160, 160, 168)
  }
}.freeze

#===============================================================================
# PokemonSystem Extension - Add KIFR theme attributes
#===============================================================================
if defined?(PokemonSystem)
  class PokemonSystem
    attr_accessor :kifr_color_theme
    attr_accessor :kifr_category_theme
    attr_accessor :kifr_global_frame  # Index into KIFR_WINDOWSKINS for global window frame
    attr_accessor :kifr_separate_speech  # 0 = Off (use global), 1 = On (use separate speech frame)
    attr_accessor :kifr_speech_frame  # Index into Settings::SPEECH_WINDOWSKINS for separate speech
    attr_accessor :kifr_shop_cursor_color  # Index into SHOP_CURSOR_COLORS for shop cursor theme
  end
end

#===============================================================================
# Shop Cursor Color Themes - Used by Regular Shop selection cursor
#===============================================================================
SHOP_CURSOR_COLORS = [
  { name: "Blue",    fill: Color.new(100, 180, 220, 180), border: Color.new(60, 140, 200, 220) },   # 0 - Default light blue
  { name: "Green",   fill: Color.new(100, 200, 120, 180), border: Color.new(60, 160, 80, 220) },    # 1 - Green
  { name: "Red",     fill: Color.new(220, 100, 100, 180), border: Color.new(180, 60, 60, 220) },    # 2 - Red
  { name: "Purple",  fill: Color.new(180, 120, 220, 180), border: Color.new(140, 80, 180, 220) },   # 3 - Purple
  { name: "Orange",  fill: Color.new(240, 160, 80, 180),  border: Color.new(200, 120, 40, 220) },   # 4 - Orange
  { name: "Pink",    fill: Color.new(240, 140, 180, 180), border: Color.new(200, 100, 140, 220) },  # 5 - Pink
  { name: "Cyan",    fill: Color.new(80, 200, 220, 180),  border: Color.new(40, 160, 180, 220) },   # 6 - Cyan
  { name: "Yellow",  fill: Color.new(240, 220, 100, 180), border: Color.new(200, 180, 60, 220) },   # 7 - Yellow
  { name: "Gold",    fill: Color.new(220, 190, 100, 180), border: Color.new(180, 150, 60, 220) },   # 8 - Gold
  { name: "Gray",    fill: Color.new(160, 160, 160, 180), border: Color.new(120, 120, 120, 220) }   # 9 - Gray
].freeze

#===============================================================================
# KIFR Windowskins - Curated list of available window frames
#===============================================================================
# Used by the Global Frame cycling option in Interface
# Only includes KIFR Choice # and KIFR Choice #a variants
KIFR_WINDOWSKINS = [
  "KIFR Choice 1",     # 0 - KIFR default
  "KIFR Choice 1a",    # 1 - KIFR Options variant
  "KIFR Choice 2",     # 2
  "KIFR Choice 2a",    # 3
  "KIFR Choice 3",     # 4
  "KIFR Choice 3a",    # 5
  "KIFR Choice 4",     # 6
  "KIFR Choice 4a",    # 7
  "KIFR Choice 5",     # 8
  "KIFR Choice 5a",    # 9
  "KIFR Choice 6",     # 10
  "KIFR Choice 6a",    # 11
  "KIFR Choice 7",     # 12
  "KIFR Choice 7a",    # 13
  "KIFR Choice 8",     # 14
  "KIFR Choice 8a",    # 15
  "KIFR Choice 9",     # 16
  "KIFR Choice 9a",    # 17
  "KIFR Choice 10",    # 18
  "KIFR Choice 10a",   # 19
  "KIFR Choice 11",    # 20
  "KIFR Choice 11a",   # 21
  "KIFR Choice 12",    # 22
  "KIFR Choice 12a",   # 23
  "KIFR Choice 13",    # 24
  "KIFR Choice 13a",   # 25
  "KIFR Choice 14",    # 26
  "KIFR Choice 14a",   # 27
  "KIFR Choice 15",    # 28
  "KIFR Choice 15a",   # 29
  "KIFR Choice 16",    # 30
  "KIFR Choice 16a",   # 31
  "KIFR Choice 17",    # 32
  "KIFR Choice 17a",   # 33
  "KIFR Choice 18",    # 34
  "KIFR Choice 18a",   # 35
  "KIFR Choice 19",    # 36
  "KIFR Choice 19a",   # 37
  "KIFR Choice 20",    # 38
  "KIFR Choice 20a",   # 39
  "KIFR Choice 21",    # 40
  "KIFR Choice 21a",   # 41
  "KIFR Choice 22",    # 42
  "KIFR Choice 22a",   # 43
  "KIFR Choice 23",    # 44
  "KIFR Choice 23a",   # 45
  "KIFR Choice 24",    # 46
  "KIFR Choice 24a",   # 47
  "KIFR Choice 25",    # 48
  "KIFR Choice 25a",   # 49
  "KIFR Choice 26",    # 50
  "KIFR Choice 26a",   # 51
  "KIFR Choice 27",    # 52
  "KIFR Choice 27a",   # 53
  "KIFR Choice 28",    # 54
  "KIFR Choice 28a",   # 55
  "KIFR Choice 29",    # 56
  "KIFR Choice 29a",   # 57
  "KIFR Choice 30",    # 58
  "KIFR Choice 30a"    # 59
].freeze

#===============================================================================
# Helper method to check if current global frame has dark background
#===============================================================================
# Returns true if the global frame ends with "a" (dark variant)
# Returns false for regular frames (light background)
def pbGlobalFrameIsDark?
  return true unless defined?(KIFR_WINDOWSKINS)  # Default to dark (1a)
  index = ($PokemonSystem.kifr_global_frame rescue 1) || 1
  return false if index < 0 || index >= KIFR_WINDOWSKINS.length
  skin_name = KIFR_WINDOWSKINS[index]
  return skin_name.end_with?("a")
end

# Get appropriate text colors based on global frame
# Returns [baseColor, shadowColor]
def pbGetGlobalFrameTextColors
  if pbGlobalFrameIsDark?
    return [MessageConfig::LIGHT_TEXT_MAIN_COLOR, MessageConfig::LIGHT_TEXT_SHADOW_COLOR]
  else
    return [Color.new(88, 88, 80), Color.new(168, 184, 184)]
  end
end

#===============================================================================
# KIFRSettings Module - Core Functionality
#===============================================================================
module KIFRSettings
  # Special category constant - options with this category appear without headers
  NOCATEGORY = "__nocategory__"
  
  # KIFR version is registered via ModRegistry at the end of this file
  # Use KIFRSettings.version to get the current version
  
  class << self
    # Get the current KIFR version
    # Uses the VERSION constant from 000_KIFR_Version.rb
    def version
      return VERSION if defined?(VERSION)
      "1.0.0"  # Fallback
    end
  end
  
  #=============================================================================
  # Storage System
  #=============================================================================
  @storage = {}
  @collapsed_categories = {}
  @option_registry = []  # Registered mod options (for Mod Settings menu)
  @on_change_registry = {}  # On-change callbacks
  
  class << self
    # Get the storage hash
    def storage
      @storage ||= {}
    end
    
    # Set the entire storage hash (used when loading from file)
    def set_storage(hash)
      @storage = hash.is_a?(Hash) ? hash : {}
    end
    
    #===========================================================================
    # Option Registry System (for Mod Settings menu)
    #===========================================================================
    
    # Get all registered options
    def registry
      @option_registry ||= []
    end
    
    # Register an option to appear in Mod Settings
    # @param key [Symbol] Unique key for the option
    # @param options [Hash] Option configuration:
    #   - name: Display name
    #   - type: :button, :toggle, :enum, :slider, :number
    #   - description: Help text
    #   - on_press: Proc for button type
    #   - values: Array for enum type
    #   - min, max, interval: For slider/number types
    #   - default: Default value
    #   - category: Category name for grouping
    #   - searchable: Array of search keywords
    def register(key, options = {})
      key = key.to_sym if key.is_a?(String)
      
      # Remove existing registration if present
      @option_registry ||= []
      @option_registry.reject! { |r| r[:key] == key }
      
      # Add new registration
      registration = options.merge(key: key)
      registration[:category] ||= "Uncategorized"
      registration[:type] ||= :button
      
      # Set default value in storage if provided
      if options.key?(:default) && !storage.key?(key)
        storage[key] = options[:default]
      end
      
      @option_registry << registration
      debug_log("Registered option: #{key} (#{options[:name] || key})")
    end
    
    # Convenience method to register a toggle option
    def register_toggle(key, name, description = "", default = 0, category = "Uncategorized")
      register(key, {
        name: name,
        type: :toggle,
        description: description,
        default: default,
        category: category,
        values: [_INTL("Off"), _INTL("On")]
      })
    end
    
    # Convenience method to register an enum option
    def register_enum(key, name, values, default = 0, description = "", category = "Uncategorized")
      register(key, {
        name: name,
        type: :enum,
        values: values,
        default: default,
        description: description,
        category: category
      })
    end
    
    # Convenience method to register a number option
    def register_number(key, name, min, max, default = nil, description = "", category = "Uncategorized")
      register(key, {
        name: name,
        type: :number,
        min: min,
        max: max,
        default: default || min,
        description: description,
        category: category
      })
    end
    
    # Convenience method to register a slider option
    def register_slider(key, name, min, max, interval = 1, default = nil, description = "", category = "Uncategorized")
      register(key, {
        name: name,
        type: :slider,
        min: min,
        max: max,
        interval: interval,
        default: default || min,
        description: description,
        category: category
      })
    end
    
    # Register a custom option object
    def register_option(option, key, category = "Uncategorized", searchable_items = [])
      register(key, {
        name: option.respond_to?(:name) ? option.name : key.to_s,
        type: :custom,
        option_object: option,
        category: category,
        searchable: searchable_items
      })
    end
    
    # Get registrations grouped by category
    def registry_by_category
      result = {}
      registry.each do |reg|
        cat = reg[:category] || "Uncategorized"
        result[cat] ||= []
        result[cat] << reg
      end
      result
    end
    
    # Check if an option is registered
    def registered?(key)
      key = key.to_sym if key.is_a?(String)
      registry.any? { |r| r[:key] == key }
    end
    
    #===========================================================================
    # On-Change Callbacks
    #===========================================================================
    
    def on_change_registry
      @on_change_registry ||= {}
    end
    
    def register_on_change(key, &block)
      key = key.to_sym if key.is_a?(String)
      @on_change_registry ||= {}
      @on_change_registry[key] ||= []
      @on_change_registry[key] << block
    end
    
    def invoke_on_change(key, new_value, old_value)
      key = key.to_sym if key.is_a?(String)
      return unless @on_change_registry && @on_change_registry[key]
      @on_change_registry[key].each { |cb| cb.call(new_value, old_value) rescue nil }
    end
    
    # Get a setting value by key
    # @param key [Symbol, String] The setting key
    # @param default [Object] Default value if key doesn't exist
    # @return [Object] The setting value or default
    def get(key, default = nil)
      key = key.to_sym if key.is_a?(String)
      storage.key?(key) ? storage[key] : default
    end
    
    # Set a setting value by key
    # @param key [Symbol, String] The setting key
    # @param value [Object] The value to store
    def set(key, value)
      key = key.to_sym if key.is_a?(String)
      old_value = storage[key]
      storage[key] = value
      
      # Invoke on_change callback if value changed
      if old_value != value && @on_change_registry && @on_change_registry[key]
        begin
          @on_change_registry[key].each { |callback| callback.call(value, old_value) }
        rescue => e
          debug_log("Error in on_change callback for #{key}: #{e.message}")
        end
      end
    end
    
    # Check if a key exists in storage
    # @param key [Symbol, String] The setting key
    # @return [Boolean] Whether the key exists
    def has_key?(key)
      key = key.to_sym if key.is_a?(String)
      storage.key?(key)
    end
    
    # Set a default value for a key ONLY if the key doesn't already exist
    # This is the recommended way to initialize defaults
    # @param key [Symbol, String] The setting key
    # @param default [Object] Default value to set if key doesn't exist
    # @return [Boolean] True if default was set, false if key already existed
    def set_default(key, default)
      key = key.to_sym if key.is_a?(String)
      if storage.key?(key)
        return false
      else
        storage[key] = default
        return true
      end
    end
    
    # Ensure a key exists with a default value
    # Only sets the value if the key doesn't already exist
    # @param key [Symbol, String] The setting key
    # @param default [Object] Default value to set if key doesn't exist
    def ensure_storage(key, default)
      key = key.to_sym if key.is_a?(String)
      storage[key] = default unless storage.key?(key)
    end
    
    #===========================================================================
    # Category Management
    #===========================================================================
    
    # Get all categories (from KIFR_CATEGORIES constant)
    # Returns a mutable copy with collapse states
    def categories
      @category_states ||= KIFR_CATEGORIES.map { |c| c.dup }
    end
    
    # Check if a category name is valid (exists in predefined list)
    # @param name [String] Category name to check
    # @return [Boolean] Whether category exists
    def valid_category?(name)
      return false if name.nil? || name.empty?
      KIFR_CATEGORIES.any? { |c| c[:name] == name }
    end
    
    # Check if a category is collapsed
    # @param name [String] Category name
    # @return [Boolean] Whether category is collapsed (default: true)
    def category_collapsed?(name)
      return true unless @collapsed_categories.key?(name)
      @collapsed_categories[name]
    end
    
    # Toggle a category's collapsed state
    # @param name [String] Category name
    def toggle_category(name)
      current_state = @collapsed_categories.key?(name) ? @collapsed_categories[name] : true
      @collapsed_categories[name] = !current_state
    end
    
    # Initialize a category's collapsed state (only if not already set)
    # @param name [String] Category name
    # @param collapsed [Boolean] Initial collapsed state
    def initialize_category(name, collapsed = true)
      @collapsed_categories[name] = collapsed unless @collapsed_categories.key?(name)
    end
    
    # Save category collapse states to storage (for persistence)
    def save_category_states
      storage[:_category_states] = @collapsed_categories.dup
    end
    
    # Restore category collapse states from storage
    def restore_category_states
      if storage[:_category_states].is_a?(Hash)
        @collapsed_categories = storage[:_category_states].dup
      end
    end
    
    # Reset all categories to collapsed state
    # Called when opening settings scene to ensure clean state
    def reset_all_categories
      @collapsed_categories = {}
    end
    
    #===========================================================================
    # Text Sanitization for Display
    #===========================================================================
    
    # Sanitize text for display by replacing unsupported characters
    # The game's bitmap font doesn't support many Unicode characters
    # @param text [String] Text to sanitize
    # @return [String] Sanitized text safe for display
    def sanitize_text(text)
      return "" if text.nil?
      text = text.to_s
      
      # Replace unsupported Unicode characters
      text = text.gsub("•", "-")       # Bullet point
      text = text.gsub("✓", "[x]")     # Check mark
      text = text.gsub("✔", "[x]")     # Heavy check mark
      
      text
    end
    
    #===========================================================================
    # Debug Logging
    #===========================================================================
    
    # Get the KIFR folder path (creates if needed)
    # All KIFR data files are stored here: debug log, settings, presets, exports
    # Located in base game directory, not save folder
    def kifr_folder
      # Use base game directory instead of save folder
      base_dir = Dir.pwd rescue "."
      folder = File.join(base_dir, "KIFR")
      Dir.mkdir(folder) unless Dir.exist?(folder)
      folder
    end
    
    # Maximum log file size in lines (keeps log from growing forever)
    LOG_MAX_LINES = 2000
    
    # Track if session header has been written
    @session_logged = false
    
    # Write debug message to KIFR/KIFRDebug.txt in save folder
    # Format: [MM-DD-YY HH:MM:SS] [LEVEL] Prefix: Message
    # @param message [String] Message to log
    # @param include_trace [Boolean] Include caller info for errors
    def debug_log(message, include_trace = false)
      begin
        folder = kifr_folder
        return unless folder
        
        log_file = File.join(folder, "KIFRDebug.txt")
        
        # Write session header on first log of this session
        unless @session_logged
          write_session_header(log_file)
          @session_logged = true
        end
        
        # Determine log level from message content
        is_error = message.include?("ERROR:")
        is_warning = message.include?("WARNING:")
        level = is_error ? "ERROR" : (is_warning ? "WARNING" : "INFO")
        
        # Clean up the message - remove redundant level indicators
        clean_message = message.gsub(/\s*ERROR:\s*/, " ").gsub(/\s*WARNING:\s*/, " ").strip
        
        # Format timestamp as MM-DD-YY HH:MM:SS
        timestamp = Time.now.strftime('%m-%d-%y %H:%M:%S')
        
        # Build log entry
        log_entry = "[#{timestamp}] [#{level}] #{clean_message}"
        
        # Add compact stack trace for errors (10 lines max, filename only)
        if is_error || include_trace
          trace_lines = caller(2..11)&.map do |c|
            # Extract just filename and line number
            if c =~ /([^\/\\]+\.rb):(\d+)/
              "    #{$1}:#{$2}"
            else
              "    #{c.split('/').last}"
            end
          end
          log_entry += "\n#{trace_lines.join("\n")}" if trace_lines && !trace_lines.empty?
        end
        
        File.open(log_file, "a") do |f|
          f.puts(log_entry)
        end
        
        # Check if log rotation is needed (do this occasionally, not every write)
        rotate_log_if_needed(log_file) if rand(50) == 0
      rescue
        # Silently fail if we can't write to debug file
      end
    end
    
    # Write session header to log file
    def write_session_header(log_file)
      timestamp = Time.now.strftime('%m-%d-%y %H:%M:%S')
      
      File.open(log_file, "a") do |f|
        f.puts("")
        f.puts("=" * 60)
        f.puts("  SESSION START - #{timestamp}")
        f.puts("  KIFR Version: #{version}")
        f.puts("=" * 60)
        f.puts("")
      end
    end
    
    # Log startup summary with mod counts
    def log_startup_summary
      return unless defined?(ModRegistry)
      
      total_mods = ModRegistry.all.length
      external_mods = ModRegistry.external_mods.length
      internal_mods = total_mods - external_mods
      
      debug_log("KIFR Core: Startup complete")
      debug_log("KIFR Core: Registered mods - Total: #{total_mods}, External: #{external_mods}, Internal: #{internal_mods}")
    end
    
    # Rotate log file if it exceeds max lines
    def rotate_log_if_needed(log_file)
      return unless File.exist?(log_file)
      
      lines = File.readlines(log_file)
      return if lines.length <= LOG_MAX_LINES
      
      # Keep only the last LOG_MAX_LINES lines
      trimmed_lines = lines.last(LOG_MAX_LINES)
      
      # Add a note about truncation at the top
      truncated_note = "[LOG TRUNCATED - Kept last #{LOG_MAX_LINES} lines]\n\n"
      
      File.open(log_file, "w") do |f|
        f.write(truncated_note)
        f.write(trimmed_lines.join)
      end
    end
    
    # Clear the debug log file
    def clear_debug_log
      begin
        folder = kifr_folder
        if folder
          log_file = File.join(folder, "KIFRDebug.txt")
          File.delete(log_file) if File.exist?(log_file)
        end
        @session_logged = false  # Reset session flag
      rescue
      end
    end
    
    #===========================================================================
    # File Persistence (Atomic Saves)
    #===========================================================================
    
    # Get the path to the settings file
    def settings_file_path
      folder = kifr_folder
      return nil unless folder
      File.join(folder, "KIFR_Settings.kro")
    end
    
    # Save all settings to file (atomic write)
    # @return [Boolean] Success or failure
    def save_to_file
      begin
        file_path = settings_file_path
        return false unless file_path
        
        # Save category states to storage before writing
        save_category_states
        
        # Prepare data
        data = storage.dup
        
        # Write to temp file first (atomic save)
        temp_file = file_path + ".tmp"
        
        if defined?(kurayjson_save)
          kurayjson_save(temp_file, data)
        else
          File.open(temp_file, 'w') { |f| f.write(data.inspect) }
        end
        
        # Rename temp to actual (atomic on most filesystems)
        if File.exist?(temp_file)
          File.delete(file_path) if File.exist?(file_path)
          File.rename(temp_file, file_path)
        end
        
        debug_log("Settings saved successfully")
        return true
      rescue => e
        debug_log("Error saving settings: #{e.message}")
        # Clean up temp file if it exists
        begin
          File.delete(temp_file) if temp_file && File.exist?(temp_file)
        rescue
        end
        return false
      end
    end
    
    # Load settings from file
    # @return [Boolean] Success or failure
    def load_from_file
      begin
        file_path = settings_file_path
        
        # Check for KIFR settings file in new location first
        if file_path && File.exist?(file_path)
          if defined?(kurayjson_load)
            data = kurayjson_load(file_path)
          else
            content = File.read(file_path)
            data = eval(content) rescue nil
          end
          
          if data.is_a?(Hash)
            set_storage(data)
            restore_category_states
            debug_log("Settings loaded successfully from KIFR/KIFR_Settings.kro")
            return true
          else
            debug_log("Settings file exists but contains invalid data")
          end
        end
        
        # Try to migrate from old locations (root save folder)
        migrate_from_old_locations
        
        # Try to migrate from old Mod_Settings.kro if still no settings
        migrate_from_mod_settings unless file_path && File.exist?(file_path)
        
        return false
      rescue => e
        debug_log("Error loading settings: #{e.message}")
        return false
      end
    end
    
    # Recursively delete a folder and all its contents
    def delete_folder_recursive(folder_path)
      return unless folder_path && Dir.exist?(folder_path)
      
      # First, delete all contents
      Dir.foreach(folder_path) do |entry|
        next if entry == '.' || entry == '..'
        full_path = File.join(folder_path, entry)
        
        if File.directory?(full_path)
          # Recursively delete subdirectory
          delete_folder_recursive(full_path)
        else
          # Delete file
          File.delete(full_path) rescue nil
        end
      end
      
      # Then delete the empty folder
      Dir.rmdir(folder_path) rescue nil
    end
    
    # Migrate files from old locations (root save folder) to new KIFR folder
    # This handles KIFR_Settings.kro and KIFR_Presets from before the folder reorganization
    # Also migrates from old save folder KIFR/ to new base directory KIFR/
    def migrate_from_old_locations
      begin
        save_folder = RTP.getSaveFolder rescue nil
        return false unless save_folder
        
        migrated = false
        new_kifr = kifr_folder  # Base directory KIFR folder
        
        # =======================================================================
        # PRIORITY 1: Migrate from old save folder KIFR/ to new base directory KIFR/
        # =======================================================================
        old_kifr_folder = File.join(save_folder, "KIFR")
        if Dir.exist?(old_kifr_folder)
          debug_log("Found old KIFR folder in save directory, migrating to base directory...")
          
          # Migrate all files from old KIFR folder
          Dir.glob(File.join(old_kifr_folder, "*")).each do |item|
            basename = File.basename(item)
            new_path = File.join(new_kifr, basename)
            
            if File.file?(item)
              # Don't overwrite existing files in new location
              unless File.exist?(new_path)
                begin
                  FileUtils.cp(item, new_path) rescue File.open(new_path, 'wb') { |f| f.write(File.read(item)) }
                  debug_log("Migrated file: #{basename}")
                  migrated = true
                rescue => e
                  debug_log("Failed to migrate #{basename}: #{e.message}")
                end
              end
            elsif File.directory?(item)
              # Handle subdirectories like Presets/
              unless Dir.exist?(new_path)
                Dir.mkdir(new_path) rescue nil
              end
              Dir.glob(File.join(item, "*")).each do |subfile|
                next unless File.file?(subfile)
                sub_basename = File.basename(subfile)
                sub_new_path = File.join(new_path, sub_basename)
                unless File.exist?(sub_new_path)
                  begin
                    FileUtils.cp(subfile, sub_new_path) rescue File.open(sub_new_path, 'wb') { |f| f.write(File.read(subfile)) }
                    debug_log("Migrated: #{basename}/#{sub_basename}")
                    migrated = true
                  rescue => e
                    debug_log("Failed to migrate #{basename}/#{sub_basename}: #{e.message}")
                  end
                end
              end
            end
          end
          
          # Delete old KIFR folder and contents after migration
          begin
            delete_folder_recursive(old_kifr_folder)
            debug_log("Removed old KIFR folder from save directory")
          rescue => e
            debug_log("Could not fully remove old KIFR folder: #{e.message}")
          end
        end
        
        # =======================================================================
        # PRIORITY 2: Migrate loose files from root save folder (legacy)
        # =======================================================================
        
        # Check for old KIFR_Settings.kro in root save folder
        old_settings = File.join(save_folder, "KIFR_Settings.kro")
        new_settings = settings_file_path
        
        if File.exist?(old_settings) && new_settings && !File.exist?(new_settings)
          debug_log("Migrating KIFR_Settings.kro from root save folder...")
          begin
            FileUtils.cp(old_settings, new_settings) rescue File.open(new_settings, 'wb') { |f| f.write(File.read(old_settings)) }
            File.delete(old_settings) rescue nil
            debug_log("Settings file migrated successfully")
            migrated = true
          rescue => e
            debug_log("Failed to migrate settings: #{e.message}")
          end
        elsif File.exist?(old_settings)
          # Delete old file if new one exists
          File.delete(old_settings) rescue nil
          debug_log("Removed duplicate old settings file")
        end
        
        # Check for old KIFR_Presets folder in root save folder
        old_presets = File.join(save_folder, "KIFR_Presets")
        new_presets = presets_folder
        
        if Dir.exist?(old_presets) && new_presets
          debug_log("Migrating KIFR_Presets folder...")
          Dir.glob(File.join(old_presets, "*")).each do |file|
            next unless File.file?(file)
            new_path = File.join(new_presets, File.basename(file))
            unless File.exist?(new_path)
              begin
                FileUtils.cp(file, new_path) rescue File.open(new_path, 'wb') { |f| f.write(File.read(file)) }
                debug_log("Migrated preset: #{File.basename(file)}")
              rescue => e
                debug_log("Failed to migrate preset: #{e.message}")
              end
            end
            File.delete(file) rescue nil
          end
          # Remove old folder if empty
          Dir.rmdir(old_presets) if Dir.empty?(old_presets) rescue nil
          migrated = true
        end
        
        # =======================================================================
        # PRIORITY 3: Clean up other old files from save folder
        # =======================================================================
        old_files_to_clean = [
          "EnhancedUI_debug.txt",
          "KIFRDebug.txt",
          "KIFR_Dismissed_Conflicts.kro"
        ]
        
        old_files_to_clean.each do |filename|
          old_path = File.join(save_folder, filename)
          if File.exist?(old_path)
            new_path = File.join(new_kifr, filename)
            # Migrate if doesn't exist in new location, then delete old
            unless File.exist?(new_path)
              begin
                FileUtils.cp(old_path, new_path) rescue File.open(new_path, 'wb') { |f| f.write(File.read(old_path)) }
                debug_log("Migrated #{filename} to new KIFR folder")
                migrated = true
              rescue
              end
            end
            File.delete(old_path) rescue nil
            debug_log("Cleaned up old #{filename} from save folder")
          end
        end
        
        migrated
      rescue => e
        debug_log("Error migrating from old locations: #{e.message}")
        false
      end
    end
    
    # Migrate settings from old Mod_Settings.kro file
    # This provides compatibility with settings saved by the standalone ModSettingsMenu
    def migrate_from_mod_settings
      begin
        save_folder = RTP.getSaveFolder rescue nil
        return false unless save_folder
        
        old_file = File.join(save_folder, "Mod_Settings.kro")
        return false unless File.exist?(old_file)
        
        # Check if we already have KIFR settings (don't overwrite)
        new_file = settings_file_path
        if new_file && File.exist?(new_file)
          debug_log("KIFR settings exist, skipping migration from Mod_Settings.kro")
          return false
        end
        
        debug_log("Found old Mod_Settings.kro, attempting migration...")
        
        # Load old settings
        if defined?(kurayjson_load)
          data = kurayjson_load(old_file)
        else
          content = File.read(old_file)
          data = eval(content) rescue nil
        end
        
        if data.is_a?(Hash)
          # Merge old settings into current storage
          data.each do |key, value|
            storage[key.to_sym] = value unless storage.key?(key.to_sym)
          end
          
          debug_log("Migrated #{data.keys.length} settings from Mod_Settings.kro")
          
          # Save to new KIFR file
          save_to_file
          
          return true
        end
        
        return false
      rescue => e
        debug_log("Error migrating from Mod_Settings.kro: #{e.message}")
        return false
      end
    end
    
    #===========================================================================
    # Preset Management
    #===========================================================================
    
    # Get path to presets folder (inside KIFR folder)
    def presets_folder
      folder = kifr_folder
      return nil unless folder
      presets = File.join(folder, "Presets")
      Dir.mkdir(presets) unless Dir.exist?(presets)
      presets
    end
    
    # List all saved presets
    # @return [Array<String>] Array of preset names
    def list_presets
      begin
        folder = presets_folder
        return [] unless folder && Dir.exist?(folder)
        
        presets = []
        Dir.glob(File.join(folder, "*.kro")).each do |file|
          name = File.basename(file, ".kro")
          presets << name
        end
        presets.sort
      rescue => e
        debug_log("Error listing presets: #{e.message}")
        []
      end
    end
    
    # Save current settings as a preset
    # @param preset_name [String] Name for the preset
    # @return [Boolean] Success or failure
    def save_preset(preset_name)
      begin
        folder = presets_folder
        return false unless folder
        
        preset_file = File.join(folder, "#{preset_name}.kro")
        temp_file = preset_file + ".tmp"
        
        # Build preset data with metadata
        data = {
          preset_version: "1.0",
          created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
          kifr_version: VERSION,
          settings: storage.reject { |k, _| k.to_s.start_with?('_') }  # Exclude internal keys
        }
        
        # Atomic save
        if defined?(kurayjson_save)
          kurayjson_save(temp_file, data)
        else
          File.open(temp_file, 'w') { |f| f.write(data.inspect) }
        end
        
        if File.exist?(temp_file)
          File.delete(preset_file) if File.exist?(preset_file)
          File.rename(temp_file, preset_file)
        end
        
        debug_log("Preset '#{preset_name}' saved successfully")
        return true
      rescue => e
        debug_log("Error saving preset: #{e.message}")
        begin
          File.delete(temp_file) if temp_file && File.exist?(temp_file)
        rescue
        end
        return false
      end
    end
    
    # Load a preset
    # @param preset_name [String] Name of the preset to load
    # @return [Boolean] Success or failure
    def load_preset(preset_name)
      begin
        folder = presets_folder
        return false unless folder
        
        preset_file = File.join(folder, "#{preset_name}.kro")
        return false unless File.exist?(preset_file)
        
        if defined?(kurayjson_load)
          data = kurayjson_load(preset_file)
        else
          content = File.read(preset_file)
          data = eval(content) rescue nil
        end
        
        return false unless data.is_a?(Hash)
        
        # Handle both old format (direct settings) and new format (with metadata)
        if data.key?(:settings) && data[:settings].is_a?(Hash)
          # New format with metadata
          settings = data[:settings]
        else
          # Old format - direct settings hash
          settings = data
        end
        
        # Merge settings into storage (preserving internal keys)
        settings.each do |key, value|
          storage[key.to_sym] = value
        end
        
        debug_log("Preset '#{preset_name}' loaded successfully")
        return true
      rescue => e
        debug_log("Error loading preset: #{e.message}")
        return false
      end
    end
    
    # Delete a preset
    # @param preset_name [String] Name of the preset to delete
    # @return [Boolean] Success or failure
    def delete_preset(preset_name)
      begin
        folder = presets_folder
        return false unless folder
        
        preset_file = File.join(folder, "#{preset_name}.kro")
        return false unless File.exist?(preset_file)
        
        File.delete(preset_file)
        debug_log("Preset '#{preset_name}' deleted successfully")
        return true
      rescue => e
        debug_log("Error deleting preset: #{e.message}")
        return false
      end
    end
    
    # Export settings to a shareable file
    # @param export_name [String] Name for the export file
    # @return [Boolean] Success or failure
    def export_to_file(export_name)
      begin
        save_folder = RTP.getSaveFolder rescue nil
        return false unless save_folder
        
        export_folder = File.join(save_folder, "KIFR_Exports")
        Dir.mkdir(export_folder) unless Dir.exist?(export_folder)
        
        export_file = File.join(export_folder, "#{export_name}.kifr")
        temp_file = export_file + ".tmp"
        
        data = {
          export_version: "1.0",
          created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
          kifr_version: VERSION,
          settings: storage.reject { |k, _| k.to_s.start_with?('_') }
        }
        
        if defined?(kurayjson_save)
          kurayjson_save(temp_file, data)
        else
          File.open(temp_file, 'w') { |f| f.write(data.inspect) }
        end
        
        if File.exist?(temp_file)
          File.delete(export_file) if File.exist?(export_file)
          File.rename(temp_file, export_file)
        end
        
        debug_log("Settings exported to '#{export_name}.kifr'")
        return true
      rescue => e
        debug_log("Error exporting settings: #{e.message}")
        return false
      end
    end
    
    # Import settings from an export file
    # @param export_name [String] Name of the export file (without extension)
    # @return [Boolean] Success or failure
    def import_from_file(export_name)
      begin
        save_folder = RTP.getSaveFolder rescue nil
        return false unless save_folder
        
        export_folder = File.join(save_folder, "KIFR_Exports")
        export_file = File.join(export_folder, "#{export_name}.kifr")
        return false unless File.exist?(export_file)
        
        if defined?(kurayjson_load)
          data = kurayjson_load(export_file)
        else
          content = File.read(export_file)
          data = eval(content) rescue nil
        end
        
        return false unless data.is_a?(Hash)
        
        settings = data[:settings] || data
        settings.each do |key, value|
          storage[key.to_sym] = value
        end
        
        debug_log("Settings imported from '#{export_name}.kifr'")
        return true
      rescue => e
        debug_log("Error importing settings: #{e.message}")
        return false
      end
    end
    
    # List all export files
    # @return [Array<String>] Array of export file names (without extension)
    def list_exports
      begin
        save_folder = RTP.getSaveFolder rescue nil
        return [] unless save_folder
        
        export_folder = File.join(save_folder, "KIFR_Exports")
        return [] unless Dir.exist?(export_folder)
        
        exports = []
        Dir.glob(File.join(export_folder, "*.kifr")).each do |file|
          name = File.basename(file, ".kifr")
          exports << name
        end
        exports.sort
      rescue => e
        debug_log("Error listing exports: #{e.message}")
        []
      end
    end
    
    # Delete an export file
    # @param export_name [String] Name of the export to delete
    # @return [Boolean] Success or failure
    def delete_export(export_name)
      begin
        save_folder = RTP.getSaveFolder rescue nil
        return false unless save_folder
        
        export_folder = File.join(save_folder, "KIFR_Exports")
        export_file = File.join(export_folder, "#{export_name}.kifr")
        return false unless File.exist?(export_file)
        
        File.delete(export_file)
        debug_log("Export '#{export_name}' deleted successfully")
        return true
      rescue => e
        debug_log("Error deleting export: #{e.message}")
        return false
      end
    end
    
    #===========================================================================
    # Integrated Files Auto-Disable System
    #===========================================================================
    # Files that have been integrated into KIFR and should be auto-disabled
    # Add filenames here as you integrate more mods into KIFR
    INTEGRATED_FILES = [
      "01_Mod_Settings.rb",       # ModSettingsMenu - now in KIFR
      "01a_Overworld_Menu.rb",    # Overworld Menu - now in 008_KIFR_OverworldMenu
      "30_Save Delete.rb",        # Save Delete - now in 009_KIFR_Title
      "10g_InstantText.rb",       # Instant Text - now in 002_KIFR_Options (Text Speed option)
      # Economy System - now in 010-014_KIFR_Economy files
      "02_EconomyMod.rb",         # Economy Mod - now in 010_KIFR_Economy
      "03_StonesKurayShop.rb",    # Stone's Kuray Shop - now in 011a_KIFR_KurayShop
      "03_PrivateKurayShop.rb",   # Private Kuray Shop - now in 011a_KIFR_KurayShop
      # Add more integrated files here as needed:
      # "SomeOtherMod.rb",
    ].freeze
    
    # Check if a filename is in the integrated files list
    def is_integrated_file?(filename)
      # Normalize filename - strip path and .disabled extension
      base_name = File.basename(filename.to_s)
      base_name = base_name.sub(/\.disabled$/, '.rb')
      
      INTEGRATED_FILES.any? { |f| f.downcase == base_name.downcase }
    end
    
    # Directories to scan for integrated files
    SCAN_DIRS = [
      "Mods",
      "Data/Scripts/998_Mods"
    ].freeze
    
    # Auto-disable integrated files that conflict with KIFR
    # Renames .rb to .disabled to prevent loading
    def auto_disable_integrated_files
      disabled_count = 0
      
      SCAN_DIRS.each do |rel_dir|
        # Try multiple base paths
        base_paths = []
        base_paths << "." if Dir.exist?(rel_dir)
        base_paths << Dir.pwd if Dir.exist?(File.join(Dir.pwd, rel_dir))
        
        # Also try relative to game folder
        if defined?(RTP) && RTP.respond_to?(:getSaveFolder)
          game_folder = File.dirname(RTP.getSaveFolder) rescue nil
          if game_folder
            # Go up from save folder to find game root
            potential_root = File.expand_path("../..", game_folder)
            base_paths << potential_root if Dir.exist?(File.join(potential_root, rel_dir))
          end
        end
        
        base_paths.uniq.each do |base|
          scan_path = File.join(base, rel_dir)
          next unless Dir.exist?(scan_path)
          
          INTEGRATED_FILES.each do |filename|
            # Check in the directory itself
            file_path = File.join(scan_path, filename)
            if File.exist?(file_path)
              if disable_integrated_file(file_path)
                disabled_count += 1
              end
            end
            
            # Also check subdirectories (one level deep)
            begin
              Dir.entries(scan_path).each do |entry|
                next if entry.start_with?(".")
                subdir = File.join(scan_path, entry)
                next unless File.directory?(subdir)
                
                sub_file_path = File.join(subdir, filename)
                if File.exist?(sub_file_path)
                  if disable_integrated_file(sub_file_path)
                    disabled_count += 1
                  end
                end
              end
            rescue
            end
          end
        end
      end
      
      if disabled_count > 0
        debug_log("Auto-disabled #{disabled_count} integrated file(s)")
      end
      
      disabled_count
    end
    
    # Disable a single integrated file
    def disable_integrated_file(file_path)
      begin
        return false unless File.exist?(file_path)
        
        disabled_path = file_path.sub(/\.rb$/i, ".disabled")
        
        # Don't disable if already has a disabled version
        if File.exist?(disabled_path)
          debug_log("Skipping #{File.basename(file_path)} - disabled version already exists")
          return false
        end
        
        File.rename(file_path, disabled_path)
        debug_log("Auto-disabled integrated file: #{File.basename(file_path)}")
        return true
      rescue => e
        debug_log("Error disabling #{file_path}: #{e.message}")
        return false
      end
    end
  end
end

#===============================================================================
# Auto-load settings and disable integrated files on game start
#===============================================================================
# This runs when the script is first loaded
KIFRSettings.load_from_file
KIFRSettings.auto_disable_integrated_files
KIFRSettings.debug_log("KIF Redux Core v#{KIFRSettings.version} initialized")
