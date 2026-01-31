#===============================================================================
# KIF Redux Kuray Shop Data - Configuration & Persistence
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file manages Kuray Shop configuration data:
# - Default item/category definitions (based on Stone's Kuray Shop structure)
# - External file persistence (KIFR/KurayShop_Config.json)
# - Config versioning for migrations
# - Category and item management
# - Favorites integration
#===============================================================================

module KurayShopData
  # Current config version - increment when making breaking changes
  CONFIG_VERSION = 1
  
  # Config filename
  CONFIG_FILE = "KurayShopConfig.json"
  
  # Available category colors (matches KIFR COLOR_THEMES)
  CATEGORY_COLORS = {
    red: { name: "Red", color: Color.new(240, 120, 120) },
    orange: { name: "Orange", color: Color.new(248, 168, 88) },
    yellow: { name: "Yellow", color: Color.new(240, 224, 88) },
    green: { name: "Green", color: Color.new(120, 200, 120) },
    cyan: { name: "Cyan", color: Color.new(88, 224, 224) },
    blue: { name: "Blue", color: Color.new(88, 176, 248) },
    purple: { name: "Purple", color: Color.new(168, 128, 228) },
    pink: { name: "Pink", color: Color.new(248, 136, 192) },
    gold: { name: "Gold", color: Color.new(255, 215, 0) }
  }.freeze
  
  #=============================================================================
  # DEFAULT CONFIGURATION
  # Based on Stone's Kuray Shop structure from 03_StonesKurayShop.rb
  #=============================================================================
  
  # Default categories with their items
  # Format: { id: symbol, name: string, enabled: bool, color: symbol, items: [item_ids] }
  DEFAULT_CATEGORIES = [
    {
      id: :items,
      name: "ITEMS",
      enabled: true,
      color: :red,
      items: [3, 568, 569, 570, 68, 121, 122, 123, 124, 125, 126, 115, 116, 100, 194]
    },
    {
      id: :medicine,
      name: "MEDICINE",
      enabled: true,
      color: :red,
      items: [235, 263, 245, 246, 247, 248, 249, 250]
    },
    {
      id: :pokeballs,
      name: "POKEBALLS",
      enabled: true,
      color: :red,
      items: [264, 623]  # 623 (Rocket Ball) has special unlock condition
    },
    {
      id: :tms,
      name: "TMs & HMs",
      enabled: true,
      color: :red,
      items: [303, 314, 329, 335, 343, 345, 346, 356, 358, 367, 371,
              618, 619, 646, 647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657]
    },
    {
      id: :berries,
      name: "BERRIES",
      enabled: true,
      color: :red,
      items: []
    },
    {
      id: :battle_items,
      name: "BATTLE ITEMS",
      enabled: true,
      color: :red,
      items: []
    },
    {
      id: :key_items,
      name: "KEY ITEMS",
      enabled: true,
      color: :red,
      items: []
    },
    {
      id: :kuray_eggs,
      name: "KURAY EGGS",
      enabled: true,
      color: :red,
      items: [2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010,
              2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021,
              2022, 2023, 2024, 2025, 2026, 2027, 2028, 2029, 2030, 2031, 2032]
    }
  ].freeze
  
  # Default prices: ItemID => [BuyPrice, SellPrice]
  # Items not listed here use game default prices
  # -1 for BuyPrice means FREE (used by Streamer's Dream)
  DEFAULT_PRICES = {
    #--------- ITEMS ---------
    3 => [700, 350],         # Max Repel
    568 => [999999, 24000],  # Mist Stone (pre-Badge 8)
    569 => [8200, 4100],     # Devolution Spray
    570 => [6900, 3450],     # Transgender Stone
    68 => [4000, 2000],      # Eviolite
    121 => [3000, 1500],     # Power Weight
    122 => [3000, 1500],     # Power Bracer
    123 => [3000, 1500],     # Power Belt
    124 => [3000, 1500],     # Power Lens
    125 => [3000, 1500],     # Power Band
    126 => [3000, 1500],     # Power Anklet
    114 => [6000, 3000],     # Focus Sash
    115 => [6000, 3000],     # Flame Orb
    116 => [6000, 3000],     # Toxic Orb
    100 => [6000, 3000],     # Life Orb
    194 => [10000, 1000],    # Deep Sea Scale
    #--------- MEDICINE ---------
    235 => [10000, 0],       # Rage Candy Bar
    263 => [10000, 0],       # Rare Candy
    245 => [1200, 600],      # Ether
    246 => [3600, 1800],     # Max Ether
    247 => [4000, 2000],     # Elixir
    248 => [12000, 6000],    # Max Elixir
    249 => [9100, 4550],     # PP Up
    250 => [29120, 14560],   # PP Max
    #--------- POKEBALLS ---------
    264 => [960000, 0],      # Master Ball
    623 => [1500, 750],      # Rocket Ball
    #--------- TMs & HMs ---------
    303 => [10000, 5000],    # Light Screen
    314 => [10000, 5000],    # Return
    329 => [10000, 5000],    # Facade
    335 => [10000, 5000],    # Round
    343 => [10000, 5000],    # Fling
    345 => [10000, 5000],    # Sky Drop
    346 => [10000, 5000],    # Incinerate
    356 => [10000, 5000],    # Rock Polish
    358 => [10000, 5000],    # Stone Edge
    367 => [10000, 5000],    # Rock Throw
    371 => [10000, 5000],    # Poison Jab
    618 => [30000, 15000],   # Spore
    619 => [30000, 15000],   # Toxic Spikes
    646 => [30000, 15000],   # Brutal Swing
    647 => [30000, 15000],   # Aurora Veil
    648 => [30000, 15000],   # Dazzling Gleam
    649 => [30000, 15000],   # Focus Punch
    650 => [30000, 15000],   # Infestation
    651 => [30000, 15000],   # Leech Life
    652 => [30000, 15000],   # Power Up Punch
    653 => [30000, 15000],   # Shock Wave
    654 => [30000, 15000],   # Smart Strike
    655 => [30000, 15000],   # Steel Wing
    656 => [30000, 15000],   # Stomping Tantrum
    657 => [30000, 15000],   # Throat Chop
  }.freeze
  
  # Kuray Egg ID range (uses $KURAYEGGS_BASEPRICE for pricing)
  # Eggs are ALWAYS included in Streamer's Dream
  
  # Kuray Egg ID range (uses $KURAYEGGS_BASEPRICE for pricing)
  # Eggs are ALWAYS included in Streamer's Dream
  EGG_RANGE = (2000..2032).freeze
  
  # Items with special unlock conditions
  # Format: item_id => { condition: proc, description: string }
  SPECIAL_UNLOCKS = {
    623 => {  # Rocket Ball
      condition: proc { 
        defined?($PokemonSystem) && 
        $PokemonSystem.respond_to?(:rocketballsteal) && 
        $PokemonSystem.rocketballsteal && 
        $PokemonSystem.rocketballsteal > 0 
      },
      description: "Unlocked after stealing from Team Rocket"
    },
    2023 => { condition: proc { $game_switches[SWITCH_GOT_BADGE_1] rescue false }, description: "Badge 1 required" },
    2024 => { condition: proc { $game_switches[SWITCH_GOT_BADGE_2] rescue false }, description: "Badge 2 required" },
    2025 => { condition: proc { $game_switches[SWITCH_GOT_BADGE_3] rescue false }, description: "Badge 3 required" },
    2026 => { condition: proc { $game_switches[SWITCH_GOT_BADGE_4] rescue false }, description: "Badge 4 required" },
    2027 => { condition: proc { $game_switches[SWITCH_GOT_BADGE_5] rescue false }, description: "Badge 5 required" },
    2028 => { condition: proc { $game_switches[SWITCH_GOT_BADGE_6] rescue false }, description: "Badge 6 required" },
    2029 => { condition: proc { $game_switches[SWITCH_GOT_BADGE_7] rescue false }, description: "Badge 7 required" },
    2030 => { condition: proc { $game_switches[SWITCH_GOT_BADGE_8] rescue false }, description: "Badge 8 required" },
    2031 => { condition: proc { ($game_variables[VAR_STAT_NB_ELITE_FOUR] rescue 0) >= 1 }, description: "Beat Elite Four" },
  }.freeze
  
  # Items with badge-based price changes
  BADGE_PRICE_ITEMS = {
    568 => {  # Mist Stone
      default: [999999, 24000],
      badge_8: [42000, 24000]
    }
  }.freeze
  
  #=============================================================================
  # PRESETS
  # Predefined configurations that can be loaded at any time
  #=============================================================================
  PRESETS = {
    default: {
      name: "Default",
      description: "Original Kuray Shop configuration",
      categories: :DEFAULT_CATEGORIES,  # Use DEFAULT_CATEGORIES constant
      prices: :DEFAULT_PRICES            # Use DEFAULT_PRICES constant
    }
    # Future presets can be added here:
    # economy: {
    #   name: "Economy Mode",
    #   description: "Reduced prices for a more casual experience",
    #   categories: :DEFAULT_CATEGORIES,
    #   prices: { ... custom prices ... }
    # }
  }.freeze
  
  # Maps where Kuray Shop is blocked
  BLOCKED_MAPS = [315, 316, 317, 318, 328, 341].freeze
  
  #=============================================================================
  # RUNTIME DATA STORAGE
  #=============================================================================
  class << self
    # Current loaded configuration
    def config
      @config ||= load_or_create_config
    end
    
    # Force reload config from file
    def reload_config
      @config = nil
      config
    end
    
    # Get categories (ordered)
    def categories
      config[:categories] || []
    end
    
    # Get custom prices
    def custom_prices
      config[:custom_prices] || {}
    end
    
    # Get favorites list
    def favorites
      config[:favorites] || []
    end
    
    # Check if item is favorited
    def favorite?(item_id)
      favorites.include?(item_id)
    end
    
    # Toggle favorite status
    def toggle_favorite(item_id)
      if favorite?(item_id)
        config[:favorites].delete(item_id)
      else
        config[:favorites] ||= []
        config[:favorites] << item_id
      end
      save_config
    end
    
    # Get show IDs setting
    def show_item_ids?
      KIFRSettings.get(:kuray_shop_show_ids, 0) == 1
    end
    
    #===========================================================================
    # CATEGORY MANAGEMENT
    #===========================================================================
    
    # Get category by ID
    def get_category(category_id)
      categories.find { |c| c[:id] == category_id.to_sym }
    end
    
    # Get category index
    def category_index(category_id)
      categories.index { |c| c[:id] == category_id.to_sym }
    end
    
    # Reorder category (move to new index)
    def reorder_category(category_id, new_index)
      old_index = category_index(category_id)
      return false unless old_index
      
      new_index = [[0, new_index].max, categories.length - 1].min
      return false if old_index == new_index
      
      cat = config[:categories].delete_at(old_index)
      config[:categories].insert(new_index, cat)
      save_config
      true
    end
    
    # Move category up
    def move_category_up(category_id)
      idx = category_index(category_id)
      return false unless idx && idx > 0
      reorder_category(category_id, idx - 1)
    end
    
    # Move category down
    def move_category_down(category_id)
      idx = category_index(category_id)
      return false unless idx && idx < categories.length - 1
      reorder_category(category_id, idx + 1)
    end
    
    # Enable/disable category
    def set_category_enabled(category_id, enabled)
      cat = get_category(category_id)
      return false unless cat
      cat[:enabled] = enabled
      save_config
      true
    end
    
    # Rename category
    def rename_category(category_id, new_name)
      cat = get_category(category_id)
      return false unless cat
      cat[:name] = new_name.to_s
      save_config
      true
    end
    
    # Add new category
    def add_category(name, id = nil, color = :red)
      id ||= name.downcase.gsub(/[^a-z0-9]/, '_').to_sym
      return false if get_category(id)
      
      config[:categories] << {
        id: id,
        name: name.to_s,
        enabled: true,
        color: color.to_sym,
        items: []
      }
      save_config
      true
    end
    
    # Delete category (moves items to uncategorized or deletes them)
    def delete_category(category_id)
      idx = category_index(category_id)
      return false unless idx
      
      config[:categories].delete_at(idx)
      save_config
      true
    end
    
    # Get category color
    def get_category_color(category_id)
      cat = get_category(category_id)
      return :red unless cat
      cat[:color] || :red
    end
    
    # Set category color
    def set_category_color(category_id, color_key)
      cat = get_category(category_id)
      return false unless cat
      return false unless CATEGORY_COLORS.key?(color_key.to_sym)
      
      cat[:color] = color_key.to_sym
      save_config
      true
    end
    
    # Get color object for category
    def get_category_color_object(category_id)
      # Special handling for favorites
      return CATEGORY_COLORS[:gold][:color] if category_id == :favorites
      
      color_key = get_category_color(category_id)
      CATEGORY_COLORS[color_key][:color]
    end
    
    # Get list of available color keys
    def available_colors
      CATEGORY_COLORS.keys
    end
    
    # Get color name for display
    def color_name(color_key)
      CATEGORY_COLORS[color_key.to_sym]&.dig(:name) || "Default"
    end
    
    #===========================================================================
    # ITEM POSITION MANAGEMENT
    #===========================================================================
    
    # Get item index within category
    def item_index_in_category(item_id, category_id)
      cat = get_category(category_id)
      return nil unless cat && cat[:items]
      cat[:items].index(item_id)
    end
    
    # Swap two items' positions within a category
    def swap_items_in_category(category_id, index1, index2)
      cat = get_category(category_id)
      return false unless cat && cat[:items]
      return false if index1 < 0 || index2 < 0
      return false if index1 >= cat[:items].length || index2 >= cat[:items].length
      return false if index1 == index2
      
      cat[:items][index1], cat[:items][index2] = cat[:items][index2], cat[:items][index1]
      save_config
      true
    end
    
    # Move item up in category (lower index)
    def move_item_up_in_category(item_id, category_id)
      idx = item_index_in_category(item_id, category_id)
      return false unless idx && idx > 0
      swap_items_in_category(category_id, idx, idx - 1)
    end
    
    # Move item down in category (higher index)
    def move_item_down_in_category(item_id, category_id)
      cat = get_category(category_id)
      return false unless cat && cat[:items]
      idx = item_index_in_category(item_id, category_id)
      return false unless idx && idx < cat[:items].length - 1
      swap_items_in_category(category_id, idx, idx + 1)
    end
    
    # Move item to specific position in category
    def move_item_to_position(item_id, category_id, new_position)
      cat = get_category(category_id)
      return false unless cat && cat[:items]
      
      current_idx = cat[:items].index(item_id)
      return false unless current_idx
      
      new_position = [[0, new_position].max, cat[:items].length - 1].min
      return false if current_idx == new_position
      
      item = cat[:items].delete_at(current_idx)
      cat[:items].insert(new_position, item)
      save_config
      true
    end
    
    #===========================================================================
    # ITEM MANAGEMENT
    #===========================================================================
    
    # Get all item IDs across all enabled categories
    def all_item_ids
      ids = []
      categories.each do |cat|
        next unless cat[:enabled]
        (cat[:items] || []).each do |item_id|
          ids << item_id if item_available?(item_id)
        end
      end
      ids
    end
    
    # Check if item is available (unlock conditions met)
    def item_available?(item_id)
      unlock = SPECIAL_UNLOCKS[item_id]
      return true unless unlock
      
      begin
        unlock[:condition].call
      rescue
        false
      end
    end
    
    # Add item to category
    def add_item_to_category(item_id, category_id)
      cat = get_category(category_id)
      return false unless cat
      
      cat[:items] ||= []
      return false if cat[:items].include?(item_id)
      
      cat[:items] << item_id
      save_config
      true
    end
    
    # Remove item from category
    def remove_item_from_category(item_id, category_id)
      cat = get_category(category_id)
      return false unless cat
      return false unless cat[:items]
      
      result = cat[:items].delete(item_id)
      save_config if result
      result
    end
    
    # Move item to different category
    def move_item_to_category(item_id, from_category_id, to_category_id)
      return false if from_category_id == to_category_id
      
      if remove_item_from_category(item_id, from_category_id)
        add_item_to_category(item_id, to_category_id)
      else
        false
      end
    end
    
    # Find which category contains an item
    def find_item_category(item_id)
      categories.each do |cat|
        return cat[:id] if (cat[:items] || []).include?(item_id)
      end
      nil
    end
    
    #===========================================================================
    # PRICE MANAGEMENT
    #===========================================================================
    
    # Get price for item [buy, sell]
    def get_price(item_id)
      # Check custom prices first
      if custom_prices.key?(item_id)
        return custom_prices[item_id]
      end
      
      # Check badge-based prices
      if BADGE_PRICE_ITEMS.key?(item_id)
        badge_data = BADGE_PRICE_ITEMS[item_id]
        if badge_data[:badge_8] && ($game_switches[SWITCH_GOT_BADGE_8] rescue false)
          return badge_data[:badge_8]
        end
        return badge_data[:default]
      end
      
      # Check default prices
      if DEFAULT_PRICES.key?(item_id)
        return DEFAULT_PRICES[item_id]
      end
      
      # Kuray Eggs use $KURAYEGGS_BASEPRICE
      if EGG_RANGE.include?(item_id)
        egg_index = item_id - 2000
        if defined?($KURAYEGGS_BASEPRICE) && $KURAYEGGS_BASEPRICE[egg_index]
          base = $KURAYEGGS_BASEPRICE[egg_index]
          return [base, (base / 2.0).round]
        end
      end
      
      nil  # Use game default
    end
    
    # Get effective price (with Streamer's Dream applied)
    def get_effective_price(item_id, selling: false)
      # Streamer's Dream check
      if streamer_dream_active?
        if streamer_dream_item?(item_id)
          return selling ? 0 : -1
        end
      end
      
      price_data = get_price(item_id)
      return nil unless price_data
      
      selling ? price_data[1] : price_data[0]
    end
    
    # Set custom price for item
    def set_custom_price(item_id, buy_price, sell_price = nil)
      sell_price ||= (buy_price / 2.0).round
      config[:custom_prices] ||= {}
      config[:custom_prices][item_id] = [buy_price, sell_price]
      save_config
    end
    
    # Remove custom price (revert to default)
    def remove_custom_price(item_id)
      return false unless config[:custom_prices]
      result = config[:custom_prices].delete(item_id)
      save_config if result
      result
    end
    
    # Check if item has custom price
    def has_custom_price?(item_id)
      config[:custom_prices]&.key?(item_id)
    end
    
    # Bulk multiply all prices
    def multiply_all_prices(multiplier)
      return if multiplier <= 0
      
      config[:custom_prices] ||= {}
      
      # Apply to all items in all categories
      categories.each do |cat|
        (cat[:items] || []).each do |item_id|
          base_price = get_price(item_id)
          next unless base_price
          
          new_buy = (base_price[0] * multiplier).round
          new_sell = (base_price[1] * multiplier).round
          config[:custom_prices][item_id] = [new_buy, new_sell]
        end
      end
      
      save_config
    end
    
    # Set sell price as percentage of buy price for all items
    def set_sell_percentage(percentage)
      return if percentage < 0 || percentage > 100
      
      config[:custom_prices] ||= {}
      
      categories.each do |cat|
        (cat[:items] || []).each do |item_id|
          base_price = get_price(item_id)
          next unless base_price
          next if base_price[0] <= 0  # Skip free items
          
          new_sell = (base_price[0] * percentage / 100.0).round
          config[:custom_prices][item_id] = [base_price[0], new_sell]
        end
      end
      
      save_config
    end
    
    #===========================================================================
    # STREAMER'S DREAM
    #===========================================================================
    
    # Check if Streamer's Dream is active
    def streamer_dream_active?
      return false unless defined?($PokemonSystem)
      return false unless $PokemonSystem.respond_to?(:kuraystreamerdream)
      $PokemonSystem.kuraystreamerdream != 0
    end
    
    # Set Streamer's Dream state
    def set_streamer_dream(enabled)
      return unless defined?($PokemonSystem)
      return unless $PokemonSystem.respond_to?(:kuraystreamerdream=)
      $PokemonSystem.kuraystreamerdream = enabled ? 1 : 0
    end
    
    # Check if item is a Streamer's Dream item
    # Uses STREAMER_DREAM_ITEMS constant from 011a_KIFR_KurayShop.rb
    def streamer_dream_item?(item_id)
      return true if EGG_RANGE.include?(item_id)
      return true if defined?(STREAMER_DREAM_ITEMS) && STREAMER_DREAM_ITEMS.include?(item_id)
      false
    end
    
    #===========================================================================
    # MAP RESTRICTIONS
    #===========================================================================
    
    # Check if Kuray Shop is blocked on current map
    def blocked_on_current_map?
      return false unless $game_map
      BLOCKED_MAPS.include?($game_map.map_id)
    end
    
    #===========================================================================
    # FILE PERSISTENCE
    #===========================================================================
    
    # Get config file path
    def config_file_path
      return nil unless defined?(KIFRSettings)
      folder = KIFRSettings.kifr_folder
      return nil unless folder
      kshop_folder = File.join(folder, "KurayShop")
      Dir.mkdir(kshop_folder) unless Dir.exist?(kshop_folder)
      File.join(kshop_folder, CONFIG_FILE)
    end
    
    # Load config from file or create default
    def load_or_create_config
      file_path = config_file_path
      
      if file_path && File.exist?(file_path)
        begin
          content = File.read(file_path)
          data = nil
          
          # Try JSON parsing
          if defined?(kurayjson_load)
            data = kurayjson_load(file_path)
          else
            # Fallback to eval (for .kro format)
            data = eval(content) rescue nil
          end
          
          if data.is_a?(Hash)
            # Migrate if needed
            data = migrate_config(data)
            debug_log("Loaded Kuray Shop config (version #{data[:version]})")
            return data
          end
        rescue => e
          debug_log("Error loading config: #{e.message}")
        end
      end
      
      # Create default config
      create_default_config
    end
    
    # Create default configuration
    def create_default_config
      config = {
        version: CONFIG_VERSION,
        created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
        categories: DEFAULT_CATEGORIES.map { |c| c.dup },
        custom_prices: {},
        favorites: []
      }
      
      # Deep copy items arrays
      config[:categories].each do |cat|
        cat[:items] = cat[:items].dup if cat[:items]
      end
      
      debug_log("Created default Kuray Shop config")
      config
    end
    
    # Migrate config from older versions
    def migrate_config(data)
      current_version = data[:version] || 0
      
      # Version 0 -> 1: Add favorites
      if current_version < 1
        data[:favorites] ||= []
        data[:version] = 1
        debug_log("Migrated config from v#{current_version} to v1")
      end
      
      # Future migrations go here
      # if current_version < 2
      #   # Migration code
      #   data[:version] = 2
      # end
      
      data
    end
    
    # Save config to file
    def save_config
      file_path = config_file_path
      return false unless file_path
      
      begin
        config[:version] = CONFIG_VERSION
        config[:updated_at] = Time.now.strftime('%Y-%m-%dT%H:%M:%S')
        
        temp_file = file_path + ".tmp"
        
        if defined?(kurayjson_save)
          kurayjson_save(temp_file, config)
        else
          File.open(temp_file, 'w') { |f| f.write(config.inspect) }
        end
        
        if File.exist?(temp_file)
          File.delete(file_path) if File.exist?(file_path)
          File.rename(temp_file, file_path)
        end
        
        debug_log("Saved Kuray Shop config")
        true
      rescue => e
        debug_log("Error saving config: #{e.message}")
        File.delete(temp_file) rescue nil if temp_file
        false
      end
    end
    
    # Reset config to defaults
    def reset_config
      @config = create_default_config
      save_config
      debug_log("Reset Kuray Shop config to defaults")
    end
    
    #===========================================================================
    # PRESETS
    #===========================================================================
    
    # Get custom presets from file
    def custom_presets
      @custom_presets ||= load_custom_presets
    end
    
    # Load custom presets from file
    def load_custom_presets
      file_path = custom_presets_file_path
      return {} unless file_path && File.exist?(file_path)
      
      begin
        if defined?(kurayjson_load)
          data = kurayjson_load(file_path)
          return data if data.is_a?(Hash)
        end
      rescue => e
        debug_log("Error loading custom presets: #{e.message}")
      end
      {}
    end
    
    # Save custom presets to file
    def save_custom_presets
      file_path = custom_presets_file_path
      return false unless file_path
      
      begin
        if defined?(kurayjson_save)
          kurayjson_save(file_path, @custom_presets || {})
        else
          File.open(file_path, 'w') { |f| f.write((@custom_presets || {}).inspect) }
        end
        true
      rescue => e
        debug_log("Error saving custom presets: #{e.message}")
        false
      end
    end
    
    # Get custom presets file path
    def custom_presets_file_path
      return nil unless defined?(KIFRSettings)
      folder = KIFRSettings.kifr_folder
      return nil unless folder
      kshop_folder = File.join(folder, "KurayShop")
      Dir.mkdir(kshop_folder) unless Dir.exist?(kshop_folder)
      File.join(kshop_folder, "KurayShopPresets.json")
    end
    
    # Get list of available presets (built-in + custom)
    def available_presets
      (PRESETS.keys + custom_presets.keys).uniq
    end
    
    # Get preset info by ID (checks built-in first, then custom)
    def get_preset(preset_id)
      id = preset_id.to_sym
      PRESETS[id] || custom_presets[id]
    end
    
    # Save current config as a custom preset
    def save_current_as_preset(name)
      return false unless name && !name.strip.empty?
      
      preset_id = name.strip.downcase.gsub(/[^a-z0-9]/, '_').to_sym
      
      # Don't overwrite built-in presets
      if PRESETS.key?(preset_id)
        debug_log("Cannot overwrite built-in preset: #{preset_id}")
        return false
      end
      
      @custom_presets ||= load_custom_presets
      
      # Deep copy current categories
      categories_copy = config[:categories].map { |c|
        cat = c.dup
        cat[:items] = cat[:items].dup if cat[:items]
        cat
      }
      
      # Copy custom prices
      prices_copy = (config[:custom_prices] || {}).dup
      
      @custom_presets[preset_id] = {
        name: name.strip,
        description: "Custom preset saved #{Time.now.strftime('%Y-%m-%d %H:%M')}",
        categories: categories_copy,
        prices: prices_copy,
        custom: true
      }
      
      save_custom_presets
      debug_log("Saved custom preset: #{name}")
      true
    end
    
    # Delete a custom preset
    def delete_preset(preset_id)
      id = preset_id.to_sym
      
      # Can't delete built-in presets
      if PRESETS.key?(id)
        debug_log("Cannot delete built-in preset: #{id}")
        return false
      end
      
      @custom_presets ||= load_custom_presets
      
      if @custom_presets.key?(id)
        @custom_presets.delete(id)
        save_custom_presets
        debug_log("Deleted preset: #{id}")
        return true
      end
      
      false
    end
    
    # Apply a preset configuration
    def apply_preset(preset_id)
      preset = get_preset(preset_id)
      return false unless preset
      
      # Get categories (either from constant or inline)
      categories = if preset[:categories] == :DEFAULT_CATEGORIES
        DEFAULT_CATEGORIES.map { |c| 
          cat = c.dup
          cat[:items] = cat[:items].dup if cat[:items]
          cat
        }
      else
        preset[:categories].map { |c| 
          cat = c.dup
          cat[:items] = cat[:items].dup if cat[:items]
          cat
        }
      end
      
      # Get prices (either from constant or inline)
      prices = if preset[:prices] == :DEFAULT_PRICES
        {}  # Empty means use DEFAULT_PRICES (no custom overrides)
      else
        preset[:prices].dup
      end
      
      # Apply to config
      @config = {
        version: CONFIG_VERSION,
        created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
        categories: categories,
        custom_prices: prices
      }
      
      save_config
      debug_log("Applied preset: #{preset[:name]}")
      true
    end
    
    # Export a single preset to a file (for sharing)
    def export_preset(preset_id)
      return false unless defined?(KIFRSettings)
      
      preset = get_preset(preset_id)
      return false unless preset
      
      folder = KIFRSettings.kifr_folder
      return false unless folder
      
      kshop_folder = File.join(folder, "KurayShop")
      Dir.mkdir(kshop_folder) unless Dir.exist?(kshop_folder)
      exports_folder = File.join(kshop_folder, "Exports")
      Dir.mkdir(exports_folder) unless Dir.exist?(exports_folder)
      
      # Use preset name for filename
      safe_name = preset[:name].to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      export_file = File.join(exports_folder, "KShopPreset_#{safe_name}.json")
      
      begin
        kifr_ver = (KIFRSettings.version rescue "unknown")
        export_data = {
          preset_name: preset[:name],
          preset_id: preset_id.to_s,
          description: preset[:description],
          categories: preset[:categories],
          prices: preset[:prices],
          exported_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
          kifr_version: kifr_ver
        }
        
        if defined?(kurayjson_save)
          kurayjson_save(export_file, export_data)
        else
          File.open(export_file, 'w') { |f| f.write(export_data.inspect) }
        end
        
        debug_log("Exported preset '#{preset[:name]}' to file")
        true
      rescue => e
        debug_log("Error exporting preset: #{e.message}")
        false
      end
    end
    
    # Import a preset from a file (adds to preset list, doesn't change current config)
    def import_preset(filename)
      return false unless defined?(KIFRSettings)
      
      folder = KIFRSettings.kifr_folder
      return false unless folder
      
      kshop_folder = File.join(folder, "KurayShop")
      exports_folder = File.join(kshop_folder, "Exports")
      import_file = File.join(exports_folder, "KShopPreset_#{filename}.json")
      
      return false unless File.exist?(import_file)
      
      begin
        data = nil
        if defined?(kurayjson_load)
          data = kurayjson_load(import_file)
        else
          content = File.read(import_file)
          data = eval(content) rescue nil
        end
        
        return false unless data.is_a?(Hash)
        return false unless data[:preset_name] && data[:categories]
        
        # Generate preset ID from name
        preset_id = data[:preset_name].to_s.downcase.gsub(/[^a-z0-9]/, '_').to_sym
        
        # Don't overwrite built-in presets
        if PRESETS.key?(preset_id)
          preset_id = "#{preset_id}_imported".to_sym
        end
        
        @custom_presets ||= load_custom_presets
        
        @custom_presets[preset_id] = {
          name: data[:preset_name],
          description: data[:description] || "Imported preset",
          categories: data[:categories],
          prices: data[:prices] || {},
          custom: true,
          imported: true
        }
        
        save_custom_presets
        debug_log("Imported preset '#{data[:preset_name]}'")
        data[:preset_name]  # Return the name for display
      rescue => e
        debug_log("Error importing preset: #{e.message}")
        false
      end
    end
    
    # List available preset export files
    def list_preset_exports
      return [] unless defined?(KIFRSettings)
      
      folder = KIFRSettings.kifr_folder
      return [] unless folder
      
      kshop_folder = File.join(folder, "KurayShop")
      exports_folder = File.join(kshop_folder, "Exports")
      return [] unless Dir.exist?(exports_folder)
      
      exports = []
      Dir.glob(File.join(exports_folder, "KShopPreset_*.json")).each do |file|
        name = File.basename(file, ".json").sub("KShopPreset_", "")
        exports << name
      end
      exports.sort
    end
    
    #===========================================================================
    # SEARCH / FILTER
    #===========================================================================
    
    # Search for items by name or ID
    def search_items(query)
      return [] if query.nil? || query.to_s.strip.empty?
      
      query = query.to_s.strip.downcase
      results = []
      
      # Check if searching by ID
      if query =~ /^\d+$/
        item_id = query.to_i
        if item_exists?(item_id)
          results << { id: item_id, name: get_item_name(item_id), category: find_item_category(item_id) }
        end
        return results
      end
      
      # Search by name across all possible items
      # First search items in shop
      all_item_ids.each do |item_id|
        name = get_item_name(item_id)
        if name && name.downcase.include?(query)
          results << { id: item_id, name: name, category: find_item_category(item_id), in_shop: true }
        end
      end
      
      results
    end
    
    # Search all game items (for adding new items)
    def search_all_items(query)
      return [] if query.nil? || query.to_s.strip.empty?
      
      query = query.to_s.strip.downcase
      results = []
      
      # Check if searching by ID
      if query =~ /^\d+$/
        item_id = query.to_i
        if item_exists?(item_id)
          in_shop = find_item_category(item_id) != nil
          results << { id: item_id, name: get_item_name(item_id), in_shop: in_shop }
        end
        return results
      end
      
      # Search game data
      begin
        if defined?(GameData::Item)
          GameData::Item.each do |item|
            next unless item.name.downcase.include?(query)
            item_id = get_item_id(item)
            in_shop = find_item_category(item_id) != nil
            results << { id: item_id, name: item.name, in_shop: in_shop }
          end
        end
      rescue
      end
      
      results.first(50)  # Limit results
    end
    
    # Check if item exists in game data
    def item_exists?(item_id)
      begin
        if defined?(GameData::Item)
          return GameData::Item.exists?(item_id)
        end
      rescue
      end
      false
    end
    
    # Get item name from game data
    def get_item_name(item_id)
      begin
        if defined?(GameData::Item)
          item = GameData::Item.try_get(item_id)
          return item.name if item
        end
      rescue
      end
      "Item ##{item_id}"
    end
    
    # Get item ID from game data item object
    def get_item_id(item)
      begin
        return item.id if item.respond_to?(:id) && item.id.is_a?(Integer)
        return item.id_number if item.respond_to?(:id_number)
      rescue
      end
      0
    end
    
    #===========================================================================
    # VALIDATION
    #===========================================================================
    
    # Validate entire configuration and return warnings
    # Returns array of warning hashes: { type: :warning/:error, message: "...", category: :id, item: id }
    def validate_config
      warnings = []
      
      # Check for empty categories
      categories.each do |cat|
        if cat[:enabled] && (cat[:items].nil? || cat[:items].empty?)
          warnings << {
            type: :warning,
            message: "Category '#{cat[:name]}' is enabled but has no items",
            category: cat[:id]
          }
        end
      end
      
      # Check for duplicate items across categories
      seen_items = {}
      categories.each do |cat|
        (cat[:items] || []).each do |item_id|
          if seen_items[item_id]
            warnings << {
              type: :warning,
              message: "Item '#{get_item_name(item_id)}' appears in multiple categories",
              category: cat[:id],
              item: item_id,
              other_category: seen_items[item_id]
            }
          else
            seen_items[item_id] = cat[:id]
          end
        end
      end
      
      # Check for $0 prices (except Streamer's Dream items)
      categories.each do |cat|
        next unless cat[:enabled]
        (cat[:items] || []).each do |item_id|
          next if streamer_dream_item?(item_id)
          
          price = get_price(item_id)
          if price && price[0] == 0
            warnings << {
              type: :info,
              message: "Item '#{get_item_name(item_id)}' has a price of $0",
              category: cat[:id],
              item: item_id
            }
          end
        end
      end
      
      # Check for invalid items (not in game data)
      categories.each do |cat|
        (cat[:items] || []).each do |item_id|
          unless item_exists?(item_id)
            warnings << {
              type: :error,
              message: "Item ##{item_id} does not exist in game data",
              category: cat[:id],
              item: item_id
            }
          end
        end
      end
      
      # Check for items with very high prices
      categories.each do |cat|
        next unless cat[:enabled]
        (cat[:items] || []).each do |item_id|
          price = get_price(item_id)
          if price && price[0] > 999999
            warnings << {
              type: :info,
              message: "Item '#{get_item_name(item_id)}' has a very high price ($#{price[0]})",
              category: cat[:id],
              item: item_id
            }
          end
        end
      end
      
      warnings
    end
    
    # Get validation summary
    def validation_summary
      warnings = validate_config
      {
        errors: warnings.count { |w| w[:type] == :error },
        warnings: warnings.count { |w| w[:type] == :warning },
        info: warnings.count { |w| w[:type] == :info },
        total: warnings.length
      }
    end
    
    # Check if config has any errors
    def config_has_errors?
      validate_config.any? { |w| w[:type] == :error }
    end
    
    # Check if config has warnings
    def config_has_warnings?
      validate_config.any? { |w| w[:type] == :warning }
    end
    
    #===========================================================================
    # DEBUG LOGGING
    #===========================================================================
    
    def debug_log(message)
      KIFRSettings.debug_log("KurayShopData: #{message}") if defined?(KIFRSettings)
    end
  end
end

#===============================================================================
# KIFR SETTINGS REGISTRATION
#===============================================================================
begin
  if defined?(KIFRSettings)
    # Register Show Item IDs setting
    # Removed: kuray_shop_show_ids setting - not used
    
    KurayShopData.debug_log("Module loaded successfully")
  end
rescue => e
  KurayShopData.debug_log("ERROR: Setup failed - #{e.message}") if defined?(KurayShopData)
end
