#===============================================================================
# KIF Redux Shop - Shop Features for All Marts
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file contains shop features that work across ALL shops (including Kuray):
# - Shop::Categories - Category headers, collapse/expand, item counts
# - Shop::CategoryMultipliers - Per-category price adjustments
# - Shop::UI - Price colors, preview panel, sort options, etc.
#
# And features for REGULAR MARTS only (not Kuray Shop):
# - Shop::Stock - Limited stock with restock timers
# - Shop::Deals - Daily deals, weekly specials
# - Shop::Gating - Badge/story-gated items
# - Shop::Seasonal - Event/seasonal items
# - Shop::Cart - Shopping cart system
#===============================================================================

module Shop
  #=============================================================================
  # DEBUG LOGGING HELPER
  #=============================================================================
  def self.debug_log(message)
    KIFRSettings.debug_log("Shop: #{message}") if defined?(KIFRSettings)
  end

  #=============================================================================
  # CATEGORIES MODULE - Category Headers & Behaviors
  #=============================================================================
  # Works in ALL shops (including Kuray Shop)
  #=============================================================================
  module Categories
    # Default categories for regular marts (Kuray has its own in 011a)
    DEFAULT_CATEGORIES = [
      "MEDICINE",
      "POKEBALLS",
      "BATTLE ITEMS",
      "TMs & HMs",
      "BERRIES",
      "KEY ITEMS",
      "MISCELLANEOUS"
    ].freeze
    
    # Category collapse states (shared across all shops)
    @collapsed = {}
    
    class << self
      def collapsed
        @collapsed ||= {}
      end
      
      # Check if a category is collapsed
      def collapsed?(category_name)
        collapsed[category_name] || false
      end
      
      # Toggle category collapse state
      def toggle(category_name)
        collapsed[category_name] = !collapsed?(category_name)
      end
      
      # Expand a category
      def expand(category_name)
        collapsed[category_name] = false
      end
      
      # Collapse a category
      def collapse(category_name)
        collapsed[category_name] = true
      end
      
      # Expand all categories
      def expand_all
        @collapsed = {}
      end
      
      # Collapse all categories
      def collapse_all
        @collapsed = {}
        DEFAULT_CATEGORIES.each { |c| @collapsed[c] = true }
      end
      
      # Count items in a category within a stock list
      # @param stock [Array] Array of items and category headers
      # @param category [String] Category name to count
      def count_items_in_category(stock, category)
        count = 0
        in_category = false
        
        stock.each do |item|
          if item.is_a?(String) || (item.is_a?(Hash) && item[:header])
            # Category header
            header_name = item.is_a?(Hash) ? item[:header] : item
            if header_name == category
              in_category = true
            elsif in_category
              break  # Reached next category
            end
          elsif in_category
            count += 1
          end
        end
        
        count
      end
      
      # Build display stock with category headers
      # Handles collapse/expand states
      def build_display_stock(items, collapsed_override = nil)
        return [] unless items
        
        display = []
        current_category = nil
        category_items = []
        
        items.each do |item|
          if item.is_a?(String) || item.is_a?(Symbol)
            # This is a category header
            # First, add previous category if it had items
            if current_category && category_items.any?
              is_collapsed = collapsed_override ? collapsed_override[current_category] : collapsed?(current_category)
              display << { header: current_category, collapsed: is_collapsed, count: category_items.length }
              display.concat(category_items) unless is_collapsed
            end
            
            current_category = item.to_s.gsub(/^\-+|\-+$/, "").strip
            category_items = []
          elsif item.is_a?(Array) && item.first.is_a?(String)
            # Nested category format: ["CATEGORY", item1, item2, ...]
            header = item.first.to_s.gsub(/^\-+|\-+$/, "").strip
            nested_items = item[1..-1]
            
            if nested_items.any?
              is_collapsed = collapsed_override ? collapsed_override[header] : collapsed?(header)
              display << { header: header, collapsed: is_collapsed, count: nested_items.length }
              display.concat(nested_items) unless is_collapsed
            end
          else
            # Regular item
            category_items << item
          end
        end
        
        # Add final category
        if current_category && category_items.any?
          is_collapsed = collapsed_override ? collapsed_override[current_category] : collapsed?(current_category)
          display << { header: current_category, collapsed: is_collapsed, count: category_items.length }
          display.concat(category_items) unless is_collapsed
        end
        
        display
      end
      
      # Extract just the items (no headers) from a stock list
      def extract_items(stock)
        stock.reject { |item| item.is_a?(String) || item.is_a?(Symbol) || (item.is_a?(Hash) && item[:header]) }
      end
    end
  end

  #=============================================================================
  # CATEGORY MULTIPLIERS - Per-Category Price Adjustments
  #=============================================================================
  # Works in ALL shops (including Kuray Shop)
  #=============================================================================
  module CategoryMultipliers
    # Default multipliers (all 1.0x)
    DEFAULT_MULTIPLIERS = {
      "MEDICINE" => 1.0,
      "POKEBALLS" => 1.0,
      "BATTLE ITEMS" => 1.0,
      "TMs & HMs" => 1.0,
      "BERRIES" => 1.0,
      "KEY ITEMS" => 1.0,
      "MISCELLANEOUS" => 1.0,
      # Kuray Shop categories
      "ITEMS" => 1.0,
      "EVOLUTION ITEMS" => 1.0,
      "KURAY EGGS" => 1.0
    }.freeze
    
    class << self
      # Get multiplier for a category
      def get(category_name)
        return 1.0 unless defined?(KIFRSettings)
        
        key = "shop_category_mult_#{category_name.downcase.gsub(/\s+/, '_')}".to_sym
        raw = KIFRSettings.get(key, 10)  # Default 10 = 1.0x
        raw / 10.0
      end
      
      # Set multiplier for a category
      def set(category_name, multiplier)
        return unless defined?(KIFRSettings)
        
        key = "shop_category_mult_#{category_name.downcase.gsub(/\s+/, '_')}".to_sym
        KIFRSettings.set(key, (multiplier * 10).round)
      end
      
      # Apply category multiplier to a price
      def apply(price, category_name)
        return price if price <= 0
        return price unless category_name
        
        mult = get(category_name)
        return price if mult == 1.0
        
        [(price * mult).round, 1].max
      end
      
      # Get item's category from current shop context
      def get_item_category(item_id, stock)
        current_category = nil
        
        stock.each do |item|
          if item.is_a?(String) || item.is_a?(Symbol)
            current_category = item.to_s.gsub(/^\-+|\-+$/, "").strip
          elsif item.is_a?(Hash) && item[:header]
            current_category = item[:header]
          else
            item_check_id = EconomyMod::Core.item_to_id(item) rescue item
            return current_category if item_check_id == item_id
          end
        end
        
        nil
      end
    end
  end

  #=============================================================================
  # STOCK MODULE - Limited Stock & Restock Timers
  #=============================================================================
  # Regular Marts only (not Kuray Shop)
  #=============================================================================
  module Stock
    # Configuration
    RESTOCK_HOURS = 24  # Hours until limited items restock
    
    class << self
      def enabled?
        return false if EconomyMod::Core.skip_economy_features?
        true
      end
      
      # Get stock data from game system
      def stock_data
        $game_system.shop_stock_data ||= {}
      end
      
      # Get remaining stock for an item at current shop
      def get_remaining(item_id, shop_id = nil)
        shop_id ||= current_shop_id
        data = stock_data[shop_id]
        return nil unless data  # nil = unlimited
        
        data[item_id]
      end
      
      # Set stock limit for an item
      def set_limit(item_id, limit, shop_id = nil)
        shop_id ||= current_shop_id
        stock_data[shop_id] ||= {}
        stock_data[shop_id][item_id] = { limit: limit, remaining: limit, last_restock: EconomyMod::Core.current_time_seconds }
      end
      
      # Decrease stock when purchasing
      def decrease(item_id, quantity = 1, shop_id = nil)
        shop_id ||= current_shop_id
        data = stock_data[shop_id]
        return true unless data && data[item_id]  # Unlimited
        
        remaining = data[item_id][:remaining] || 0
        return false if remaining < quantity
        
        data[item_id][:remaining] = remaining - quantity
        true
      end
      
      # Check if item needs restock
      def check_restock(item_id, shop_id = nil)
        shop_id ||= current_shop_id
        data = stock_data[shop_id]
        return unless data && data[item_id]
        
        last_restock = data[item_id][:last_restock] || 0
        elapsed = EconomyMod::Core.current_time_seconds - last_restock
        
        if elapsed >= RESTOCK_HOURS * 3600
          data[item_id][:remaining] = data[item_id][:limit]
          data[item_id][:last_restock] = EconomyMod::Core.current_time_seconds
        end
      end
      
      # Get time until restock
      def time_until_restock(item_id, shop_id = nil)
        shop_id ||= current_shop_id
        data = stock_data[shop_id]
        return nil unless data && data[item_id]
        
        last_restock = data[item_id][:last_restock] || 0
        elapsed = EconomyMod::Core.current_time_seconds - last_restock
        remaining = (RESTOCK_HOURS * 3600) - elapsed
        
        [remaining, 0].max
      end
      
      # Format restock time for display
      def restock_time_text(item_id, shop_id = nil)
        seconds = time_until_restock(item_id, shop_id)
        return nil unless seconds && seconds > 0
        
        hours = seconds / 3600
        minutes = (seconds % 3600) / 60
        
        if hours > 0
          _INTL("Restocks in: {1}h {2}m", hours, minutes)
        else
          _INTL("Restocks in: {1}m", minutes)
        end
      end
      
      # Get current shop ID (based on map/event)
      def current_shop_id
        return "default" unless $game_map
        "shop_#{$game_map.map_id}"
      end
    end
  end

  #=============================================================================
  # DEALS MODULE - Daily Deals & Weekly Specials (DISABLED)
  #=============================================================================
  # These features are not used in KIFR.
  #=============================================================================
  module Deals
    # Configuration
    DAILY_DEAL_COUNT = 3       # Number of daily deals
    DAILY_DEAL_DISCOUNT = 25   # Discount percentage for daily deals
    
    # Weekly special themes: day_of_week => category that gets discount
    WEEKLY_THEMES = {
      0 => nil,           # Sunday - no special
      1 => "MEDICINE",    # Medicine Monday
      2 => "TMs & HMs",   # TM Tuesday
      3 => nil,           # Wednesday - no special
      4 => nil,           # Thursday - no special
      5 => "POKEBALLS",   # Pokeball Friday
      6 => "BATTLE ITEMS" # Saturday Special
    }.freeze
    
    WEEKLY_DISCOUNT = 15  # Discount for weekly specials
    
    class << self
      def enabled?
        # Daily Deals and Weekly Specials are disabled
        false
      end
      
      # Get today's daily deal items
      def daily_deal_items(stock)
        return [] unless enabled?
        
        # Use daily seed for consistent deals
        rng = Random.new(EconomyMod::Core.daily_seed)
        
        # Get valid items (exclude categories, limited stock items)
        valid_items = Shop::Categories.extract_items(stock).select do |item|
          item.is_a?(Integer) || item.is_a?(Symbol)
        end
        
        return [] if valid_items.empty?
        
        # Pick random items
        valid_items.shuffle(random: rng).first([DAILY_DEAL_COUNT, valid_items.length].min)
      end
      
      # Check if item is a daily deal
      def daily_deal?(item_id, stock)
        daily_deal_items(stock).any? do |item|
          EconomyMod::Core.item_to_id(item) == item_id
        end
      end
      
      # Get daily deal discount for item
      def daily_deal_discount(item_id, stock)
        daily_deal?(item_id, stock) ? DAILY_DEAL_DISCOUNT : 0
      end
      
      # Get today's weekly special category
      def weekly_special_category
        return nil unless enabled?
        WEEKLY_THEMES[EconomyMod::Core.day_of_week]
      end
      
      # Check if item is in weekly special category
      def weekly_special?(item_id, category)
        return false unless enabled?
        special_cat = weekly_special_category
        return false unless special_cat
        category == special_cat
      end
      
      # Get weekly special discount for item
      def weekly_special_discount(item_id, category)
        weekly_special?(item_id, category) ? WEEKLY_DISCOUNT : 0
      end
      
      # Get combined deal discount for an item
      def get_deal_discount(item_id, stock, category = nil)
        return 0 unless enabled?
        
        # Daily deals take priority
        daily = daily_deal_discount(item_id, stock)
        return daily if daily > 0
        
        # Check weekly special
        category ||= Shop::CategoryMultipliers.get_item_category(item_id, stock)
        weekly_special_discount(item_id, category)
      end
      
      # Get deals summary text
      def deals_summary_text(stock)
        lines = []
        
        # Daily deals
        deals = daily_deal_items(stock)
        if deals.any?
          deal_names = deals.map { |d| EconomyMod::Core.item_name(d) }
          lines << _INTL("Daily Deals ({1}% off): {2}", DAILY_DEAL_DISCOUNT, deal_names.join(", "))
        end
        
        # Weekly special
        special = weekly_special_category
        if special
          day = EconomyMod::Core.day_name
          lines << _INTL("{1} Special: {2}% off all {3}!", day, WEEKLY_DISCOUNT, special)
        end
        
        lines.any? ? lines.join("\n") : nil
      end
    end
  end

  #=============================================================================
  # GATING MODULE - Badge/Story-Gated Items
  #=============================================================================
  # Regular Marts only (not Kuray Shop)
  #=============================================================================
  module Gating
    # Configuration: badge_count => array of item IDs that unlock
    BADGE_GATES = {
      # 2 => [:SUPERPOTION, :GREATBALL],
      # 4 => [:HYPERPOTION, :ULTRABALL],
      # 6 => [:MAXPOTION, :MAXREPEL],
      # 8 => [:FULLRESTORE, :MAXREVIVE]
    }.freeze
    
    # Configuration: game_switch_id => array of item IDs that unlock
    STORY_GATES = {
      # 100 => [:MASTERBALL],  # Unlocks after beating Team Rocket
      # 150 => [:SACREDASH]    # Unlocks after legendary event
    }.freeze
    
    class << self
      def enabled?
        return false if EconomyMod::Core.skip_economy_features?
        true
      end
      
      # Get player's badge count
      def badge_count
        return 0 unless $Trainer
        $Trainer.badge_count rescue 0
      end
      
      # Check if a game switch is ON
      def switch_on?(switch_id)
        return false unless $game_switches
        $game_switches[switch_id] rescue false
      end
      
      # Get items unlocked by badges
      def badge_unlocked_items
        return [] unless enabled?
        
        unlocked = []
        BADGE_GATES.each do |badges, items|
          unlocked.concat(items) if badge_count >= badges
        end
        unlocked.map { |i| EconomyMod::Core.item_to_id(i) }
      end
      
      # Get items unlocked by story switches
      def story_unlocked_items
        return [] unless enabled?
        
        unlocked = []
        STORY_GATES.each do |switch_id, items|
          unlocked.concat(items) if switch_on?(switch_id)
        end
        unlocked.map { |i| EconomyMod::Core.item_to_id(i) }
      end
      
      # Check if item is unlocked
      def item_unlocked?(item_id)
        return true unless enabled?
        
        item_id = EconomyMod::Core.item_to_id(item_id)
        
        # Check if item is gated at all
        all_gated = []
        BADGE_GATES.values.each { |items| all_gated.concat(items) }
        STORY_GATES.values.each { |items| all_gated.concat(items) }
        all_gated.map! { |i| EconomyMod::Core.item_to_id(i) }
        
        # If not gated, it's available
        return true unless all_gated.include?(item_id)
        
        # Check if unlocked
        badge_unlocked_items.include?(item_id) || story_unlocked_items.include?(item_id)
      end
      
      # Filter stock to only show unlocked items
      def filter_stock(stock)
        return stock unless enabled?
        
        stock.select do |item|
          if item.is_a?(String) || item.is_a?(Symbol) || (item.is_a?(Hash) && item[:header])
            true  # Keep category headers
          else
            item_unlocked?(item)
          end
        end
      end
      
      # Get text describing what unlocks an item
      def unlock_requirement_text(item_id)
        item_id = EconomyMod::Core.item_to_id(item_id)
        
        BADGE_GATES.each do |badges, items|
          if items.map { |i| EconomyMod::Core.item_to_id(i) }.include?(item_id)
            return _INTL("Unlocks at {1} badges", badges)
          end
        end
        
        STORY_GATES.each do |switch_id, items|
          if items.map { |i| EconomyMod::Core.item_to_id(i) }.include?(item_id)
            return _INTL("Unlocks after story event")
          end
        end
        
        nil
      end
    end
  end

  #=============================================================================
  # SEASONAL MODULE - Event/Seasonal Items
  #=============================================================================
  # Regular Marts only (not Kuray Shop)
  #=============================================================================
  module Seasonal
    # Configuration: { event_name => { months: [1,2], days: [1..14], items: [...] } }
    EVENTS = {
      # christmas: {
      #   months: [12],
      #   days: [1..31],
      #   items: [:RARECANDY, :MASTERBALL],
      #   discount: 20
      # },
      # halloween: {
      #   months: [10],
      #   days: [25..31],
      #   items: [:GHOSTGEM, :DARKGEM],
      #   discount: 15
      # },
      # valentines: {
      #   months: [2],
      #   days: [10..14],
      #   items: [:LOVEBALL],
      #   discount: 25
      # }
    }.freeze
    
    class << self
      def enabled?
        return false if EconomyMod::Core.skip_economy_features?
        true
      end
      
      # Get currently active events
      def active_events
        return [] unless enabled?
        
        now = EconomyMod::Core.current_date
        current_month = now.month
        current_day = now.day
        
        EVENTS.select do |name, config|
          months = config[:months] || []
          days = config[:days] || [1..31]
          
          months.include?(current_month) && days.any? { |d| d === current_day }
        end.keys
      end
      
      # Get seasonal items currently available
      def available_items
        return [] unless enabled?
        
        items = []
        active_events.each do |event_name|
          config = EVENTS[event_name]
          items.concat(config[:items] || [])
        end
        items.uniq.map { |i| EconomyMod::Core.item_to_id(i) }
      end
      
      # Check if item is seasonal
      def seasonal_item?(item_id)
        available_items.include?(EconomyMod::Core.item_to_id(item_id))
      end
      
      # Get seasonal discount for item
      def seasonal_discount(item_id)
        return 0 unless enabled?
        
        item_id = EconomyMod::Core.item_to_id(item_id)
        
        active_events.each do |event_name|
          config = EVENTS[event_name]
          event_items = (config[:items] || []).map { |i| EconomyMod::Core.item_to_id(i) }
          return config[:discount] || 0 if event_items.include?(item_id)
        end
        
        0
      end
      
      # Get seasonal event text
      def event_text
        return nil unless enabled?
        return nil if active_events.empty?
        
        names = active_events.map { |e| e.to_s.capitalize.gsub('_', ' ') }
        _INTL("Active Events: {1}", names.join(", "))
      end
    end
  end

  #=============================================================================
  # CART MODULE - Shopping Cart System
  #=============================================================================
  # Regular Marts only (not Kuray Shop)
  #=============================================================================
  module Cart
    class << self
      def enabled?
        return false if EconomyMod::Core.skip_economy_features?
        true
      end
      
      # Get current cart
      def current
        $game_temp.shop_cart ||= []
      end
      
      # Clear cart
      def clear
        $game_temp.shop_cart = []
      end
      
      # Add item to cart
      def add(item_id, quantity = 1, unit_price = nil)
        return unless enabled?
        
        item_id = EconomyMod::Core.item_to_id(item_id)
        
        # Check if item already in cart
        existing = current.find { |entry| entry[:item] == item_id }
        
        if existing
          existing[:quantity] += quantity
        else
          current << {
            item: item_id,
            quantity: quantity,
            unit_price: unit_price
          }
        end
      end
      
      # Remove item from cart
      def remove(item_id, quantity = nil)
        return unless enabled?
        
        item_id = EconomyMod::Core.item_to_id(item_id)
        
        if quantity.nil?
          current.reject! { |entry| entry[:item] == item_id }
        else
          existing = current.find { |entry| entry[:item] == item_id }
          if existing
            existing[:quantity] -= quantity
            current.reject! { |entry| entry[:quantity] <= 0 }
          end
        end
      end
      
      # Get item count in cart
      def item_count(item_id = nil)
        if item_id
          item_id = EconomyMod::Core.item_to_id(item_id)
          entry = current.find { |e| e[:item] == item_id }
          entry ? entry[:quantity] : 0
        else
          current.sum { |e| e[:quantity] }
        end
      end
      
      # Calculate cart total
      def total(adapter = nil)
        current.sum do |entry|
          price = entry[:unit_price]
          if price.nil? && adapter
            price = adapter.getPrice(entry[:item], false) rescue 0
          end
          (price || 0) * entry[:quantity]
        end
      end
      
      # Apply bulk discounts to cart total
      def total_with_bulk_discount(adapter = nil)
        base_total = total(adapter)
        total_items = item_count
        
        discount = EconomyMod::BulkDiscounts.discount_for_quantity(total_items)
        return base_total if discount <= 0
        
        savings = (base_total * discount / 100.0).round
        base_total - savings
      end
      
      # Checkout - purchase all items in cart
      def checkout(adapter, scene)
        return false unless enabled?
        return false if current.empty?
        
        final_total = total_with_bulk_discount(adapter)
        
        # Check if player can afford
        unless $Trainer.money >= final_total
          scene.pbDisplayPaused(_INTL("You don't have enough money."))
          return false
        end
        
        # Process purchase
        current.each do |entry|
          quantity = entry[:quantity]
          
          # Check bag space
          unless $bag.can_add?(entry[:item], quantity)
            scene.pbDisplayPaused(_INTL("Your Bag is full."))
            return false
          end
          
          # Add to bag
          $bag.add(entry[:item], quantity)
        end
        
        # Deduct money
        $Trainer.money -= final_total
        
        # Show confirmation
        if item_count > 1
          scene.pbDisplayPaused(_INTL("Purchased {1} items for ${2}!", item_count, final_total.to_s_formatted))
        end
        
        # Clear cart
        clear
        true
      end
      
      # Get cart summary text
      def summary_text(adapter = nil)
        return nil if current.empty?
        
        lines = []
        lines << _INTL("Shopping Cart ({1} items):", item_count)
        
        current.each do |entry|
          name = EconomyMod::Core.item_name(entry[:item])
          lines << _INTL("  {1} x{2}", name, entry[:quantity])
        end
        
        base = total(adapter)
        final = total_with_bulk_discount(adapter)
        
        if final < base
          lines << _INTL("Subtotal: ${1}", base.to_s_formatted)
          lines << _INTL("Bulk Discount: -${1}", (base - final).to_s_formatted)
          lines << _INTL("Total: ${1}", final.to_s_formatted)
        else
          lines << _INTL("Total: ${1}", final.to_s_formatted)
        end
        
        lines.join("\n")
      end
    end
  end

  #=============================================================================
  # UI MODULE - Display Features
  #=============================================================================
  # Works in ALL shops (including Kuray Shop for some features)
  #=============================================================================
  module UI
    class << self
      # Check if price color coding is enabled
      def price_colors_enabled?
        return true unless defined?(KIFRSettings)
        KIFRSettings.get(:shop_price_colors, 1) == 1
      end
      
      # Check if sell price display is enabled
      def sell_price_enabled?
        return false unless defined?(KIFRSettings)
        KIFRSettings.get(:shop_sell_price, 0) == 1
      end
      
      # Check if preview panel is enabled
      def preview_panel_mode
        return 0 unless defined?(KIFRSettings)
        KIFRSettings.get(:shop_preview_panel, 0)  # 0=Off, 1=Compact, 2=Full
      end
      
      # Get sort mode
      def sort_mode
        return 0 unless defined?(KIFRSettings)
        KIFRSettings.get(:shop_sort_mode, 0)  # 0=Default, 1=Name, 2=Price↑, 3=Price↓, 4=Type, 5=New
      end
      
      # Get price color based on affordability
      # Returns [base_color, shadow_color]
      def price_color(price, player_money = nil)
        return [nil, nil] unless price_colors_enabled?
        
        player_money ||= $Trainer.money rescue 0
        
        if price <= 0
          # Free item - blue
          [Color.new(64, 160, 255), Color.new(32, 80, 128)]
        elsif price > player_money
          # Can't afford - red
          [Color.new(255, 80, 80), Color.new(128, 40, 40)]
        elsif price > player_money * 0.5
          # Expensive (>50% of money) - yellow
          [Color.new(255, 200, 80), Color.new(128, 100, 40)]
        else
          # Affordable - green
          [Color.new(80, 200, 80), Color.new(40, 100, 40)]
        end
      end
      
      # Sort stock based on current sort mode
      def sort_stock(stock, adapter = nil)
        mode = sort_mode
        return stock if mode == 0  # Default order
        
        # Extract items and headers
        items_with_categories = []
        current_category = nil
        
        stock.each do |item|
          if item.is_a?(String) || item.is_a?(Symbol) || (item.is_a?(Hash) && item[:header])
            current_category = item.is_a?(Hash) ? item[:header] : item.to_s
          else
            items_with_categories << { item: item, category: current_category }
          end
        end
        
        # Sort items
        sorted = case mode
        when 1  # Name A-Z
          items_with_categories.sort_by { |e| EconomyMod::Core.item_name(e[:item]).downcase }
        when 2  # Price Low→High
          items_with_categories.sort_by { |e| adapter ? adapter.getPrice(e[:item], false) : 0 }
        when 3  # Price High→Low
          items_with_categories.sort_by { |e| -(adapter ? adapter.getPrice(e[:item], false) : 0) }
        when 4  # Type (group by category)
          items_with_categories.sort_by { |e| [e[:category] || "", EconomyMod::Core.item_name(e[:item]).downcase] }
        when 5  # New items first (would need tracking)
          items_with_categories  # TODO: Implement new item tracking
        else
          items_with_categories
        end
        
        # Rebuild with categories if sorting by type
        if mode == 4
          result = []
          last_category = nil
          sorted.each do |entry|
            if entry[:category] != last_category
              result << entry[:category] if entry[:category]
              last_category = entry[:category]
            end
            result << entry[:item]
          end
          result
        else
          sorted.map { |e| e[:item] }
        end
      end
    end
  end
end

#===============================================================================
# GAME_TEMP EXTENSIONS - Shop Transient Data
#===============================================================================
class Game_Temp
  attr_accessor :shop_cart
end

#===============================================================================
# GAME_SYSTEM EXTENSIONS - Shop Persistent Data
#===============================================================================
class Game_System
  attr_accessor :shop_stock_data
end

#===============================================================================
# KIFR SETTINGS REGISTRATION
#===============================================================================
begin
  if defined?(KIFRSettings)
    # Initialize defaults
    KIFRSettings.set_default(:shop_price_colors, 1)
    KIFRSettings.set_default(:shop_sell_price, 0)
    KIFRSettings.set_default(:shop_preview_panel, 0)
    KIFRSettings.set_default(:shop_sort_mode, 0)
    
    KIFRSettings.debug_log("Shop: Module loaded - Categories, Stock, Deals, Cart systems ready")
  end
rescue => e
  KIFRSettings.debug_log("Shop: ERROR: Setup failed - #{e.message}") if defined?(KIFRSettings)
end
