#===============================================================================
# KIF Redux Economy - Core Economy Systems
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file contains economy features for REGULAR MARTS (not Kuray Shop):
# - EconomyMod::Core - Shared utilities, time functions
# - EconomyMod::Sale - Random sales (skip Kuray)
# - EconomyMod::Markup - Random markups (skip Kuray)
# - EconomyMod::BulkDiscounts - Buy X get Y% off (skip Kuray)
# - EconomyMod::Pricing - Global multiplier (skip Kuray)
# - EconomyMod::BattleMoney - Trainer payouts
# - EconomyMod::InitialMoney - Starting money
# - EconomyMod::PokeVialCost - PokeVial pricing
#
# Note: These features DO NOT affect Kuray Shop. Kuray Shop has its own
# pricing system in 011a_KIFR_KurayShop.rb
#===============================================================================

module EconomyMod
  #=============================================================================
  # CORE MODULE - Shared Utilities
  #=============================================================================
  module Core
    # Check if we're currently in the Kuray Shop
    # Used to skip economy features that shouldn't affect Kuray
    def self.in_kuray_shop?
      return false unless $game_temp
      $game_temp.respond_to?(:fromkurayshop) && $game_temp.fromkurayshop
    end
    
    # Check if we're in the outfit menu
    def self.in_outfit_menu?
      return false unless $game_temp
      $game_temp.respond_to?(:in_outfit_menu) && $game_temp.in_outfit_menu
    end
    
    # Should we skip economy features? (Kuray Shop or Outfit Menu)
    def self.skip_economy_features?
      in_kuray_shop? || in_outfit_menu?
    end
    
    # Get current time in seconds (game time or real time)
    # Used for sale/markup duration, daily resets, etc.
    def self.current_time_seconds
      # Try game time first
      if defined?(pbGetTimeNow)
        begin
          t = pbGetTimeNow
          return t.to_i if t
        rescue => e
          KIFRSettings.debug_log("EconomyMod::Core: Error getting pbGetTimeNow: #{e.class}") if defined?(KIFRSettings)
        end
      end
      
      # Try play time
      gs = $game_system
      if gs
        if gs.respond_to?(:play_time) && gs.play_time
          return gs.play_time.to_i
        end
        if gs.respond_to?(:playtime) && gs.playtime
          return gs.playtime.to_i
        end
      end
      
      # Fallback to Graphics frame count
      if defined?(Graphics) && Graphics.respond_to?(:frame_count) && Graphics.respond_to?(:frame_rate)
        begin
          return (Graphics.frame_count / Graphics.frame_rate.to_f).to_i
        rescue
        end
      end
      
      # Last resort: real time
      return Time.now.to_i
    end
    
    # Get the current real-world date (for daily resets, seasonal items)
    def self.current_date
      Time.now
    end
    
    # Get a date-based seed for consistent daily randomization
    # Same seed = same results for the whole day
    def self.daily_seed
      date = current_date
      date.year * 10000 + date.month * 100 + date.day
    end
    
    # Get a week-based seed
    def self.weekly_seed
      date = current_date
      date.year * 100 + date.cweek
    end
    
    # Get the current day of week (0 = Sunday, 6 = Saturday)
    def self.day_of_week
      current_date.wday
    end
    
    # Get day name
    def self.day_name
      %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday][day_of_week]
    end
    
    # Convert item to ID (handles symbols, strings, integers)
    def self.item_to_id(item)
      return item if item.is_a?(Integer)
      begin
        return GameData::Item.get(item).id
      rescue
        return item
      end
    end
    
    # Get item name safely
    def self.item_name(item_id)
      begin
        return GameData::Item.get(item_id).name
      rescue
        return item_id.to_s
      end
    end
    
    # Format price for display
    def self.format_price(amount)
      return "FREE" if amount <= 0
      _INTL("₽{1}", amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)
    end
    
    # Log debug message
    def self.debug_log(message)
      KIFRSettings.debug_log("EconomyMod: #{message}") if defined?(KIFRSettings)
    end
  end

  #=============================================================================
  # SALE MODULE - Random Sales at Regular Marts
  #=============================================================================
  module Sale
    # Configuration (can be overridden via hardcoded config)
    SALE_CHANCE_PERCENT = 75          # Chance a sale occurs when entering a mart
    SALE_MIN_PERCENT    = 5           # Minimum sale discount
    SALE_MAX_PERCENT    = 60          # Maximum sale discount
    GLOBAL_VS_SINGLE_PERCENT = 3      # Chance sale is global vs single item
    MULTI_ITEM_PERCENT = 50           # Chance sale is on 2 items instead of 1
    ANNOUNCE_SALE = true              # Show message announcing sale
    SALE_DURATION_HOURS = 5           # How long sale lasts (in-game hours)
    SINGLE_ACTIVE_SALE = true         # Only one sale active at a time
    
    class << self
      # Check if sales are enabled (always on now)
      def enabled?
        return false if EconomyMod::Core.skip_economy_features?
        true
      end
      
      def current_time_seconds
        EconomyMod::Core.current_time_seconds
      end
      
      def sale_duration_seconds
        SALE_DURATION_HOURS * 60 * 60
      end
      
      # Validate and clean up expired sales
      def validate_sale_data!
        begin
          return unless $game_system && $game_system.respond_to?(:mart_sale_data) && $game_system.mart_sale_data
          data = $game_system.mart_sale_data
          st = data[:start_time]
          if st.nil?
            clear_sale
            return
          end
          elapsed = current_time_seconds - st
          if elapsed < 0 || elapsed >= sale_duration_seconds
            clear_sale
          end
        rescue => e
          EconomyMod::Core.debug_log("Error validating sale data: #{e.class} - #{e.message}")
        end
      end
      
      # Start a sale with given parameters
      def start_sale(default_percent = nil, overrides = nil)
        $game_temp.mart_sale_percent ||= {}
        $game_temp.mart_sale_default = default_percent if default_percent
        if overrides
          overrides.each do |k, v|
            id = EconomyMod::Core.item_to_id(k)
            $game_temp.mart_sale_percent[id] = v
          end
        end
        EconomyMod::Core.debug_log("Sale started - Default: #{default_percent}%, Overrides: #{overrides ? overrides.size : 0}")
      end
      
      # Clear active sale
      def clear_sale
        $game_temp.mart_sale_percent = nil if $game_temp.respond_to?(:mart_sale_percent=)
        $game_temp.mart_sale_default = nil if $game_temp.respond_to?(:mart_sale_default=)
        $game_temp.mart_sale_active = false if $game_temp.respond_to?(:mart_sale_active=)
        if $game_system.respond_to?(:mart_sale_data=)
          $game_system.mart_sale_data = nil
        end
        $game_temp.mart_sale_announced = false if $game_temp.respond_to?(:mart_sale_announced=)
        EconomyMod::Core.debug_log("Sale cleared")
      end
      
      # Clear transient sale data (keeps persistent data)
      def clear_transient_sale
        $game_temp.mart_sale_percent = nil if $game_temp.respond_to?(:mart_sale_percent=)
        $game_temp.mart_sale_default = nil if $game_temp.respond_to?(:mart_sale_default=)
        $game_temp.mart_sale_active = false if $game_temp.respond_to?(:mart_sale_active=)
        $game_temp.mart_sale_announced = false if $game_temp.respond_to?(:mart_sale_announced=)
      end
      
      # Get sale percent for a specific item
      def sale_percent_for_item(item_id)
        validate_sale_data!
        return nil unless enabled?
        
        # Check persistent sale data
        if $game_system && $game_system.respond_to?(:mart_sale_data) && $game_system.mart_sale_data
          data = $game_system.mart_sale_data
          if data[:start_time] && (current_time_seconds - data[:start_time] >= sale_duration_seconds)
            clear_sale
            return nil
          end
          per = data[:per_item] || {}
          return per[item_id] if per[item_id]
          return data[:default]
        end
        
        # Check transient data
        if $game_temp && $game_temp.respond_to?(:mart_sale_percent) && $game_temp.mart_sale_percent
          return $game_temp.mart_sale_percent[item_id]
        end
        if $game_temp && $game_temp.respond_to?(:mart_sale_default) && $game_temp.mart_sale_default
          return $game_temp.mart_sale_default
        end
        
        return nil
      end
      
      # Maybe start a sale when entering a mart
      def maybe_start_sale_for_stock(stock)
        validate_sale_data!
        return unless enabled?
        
        # Check for existing active sale
        if SINGLE_ACTIVE_SALE
          if $game_system && $game_system.respond_to?(:mart_sale_data) && $game_system.mart_sale_data
            data = $game_system.mart_sale_data
            if data[:start_time]
              elapsed = current_time_seconds - data[:start_time]
              if elapsed >= 0 && elapsed < sale_duration_seconds
                return data  # Sale still active
              else
                clear_sale
              end
            end
          end
        end
        
        return if $game_temp.respond_to?(:mart_sale_active) && $game_temp.mart_sale_active
        return unless rand(100) < SALE_CHANCE_PERCENT
        
        # Build list of valid item IDs
        ids = stock.map { |it| EconomyMod::Core.item_to_id(it) }.compact.uniq
        return if ids.empty?
        
        per_item = {}
        origin = build_origin_data
        
        if rand(100) < GLOBAL_VS_SINGLE_PERCENT
          # Global sale
          percent = rand(SALE_MIN_PERCENT..SALE_MAX_PERCENT)
          ids.each { |iid| per_item[iid] = percent }
          sale_data = { 
            start_time: current_time_seconds, 
            type: :global, 
            default: percent, 
            per_item: per_item, 
            origin: origin 
          }
        else
          # Single or multi-item sale
          num_items = (rand(100) < MULTI_ITEM_PERCENT && ids.length >= 2) ? 2 : 1
          chosen = ids.sample(num_items)
          
          chosen.each do |item|
            percent = rand(SALE_MIN_PERCENT..SALE_MAX_PERCENT)
            per_item[item] = percent
          end
          
          sale_type = num_items == 2 ? :multi : :single
          sale_data = { 
            start_time: current_time_seconds, 
            type: sale_type, 
            default: nil, 
            per_item: per_item, 
            origin: origin, 
            single_item: (num_items == 1 ? chosen.first : nil),
            multi_items: (num_items == 2 ? chosen : nil)
          }
        end
        
        # Store sale data
        $game_system.mart_sale_data = sale_data if $game_system.respond_to?(:mart_sale_data=)
        $game_temp.mart_sale_percent ||= {}
        $game_temp.mart_sale_start_time = sale_data[:start_time] if $game_temp.respond_to?(:mart_sale_start_time=)
        $game_temp.mart_sale_default = sale_data[:default]
        sale_data[:per_item].each { |k, v| $game_temp.mart_sale_percent[k] = v }
        $game_temp.mart_sale_active = true if $game_temp.respond_to?(:mart_sale_active=)
        
        return sale_data
      end
      
      # Build origin data for tracking where sale started
      def build_origin_data
        origin = nil
        if $game_map.respond_to?(:map_id)
          origin = { map_id: $game_map.map_id }
          if $game_player && $game_player.respond_to?(:x) && $game_player.respond_to?(:y)
            origin[:x] = $game_player.x
            origin[:y] = $game_player.y
          end
        end
        origin
      end
      
      # Get sale header text for display
      def sale_header_for_stock(stock)
        validate_sale_data!
        return nil unless enabled?
        
        if $game_system && $game_system.respond_to?(:mart_sale_data) && $game_system.mart_sale_data
          data = $game_system.mart_sale_data
          per = data[:per_item] || {}
          if data[:type] == :global
            pct = data[:default] || per.values.first
            return sprintf("Sale: %d%% off!", pct) if pct && pct > 0
          elsif data[:type] == :single
            item_id = data[:single_item] || per.keys.first
            pct = per[item_id]
            name = EconomyMod::Core.item_name(item_id)
            return sprintf("Sale: %s %d%% off!", name, pct) if pct && pct > 0
          elsif data[:type] == :multi
            items = data[:multi_items] || per.keys
            if items.length >= 2
              names = items.first(2).map { |iid| EconomyMod::Core.item_name(iid) }
              return sprintf("Sale: %s on sale!", names.join(' & '))
            end
          end
        end
        
        # Fallback to transient data
        if $game_temp && $game_temp.respond_to?(:mart_sale_percent) && $game_temp.mart_sale_percent && $game_temp.mart_sale_percent.any?
          keys = $game_temp.mart_sale_percent.keys
          if keys.length == 1
            item_id = keys.first
            pct = $game_temp.mart_sale_percent[item_id]
            name = EconomyMod::Core.item_name(item_id)
            return sprintf("Sale: %s %d%% off!", name, pct) if pct && pct > 0
          else
            names = keys.first(2).map { |k| EconomyMod::Core.item_name(k) }
            pct = $game_temp.mart_sale_default || $game_temp.mart_sale_percent[keys.first]
            return sprintf("Sale: %s %d%% off!", names.join('/'), pct) if pct && pct > 0
          end
        end
        
        if $game_temp && $game_temp.respond_to?(:mart_sale_default) && $game_temp.mart_sale_default
          pct = $game_temp.mart_sale_default
          return sprintf("Sale: %d%% off!", pct) if pct && pct > 0
        end
        
        return nil
      end
      
      # Get detailed sale information
      def sale_details_for_stock(stock)
        validate_sale_data!
        return nil unless enabled?
        
        lines = []
        
        if $game_system && $game_system.respond_to?(:mart_sale_data) && $game_system.mart_sale_data
          data = $game_system.mart_sale_data
          if data[:type] == :global
            pct = data[:default] || (data[:per_item] && data[:per_item].values.first)
            lines << _INTL("Sales: Everything in this shop is {1}% off!", pct)
            sample = stock.first(6).map { |iid| EconomyMod::Core.item_name(iid) }
            lines << _INTL("Examples: {1}", sample.join(', ')) if sample && sample.any?
          elsif data[:type] == :single
            per = data[:per_item] || {}
            item_id = data[:single_item] || per.keys.first
            pct = per[item_id]
            name = EconomyMod::Core.item_name(item_id)
            lines << _INTL("Sales: {1} is {2}% off!", name, pct)
          elsif data[:type] == :multi
            per = data[:per_item] || {}
            items = data[:multi_items] || per.keys
            items.each do |item_id|
              pct = per[item_id]
              name = EconomyMod::Core.item_name(item_id)
              lines << _INTL("{1} is {2}% off!", name, pct) if pct
            end
          end
          
          # Add time remaining
          lines << get_time_remaining_text(data[:start_time], sale_duration_seconds)
        end
        
        return lines.any? ? lines.join("\n") : nil
      end
      
      def get_time_remaining_text(start_time, duration_seconds)
        return nil unless start_time
        rem = duration_seconds - (current_time_seconds - start_time)
        return nil if rem <= 0
        
        hrs = rem / 3600
        mins = (rem % 3600) / 60
        if hrs > 0
          return _INTL("Time left: {1}h {2}m", hrs, mins)
        else
          return _INTL("Time left: {1}m", mins)
        end
      end
    end
  end
  #=============================================================================
  # MARKUP MODULE - Random Price Increases at Regular Marts
  #=============================================================================
  # Markups are the opposite of sales - they increase prices.
  # Never stacks with sales: if item is on sale, markup won't apply.
  #=============================================================================
  module Markup
    # Configuration
    CHANCE_PERCENT = 50            # Chance a markup occurs when entering a mart
    MIN_PERCENT    = 5             # Minimum markup percent
    MAX_PERCENT    = 60            # Maximum markup percent
    GLOBAL_VS_SINGLE_PERCENT = 0   # Chance markup is global vs single item
    MULTI_ITEM_PERCENT = 50        # Chance markup is on 2 items instead of 1
    DURATION_HOURS = 5             # How long markup lasts (in-game hours)
    SINGLE_ACTIVE_MARKUP = true    # Only one markup active at a time
    
    class << self
      def enabled?
        return false if EconomyMod::Core.skip_economy_features?
        true
      end
      
      def current_time_seconds
        EconomyMod::Core.current_time_seconds
      end
      
      def duration_seconds
        DURATION_HOURS * 60 * 60
      end
      
      def validate_markup_data!
        begin
          return unless $game_system && $game_system.respond_to?(:mart_markup_data) && $game_system.mart_markup_data
          data = $game_system.mart_markup_data
          st = data[:start_time]
          if st.nil?
            clear_markup
            return
          end
          elapsed = current_time_seconds - st
          if elapsed < 0 || elapsed >= duration_seconds
            clear_markup
          end
        rescue => e
          EconomyMod::Core.debug_log("Error validating markup data: #{e.class} - #{e.message}")
        end
      end
      
      def clear_markup
        $game_temp.mart_markup_percent = nil if $game_temp.respond_to?(:mart_markup_percent=)
        $game_temp.mart_markup_default = nil if $game_temp.respond_to?(:mart_markup_default=)
        $game_temp.mart_markup_active = false if $game_temp.respond_to?(:mart_markup_active=)
        $game_system.mart_markup_data = nil if $game_system.respond_to?(:mart_markup_data=)
        EconomyMod::Core.debug_log("Markup cleared")
      end
      
      def clear_transient_markup
        $game_temp.mart_markup_percent = nil if $game_temp.respond_to?(:mart_markup_percent=)
        $game_temp.mart_markup_default = nil if $game_temp.respond_to?(:mart_markup_default=)
        $game_temp.mart_markup_active = false if $game_temp.respond_to?(:mart_markup_active=)
      end
      
      # Get markup percent for item (returns nil if on sale)
      def percent_for_item(item_id)
        validate_markup_data!
        return nil unless enabled?
        
        # Never markup items that are on sale
        begin
          sale_pct = EconomyMod::Sale.sale_percent_for_item(item_id)
          return nil if sale_pct && sale_pct > 0
        rescue
        end
        
        # Check persistent data
        if $game_system && $game_system.respond_to?(:mart_markup_data) && $game_system.mart_markup_data
          data = $game_system.mart_markup_data
          if data[:start_time] && (current_time_seconds - data[:start_time] >= duration_seconds)
            clear_markup
            return nil
          end
          per = data[:per_item] || {}
          return per[item_id] if per[item_id]
          return data[:default]
        end
        
        # Check transient data
        if $game_temp && $game_temp.respond_to?(:mart_markup_percent) && $game_temp.mart_markup_percent
          return $game_temp.mart_markup_percent[item_id]
        end
        if $game_temp && $game_temp.respond_to?(:mart_markup_default) && $game_temp.mart_markup_default
          return $game_temp.mart_markup_default
        end
        
        return nil
      end
      
      # Maybe start a markup when entering a mart
      def maybe_start_markup_for_stock(stock)
        validate_markup_data!
        return unless enabled?
        
        # Check for existing active markup
        if SINGLE_ACTIVE_MARKUP
          if $game_system && $game_system.respond_to?(:mart_markup_data) && $game_system.mart_markup_data
            data = $game_system.mart_markup_data
            if data[:start_time]
              elapsed = current_time_seconds - data[:start_time]
              if elapsed >= 0 && elapsed < duration_seconds
                return data
              else
                clear_markup
              end
            end
          end
        end
        
        return if $game_temp.respond_to?(:mart_markup_active) && $game_temp.mart_markup_active
        return unless rand(100) < CHANCE_PERCENT
        
        ids = stock.map { |it| EconomyMod::Core.item_to_id(it) }.compact.uniq
        return if ids.empty?
        
        per_item = {}
        origin = EconomyMod::Sale.build_origin_data
        
        if rand(100) < GLOBAL_VS_SINGLE_PERCENT
          # Global markup
          percent = rand(MIN_PERCENT..MAX_PERCENT)
          ids.each { |iid| per_item[iid] = percent }
          markup_data = { 
            start_time: current_time_seconds, 
            type: :global, 
            default: percent, 
            per_item: per_item, 
            origin: origin 
          }
        else
          # Single or multi-item markup
          num_items = (rand(100) < MULTI_ITEM_PERCENT && ids.length >= 2) ? 2 : 1
          chosen = ids.sample(num_items)
          chosen.each do |item|
            percent = rand(MIN_PERCENT..MAX_PERCENT)
            per_item[item] = percent
          end
          
          markup_type = (num_items == 2) ? :multi : :single
          markup_data = {
            start_time: current_time_seconds,
            type: markup_type,
            default: nil,
            per_item: per_item,
            origin: origin,
            single_item: (num_items == 1 ? chosen.first : nil),
            multi_items: (num_items == 2 ? chosen : nil)
          }
        end
        
        # Store markup data
        $game_system.mart_markup_data = markup_data if $game_system.respond_to?(:mart_markup_data=)
        $game_temp.mart_markup_percent ||= {}
        $game_temp.mart_markup_default = markup_data[:default] if $game_temp.respond_to?(:mart_markup_default=)
        markup_data[:per_item].each { |k, v| $game_temp.mart_markup_percent[k] = v }
        $game_temp.mart_markup_active = true if $game_temp.respond_to?(:mart_markup_active=)
        
        return markup_data
      end
      
      def markup_header_for_stock(stock)
        validate_markup_data!
        return nil unless enabled?
        
        begin
          data = ($game_system && $game_system.respond_to?(:mart_markup_data)) ? $game_system.mart_markup_data : nil
          return nil unless data
          per = data[:per_item] || {}
          if data[:type] == :global
            pct = data[:default] || per.values.first
            return sprintf("Markup: +%d%% on all items", pct) if pct && pct > 0
          elsif data[:type] == :single
            item_id = data[:single_item] || per.keys.first
            pct = per[item_id]
            name = EconomyMod::Core.item_name(item_id)
            return sprintf("Markup: %s +%d%%", name, pct) if pct && pct > 0
          elsif data[:type] == :multi
            items = data[:multi_items] || per.keys
            if items && items.length >= 2
              names = items.first(2).map { |iid| EconomyMod::Core.item_name(iid) }
              return sprintf("Markup: %s are marked up", names.join(' & '))
            end
          end
        rescue
        end
        return nil
      end
      
      def markup_details_for_stock(stock)
        validate_markup_data!
        return nil unless enabled?
        
        lines = []
        begin
          data = ($game_system && $game_system.respond_to?(:mart_markup_data)) ? $game_system.mart_markup_data : nil
          return nil unless data
          if data[:type] == :global
            pct = data[:default] || (data[:per_item] && data[:per_item].values.first)
            lines << _INTL("Markups: Everything in this shop costs +{1}% more.", pct)
            sample = stock.first(6).map { |iid| EconomyMod::Core.item_name(iid) }
            lines << _INTL("Examples: {1}", sample.join(', ')) if sample && sample.any?
          elsif data[:type] == :single
            per = data[:per_item] || {}
            item_id = data[:single_item] || per.keys.first
            pct = per[item_id]
            name = EconomyMod::Core.item_name(item_id)
            lines << _INTL("Markups: {1} costs +{2}% more.", name, pct)
          elsif data[:type] == :multi
            per = data[:per_item] || {}
            items = data[:multi_items] || per.keys
            items.each do |item_id|
              pct = per[item_id]
              name = EconomyMod::Core.item_name(item_id)
              lines << _INTL("{1} costs +{2}% more.", name, pct) if pct
            end
          end
          
          # Add time remaining
          time_text = EconomyMod::Sale.get_time_remaining_text(data[:start_time], duration_seconds)
          lines << time_text if time_text
        rescue
        end
        
        return lines.any? ? lines.join("\n") : nil
      end
    end
  end

  #=============================================================================
  # BULK DISCOUNTS MODULE - Quantity-Based Discounts
  #=============================================================================
  module BulkDiscounts
    # Configuration: quantity => discount percent
    THRESHOLDS = {
      10 => 5,   # 5% off when buying 10+
      25 => 10,  # 10% off when buying 25+
      50 => 15   # 15% off when buying 50+
    }
    
    class << self
      def enabled?
        return false if EconomyMod::Core.skip_economy_features?
        true  # Always enabled, no setting to toggle
      end
      
      # Get discount percent for a quantity
      def discount_for_quantity(quantity)
        return 0 unless enabled?
        return 0 if quantity < THRESHOLDS.keys.min
        
        # Find highest applicable threshold
        applicable = THRESHOLDS.select { |q, _| quantity >= q }
        return 0 if applicable.empty?
        
        applicable.max_by { |q, _| q }[1]
      end
      
      # Calculate discounted total price
      def calculate_bulk_price(unit_price, quantity)
        return unit_price * quantity unless enabled?
        
        discount = discount_for_quantity(quantity)
        total = unit_price * quantity
        
        if discount > 0
          savings = (total * discount / 100.0).round
          total - savings
        else
          total
        end
      end
      
      # Get discount text for display
      def discount_text(quantity)
        discount = discount_for_quantity(quantity)
        return nil if discount <= 0
        _INTL("Bulk discount: {1}% off!", discount)
      end
    end
  end

  #=============================================================================
  # PRICING MODULE - Global Price Multiplier
  #=============================================================================
  module Pricing
    class << self
      def enabled?
        return false if EconomyMod::Core.skip_economy_features?
        true
      end
      
      # Get global price multiplier from settings
      def global_multiplier
        return 1.0 unless enabled?
        return 1.0 unless defined?(KIFRSettings)
        
        # Stored as integer (10 = 1.0x, 15 = 1.5x, etc.)
        raw = KIFRSettings.get(:economymod_global_multiplier, 10)
        raw / 10.0
      end
      
      # Apply global multiplier to a price
      def apply_global_multiplier(price)
        return price unless enabled?
        return price if price <= 0
        
        mult = global_multiplier
        return price if mult == 1.0
        
        [(price * mult).round, 1].max
      end
      
      # Get final adjusted price for an item (applies all modifiers)
      # Order: Base -> Sale/Markup -> Dynamic -> Global Multiplier
      def get_final_price(item_id, base_price, selling = false)
        return base_price if selling  # No modifiers when selling
        return base_price unless enabled?
        return base_price if base_price <= 0
        
        price = base_price
        
        # Apply sale discount
        sale_pct = EconomyMod::Sale.sale_percent_for_item(item_id)
        if sale_pct && sale_pct > 0
          price = price - (price * sale_pct / 100.0).round
        else
          # Apply markup (only if no sale)
          markup_pct = EconomyMod::Markup.percent_for_item(item_id)
          if markup_pct && markup_pct > 0
            price = price + (price * markup_pct / 100.0).round
          end
        end
        
        # Apply global multiplier
        price = apply_global_multiplier(price)
        
        [price, 1].max
      end
    end
  end

  #=============================================================================
  # BATTLE MONEY MODULE - Trainer Battle Payouts
  #=============================================================================
  module BattleMoney
    DEFAULT_MULTIPLIER = 1.0
    
    class << self
      def enabled?
        return false unless defined?(KIFRSettings)
        KIFRSettings.get(:economymod_battle_money_enabled, 0) == 1
      end
      
      def multiplier
        return DEFAULT_MULTIPLIER unless enabled?
        return DEFAULT_MULTIPLIER unless defined?(KIFRSettings)
        
        KIFRSettings.get(:economymod_battle_money_multiplier, 1) || DEFAULT_MULTIPLIER
      end
      
      # Apply multiplier to battle winnings
      def adjust_winnings(base_amount)
        return base_amount unless enabled?
        
        mult = multiplier
        return base_amount if mult == 1
        
        [(base_amount * mult).round, 1].max
      end
    end
  end

  #=============================================================================
  # INITIAL MONEY MODULE - Starting Money
  #=============================================================================
  module InitialMoney
    DEFAULT_STARTING_MONEY = 3000
    
    class << self
      def enabled?
        return true unless defined?(KIFRSettings)
        KIFRSettings.get(:economymod_starting_money_enabled, 1) == 1
      end
      
      def starting_money
        return DEFAULT_STARTING_MONEY unless enabled?
        return DEFAULT_STARTING_MONEY unless defined?(KIFRSettings)
        
        amount = KIFRSettings.get(:economymod_starting_money, DEFAULT_STARTING_MONEY)
        amount && amount > 0 ? amount : DEFAULT_STARTING_MONEY
      end
    end
  end

  #=============================================================================
  # POKEVIAL COST MODULE - PokeVial Usage Cost
  #=============================================================================
  module PokeVialCost
    DEFAULT_COST = 500
    
    class << self
      def enabled?
        return true unless defined?(KIFRSettings)
        KIFRSettings.get(:economymod_pokevial_cost_enabled, 1) == 1
      end
      
      def cost
        return DEFAULT_COST unless enabled?
        return DEFAULT_COST unless defined?(KIFRSettings)
        
        KIFRSettings.get(:economymod_pokevial_cost, DEFAULT_COST) || DEFAULT_COST
      end
      
      # Check if player can afford to use PokeVial
      def can_afford?
        return true unless enabled?
        $Trainer.money >= cost
      end
      
      # Deduct cost for using PokeVial
      def charge!
        return true unless enabled?
        return false unless can_afford?
        
        $Trainer.money -= cost
        EconomyMod::Core.debug_log("PokeVial charged: #{cost}")
        true
      end
    end
  end
end

#===============================================================================
# GAME_TEMP EXTENSIONS - Transient Economy Data
#===============================================================================
class Game_Temp
  # Sale data
  attr_accessor :mart_sale_percent
  attr_accessor :mart_sale_default
  attr_accessor :mart_sale_active
  attr_accessor :mart_sale_announced
  attr_accessor :mart_sale_start_time
  attr_accessor :mart_sale_details_open
  
  # Markup data
  attr_accessor :mart_markup_percent
  attr_accessor :mart_markup_default
  attr_accessor :mart_markup_active
  
  # Shop context
  attr_accessor :fromkurayshop
  attr_accessor :in_outfit_menu
end

#===============================================================================
# GAME_SYSTEM EXTENSIONS - Persistent Economy Data
#===============================================================================
class Game_System
  attr_accessor :mart_sale_data
  attr_accessor :mart_markup_data
end

#===============================================================================
# POKEMONMARTADAPTER HOOKS - Apply Pricing to Shops
#===============================================================================
if defined?(PokemonMartAdapter)
  class PokemonMartAdapter
    unless method_defined?(:kifr_economy_orig_getPrice)
      alias :kifr_economy_orig_getPrice :getPrice
    end
    
    # Override getPrice to apply economy modifiers
    def getPrice(item, selling = false)
      base_price = kifr_economy_orig_getPrice(item, selling)
      
      # Don't modify if in Kuray Shop or outfit menu
      return base_price if EconomyMod::Core.skip_economy_features?
      
      # Don't modify sell prices or free items
      return base_price if selling || base_price <= 0
      
      # Get item ID
      item_id = EconomyMod::Core.item_to_id(item)
      
      # Apply all economy modifiers
      EconomyMod::Pricing.get_final_price(item_id, base_price, selling)
    end
    
    # Get base price without economy modifiers (for display comparison)
    def getBasePriceWithoutModifiers(item, selling = false)
      kifr_economy_orig_getPrice(item, selling)
    end
  end
end

#===============================================================================
# POKEMONMARTSCREEN HOOKS - Trigger Sales/Markups on Shop Open
#===============================================================================
if defined?(PokemonMartScreen)
  class PokemonMartScreen
    unless method_defined?(:kifr_economy_orig_pbBuyScreen)
      alias :kifr_economy_orig_pbBuyScreen :pbBuyScreen
    end
    
    def pbBuyScreen
      # Skip economy features for Kuray Shop
      unless EconomyMod::Core.skip_economy_features?
        # Maybe start a sale or markup
        EconomyMod::Sale.maybe_start_sale_for_stock(@stock) if EconomyMod::Sale.enabled?
        EconomyMod::Markup.maybe_start_markup_for_stock(@stock) if EconomyMod::Markup.enabled?
      end
      
      kifr_economy_orig_pbBuyScreen
    end
  end
end

#===============================================================================
# ECONOMY SPECIALS PAGE - Add as first category in shop
#===============================================================================
module EconomyMod
  module SpecialsPage
    # Get items that are on sale or have markups
    # Uses new KIFR::Shop::Specials system
    # Returns SALE items first, then MARKUP items (sorted order)
    def self.get_specials_items(stock)
      return [] unless defined?(KIFR::Shop::Specials)
      return [] unless KIFR::Shop::Specials.has_active_special?
      
      # Get sale items first, then markup items (separate so sales appear first)
      sale_items = KIFR::Shop::Specials.get_sale_items
      markup_items = KIFR::Shop::Specials.get_markup_items
      
      # Filter to items in stock, keeping sales first
      result = []
      sale_items.each { |item| result << item if stock.include?(item) }
      markup_items.each { |item| result << item if stock.include?(item) && !result.include?(item) }
      
      result
    end
    
    # Check if there are any specials
    def self.has_specials?(stock)
      return false if EconomyMod::Core.skip_economy_features?
      get_specials_items(stock).any?
    end
  end
end

#===============================================================================
# Hook into EnhancedMart to add Specials category
#===============================================================================
if defined?(EnhancedMart)
  module EnhancedMart
    # Add Specials category constant
    SPECIALS_POCKET_ID = 99
    
    class << self
      unless method_defined?(:kifr_economy_orig_categorize_stock)
        alias :kifr_economy_orig_categorize_stock :categorize_stock
      end
      
      def categorize_stock(stock, adapter)
        categorized, sorted_categories = kifr_economy_orig_categorize_stock(stock, adapter)
        
        # Add Specials category if there are sales/markups
        begin
          skip = EconomyMod::Core.skip_economy_features?
        rescue
          skip = true
        end
        
        unless skip
          specials = EconomyMod::SpecialsPage.get_specials_items(stock) rescue []
          if specials.any?
            categorized[SPECIALS_POCKET_ID] = specials
            # Insert Specials at the BEGINNING (page 1)
            sorted_categories.unshift(SPECIALS_POCKET_ID)
          end
        end
        
        return categorized, sorted_categories
      end
      
      unless method_defined?(:kifr_economy_orig_category_name)
        alias :kifr_economy_orig_category_name :category_name
      end
      
      def category_name(pocket)
        return "Specials" if pocket == SPECIALS_POCKET_ID
        kifr_economy_orig_category_name(pocket)
      end
    end
  end
end

#===============================================================================
# WINDOW_POKEMONMART HOOKS - Sale/Markup Price Display
#===============================================================================
if defined?(Window_PokemonMart)
  class Window_PokemonMart
    unless method_defined?(:kifr_economy_orig_drawItem)
      alias :kifr_economy_orig_drawItem :drawItem
    end
    
    def drawItem(index, count, rect)
      # Use original draw for Kuray Shop or outfit menu
      if EconomyMod::Core.skip_economy_features?
        return kifr_economy_orig_drawItem(index, count, rect)
      end
      
      textpos = []
      rect = drawCursor(index, rect)
      ypos = rect.y
      
      # No more CANCEL button - all items are real stock
      # If index is beyond stock, skip
      return if index >= @stock.length
      
      item = @stock[index]
      
      # Handle Outfit items (not regular item Symbols)
      if defined?(Outfit) && item.is_a?(Outfit)
        return kifr_economy_orig_drawItem(index, count, rect)
      end
      
      # Skip non-symbol items (shouldn't happen but just in case)
      unless item.is_a?(Symbol)
        return kifr_economy_orig_drawItem(index, count, rect)
      end
      
      itemname = @adapter.getDisplayName(item) rescue ""
      
      # Get the real adapter (BuyAdapter wraps the actual PokemonMartAdapter)
      real_adapter = @adapter.respond_to?(:getAdapter) ? @adapter.getAdapter : @adapter
      
      # Get base price (without modifiers)
      base_price = nil
      if real_adapter.respond_to?(:getBasePriceWithoutModifiers)
        base_price = real_adapter.getBasePriceWithoutModifiers(item, false)
      else
        begin
          base_price = GameData::Item.get(item).price
        rescue
          base_price = nil
        end
      end
      
      # Get current (modified) price
      sale_price = real_adapter.respond_to?(:getPrice) ? real_adapter.getPrice(item, false) : nil
      
      # Check if item has an active sale or markup (these are what should color the price)
      has_sale = EconomyMod::Sale.sale_percent_for_item(item).to_i > 0 rescue false
      has_markup = EconomyMod::Markup.percent_for_item(item).to_i > 0 rescue false
      has_special = has_sale || has_markup
      
      # If no special active or can't determine prices, use normal coloring
      if sale_price.nil? || base_price.nil? || base_price <= 0 || !has_special
        qty = @adapter.getDisplayPrice(item) rescue _INTL("₽ {1}", (sale_price || 0).to_s_formatted)
        sizeQty = self.contents.text_size(qty).width
        xQty = rect.x + rect.width - sizeQty - 2 - 16 + 9
        textpos.push([itemname, rect.x + 9, ypos - 4, false, self.baseColor, self.shadowColor])
        textpos.push([qty, xQty, ypos - 4, false, self.baseColor, self.shadowColor])
        pbDrawTextPositions(self.contents, textpos)
        return
      end
      
      # Determine colors based on sale vs markup (only reach here if has_special is true)
      if has_sale
        # SALE - use green
        priceBase = defined?(COLOR_THEMES) ? COLOR_THEMES[:green][:base] : Color.new(120, 200, 120)
        priceShadow = defined?(COLOR_THEMES) ? COLOR_THEMES[:green][:shadow] : Color.new(44, 76, 44)
      else
        # MARKUP - use red
        priceBase = defined?(COLOR_THEMES) ? COLOR_THEMES[:red][:base] : Color.new(240, 120, 120)
        priceShadow = defined?(COLOR_THEMES) ? COLOR_THEMES[:red][:shadow] : Color.new(92, 44, 44)
      end
      
      # Check if we're on the Specials page
      is_specials = @is_specials_page rescue false
      
      if is_specials
        # SPECIALS PAGE: Show "{Old Price} > {New Price}" format (no strikethrough)
        # Detect if item was currency-converted (e.g., PokeDollars -> BP)
        # In that case, show original currency for old price, new currency for new price
        
        # Get the current (possibly converted) currency for this item
        current_currency_sym = "₽"
        original_currency_sym = "₽"
        is_converted = false
        
        # Check if item has been converted to a different currency
        if real_adapter.respond_to?(:get_item_currency)
          item_currency = real_adapter.get_item_currency(item)
          if item_currency && item_currency != :money
            # Item was converted - new price uses converted currency
            current_currency_sym = KIFR::Currency.safe_symbol(item_currency) rescue item_currency.to_s.upcase
            original_currency_sym = "₽"  # Original was always PokeDollars
            is_converted = true
          elsif real_adapter.respond_to?(:getCurrencySymbol)
            # Not converted - use shop's currency
            current_currency_sym = real_adapter.getCurrencySymbol
            original_currency_sym = current_currency_sym
          end
        elsif real_adapter.respond_to?(:getCurrencySymbol)
          current_currency_sym = real_adapter.getCurrencySymbol
          original_currency_sym = current_currency_sym
        elsif real_adapter.respond_to?(:currency_id)
          current_currency_sym = KIFR::Currency.symbol(real_adapter.currency_id) rescue "₽"
          original_currency_sym = current_currency_sym
        end
        
        old_text = _INTL("{1}{2}", original_currency_sym, base_price.to_s_formatted)
        new_text = _INTL("{1}{2}", current_currency_sym, sale_price.to_s_formatted)
        arrow_text = " > "
        
        # Calculate total width for right alignment (+9 pixels right)
        full_price_text = old_text + arrow_text + new_text
        full_width = self.contents.text_size(full_price_text).width
        xStart = rect.x + rect.width - full_width - 2 - 16 + 9
        
        # Draw item name (+9 pixels right)
        textpos.push([itemname, rect.x + 9, ypos - 4, false, self.baseColor, self.shadowColor])
        
        # Draw old price (normal color)
        textpos.push([old_text, xStart, ypos - 4, false, self.baseColor, self.shadowColor])
        xArrow = xStart + self.contents.text_size(old_text).width
        
        # Draw arrow (normal color)
        textpos.push([arrow_text, xArrow, ypos - 4, false, self.baseColor, self.shadowColor])
        xNew = xArrow + self.contents.text_size(arrow_text).width
        
        # Draw new price (colored)
        textpos.push([new_text, xNew, ypos - 4, false, priceBase, priceShadow])
        
        pbDrawTextPositions(self.contents, textpos)
      else
        # REGULAR PAGE: Just show colored price (+9 pixels right)
        qty = @adapter.getDisplayPrice(item) rescue _INTL("₽ {1}", sale_price.to_s_formatted)
        sizeQty = self.contents.text_size(qty).width
        xQty = rect.x + rect.width - sizeQty - 2 - 16 + 9
        
        textpos.push([itemname, rect.x + 9, ypos - 4, false, self.baseColor, self.shadowColor])
        textpos.push([qty, xQty, ypos - 4, false, priceBase, priceShadow])
        pbDrawTextPositions(self.contents, textpos)
      end
    end
  end
end

#===============================================================================
# POKEMONMART_SCENE HOOKS - Special Info Display on Button Press
#===============================================================================
if defined?(PokemonMart_Scene)
  class PokemonMart_Scene
    unless method_defined?(:kifr_economy_orig_update)
      alias :kifr_economy_orig_update :update
    end

    def update
      kifr_economy_orig_update

      begin
        # Skip for Kuray Shop
        return if EconomyMod::Core.skip_economy_features?
        
        iw = @sprites && @sprites["itemwindow"]
        if iw && iw.visible
          # Show special info on AUX2 (usually S key)
          if Input.trigger?(Input::AUX2)
            return if $game_temp.respond_to?(:mart_sale_details_open) && $game_temp.mart_sale_details_open
            
            # Use new KIFR::Shop::Specials info window
            if defined?(KIFR::Shop::Specials)
              begin
                $game_temp.mart_sale_details_open = true if $game_temp.respond_to?(:mart_sale_details_open=)
                # Show the centered info window (handles both active and no specials)
                KIFR::Shop::Specials.show_info_window(@viewport)
              rescue StandardError => e
                EconomyMod::Core.debug_log("Error showing specials: #{e.message}")
                pbMessage(_INTL("Error displaying specials info."))
              ensure
                $game_temp.mart_sale_details_open = false if $game_temp.respond_to?(:mart_sale_details_open=)
              end
              pbRefresh
            else
              # KIFR::Shop::Specials not defined - show fallback message
              pbPlayCancelSE
              pbMessage(_INTL("Specials system not loaded."))
            end
          end
        end
      rescue StandardError => e
        EconomyMod::Core.debug_log("Error in mart scene update: #{e.message}")
      end
    end
  end
end

#===============================================================================
# BATTLE MONEY HOOK - Apply Multiplier to Trainer Winnings
#===============================================================================
# Hooks into PokeBattle_Battle#pbGainMoney to apply the battle money multiplier
begin
  if defined?(PokeBattle_Battle)
    class PokeBattle_Battle
      unless method_defined?(:kifr_economy_orig_pbGainMoney)
        alias_method :kifr_economy_orig_pbGainMoney, :pbGainMoney
      end
      
      def pbGainMoney
        # If battle money multiplier is not enabled, use original
        unless EconomyMod::BattleMoney.enabled?
          return kifr_economy_orig_pbGainMoney
        end
        
        # Skip if not internal battle or no money gain
        return if !@internalBattle || !@moneyGain
        
        # Skip if no money lost setting is active
        if $PokemonSystem.respond_to?(:nomoneylost) && $PokemonSystem.nomoneylost && $PokemonSystem.nomoneylost != 0
          $PokemonSystem.nomoneylost = 0
          return
        end
        
        # Skip if rematch (if that switch exists)
        return if defined?(SWITCH_IS_REMATCH) && $game_switches[SWITCH_IS_REMATCH]
        
        battle_mult = EconomyMod::BattleMoney.multiplier
        
        # Trainer prize money
        if trainerBattle?
          tMoney = 0
          @opponent.each_with_index do |t, i|
            tMoney += pbMaxLevelInTeam(1, i) * t.base_money
          end
          tMoney *= 2 if @field.effects[PBEffects::AmuletCoin]
          tMoney *= 2 if @field.effects[PBEffects::HappyHour]
          tMoney = (tMoney * battle_mult).round if battle_mult && battle_mult > 0
          oldMoney = pbPlayer.money
          pbPlayer.money += tMoney
          moneyGained = pbPlayer.money - oldMoney
          if moneyGained > 0
            pbDisplayPaused(_INTL("You got ${1} for winning!", moneyGained.to_s_formatted))
          end
        end
        
        # Pay Day pickup
        if @field.effects[PBEffects::PayDay] > 0
          payMoney = @field.effects[PBEffects::PayDay]
          payMoney *= 2 if @field.effects[PBEffects::AmuletCoin]
          payMoney *= 2 if @field.effects[PBEffects::HappyHour]
          payMoney = (payMoney * battle_mult).round if battle_mult && battle_mult > 0
          oldMoney = pbPlayer.money
          pbPlayer.money += payMoney
          moneyGained = pbPlayer.money - oldMoney
          if moneyGained > 0
            pbDisplayPaused(_INTL("You picked up ${1}!", moneyGained.to_s_formatted))
          end
        end
      end
    end
  end
rescue => e
  KIFRSettings.debug_log("EconomyMod: Battle money hook failed - #{e.message}") if defined?(KIFRSettings)
end

#===============================================================================
# INITIAL MONEY HOOK - Set Starting Money on New Game
#===============================================================================
# Hooks into PokemonLoadScreen#pbStartNewGame and Game.start_new
begin
  if defined?(PokemonLoadScreen)
    module EconomyMod_NewGameOverride
      def pbStartNewGame
        super
        begin
          if defined?(EconomyMod) && EconomyMod::InitialMoney.enabled?
            starting_money = EconomyMod::InitialMoney.starting_money
            if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:money=)
              $Trainer.money = starting_money
              KIFRSettings.debug_log("EconomyMod: Set starting money to #{starting_money}") if defined?(KIFRSettings)
            end
          end
        rescue => e
          KIFRSettings.debug_log("EconomyMod: Starting money failed - #{e.message}") if defined?(KIFRSettings)
        end
      end
    end
    
    class PokemonLoadScreen
      prepend EconomyMod_NewGameOverride
    end
  end
rescue => e
  KIFRSettings.debug_log("EconomyMod: PokemonLoadScreen hook failed - #{e.message}") if defined?(KIFRSettings)
end

# Also hook into Game.start_new for additional coverage
begin
  if defined?(Game)
    module Game
      class << self
        unless method_defined?(:kifr_economy_orig_start_new)
          alias_method :kifr_economy_orig_start_new, :start_new
        end
        
        def start_new(*args)
          kifr_economy_orig_start_new(*args)
          begin
            if defined?(EconomyMod) && EconomyMod::InitialMoney.enabled?
              starting_money = EconomyMod::InitialMoney.starting_money
              if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:money=)
                $Trainer.money = starting_money
                KIFRSettings.debug_log("EconomyMod: Set starting money to #{starting_money} (Game.start_new)") if defined?(KIFRSettings)
              end
            end
          rescue => e
            KIFRSettings.debug_log("EconomyMod: Game.start_new money failed - #{e.message}") if defined?(KIFRSettings)
          end
        end
      end
    end
  end
rescue => e
  KIFRSettings.debug_log("EconomyMod: Game.start_new hook failed - #{e.message}") if defined?(KIFRSettings)
end

#===============================================================================
# POKEVIAL HOOK - Charge for PokeVial Usage
#===============================================================================
# This would hook into wherever the PokeVial healing is triggered
# Implementation depends on how KIF handles PokeVial

#===============================================================================
# BACKWARD COMPATIBILITY - Alias for old module name
#===============================================================================
MartSale = EconomyMod::Sale unless defined?(MartSale)

#===============================================================================
# KIFR SETTINGS REGISTRATION
#===============================================================================
begin
  if defined?(KIFRSettings)
    # Initialize default values
    KIFRSettings.set_default(:economymod_global_multiplier, 10)  # 1.0x
    KIFRSettings.set_default(:economymod_starting_money_enabled, 0)  # Default Off
    KIFRSettings.set_default(:economymod_starting_money, 3000)
    KIFRSettings.set_default(:economymod_battle_money_enabled, 0)
    KIFRSettings.set_default(:economymod_battle_money_multiplier, 1)
    KIFRSettings.set_default(:economymod_pokevial_cost_enabled, 1)
    KIFRSettings.set_default(:economymod_pokevial_cost, 500)
    
    KIFRSettings.debug_log("EconomyMod: Defaults initialized")
  end
rescue => e
  KIFRSettings.debug_log("EconomyMod: ERROR: Setup failed - #{e.message}") if defined?(KIFRSettings)
end

#===============================================================================
# ECONOMY SETTINGS SCENE
#===============================================================================
class KIFR_EconomyScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    #===========================================================================
    # PRICING SETTINGS
    #===========================================================================
    options << SimpleCategoryHeaderOption.new(_INTL("Pricing Settings"))
    
    multiplier_option = StoneSliderOption.new(
      _INTL("Global Price Multiplier"),
      10, 30, 1,
      proc { KIFRSettings.get(:economymod_global_multiplier, 10) },
      proc { |value| KIFRSettings.set(:economymod_global_multiplier, value) },
      _INTL("Multiply all shop prices")
    )
    # Display as decimal (10 -> "1.0", 15 -> "1.5", etc.)
    multiplier_option.display_formatter = proc { |val| sprintf("%.1f", val / 10.0) }
    options << multiplier_option
    
    #===========================================================================
    # MONEY SETTINGS
    #===========================================================================
    options << SimpleCategoryHeaderOption.new(_INTL("Money Settings"))
    
    options << EnumOption.new(
      _INTL("Custom Starting Money"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:economymod_starting_money_enabled, 0) },
      proc { |value| KIFRSettings.set(:economymod_starting_money_enabled, value) },
      _INTL("Use custom amount of money when starting a new game")
    )
    
    starting_money_option = StoneSliderOption.new(
      _INTL("Starting Money Amount"),
      0, 50000, 1000,
      proc { KIFRSettings.get(:economymod_starting_money, 3000) },
      proc { |value| KIFRSettings.set(:economymod_starting_money, value) },
      _INTL("Amount of money to start with (0-50,000)")
    )
    options << starting_money_option
    
    options << EnumOption.new(
      _INTL("Battle Money Multiplier"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:economymod_battle_money_enabled, 0) },
      proc { |value| KIFRSettings.set(:economymod_battle_money_enabled, value) },
      _INTL("Multiply money earned from trainer battles")
    )
    
    battle_mult_option = StoneSliderOption.new(
      _INTL("Battle Money Multiplier"),
      1, 10, 1,
      proc { KIFRSettings.get(:economymod_battle_money_multiplier, 1) },
      proc { |value| KIFRSettings.set(:economymod_battle_money_multiplier, value) },
      _INTL("Multiplier for battle money rewards (1-10)")
    )
    # Display as "2x", "3x", etc.
    battle_mult_option.display_formatter = proc { |val| "#{val}x" }
    options << battle_mult_option
    
    options << EnumOption.new(
      _INTL("PokeVial Cost"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:economymod_pokevial_cost_enabled, 1) },
      proc { |value| KIFRSettings.set(:economymod_pokevial_cost_enabled, value) },
      _INTL("Charge money each time the PokeVial is used")
    )
    
    pokevial_option = StoneSliderOption.new(
      _INTL("PokeVial Cost Per Use"),
      0, 5000, 100,
      proc { KIFRSettings.get(:economymod_pokevial_cost, 500) },
      proc { |value| KIFRSettings.set(:economymod_pokevial_cost, value) },
      _INTL("Cost in Pokedollars for each PokeVial use")
    )
    options << pokevial_option
    
    return options
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create title (invisible initially)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Economy Settings"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    
    # Create description textbox (96px - 1.5 rows)
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
    
    # Apply KIFR theme colors
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
          break if isConfirmedOnKeyPress
        end
        
        # Update description based on current selection
        current = @sprites["option"].index
        if current >= 0 && current < @PokemonOptions.length
          desc = @PokemonOptions[current].description rescue ""
          @sprites["textbox"].text = desc if @sprites["textbox"]
        elsif current == @PokemonOptions.length
          @sprites["textbox"].text = _INTL("Return to Economy category.") if @sprites["textbox"]
        end
      end
    }
  end
end

#===============================================================================
# LOG INITIALIZATION
#===============================================================================
KIFRSettings.debug_log("KIFR Economy: Module loaded") if defined?(KIFRSettings)
