#===============================================================================
# KIF Redux Kuray Shop - Kuray Shop-Specific Features
# Script Version: 1.1.0
# Author: Stonewall
#===============================================================================
# This file contains the Kuray Shop integration with KIFR:
# - KurayShop::Stock - Build shop stock from KurayShopData
# - KurayShop::Display - Display stock with headers and favorites
# - KurayShop::Statistics - Track shop usage
# - PokemonMartScreen hooks - Integrate with game mart system
#
# Configuration is managed by 011_KIFR_KurayShop_Data.rb
# Editor UI is in 011b_KIFR_KurayShop_Editor.rb
#===============================================================================

#===============================================================================
# STREAMER'S DREAM CONFIGURATION
# Items in this list become FREE when Streamer's Dream is enabled.
# Kuray Eggs (2000-2032) are ALWAYS included automatically.
#===============================================================================
STREAMER_DREAM_ITEMS = [
  235,  # Rage Candy Bar
  263,  # Rare Candy
  570,  # Mist Stone
  264,  # Master Ball
  568,  # Devolution Spray
  569,  # Transgender Stone
  3,    # Max Repel
].freeze

module KurayShop
  #=============================================================================
  # DEBUG LOGGING HELPER
  #=============================================================================
  def self.debug_log(message)
    KIFRSettings.debug_log("KurayShop: #{message}") if defined?(KIFRSettings)
  end

  #=============================================================================
  # CHECK IF IN KURAY SHOP
  #=============================================================================
  def self.in_kuray_shop?
    $game_temp && $game_temp.respond_to?(:fromkurayshop) && $game_temp.fromkurayshop
  end

  #=============================================================================
  # STOCK MODULE - Build Shop Stock from KurayShopData
  #=============================================================================
  module Stock
    class << self
      # Build complete item list for the shop
      # Returns array of item IDs (integers only, no headers)
      def build
        return [] unless defined?(KurayShopData)
        
        items = []
        
        # Add favorites first if any
        favorites = KurayShopData.favorites
        favorites.each do |item_id|
          items << item_id if KurayShopData.item_available?(item_id)
        end
        
        # Add category items
        KurayShopData.categories.each do |cat|
          next unless cat[:enabled]
          (cat[:items] || []).each do |item_id|
            next if favorites.include?(item_id)  # Already added
            items << item_id if KurayShopData.item_available?(item_id)
          end
        end
        
        items.uniq
      end
      
      # Build display stock with headers
      # Returns array of item IDs and header hashes
      def build_display
        return [] unless defined?(KurayShopData)
        
        display = []
        
        # Add favorites section if any
        favorites = KurayShopData.favorites.select { |id| KurayShopData.item_available?(id) }
        if favorites.any?
          display << { header: "★ FAVORITES", category_id: :favorites }
          favorites.each { |id| display << id }
        end
        
        # Add category sections
        KurayShopData.categories.each do |cat|
          next unless cat[:enabled]
          
          available_items = (cat[:items] || []).select do |item_id|
            !favorites.include?(item_id) && KurayShopData.item_available?(item_id)
          end
          
          next if available_items.empty?
          
          display << { header: cat[:name], category_id: cat[:id] }
          available_items.each { |id| display << id }
        end
        
        display
      end
    end
  end

  #=============================================================================
  # PRICES MODULE - Get Prices from KurayShopData
  #=============================================================================
  module Prices
    class << self
      # Get price for an item [buy, sell]
      def get(item_id)
        return nil unless defined?(KurayShopData)
        KurayShopData.get_price(item_id)
      end
      
      # Get effective price (with Streamer's Dream applied)
      def get_effective(item_id, selling: false)
        return nil unless defined?(KurayShopData)
        KurayShopData.get_effective_price(item_id, selling: selling)
      end
      
      # Build prices hash for mart
      def build_hash
        prices = {}
        return prices unless defined?(KurayShopData)
        
        Stock.build.each do |item_id|
          price_data = KurayShopData.get_price(item_id)
          next unless price_data
          
          # Apply Streamer's Dream
          if KurayShopData.streamer_dream_active?
            if KurayShopData.streamer_dream_item?(item_id)
              prices[item_id] = [-1, 0]
              next
            end
          end
          
          prices[item_id] = price_data
        end
        
        prices
      end
    end
  end

  #=============================================================================
  # ITEMS MODULE - Compatibility Layer
  # Delegates to KurayShopData for backwards compatibility
  #=============================================================================
  module Items
    class << self
      def current
        return build_legacy_items if defined?(KurayShopData)
        DEFAULT_ITEMS
      end
      
      def item_ids
        return KurayShopData.all_item_ids if defined?(KurayShopData)
        current.select { |item| item.is_a?(Integer) }
      end
      
      def categories
        return KurayShopData.categories.map { |c| c[:name] } if defined?(KurayShopData)
        current.select { |item| item.is_a?(String) }
      end
      
      private
      
      # Build legacy-format items array for compatibility
      def build_legacy_items
        items = []
        KurayShopData.categories.each do |cat|
          next unless cat[:enabled]
          items << cat[:name]
          (cat[:items] || []).each { |id| items << id }
        end
        items
      end
    end
    
    # Legacy default items (kept for reference)
    DEFAULT_ITEMS = [
      "ITEMS",
      3, 568, 569, 570, 68, 121, 122, 123, 124, 125, 126, 115, 116, 100, 194,
      "MEDICINE",
      235, 263, 245, 246, 247, 248, 249, 250,
      "POKEBALLS",
      264, 623,
      "TMs & HMs",
      303, 314, 329, 335, 343, 345, 346, 356,
      358, 367, 371, 618, 619, 646, 647, 648,
      649, 650, 651, 652, 653, 654, 655, 656,
      657,
      "BERRIES",
      "BATTLE ITEMS",
      "KEY ITEMS",
      "KURAY EGGS",
      2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010,
      2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021,
      2022, 2023, 2024, 2025, 2026, 2027, 2028, 2029, 2030
    ].freeze
  end

  #=============================================================================
  # STREAMER DREAM MODULE - Compatibility Layer
  #=============================================================================
  module StreamerDream
    class << self
      def active?
        return KurayShopData.streamer_dream_active? if defined?(KurayShopData)
        return false unless defined?($PokemonSystem)
        return false unless $PokemonSystem.respond_to?(:kuraystreamerdream)
        $PokemonSystem.kuraystreamerdream != 0
      end
      
      def affects?(item_id)
        return false unless defined?(KurayShopData)
        KurayShopData.streamer_dream_item?(item_id)
      end
    end
  end

  #=============================================================================
  # EGG PRICING MODULE - Compatibility Layer
  #=============================================================================
  module EggPricing
    EGG_RANGE = (2000..2032).freeze
    
    class << self
      def egg?(item_id)
        EGG_RANGE.include?(item_id)
      end
      
      def get_base_price(egg_id)
        return nil unless EGG_RANGE.include?(egg_id)
        
        egg_index = egg_id - 2000
        if defined?($KURAYEGGS_BASEPRICE) && $KURAYEGGS_BASEPRICE[egg_index]
          return $KURAYEGGS_BASEPRICE[egg_index]
        end
        
        nil
      end
      
      def get_price(egg_id, selling: false)
        return nil unless EGG_RANGE.include?(egg_id)
        
        if StreamerDream.active?
          return selling ? 0 : -1
        end
        
        base = get_base_price(egg_id)
        return nil unless base
        
        selling ? (base / 2.0).round : base
      end
    end
  end

  #=============================================================================
  # DISPLAY MODULE - Build Display Stock with Headers
  #=============================================================================
  module Display
    class << self
      def build_stock(items = nil)
        # Use new Stock module
        Stock.build_display
      end
      
      def clean_stock(items = nil)
        Stock.build
      end
    end
  end

  #=============================================================================
  # STATISTICS MODULE - Track Kuray Shop Usage
  #=============================================================================
  module Statistics
    class << self
      def data
        $game_system.kuray_shop_stats ||= {
          total_spent: 0,
          total_earned: 0,
          items_bought: {},
          items_sold: {},
          eggs_bought: 0,
          visits: 0
        }
      end
      
      # Record a purchase
      def record_purchase(item_id, quantity, price)
        data[:total_spent] += price * quantity
        data[:items_bought][item_id] ||= 0
        data[:items_bought][item_id] += quantity
        
        if EggPricing.egg?(item_id)
          data[:eggs_bought] += quantity
        end
      end
      
      # Record a sale
      def record_sale(item_id, quantity, price)
        data[:total_earned] += price * quantity
        data[:items_sold][item_id] ||= 0
        data[:items_sold][item_id] += quantity
      end
      
      # Record a shop visit
      def record_visit
        data[:visits] += 1
      end
      
      # Get statistics summary
      def summary
        {
          total_spent: data[:total_spent],
          total_earned: data[:total_earned],
          net: data[:total_earned] - data[:total_spent],
          unique_items_bought: data[:items_bought].keys.length,
          unique_items_sold: data[:items_sold].keys.length,
          eggs_bought: data[:eggs_bought],
          visits: data[:visits]
        }
      end
      
      # Reset statistics
      def reset
        $game_system.kuray_shop_stats = nil
      end
    end
  end

  #=============================================================================
  # GET PRICE METHOD - Main interface for pricing
  #=============================================================================
  class << self
    # Get price for a specific item
    def get_price(item_id, selling: false)
      return nil unless defined?(KurayShopData)
      KurayShopData.get_effective_price(item_id, selling: selling)
    end
    
    # Get complete prices hash
    def get_prices_hash
      Prices.build_hash
    end
  end
end

#===============================================================================
# GAME_SYSTEM EXTENSIONS
#===============================================================================
class Game_System
  attr_accessor :kuray_shop_stats
end

#===============================================================================
# POKEMONMARTSCREEN HOOK - Kuray Shop Integration
#===============================================================================
class PokemonMartScreen
  unless method_defined?(:kifr_kurayshop_orig_pbBuyScreen)
    alias_method :kifr_kurayshop_orig_pbBuyScreen, :pbBuyScreen
  end

  def pbBuyScreen
    if KurayShop.in_kuray_shop?
      # Record visit to both Kuray and global statistics
      KurayShop::Statistics.record_visit rescue nil
      ShopData::Statistics.record_visit(true) if defined?(ShopData::Statistics)
      
      # Store initial state for tracking purchases (deep copy)
      initial_money = @adapter.getMoney rescue 0
      initial_bag_state = kifr_deep_copy_bag_state
      
      # Check if Streamer's Dream is active BEFORE the shop runs
      streamer_dream_active = KurayShopData.streamer_dream_active? rescue false
      
      # Call the original buy screen (pause menu already set up stock and prices)
      result = kifr_kurayshop_orig_pbBuyScreen
      
      # Track purchases to global ShopData::Statistics
      begin
        if defined?(ShopData::Statistics)
          final_money = @adapter.getMoney rescue 0
          money_spent = initial_money - final_money
          
          # Detect what items were purchased (regardless of money spent - could be free items)
          items_purchased = kifr_detect_bag_changes(initial_bag_state, true)
          
          if items_purchased.any?
            items_purchased.each do |item_id, quantity|
              # Determine if this was a free item (Streamer's Dream)
              is_free = false
              if streamer_dream_active
                is_free = KurayShopData.streamer_dream_item?(item_id) rescue false
              end
              
              # Get the actual price paid (0 if free)
              if is_free
                actual_price = 0
                total_item_price = 0
              else
                # Get price from KurayShopData (more reliable than adapter after shop closes)
                actual_price = KurayShopData.get_effective_price(item_id, selling: false) rescue 0
                total_item_price = actual_price * quantity
              end
              
              ShopData::Statistics.record_purchase(item_id, quantity, total_item_price, :kuray)
              ShopData::History.add_purchase(item_id, quantity, actual_price, :kuray) if defined?(ShopData::History)
              
              # Also record to Kuray-specific stats
              KurayShop::Statistics.record_purchase(item_id, quantity, actual_price) rescue nil
            end
            
            free_count = items_purchased.count { |id, _| streamer_dream_active && (KurayShopData.streamer_dream_item?(id) rescue false) }
            ShopData.debug_log("Kuray Shop: Tracked #{items_purchased.length} item types, #{items_purchased.values.sum} total items, $#{money_spent} spent, #{free_count} free") if defined?(ShopData)
          end
        end
      rescue => e
        ShopData.debug_log("Kuray Shop purchase tracking error: #{e.message}") if defined?(ShopData)
      end
      
      return result
    else
      return kifr_kurayshop_orig_pbBuyScreen
    end
  end
  
  # Sell screen hook for Kuray Shop
  unless method_defined?(:kifr_kurayshop_orig_pbSellScreen)
    alias_method :kifr_kurayshop_orig_pbSellScreen, :pbSellScreen
  end
  
  def pbSellScreen
    if KurayShop.in_kuray_shop?
      # Store initial state for tracking sales (deep copy)
      initial_money = @adapter.getMoney rescue 0
      initial_bag_state = kifr_deep_copy_bag_state
      
      # Call the original sell screen
      result = kifr_kurayshop_orig_pbSellScreen
      
      # Track sales to global ShopData::Statistics
      begin
        if defined?(ShopData::Statistics)
          final_money = @adapter.getMoney rescue 0
          money_earned = final_money - initial_money
          
          # Detect what items were sold
          items_sold = kifr_detect_bag_changes(initial_bag_state, false)
          
          if items_sold.any?
            items_sold.each do |item_id, quantity|
              item_price = @adapter.getPrice(item_id, true) rescue 0
              total_item_price = item_price * quantity
              
              ShopData::Statistics.record_sale(item_id, quantity, total_item_price, :kuray)
              ShopData::History.add_sale(item_id, quantity, item_price, :kuray) if defined?(ShopData::History)
              
              # Also record to Kuray-specific stats
              KurayShop::Statistics.record_sale(item_id, quantity, item_price) rescue nil
            end
            
            ShopData.debug_log("Kuray Shop: Tracked #{items_sold.length} item types sold, #{items_sold.values.sum} total items, $#{money_earned} earned") if defined?(ShopData)
          end
        end
      rescue => e
        ShopData.debug_log("Kuray Shop sell tracking error: #{e.message}") if defined?(ShopData)
      end
      
      return result
    else
      return kifr_kurayshop_orig_pbSellScreen
    end
  end
  
  # Deep copy the bag state for accurate before/after comparison
  def kifr_deep_copy_bag_state
    return [] unless $PokemonBag
    
    begin
      $PokemonBag.pockets.map do |pocket|
        next [] unless pocket.is_a?(Array)
        pocket.map do |entry|
          next nil unless entry.is_a?(Array)
          entry.dup  # Duplicate each [item_id, quantity] array
        end.compact
      end
    rescue
      []
    end
  end
  
  # Helper method for detecting bag changes (used by Kuray Shop tracking)
  def kifr_detect_bag_changes(initial_state, is_purchase)
    changes = {}
    return changes unless $PokemonBag
    
    begin
      current_state = kifr_deep_copy_bag_state
      
      # Build hash of initial items (convert item IDs to integers)
      initial_items = {}
      initial_state.each do |pocket|
        next unless pocket.is_a?(Array)
        pocket.each do |entry|
          next unless entry.is_a?(Array) && entry.length >= 2
          item_id = kifr_normalize_item_id(entry[0])
          next unless item_id
          quantity = entry[1]
          initial_items[item_id] ||= 0
          initial_items[item_id] += quantity
        end
      end
      
      # Build hash of current items (convert item IDs to integers)
      current_items = {}
      current_state.each do |pocket|
        next unless pocket.is_a?(Array)
        pocket.each do |entry|
          next unless entry.is_a?(Array) && entry.length >= 2
          item_id = kifr_normalize_item_id(entry[0])
          next unless item_id
          quantity = entry[1]
          current_items[item_id] ||= 0
          current_items[item_id] += quantity
        end
      end
      
      if is_purchase
        # For purchases, find items that increased
        current_items.each do |item_id, qty|
          initial_qty = initial_items[item_id] || 0
          if qty > initial_qty
            changes[item_id] = qty - initial_qty
          end
        end
      else
        # For sales, find items that decreased
        initial_items.each do |item_id, qty|
          current_qty = current_items[item_id] || 0
          if qty > current_qty
            changes[item_id] = qty - current_qty
          end
        end
      end
    rescue => e
      # Silent fail
    end
    
    changes
  end
  
  # Convert item ID to integer (handles symbols, GameData::Item, etc.)
  def kifr_normalize_item_id(item)
    return item if item.is_a?(Integer)
    
    begin
      if item.is_a?(Symbol)
        # Try GameData::Item first
        if defined?(GameData::Item)
          item_data = GameData::Item.try_get(item)
          return item_data.id_number if item_data && item_data.respond_to?(:id_number)
          return item_data.id if item_data && item_data.id.is_a?(Integer)
        end
        # Fallback: try to get ID from item data
        return getID(PBItems, item) if defined?(PBItems) && respond_to?(:getID)
      elsif item.respond_to?(:id_number)
        return item.id_number
      elsif item.respond_to?(:id) && item.id.is_a?(Integer)
        return item.id
      end
    rescue
    end
    
    nil
  end
end

#===============================================================================
# WINDOW_POKEMONMART HOOKS - Display Category Headers
#===============================================================================
class Window_PokemonMart
  unless method_defined?(:kifr_kurayshop_orig_drawItem)
    alias_method :kifr_kurayshop_orig_drawItem, :drawItem
  end

  def item
    return nil if !@stock || self.index >= @stock.length
    it = @stock[self.index]
    return nil if it.is_a?(Hash) && it[:header]
    return it
  end

  def drawItem(index, count, rect)
    item = @stock[index]
    
    if item.is_a?(Hash) && item[:header]
      rect = drawCursor(index, rect)
      ypos = rect.y
      
      # Get category color from KurayShopData if available
      base = Color.new(255, 50, 50)  # Default red
      shadow = Color.new(0, 0, 0)
      
      if defined?(KurayShopData) && item[:category_id]
        begin
          color_obj = KurayShopData.get_category_color_object(item[:category_id])
          base = color_obj if color_obj
        rescue
          # Use default red
        end
      end
      
      textpos = []
      cx = rect.x + (rect.width / 2)
      textpos.push([item[:header], cx, ypos - 4, 2, base, shadow])
      pbDrawTextPositions(self.contents, textpos)
      return
    end
    
    kifr_kurayshop_orig_drawItem(index, count, rect)
  end

  unless method_defined?(:kifr_kurayshop_orig_index=)
    alias_method :kifr_kurayshop_orig_index=, :index=
  end

  def index=(value)
    return kifr_kurayshop_orig_index=(value) if !@stock || !@stock.is_a?(Array) || @item_max.nil? || @item_max <= 0

    old = @index || 0
    target = value
    target = 0 if target < 0
    target = @item_max - 1 if target > @item_max - 1

    entry = @stock[target] rescue nil
    
    if entry.is_a?(Hash) && entry[:header]
      # Skip headers when navigating
      dir = 0
      dir = 1 if target > old
      dir = -1 if target < old
      dir = 1 if dir == 0
      
      newidx = target
      found = false
      
      @item_max.times do
        newidx = (newidx + dir) % @item_max
        ent = @stock[newidx] rescue nil
        unless ent.is_a?(Hash) && ent[:header]
          found = true
          break
        end
      end
      
      target = newidx if found
    end

    kifr_kurayshop_orig_index=(target)
  end
end

#===============================================================================
# POKEMONMART_SCENE HOOKS
#===============================================================================
class PokemonMart_Scene
  unless method_defined?(:kifr_kurayshop_orig_pbRefresh)
    alias_method :kifr_kurayshop_orig_pbRefresh, :pbRefresh
  end

  def pbRefresh
    kifr_kurayshop_orig_pbRefresh
    
    begin
      itemwindow = @sprites["itemwindow"]
      if itemwindow
        stock_arr = itemwindow.instance_variable_get(:@stock) rescue nil
        raw = stock_arr ? (stock_arr[itemwindow.index] rescue nil) : nil
        
        if raw.is_a?(Hash) && raw[:header]
          @sprites["icon"].item = nil if @sprites["icon"]
          @sprites["itemtextwindow"].text = "" if @sprites["itemtextwindow"]
        end
      end
    rescue StandardError
    end
  end

  unless method_defined?(:kifr_kurayshop_orig_pbChooseBuyItem)
    alias_method :kifr_kurayshop_orig_pbChooseBuyItem, :pbChooseBuyItem
  end

  def pbChooseBuyItem
    # Only use Kuray Shop's custom handling when in Kuray Shop
    # Regular shops should use the original method with category switching
    return kifr_kurayshop_orig_pbChooseBuyItem unless $game_temp.fromkurayshop
    
    itemwindow = @sprites["itemwindow"]
    @sprites["helpwindow"].visible = false
    
    pbActivateWindow(@sprites, "itemwindow") {
      pbRefresh
      
      loop do
        Graphics.update
        Input.update
        olditem = itemwindow.item
        self.update
        
        if itemwindow.item != olditem
          @sprites["icon"].item = itemwindow.item
          @sprites["itemtextwindow"].text =
            (itemwindow.item && !itemwindow.item.is_a?(Hash)) ? @adapter.getDescription(itemwindow.item) : _INTL("Quit shopping.")
        end
        
        if Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          return nil
        elsif Input.trigger?(Input::USE)
          stock_arr = itemwindow.instance_variable_get(:@stock) rescue nil
          raw2 = stock_arr ? (stock_arr[itemwindow.index] rescue nil) : nil
          
          if raw2.is_a?(Hash) && raw2[:header]
            pbPlayCancelSE
            next
          end
          
          # Check if this is the Cancel option (index past the end of stock)
          if stock_arr && itemwindow.index >= stock_arr.length
            return nil
          end
          
          # Get the actual item - if it's valid (not a header and not nil), return it
          current_item = itemwindow.item
          if current_item && !current_item.is_a?(Hash)
            pbRefresh
            return current_item
          else
            # Unexpected nil (shouldn't happen) - treat as cancel sound and continue
            pbPlayCancelSE
            next
          end
        end
      end
    }
  end

  unless method_defined?(:kifr_kurayshop_orig_pbStartBuyOrSellScene)
    alias_method :kifr_kurayshop_orig_pbStartBuyOrSellScene, :pbStartBuyOrSellScene
  end

  def pbStartBuyOrSellScene(buying, stock, adapter)
    rv = kifr_kurayshop_orig_pbStartBuyOrSellScene(buying, stock, adapter)
    
    begin
      if KurayShop.in_kuray_shop?
        iw = @sprites["itemwindow"] rescue nil
        if iw
          iw.instance_variable_set(:@stock, KurayShop::Display.build_stock)
          iw.index = 0 if iw.respond_to?(:index=)
          iw.refresh if iw.respond_to?(:refresh)
        end
      end
    rescue StandardError
    end
    
    return rv
  end
end

#===============================================================================
# POKEMONMARTADAPTER HOOK - Kuray Shop Pricing
#===============================================================================
if defined?(PokemonMartAdapter)
  class PokemonMartAdapter
    unless method_defined?(:kifr_kurayshop_orig_getPrice)
      alias_method :kifr_kurayshop_orig_getPrice, :getPrice
    end

    def getPrice(item, selling = false)
      # Check if we're in the Kuray Shop
      if KurayShop.in_kuray_shop?
        # Get price from KurayShop module
        custom_price = KurayShop.get_price(item, selling: selling)
        
        if custom_price
          # Check mart_prices for Streamer's Dream overrides
          if !selling && $game_temp.mart_prices && $game_temp.mart_prices[item]
            price_data = $game_temp.mart_prices[item]
            return 0 if price_data[0] == -1  # Free item (Streamer's Dream)
            return price_data[0] if price_data[0]
          end
          
          return custom_price
        end
      end
      
      # Fallback to original pricing
      return kifr_kurayshop_orig_getPrice(item, selling)
    end
  end
end

#===============================================================================
# KIFR SETTINGS REGISTRATION
#===============================================================================
begin
  if defined?(KIFRSettings)
    # Initialize defaults for show_item_ids setting
    # Removed: kuray_show_ids setting - not used
    
    # Initialize KurayShopData if available
    if defined?(KurayShopData)
      KurayShopData.initialize_config
      KIFRSettings.debug_log("KurayShop: Module loaded - Config initialized")
    else
      KIFRSettings.debug_log("KurayShop: Module loaded - Waiting for KurayShopData")
    end
  end
rescue => e
  KIFRSettings.debug_log("KurayShop: ERROR: Setup failed - #{e.message}") if defined?(KIFRSettings)
end
