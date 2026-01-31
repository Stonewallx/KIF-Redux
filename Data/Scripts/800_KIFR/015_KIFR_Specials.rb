#===============================================================================
# KIFR Shop Specials System
# Script Version: 3.1.0 - Hybrid Per-Shop Randoms
# Author: Stonewall
#===============================================================================
# Unified system for shop sales and markups:
#
# EVENT MODE (Custom or Themed) - GLOBAL, affects ALL shops:
# - Only ONE event can be active at a time
# - An event can have BOTH sale items AND markup items
# - Themed events are day-based (e.g., Medicine Monday)
# - Custom events are date-range based (e.g., New Year's Sale)
# - Priority: Custom (100+) > Themed (50)
#
# RANDOM MODE (no event active) - PER-SHOP, each shop has its own:
# - Can have 1 random SALE + 1 random MARKUP per shop
# - Different items for each (no overlap within shop)
# - Only activates when NO event is running
# - Each shop generates its own randoms when you visit
#===============================================================================

module KIFR
  module Shop
    module Specials
      #=========================================================================
      # CONFIGURATION
      #=========================================================================
      
      # Random specials settings (only when no event active)
      RANDOM_SALE_CHANCE = 75           # % chance for random sale
      RANDOM_MARKUP_CHANCE = 50         # % chance for random markup
      RANDOM_MIN_PERCENT = 5            # Min discount/markup %
      RANDOM_MAX_PERCENT = 50           # Max discount/markup %
      RANDOM_MULTI_ITEM_CHANCE = 50     # % chance for 2 items instead of 1
      RANDOM_DURATION_HOURS = 5         # How long random specials last
      
      # Themed specials settings
      THEMED_CHANCE = 15                # % chance themed special triggers
      THEMED_PRIORITY = 50              # Priority level
      THEMED_DURATION_HOURS = 5         # How long themed specials last
      
      # Pocket ID mapping (matches Settings.bag_pocket_names)
      POCKET_NAMES = {
        1 => "Items",
        2 => "Medicine", 
        3 => "Poké Balls",
        4 => "TMs & HMs",
        5 => "Berries",
        6 => "Mail",
        7 => "Battle Items",
        8 => "Key Items"
      }
      
      #=========================================================================
      # THEMED SPECIALS - Day-based events (can have BOTH sales AND markups)
      #=========================================================================
      # Format:
      # {
      #   name: "Event Name",
      #   days: [0, 1, 2...],           # 0=Sunday, 6=Saturday
      #   chance: 15,                   # % chance to trigger
      #   sale_pockets: [2, 5],         # Pockets to put on SALE (optional)
      #   sale_percent: 5..25,          # Sale discount range
      #   markup_pockets: [1],          # Pockets to MARK UP (optional)
      #   markup_percent: 5..15,        # Markup increase range (optional)
      #   currency: :platinum,          # Alternate currency for this event (optional)
      #   currency_items: { ... }       # Per-item currency overrides (optional)
      # }
      # NOTE: An event can have sale_pockets, markup_pockets, or BOTH!
      # NOTE: Currency support is optional - defaults to :money if not specified
      THEMED_SPECIALS = {
        medicine_monday: {
          name: "Medicine Monday",
          days: [1],                    # Monday
          chance: 15,
          sale_pockets: [2],            # Medicine on sale
          sale_percent: 5..25
        },
        tm_tuesday: {
          name: "TM Tuesday",
          days: [2],                    # Tuesday
          chance: 15,
          sale_pockets: [4],            # TMs on sale
          sale_percent: 5..25
        },
        wellness_wednesday: {
          name: "Wellness Wednesday",
          days: [3],                    # Wednesday
          chance: 15,
          sale_pockets: [2, 5],         # Medicine + Berries on sale
          sale_percent: 5..25
        },
        throwback_thursday: {
          name: "Throwback Thursday",
          days: [4],                    # Thursday
          chance: 15,
          markup_pockets: [1],          # General Items marked up
          markup_percent: 5..25
        },
        battle_friday: {
          name: "Battle Friday",
          days: [5],                    # Friday
          chance: 15,
          sale_pockets: [7],            # Battle Items on sale
          sale_percent: 5..25
        },
        ball_weekend: {
          name: "Ball Bonanza",
          days: [0, 6],                 # Saturday & Sunday
          chance: 15,
          sale_pockets: [3],            # Poké Balls on sale
          sale_percent: 5..25
        },
        # Example of a MIXED event (has both sales and markups):
        # mixed_event: {
        #   name: "Chaos Day",
        #   days: [3],
        #   chance: 15,
        #   sale_pockets: [3],          # Balls on sale
        #   sale_percent: 10..20,
        #   markup_pockets: [7],        # Battle items marked up
        #   markup_percent: 10..20
        # }
      }
      
      #=========================================================================
      # CUSTOM SPECIALS - Date/time-based events (can have BOTH sales AND markups)
      #=========================================================================
      # These are loaded from $game_system.kifr_custom_specials or defined here
      # Format:
      # {
      #   id: :event_name,
      #   name: "Display Name",
      #   start_date: "YYYY-MM-DD",
      #   end_date: "YYYY-MM-DD",
      #   hours: nil or [start_hour, end_hour],  # 24h format (optional)
      #   priority: 100,                          # Higher = takes precedence
      #   # SALE settings (optional):
      #   sale_pockets: [1, 2, 3] or nil,        # nil = use sale_items instead
      #   sale_items: [:POTION, :SUPERPOTION],   # nil = use sale_pockets
      #   sale_percent: 25 or 20..30,            # fixed or range
      #   # MARKUP settings (optional):
      #   markup_pockets: [4, 5] or nil,
      #   markup_items: [:RARE_CANDY],
      #   markup_percent: 15 or 10..20,
      #   # CURRENCY settings (optional - NEW!):
      #   currency: :platinum,                   # Default currency for this event
      #   currency_items: {                      # Override currency per item
      #     :RARECANDY => { currency: :platinum, price: 50 },
      #     :MASTERBALL => { currency: :bp, price: 100 }
      #   }
      # }
      # NOTE: An event can have sales, markups, or BOTH!
      # NOTE: Currency support allows events to sell items in alternate currencies!
      DEFAULT_CUSTOM_SPECIALS = [
        # Example: New Year's Sale (sales only)
        # {
        #   id: :new_years_2026,
        #   name: "New Year's Sale!",
        #   start_date: "2026-01-01",
        #   end_date: "2026-01-03",
        #   hours: nil,
        #   priority: 100,
        #   sale_pockets: [1, 2, 3],
        #   sale_percent: 25
        # },
        #
        # Example: Mixed Event (sales AND markups)
        # {
        #   id: :summer_chaos,
        #   name: "Summer Chaos Event",
        #   start_date: "2026-06-01",
        #   end_date: "2026-06-07",
        #   priority: 100,
        #   sale_pockets: [3],                   # Poké Balls on sale
        #   sale_percent: 20..30,
        #   markup_pockets: [2],                 # Medicine marked up
        #   markup_percent: 10..15
        # },
        #
        # Example: Platinum Event (alternate currency)
        # {
        #   id: :platinum_weekend,
        #   name: "Platinum Weekend!",
        #   start_date: "2026-03-01",
        #   end_date: "2026-03-02",
        #   priority: 100,
        #   currency: :platinum,                 # All items use Platinum
        #   sale_items: [:RARECANDY, :PPUP],
        #   sale_percent: 0,                     # No discount, just Platinum pricing
        #   currency_items: {
        #     :RARECANDY => { price: 25 },       # 25 Pt
        #     :PPUP => { price: 15 }             # 15 Pt
        #   }
        # }
      ]
      
      #=========================================================================
      # CORE MODULE - Shared utilities
      #=========================================================================
      module Core
        def self.debug_log(message)
          # Use KIFR debug system
          if defined?(KIFRSettings) && KIFRSettings.respond_to?(:debug_log)
            KIFRSettings.debug_log("Economy::Specials: #{message}")
          end
        end
        
        # Check if we should skip specials (Kuray Shop, Outfit Menu)
        def self.skip_specials?
          return false unless $game_temp
          kuray = $game_temp.respond_to?(:fromkurayshop) && $game_temp.fromkurayshop
          outfit = $game_temp.respond_to?(:in_outfit_menu) && $game_temp.in_outfit_menu
          kuray || outfit
        end
        
        # Get current real time
        def self.current_time
          Time.now
        end
        
        # Get current real time in seconds (for duration tracking)
        def self.real_time_seconds
          Time.now.to_i
        end
        
        # Get current day of week (0=Sunday, 6=Saturday)
        def self.day_of_week
          current_time.wday
        end
        
        # Get game time in seconds (legacy, kept for compatibility)
        def self.game_time_seconds
          if defined?(pbGetTimeNow)
            begin
              t = pbGetTimeNow
              return t.to_i if t
            rescue
            end
          end
          
          gs = $game_system
          if gs
            return gs.play_time.to_i if gs.respond_to?(:play_time) && gs.play_time
            return gs.playtime.to_i if gs.respond_to?(:playtime) && gs.playtime
          end
          
          if defined?(Graphics) && Graphics.respond_to?(:frame_count)
            return (Graphics.frame_count / Graphics.frame_rate.to_f).to_i rescue 0
          end
          
          Time.now.to_i
        end
        
        # Parse date string "YYYY-MM-DD" to Time
        def self.parse_date(date_str)
          return nil unless date_str.is_a?(String)
          parts = date_str.split('-').map(&:to_i)
          return nil if parts.length != 3
          Time.new(parts[0], parts[1], parts[2])
        end
        
        # Check if current real time is within date range
        def self.within_date_range?(start_date, end_date, hours = nil)
          now = current_time
          start_t = parse_date(start_date)
          end_t = parse_date(end_date)
          return false unless start_t && end_t
          
          # Check date
          today = Time.new(now.year, now.month, now.day)
          start_day = Time.new(start_t.year, start_t.month, start_t.day)
          end_day = Time.new(end_t.year, end_t.month, end_t.day) + 86400 - 1  # End of day
          
          return false if today < start_day || today > end_day
          
          # Check hours if specified
          if hours && hours.length == 2
            current_hour = now.hour
            return current_hour >= hours[0] && current_hour < hours[1]
          end
          
          true
        end
        
        # Get pocket names for display
        def self.pocket_names(pockets)
          return "All Items" if pockets == :all
          return [] unless pockets.is_a?(Array)
          pockets.map { |p| POCKET_NAMES[p] || "Unknown" }
        end
        
        # Convert item to ID
        def self.item_to_id(item)
          return item if item.is_a?(Symbol)
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
      end
      
      #=========================================================================
      # ACTIVE SPECIAL TRACKING - Event Slot (Global) + Random Slots (Per-Shop)
      #=========================================================================
      # STRUCTURE:
      #
      # GLOBAL - Event Slot (Custom or Themed - only ONE active, applies to ALL shops):
      # $game_system.kifr_active_event = {
      #   source: :themed or :custom,
      #   name: "Event Name",
      #   sale_items: { item_id => percent, ... },    # Items on sale
      #   markup_items: { item_id => percent, ... },  # Items marked up
      #   sale_pockets: [1, 2],                       # For display
      #   markup_pockets: [3, 4],                     # For display
      #   start_time: real_time_seconds,
      #   duration: seconds or nil (nil = date-based),
      #   priority: number,
      #   theme_id: :medicine_monday or nil,
      #   custom_id: :new_years_2026 or nil,
      #   # Currency support (NEW!):
      #   currency: :platinum or nil,                 # Default currency for event
      #   currency_items: {                           # Per-item currency overrides
      #     item_id => { currency: :platinum, price: 50 }
      #   }
      # }
      #
      # PER-SHOP - Random Slots (ONLY when no event active, each shop has its own):
      # $game_system.kifr_shop_randoms = {
      #   shop_key => {
      #     sale: {
      #       name: "Potion Sale",
      #       items: { item_id => percent, ... },
      #       start_time: real_time_seconds,
      #       duration: seconds,
      #       currency: :money,
      #       currency_items: { ... }
      #     },
      #     markup: { same format }
      #   },
      #   another_shop_key => { ... }
      # }
      #
      # Shop keys are generated from stock hash to uniquely identify each shop.
      #=========================================================================
      
      class << self
        #=======================================================================
        # CURRENT SHOP TRACKING (for per-shop random specials)
        #=======================================================================
        
        # Generate a unique shop key from stock AND location
        # This ensures different shops in different cities have different keys
        # even if they have similar stock
        def generate_shop_key(stock)
          return nil unless stock.is_a?(Array)
          
          # Extract just item IDs (ignore currency format)
          items = stock.compact.map do |item|
            if item.is_a?(Array)
              item[0]  # First element is item ID in mixed currency format
            else
              item
            end
          end
          
          # Sort for consistency
          sorted = items.sort_by { |i| i.to_s }
          item_str = sorted.map { |i| i.to_s }.join(",")
          
          # Use BOTH current map AND previous map for unique key
          # This handles shared indoor maps (like PokéMart) that multiple cities use
          # Players entering from different outdoor maps will get different shop keys
          current_map = $game_map ? $game_map.map_id : 0
          previous_map = 0
          if $PokemonGlobal && $PokemonGlobal.respond_to?(:mapTrail) && $PokemonGlobal.mapTrail
            previous_map = $PokemonGlobal.mapTrail[1] || 0
          end
          
          # Generate unique key from current + previous map + items hash
          "m#{current_map}_p#{previous_map}_#{item_str.hash.abs.to_s(36)}"
        end
        
        # Get/set current shop key (set when entering a shop)
        def current_shop_key
          return nil unless $game_temp
          $game_temp.kifr_current_shop_key rescue nil
        end
        
        def current_shop_key=(key)
          return unless $game_temp
          $game_temp.kifr_current_shop_key = key
        end
        
        # Get all shop randoms storage
        def shop_randoms
          return {} unless $game_system
          $game_system.kifr_shop_randoms ||= {}
          $game_system.kifr_shop_randoms
        end
        
        # Get random data for a specific shop
        def get_shop_randoms(shop_key)
          return nil unless shop_key
          shop_randoms[shop_key]
        end
        
        # Set random data for a specific shop
        def set_shop_randoms(shop_key, data)
          return unless shop_key && $game_system
          $game_system.kifr_shop_randoms ||= {}
          $game_system.kifr_shop_randoms[shop_key] = data
        end
        
        # Clear random data for a specific shop
        def clear_shop_randoms(shop_key)
          return unless shop_key && $game_system
          $game_system.kifr_shop_randoms ||= {}
          $game_system.kifr_shop_randoms.delete(shop_key)
        end
        
        # Clear ALL shop randoms
        def clear_all_shop_randoms
          return unless $game_system
          $game_system.kifr_shop_randoms = {}
        end
        
        #=======================================================================
        # SLOT ACCESSORS (updated for per-shop randoms)
        #=======================================================================
        
        # Event slot (Custom or Themed) - GLOBAL
        def active_event
          return nil unless $game_system
          $game_system.kifr_active_event rescue nil
        end
        
        def active_event=(data)
          return unless $game_system
          $game_system.kifr_active_event = data
        end
        
        # Random sale slot - PER-SHOP (uses current_shop_key)
        def random_sale
          return nil unless current_shop_key
          data = get_shop_randoms(current_shop_key)
          return nil unless data
          data[:sale]
        end
        
        def random_sale=(data)
          return unless current_shop_key
          shop_data = get_shop_randoms(current_shop_key) || {}
          if data.nil?
            shop_data.delete(:sale)
          else
            shop_data[:sale] = data
          end
          if shop_data.empty?
            clear_shop_randoms(current_shop_key)
          else
            set_shop_randoms(current_shop_key, shop_data)
          end
        end
        
        # Random markup slot - PER-SHOP (uses current_shop_key)
        def random_markup
          return nil unless current_shop_key
          data = get_shop_randoms(current_shop_key)
          return nil unless data
          data[:markup]
        end
        
        def random_markup=(data)
          return unless current_shop_key
          shop_data = get_shop_randoms(current_shop_key) || {}
          if data.nil?
            shop_data.delete(:markup)
          else
            shop_data[:markup] = data
          end
          if shop_data.empty?
            clear_shop_randoms(current_shop_key)
          else
            set_shop_randoms(current_shop_key, shop_data)
          end
        end
        
        #=======================================================================
        # LEGACY ACCESSORS (for backward compatibility)
        #=======================================================================
        
        # Legacy: active_sale - returns event sale or random sale
        def active_sale
          if has_active_event?
            event = active_event
            return nil unless event
            # For themed/custom events, check if there are sale pockets OR sale items
            has_sale = (event[:sale_pockets] && !event[:sale_pockets].empty?) ||
                       (event[:sale_items] && !event[:sale_items].empty?)
            return nil unless has_sale
            # Build legacy format
            {
              type: :sale,
              source: event[:source],
              name: event[:name],
              pockets: event[:sale_pockets],
              items: event[:sale_items] || {},
              start_time: event[:start_time],
              duration: event[:duration],
              priority: event[:priority],
              theme_id: event[:theme_id],
              custom_id: event[:custom_id]
            }
          else
            rs = random_sale
            return nil unless rs
            {
              type: :sale,
              source: :random,
              name: rs[:name],
              pockets: nil,
              items: rs[:items],
              start_time: rs[:start_time],
              duration: rs[:duration],
              priority: 10
            }
          end
        end
        
        # Legacy: active_markup - returns event markup or random markup
        def active_markup
          if has_active_event?
            event = active_event
            return nil unless event
            # For themed/custom events, check if there are markup pockets OR markup items
            has_markup = (event[:markup_pockets] && !event[:markup_pockets].empty?) ||
                         (event[:markup_items] && !event[:markup_items].empty?)
            return nil unless has_markup
            # Build legacy format
            {
              type: :markup,
              source: event[:source],
              name: event[:name],
              pockets: event[:markup_pockets],
              items: event[:markup_items] || {},
              start_time: event[:start_time],
              duration: event[:duration],
              priority: event[:priority],
              theme_id: event[:theme_id],
              custom_id: event[:custom_id]
            }
          else
            rm = random_markup
            return nil unless rm
            {
              type: :markup,
              source: :random,
              name: rm[:name],
              pockets: nil,
              items: rm[:items],
              start_time: rm[:start_time],
              duration: rm[:duration],
              priority: 10
            }
          end
        end
        
        # Legacy: active_special - returns first available
        def active_special
          active_sale || active_markup
        end
        
        #=======================================================================
        # CURRENCY ACCESSORS
        #=======================================================================
        
        # Get the currency for a specific item in the current specials
        # @param item_id [Symbol] Item ID to check
        # @return [Symbol] Currency ID (:money, :platinum, etc.)
        def get_item_currency(item_id)
          # Check active event first
          if has_active_event?
            event = active_event
            if event
              # Check per-item currency overrides
              if event[:currency_items] && event[:currency_items][item_id]
                return event[:currency_items][item_id][:currency] || event[:currency] || :money
              end
              # Return event's default currency
              return event[:currency] || :money
            end
          end
          
          # Check random specials
          [random_sale, random_markup].each do |slot|
            next unless slot && slot[:items] && slot[:items].key?(item_id)
            if slot[:currency_items] && slot[:currency_items][item_id]
              return slot[:currency_items][item_id][:currency] || slot[:currency] || :money
            end
            return slot[:currency] || :money
          end
          
          :money
        end
        
        # Get custom price for an item (if set)
        # @param item_id [Symbol] Item ID to check
        # @return [Integer, nil] Custom price or nil if using normal price
        def get_item_custom_price(item_id)
          # Check active event
          if has_active_event?
            event = active_event
            if event && event[:currency_items] && event[:currency_items][item_id]
              return event[:currency_items][item_id][:price]
            end
          end
          
          # Check random specials
          [random_sale, random_markup].each do |slot|
            next unless slot
            if slot[:currency_items] && slot[:currency_items][item_id]
              return slot[:currency_items][item_id][:price]
            end
          end
          
          nil
        end
        
        # Check if item uses alternate (non-money) currency
        # @param item_id [Symbol] Item ID to check
        # @return [Boolean] True if using alternate currency
        def item_uses_alternate_currency?(item_id)
          get_item_currency(item_id) != :money
        end
        
        # Get all items with alternate currencies in current specials
        # @return [Hash] { item_id => { currency: :symbol, price: int_or_nil } }
        def get_alternate_currency_items
          result = {}
          
          # From event
          if has_active_event?
            event = active_event
            if event && event[:currency_items]
              event[:currency_items].each do |item_id, info|
                result[item_id] = {
                  currency: info[:currency] || event[:currency] || :money,
                  price: info[:price]
                }
              end
            end
          end
          
          # From random specials
          [random_sale, random_markup].each do |slot|
            next unless slot && slot[:currency_items]
            slot[:currency_items].each do |item_id, info|
              result[item_id] ||= {
                currency: info[:currency] || slot[:currency] || :money,
                price: info[:price]
              }
            end
          end
          
          result
        end
        
        #=======================================================================
        # EXPIRATION CHECKS
        #=======================================================================
        
        # Check and expire event
        def check_event_expiration
          event = active_event
          return false unless event
          
          # Check duration expiration for themed events (uses real time)
          if event[:source] == :themed && event[:duration]
            elapsed = Core.real_time_seconds - (event[:start_time] || 0)
            if elapsed >= event[:duration]
              self.active_event = nil
              Core.debug_log("Themed event expired: #{event[:name]}")
              return false
            end
          end
          
          # Check date range for custom events
          if event[:source] == :custom && event[:custom_id]
            custom = get_custom_special(event[:custom_id])
            if custom && !Core.within_date_range?(custom[:start_date], custom[:end_date], custom[:hours])
              self.active_event = nil
              Core.debug_log("Custom event expired: #{event[:name]}")
              return false
            end
          end
          
          true
        end
        
        # Check and expire random slots for CURRENT shop only
        def check_random_expiration
          return false unless current_shop_key
          expired_any = false
          
          # Check random sale for current shop
          rs = random_sale
          if rs && rs[:duration]
            elapsed = Core.real_time_seconds - (rs[:start_time] || 0)
            if elapsed >= rs[:duration]
              self.random_sale = nil
              Core.debug_log("Random sale expired for shop #{current_shop_key}")
              expired_any = true
            end
          end
          
          # Check random markup for current shop
          rm = random_markup
          if rm && rm[:duration]
            elapsed = Core.real_time_seconds - (rm[:start_time] || 0)
            if elapsed >= rm[:duration]
              self.random_markup = nil
              Core.debug_log("Random markup expired for shop #{current_shop_key}")
              expired_any = true
            end
          end
          
          # Also check currency conversions (synced timing)
          if defined?(KIFR::Currency::Shop) && KIFR::Currency::Shop.respond_to?(:check_conversion_expiration)
            if KIFR::Currency::Shop.check_conversion_expiration
              expired_any = true
            end
          end
          
          expired_any
        end
        
        # Clean up expired randoms across ALL shops (call periodically)
        def cleanup_all_expired_randoms
          return unless $game_system
          shop_randoms.each do |shop_key, data|
            next unless data
            expired = false
            
            # Check sale
            if data[:sale] && data[:sale][:duration]
              elapsed = Core.real_time_seconds - (data[:sale][:start_time] || 0)
              if elapsed >= data[:sale][:duration]
                data.delete(:sale)
                expired = true
              end
            end
            
            # Check markup
            if data[:markup] && data[:markup][:duration]
              elapsed = Core.real_time_seconds - (data[:markup][:start_time] || 0)
              if elapsed >= data[:markup][:duration]
                data.delete(:markup)
                expired = true
              end
            end
            
            # Remove shop entry if empty
            if data.empty?
              clear_shop_randoms(shop_key)
            elsif expired
              set_shop_randoms(shop_key, data)
            end
          end
        end
        
        # Check if there's an active event (Custom or Themed)
        def has_active_event?
          check_event_expiration
          active_event != nil
        end
        
        # Check if there's an active sale (event or random)
        def has_active_sale?
          if has_active_event?
            event = active_event
            return false unless event
            # Check for sale pockets (pocket-based) OR sale items (item-specific)
            has_pockets = event[:sale_pockets] && !event[:sale_pockets].empty?
            has_items = event[:sale_items] && !event[:sale_items].empty?
            return has_pockets || has_items
          else
            check_random_expiration
            return random_sale != nil
          end
        end
        
        # Check if there's an active markup (event or random)
        def has_active_markup?
          if has_active_event?
            event = active_event
            return false unless event
            # Check for markup pockets (pocket-based) OR markup items (item-specific)
            has_pockets = event[:markup_pockets] && !event[:markup_pockets].empty?
            has_items = event[:markup_items] && !event[:markup_items].empty?
            return has_pockets || has_items
          else
            check_random_expiration
            return random_markup != nil
          end
        end
        
        # Check if there's ANY active special
        def has_active_special?
          has_active_sale? || has_active_markup?
        end
        
        # Check if there's an active random sale
        def has_random_sale?
          return false if has_active_event?
          check_random_expiration
          random_sale != nil
        end
        
        # Check if there's an active random markup
        def has_random_markup?
          return false if has_active_event?
          check_random_expiration
          random_markup != nil
        end
        
        #=======================================================================
        # CLEARING SPECIALS
        #=======================================================================
        
        # Clear everything (global event + current shop's randoms)
        def clear_special
          self.active_event = nil
          self.random_sale = nil
          self.random_markup = nil
          if $game_temp
            $game_temp.kifr_special_announced = false if $game_temp.respond_to?(:kifr_special_announced=)
          end
          # Also refresh currency conversions when clearing all specials
          refresh_currency_conversions
          Core.debug_log("Cleared event and current shop randoms")
        end
        
        # Clear ALL specials including all shop randoms
        def clear_all_specials
          self.active_event = nil
          clear_all_shop_randoms
          if $game_temp
            $game_temp.kifr_special_announced = false if $game_temp.respond_to?(:kifr_special_announced=)
          end
          refresh_currency_conversions
          Core.debug_log("All specials cleared (including all shop randoms)")
        end
        
        # Clear event only (global)
        def clear_event
          self.active_event = nil
          Core.debug_log("Event cleared")
        end
        
        # Clear current shop's randoms only
        def clear_current_shop_randoms
          return unless current_shop_key
          clear_shop_randoms(current_shop_key)
          Core.debug_log("Cleared randoms for shop #{current_shop_key}")
        end
        
        # Clear sale (random sale or event sale items)
        def clear_sale
          if has_active_event?
            # Clear sale items from event
            event = active_event
            if event
              event[:sale_items] = {}
              event[:sale_pockets] = []
              self.active_event = event
              # If both sale and markup are empty, clear event
              if event[:markup_items].nil? || event[:markup_items].empty?
                self.active_event = nil
              end
            end
          else
            self.random_sale = nil
          end
          Core.debug_log("Sale cleared")
        end
        
        # Clear markup (random markup or event markup items)
        def clear_markup
          if has_active_event?
            # Clear markup items from event
            event = active_event
            if event
              event[:markup_items] = {}
              event[:markup_pockets] = []
              self.active_event = event
              # If both sale and markup are empty, clear event
              if event[:sale_items].nil? || event[:sale_items].empty?
                self.active_event = nil
              end
            end
          else
            self.random_markup = nil
          end
          Core.debug_log("Markup cleared")
        end
        
        # Legacy: clear_slot
        def clear_slot(slot_type)
          slot_type == :sale ? clear_sale : clear_markup
        end
        
        # Refresh currency conversions (synced with specials)
        def refresh_currency_conversions
          if defined?(KIFR::Currency::Shop) && KIFR::Currency::Shop.respond_to?(:refresh_conversions!)
            KIFR::Currency::Shop.refresh_conversions!
          end
        end
        
        # Get custom specials list
        def custom_specials
          list = DEFAULT_CUSTOM_SPECIALS.dup
          if $game_system && $game_system.respond_to?(:kifr_custom_specials)
            user_list = $game_system.kifr_custom_specials rescue []
            list.concat(user_list) if user_list.is_a?(Array)
          end
          list
        end
        
        # Get a specific custom special by ID
        def get_custom_special(id)
          custom_specials.find { |s| s[:id] == id }
        end
        
        # Add a custom special (for KIFRDEV tool)
        def add_custom_special(special_data)
          $game_system.kifr_custom_specials ||= []
          # Remove existing with same ID
          $game_system.kifr_custom_specials.reject! { |s| s[:id] == special_data[:id] }
          $game_system.kifr_custom_specials << special_data
          Core.debug_log("Added custom special: #{special_data[:id]}")
        end
        
        # Remove a custom special
        def remove_custom_special(id)
          return unless $game_system && $game_system.respond_to?(:kifr_custom_specials)
          $game_system.kifr_custom_specials ||= []
          $game_system.kifr_custom_specials.reject! { |s| s[:id] == id }
          # Clear active event if it was this one
          if active_event && active_event[:custom_id] == id
            self.active_event = nil
          end
          Core.debug_log("Removed custom special: #{id}")
        end
        
        #=======================================================================
        # SPECIAL ACTIVATION - Called when entering shop
        #=======================================================================
        def maybe_activate_special(stock)
          return if Core.skip_specials?
          
          # Generate and set shop key for per-shop random tracking
          shop_key = generate_shop_key(stock)
          self.current_shop_key = shop_key
          
          # DEBUG: Show shop key with map info
          map_name = $game_map ? ($game_map.name rescue "Unknown") : "No Map"
          prev_map = ($PokemonGlobal && $PokemonGlobal.mapTrail) ? $PokemonGlobal.mapTrail[1] : nil
          prev_name = prev_map ? (pbGetMapNameFromId(prev_map) rescue "Map #{prev_map}") : "None"
          Core.debug_log("Shop Key: #{shop_key} | Current: #{map_name} | From: #{prev_name}")
          
          # Clean up expired randoms for all shops periodically
          cleanup_all_expired_randoms
          
          # DEBUG: Show existing randoms for this shop
          existing = get_shop_randoms(shop_key)
          if existing
            Core.debug_log("Found existing randoms for #{shop_key}: #{existing.keys.inspect}")
          else
            Core.debug_log("No existing randoms for #{shop_key}")
          end

          
          # Priority: Custom > Themed > Random
          # Custom/Themed fill the EVENT slot (GLOBAL - only one at a time)
          # Random fills RANDOM slots (PER-SHOP - only when no event active)
          
          # 1. Check for custom events (date-based) - GLOBAL
          unless has_active_event?
            activate_custom_event(stock)
          end
          
          # 2. Check for themed events (day-based) - GLOBAL, only if no event active
          unless has_active_event?
            activate_themed_event(stock)
          end
          
          # 3. Random specials - PER-SHOP, ONLY if no event active
          unless has_active_event?
            activate_random_specials(stock)
          end
          
          # DEBUG: Show final state
          Core.debug_log("After activation - Sale: #{random_sale ? random_sale[:name] : 'none'}, Markup: #{random_markup ? random_markup[:name] : 'none'}")
        end
        
        #=======================================================================
        # CUSTOM EVENT ACTIVATION
        #=======================================================================
        def activate_custom_event(stock)
          now = Core.current_time
          
          # Find all active custom events
          active = custom_specials.select do |s|
            Core.within_date_range?(s[:start_date], s[:end_date], s[:hours])
          end
          
          return if active.empty?
          
          # Sort by priority (highest first)
          active.sort_by! { |s| -(s[:priority] || 0) }
          custom = active.first
          
          # Build sale items
          sale_items = {}
          sale_pockets = custom[:sale_pockets] || []
          sale_percent = custom[:sale_percent]
          sale_percent = rand(sale_percent) if sale_percent.is_a?(Range)
          
          if custom[:sale_items] && custom[:sale_items].any?
            # Specific items for sale
            custom[:sale_items].each do |item|
              id = Core.item_to_id(item)
              sale_items[id] = sale_percent if stock.include?(id)
            end
          elsif sale_pockets.any?
            # Whole pockets for sale
            stock.each do |item|
              next unless item.is_a?(Symbol)
              pocket = GameData::Item.get(item).pocket rescue nil
              sale_items[item] = sale_percent if pocket && sale_pockets.include?(pocket)
            end
          end
          
          # Build markup items
          markup_items = {}
          markup_pockets = custom[:markup_pockets] || []
          markup_percent = custom[:markup_percent]
          markup_percent = rand(markup_percent) if markup_percent.is_a?(Range)
          
          if custom[:markup_items] && custom[:markup_items].any?
            # Specific items for markup
            custom[:markup_items].each do |item|
              id = Core.item_to_id(item)
              markup_items[id] = markup_percent if stock.include?(id)
            end
          elsif markup_pockets.any?
            # Whole pockets for markup
            stock.each do |item|
              next unless item.is_a?(Symbol)
              pocket = GameData::Item.get(item).pocket rescue nil
              markup_items[item] = markup_percent if pocket && markup_pockets.include?(pocket)
            end
          end
          
          # Only activate if we have something
          return if sale_items.empty? && markup_items.empty?
          
          self.active_event = {
            source: :custom,
            name: custom[:name],
            sale_items: sale_items,
            markup_items: markup_items,
            sale_pockets: sale_pockets,
            markup_pockets: markup_pockets,
            start_time: Core.real_time_seconds,
            duration: nil,  # Custom events use date range
            priority: custom[:priority] || 100,
            custom_id: custom[:id]
          }
          
          Core.debug_log("Activated custom event: #{custom[:name]} (#{sale_items.size} sales, #{markup_items.size} markups)")
        end
        
        #=======================================================================
        # THEMED EVENT ACTIVATION - Only tries once per valid day
        #=======================================================================
        def activate_themed_event(stock)
          today = Core.day_of_week
          today_date = Time.now.strftime("%Y-%m-%d")
          
          # Check if we already tried and failed today
          if $game_system.kifr_themed_roll_date == today_date && $game_system.kifr_themed_roll_failed
            Core.debug_log("Themed event roll already failed for today, skipping")
            return
          end
          
          # Find themes that match today
          matching = THEMED_SPECIALS.select do |id, theme|
            theme[:days].include?(today)
          end
          
          return if matching.empty?
          
          # Roll for each matching theme (only once per day)
          chosen = nil
          matching.each do |id, theme|
            chance = theme[:chance] || THEMED_CHANCE
            if rand(100) < chance
              chosen = { id: id, **theme }
              break
            end
          end
          
          # Track that we rolled today
          $game_system.kifr_themed_roll_date = today_date
          
          # If nothing was chosen, mark as failed for today
          unless chosen
            $game_system.kifr_themed_roll_failed = true
            Core.debug_log("Themed event roll failed for today, won't try again")
            return
          end
          
          # Success! Clear the failed flag
          $game_system.kifr_themed_roll_failed = false
          
          # Get pockets and calculate percent (themed events are POCKET-BASED, not item-specific)
          sale_pockets = chosen[:sale_pockets] || []
          sale_range = chosen[:sale_percent] || (RANDOM_MIN_PERCENT..RANDOM_MAX_PERCENT)
          sale_percent = sale_range.is_a?(Range) ? rand(sale_range) : sale_range
          
          markup_pockets = chosen[:markup_pockets] || []
          markup_range = chosen[:markup_percent] || (RANDOM_MIN_PERCENT..RANDOM_MAX_PERCENT)
          markup_percent = markup_range.is_a?(Range) ? rand(markup_range) : markup_range
          
          # Store a dummy item with the percent so we can retrieve it later
          # The actual pocket check happens dynamically in sale_percent_for_item
          sale_items = sale_pockets.any? ? { :_pocket_sale => sale_percent } : {}
          markup_items = markup_pockets.any? ? { :_pocket_markup => markup_percent } : {}
          
          # Only activate if we have sale or markup pockets defined
          return if sale_pockets.empty? && markup_pockets.empty?
          
          self.active_event = {
            source: :themed,
            name: chosen[:name],
            sale_items: sale_items,
            markup_items: markup_items,
            sale_pockets: sale_pockets,
            markup_pockets: markup_pockets,
            start_time: Core.real_time_seconds,
            duration: THEMED_DURATION_HOURS * 3600,
            priority: THEMED_PRIORITY,
            theme_id: chosen[:id]
          }
          
          Core.debug_log("Activated themed event: #{chosen[:name]} (pockets: sale=#{sale_pockets.inspect}, markup=#{markup_pockets.inspect})")
        end
        
        #=======================================================================
        # RANDOM SPECIAL ACTIVATION - Per-shop, only when NO event is active
        #=======================================================================
        def activate_random_specials(stock)
          return if has_active_event?  # Block random if event active
          return unless current_shop_key  # Need shop key set
          
          valid_items = stock.select { |i| i.is_a?(Symbol) }
          return if valid_items.empty?
          
          # Get items already used by THIS SHOP's random slots
          used_items = []
          used_items.concat(random_sale[:items].keys) if random_sale && random_sale[:items]
          used_items.concat(random_markup[:items].keys) if random_markup && random_markup[:items]
          
          available_items = valid_items - used_items
          return if available_items.empty?
          
          # Try to fill random sale slot for THIS shop
          unless has_random_sale?
            if rand(100) < RANDOM_SALE_CHANCE
              activate_random_slot(:sale, available_items)
              # Update available items
              if random_sale && random_sale[:items]
                available_items -= random_sale[:items].keys
              end
            end
          end
          
          # Try to fill random markup slot (with remaining items) for THIS shop
          unless has_random_markup?
            if rand(100) < RANDOM_MARKUP_CHANCE && available_items.any?
              activate_random_slot(:markup, available_items)
            end
          end
        end
        
        def activate_random_slot(type, available_items)
          return if available_items.empty?
          
          # Pick items
          num_items = rand(100) < RANDOM_MULTI_ITEM_CHANCE ? 2 : 1
          num_items = [num_items, available_items.length].min
          chosen = available_items.sample(num_items)
          
          items_hash = {}
          chosen.each do |item|
            percent = rand(RANDOM_MIN_PERCENT..RANDOM_MAX_PERCENT)
            items_hash[item] = percent
          end
          
          # Determine name
          if num_items == 1
            item_name = Core.item_name(chosen.first)
            name = type == :sale ? "#{item_name} Sale" : "#{item_name} Markup"
          else
            name = type == :sale ? "Multi-Item Sale" : "Multi-Item Markup"
          end
          
          special_data = {
            name: name,
            items: items_hash,
            start_time: Core.real_time_seconds,
            duration: RANDOM_DURATION_HOURS * 3600
          }
          
          # Assign to correct slot
          if type == :markup
            self.random_markup = special_data
          else
            self.random_sale = special_data
          end
          
          Core.debug_log("Activated random #{type}: #{name}")
        end
        
        #=======================================================================
        # PRICE CALCULATION - Check both slots
        #=======================================================================
        
        # Get the special percent for an item (positive = discount, negative = markup)
        # Returns nil if item not affected
        def special_percent_for_item(item_id)
          # Check sale first (discount = positive)
          sale_pct = sale_percent_for_item(item_id)
          return sale_pct if sale_pct
          
          # Check markup (markup = negative)
          markup_pct = markup_percent_for_item(item_id)
          return -markup_pct if markup_pct
          
          nil
        end
        
        # Check if item is on sale (returns percent or nil)
        def sale_percent_for_item(item_id)
          return nil unless has_active_sale?
          data = active_sale
          return nil unless data
          
          # For themed/custom events with pockets, check pocket membership dynamically
          if data[:source] == :themed || data[:source] == :custom
            if data[:pockets] && data[:pockets].any?
              pocket = GameData::Item.get(item_id).pocket rescue nil
              if pocket && data[:pockets].include?(pocket)
                # Return the discount percentage (stored in first item or as separate field)
                return data[:items].values.first if data[:items] && data[:items].any?
                return 10  # Default fallback
              end
            end
          end
          
          # Check specific items hash
          return nil unless data[:items]
          data[:items][item_id]
        end
        
        # Check if item has markup (returns percent or nil)
        def markup_percent_for_item(item_id)
          return nil unless has_active_markup?
          data = active_markup
          return nil unless data
          
          # For themed/custom events with pockets, check pocket membership dynamically
          if data[:source] == :themed || data[:source] == :custom
            if data[:pockets] && data[:pockets].any?
              pocket = GameData::Item.get(item_id).pocket rescue nil
              if pocket && data[:pockets].include?(pocket)
                return data[:items].values.first if data[:items] && data[:items].any?
                return 10  # Default fallback
              end
            end
          end
          
          # Check specific items hash
          return nil unless data[:items]
          data[:items][item_id]
        end
        
        # Get all items currently on special (either slot)
        def get_special_items
          items = []
          items.concat(get_sale_items)
          items.concat(get_markup_items)
          items.uniq
        end
        
        # Get sale items only
        def get_sale_items
          return [] unless has_active_sale?
          data = active_sale
          return [] unless data && data[:items]
          data[:items].keys
        end
        
        # Get markup items only
        def get_markup_items
          return [] unless has_active_markup?
          data = active_markup
          return [] unless data && data[:items]
          data[:items].keys
        end
        
        #=======================================================================
        # INFO DISPLAY - Shows event or random specials
        #=======================================================================
        
        # Get info for a specific slot type (:sale or :markup)
        def get_slot_info(slot_type)
          data = slot_type == :sale ? active_sale : active_markup
          return nil unless data
          
          info = {
            type: slot_type,
            name: data[:name] || "Special",
            categories: [],
            discount: data[:items] ? (data[:items].values.first rescue 0) : 0,
            time_remaining: nil,
            source: data[:source]
          }
          
          # Get category names
          if data[:pockets] && data[:pockets].any?
            info[:categories] = Core.pocket_names(data[:pockets])
          else
            info[:categories] = ["Selected Items"]
          end
          
          # Calculate time remaining (uses real time)
          if data[:duration] && data[:start_time]
            elapsed = Core.real_time_seconds - data[:start_time]
            remaining = data[:duration] - elapsed
            if remaining > 0
              hours = remaining / 3600
              minutes = (remaining % 3600) / 60
              if hours > 0
                info[:time_remaining] = "#{hours}h #{minutes}m"
              else
                info[:time_remaining] = "#{minutes}m"
              end
            end
          elsif data[:source] == :custom
            info[:time_remaining] = "Event"
          end
          
          info
        end
        
        # Get info for the special display (legacy - returns first available)
        def get_special_info
          get_slot_info(:sale) || get_slot_info(:markup)
        end
        
        # Get info for both slots
        def get_all_specials_info
          {
            sale: has_active_sale? ? get_slot_info(:sale) : nil,
            markup: has_active_markup? ? get_slot_info(:markup) : nil
          }
        end
        
        # Get comprehensive event info (for new UI)
        def get_event_info
          return nil unless has_active_event?
          event = active_event
          return nil unless event
          
          info = {
            name: event[:name],
            source: event[:source],
            has_sales: event[:sale_items] && !event[:sale_items].empty?,
            has_markups: event[:markup_items] && !event[:markup_items].empty?,
            sale_categories: Core.pocket_names(event[:sale_pockets] || []),
            markup_categories: Core.pocket_names(event[:markup_pockets] || []),
            sale_count: event[:sale_items] ? event[:sale_items].size : 0,
            markup_count: event[:markup_items] ? event[:markup_items].size : 0,
            time_remaining: nil
          }
          
          # Calculate time remaining for themed events
          if event[:duration] && event[:start_time]
            elapsed = Core.real_time_seconds - event[:start_time]
            remaining = event[:duration] - elapsed
            if remaining > 0
              hours = remaining / 3600
              minutes = (remaining % 3600) / 60
              if hours > 0
                info[:time_remaining] = "#{hours}h #{minutes}m"
              else
                info[:time_remaining] = "#{minutes}m"
              end
            end
          elsif event[:source] == :custom
            info[:time_remaining] = "Event"
          end
          
          info
        end
      end
    end
  end
end

#===============================================================================
# GAME_SYSTEM EXTENSIONS - Storage for specials data
#===============================================================================
class Game_System
  # New structure (v3.1 - hybrid per-shop)
  attr_accessor :kifr_active_event     # Event slot (Custom or Themed) - GLOBAL
  attr_accessor :kifr_shop_randoms     # Per-shop random specials { shop_key => { sale: {}, markup: {} } }
  attr_accessor :kifr_custom_specials  # Custom specials definitions
  attr_accessor :kifr_themed_roll_date # Date we last rolled for themed (to only try once per day)
  attr_accessor :kifr_themed_roll_failed # Whether the roll failed for today
  attr_accessor :kifr_currency_conversions # Random currency conversions (syncs with specials timing)
  
  # Legacy (deprecated - kept for backward compatibility)
  attr_accessor :kifr_random_sale      # Old global random sale
  attr_accessor :kifr_random_markup    # Old global random markup
  attr_accessor :kifr_active_sale
  attr_accessor :kifr_active_markup
  attr_accessor :kifr_active_special
end

#===============================================================================
# GAME_TEMP EXTENSIONS - Temporary shop tracking
#===============================================================================
class Game_Temp
  attr_accessor :kifr_current_shop_key   # Current shop's unique key (for per-shop randoms)
  attr_accessor :kifr_special_announced  # Whether we've announced the special this shop visit
end

#===============================================================================
# BACKWARD COMPATIBILITY - Alias EconomyMod methods
#===============================================================================
module EconomyMod
  module Sale
    def self.enabled?
      !KIFR::Shop::Specials::Core.skip_specials?
    end
    
    def self.sale_percent_for_item(item_id)
      KIFR::Shop::Specials.sale_percent_for_item(item_id)
    end
    
    def self.clear_sale
      KIFR::Shop::Specials.clear_sale
    end
    
    def self.maybe_start_sale_for_stock(stock)
      KIFR::Shop::Specials.maybe_activate_special(stock)
    end
  end
  
  module Markup
    def self.enabled?
      !KIFR::Shop::Specials::Core.skip_specials?
    end
    
    def self.percent_for_item(item_id)
      KIFR::Shop::Specials.markup_percent_for_item(item_id)
    end
    
    def self.clear_markup
      KIFR::Shop::Specials.clear_markup
    end
    
    def self.maybe_start_markup_for_stock(stock)
      KIFR::Shop::Specials.maybe_activate_special(stock)
    end
  end
  
  module Core
    def self.skip_economy_features?
      KIFR::Shop::Specials::Core.skip_specials?
    end
    
    def self.item_name(item_id)
      KIFR::Shop::Specials::Core.item_name(item_id)
    end
    
    def self.current_time_seconds
      KIFR::Shop::Specials::Core.game_time_seconds
    end
  end
end

#===============================================================================
# POKEMONMARTSCREEN HOOK - Trigger specials on shop open
#===============================================================================
if defined?(PokemonMartScreen)
  class PokemonMartScreen
    unless method_defined?(:kifr_specials_orig_pbBuyScreen)
      alias :kifr_specials_orig_pbBuyScreen :pbBuyScreen
    end
    
    def pbBuyScreen
      # Activate specials when entering buy screen
      KIFR::Shop::Specials.maybe_activate_special(@stock)
      kifr_specials_orig_pbBuyScreen
    end
  end
end

#===============================================================================
# SPECIALS INFO WINDOW - Centered popup with colored text (supports dual slots)
#===============================================================================
class Window_SpecialsInfo < SpriteWindow_Base
  # Color constants
  SALE_COLOR = Color.new(34, 139, 34)      # Forest green for sales
  SALE_SHADOW = Color.new(20, 80, 20)      # Dark green shadow
  MARKUP_COLOR = Color.new(178, 34, 34)    # Firebrick red for markups
  MARKUP_SHADOW = Color.new(100, 20, 20)   # Dark red shadow
  TITLE_COLOR = Color.new(248, 248, 248)   # White for title
  TITLE_SHADOW = Color.new(72, 72, 72)     # Gray shadow
  INFO_COLOR = Color.new(248, 248, 248)    # White for info text
  INFO_SHADOW = Color.new(72, 72, 72)      # Gray shadow
  TIME_COLOR = Color.new(255, 215, 0)      # Gold for time remaining
  TIME_SHADOW = Color.new(140, 115, 0)     # Dark gold shadow
  DIVIDER_COLOR = Color.new(120, 120, 120) # Gray for divider
  
  def initialize(viewport = nil)
    # Determine height based on how many slots are active
    has_sale = defined?(KIFR::Shop::Specials) && KIFR::Shop::Specials.has_active_sale?
    has_markup = defined?(KIFR::Shop::Specials) && KIFR::Shop::Specials.has_active_markup?
    
    # Calculate base height
    if has_sale && has_markup
      height = 280  # Both slots - taller window
    elsif has_sale || has_markup
      height = 180  # Single slot
    else
      height = 100  # No specials - compact window
    end
    
    win_width = Graphics.width - 80
    
    # SpriteWindow_Base.initialize takes (x, y, width, height) - NOT viewport
    super(0, 0, win_width, height)
    
    # Set viewport after initialization
    self.viewport = viewport if viewport
    
    # Create the contents bitmap (required for drawing text)
    # Contents size = window size minus border
    contents_width = win_width - self.borderX
    contents_height = height - self.borderY
    self.contents = Bitmap.new([contents_width, 1].max, [contents_height, 1].max)
    pbSetSystemFont(self.contents)
    
    self.x = (Graphics.width - self.width) / 2
    self.y = (Graphics.height - self.height) / 2
    @baseColor = INFO_COLOR
    @shadowColor = INFO_SHADOW
    self.z = 99999
    refresh
  end
  
  def refresh
    return unless self.contents
    self.contents.clear
    pbSetSystemFont(self.contents)
    
    has_specials = defined?(KIFR::Shop::Specials) && KIFR::Shop::Specials.has_active_special?
    
    # Check if we have anything to show
    unless has_specials
      # Draw "No specials" message centered
      no_special_text = _INTL("No active specials at this time.")
      pbDrawShadowText(self.contents, 0, (self.contents.height - 26) / 2, 
                       self.contents.width, 26, no_special_text, 
                       INFO_COLOR, INFO_SHADOW, 1)
      return
    end
    
    y_offset = 4
    line_height = 26
    content_width = self.contents.width
    
    all_info = KIFR::Shop::Specials.get_all_specials_info
    
    # Draw sale info if active
    if all_info[:sale]
      y_offset = draw_slot_info(all_info[:sale], KIFR::Shop::Specials.active_sale, y_offset, line_height, content_width)
    end
    
    # Draw divider if both are active
    if all_info[:sale] && all_info[:markup]
      y_offset += 6
      # Draw horizontal line
      self.contents.fill_rect(20, y_offset, content_width - 40, 2, DIVIDER_COLOR)
      y_offset += 10
    end
    
    # Draw markup info if active
    if all_info[:markup]
      y_offset = draw_slot_info(all_info[:markup], KIFR::Shop::Specials.active_markup, y_offset, line_height, content_width)
    end
  end
  
  def draw_slot_info(info, data, y_offset, line_height, content_width)
    return y_offset unless info && data
    
    # Determine type colors based on info[:type] (not data[:type] which may not exist)
    slot_type = info[:type] || :sale
    if slot_type == :sale
      type_color = SALE_COLOR
      type_shadow = SALE_SHADOW
      type_text = "SALE"
    else
      type_color = MARKUP_COLOR
      type_shadow = MARKUP_SHADOW
      type_text = "MARKUP"
    end
    
    # Title: "[SALE/MARKUP] Name"
    title_text = "#{type_text}: #{info[:name]}"
    pbDrawShadowText(self.contents, 0, y_offset, content_width, line_height, 
                     title_text, type_color, type_shadow, 1)
    y_offset += line_height
    
    # Categories
    categories_text = "Categories: #{info[:categories].join(', ')}"
    pbDrawShadowText(self.contents, 0, y_offset, content_width, line_height, 
                     categories_text, INFO_COLOR, INFO_SHADOW, 1)
    y_offset += line_height
    
    # Discount/Markup percentage
    if slot_type == :sale
      percent_text = "Discount: #{info[:discount]}% OFF"
      percent_color = SALE_COLOR
      percent_shadow = SALE_SHADOW
    else
      percent_text = "Price Increase: +#{info[:discount]}%"
      percent_color = MARKUP_COLOR
      percent_shadow = MARKUP_SHADOW
    end
    pbDrawShadowText(self.contents, 0, y_offset, content_width, line_height, 
                     percent_text, percent_color, percent_shadow, 1)
    y_offset += line_height
    
    # Time remaining and source on same line
    time_text = ""
    if info[:time_remaining]
      if info[:time_remaining] == "Event"
        time_text = "Limited Event"
      else
        time_text = "#{info[:time_remaining]} left"
      end
    end
    
    source_names = { random: "Random", themed: "Themed", custom: "Event" }
    source_text = "(#{source_names[info[:source]] || "Special"})"
    
    combined_text = time_text.empty? ? source_text : "#{time_text} #{source_text}"
    pbDrawShadowText(self.contents, 0, y_offset, content_width, line_height, 
                     combined_text, TIME_COLOR, TIME_SHADOW, 1)
    y_offset += line_height
    
    y_offset
  end
end

#===============================================================================
# SPECIALS INFO DISPLAY - Show the popup window
#===============================================================================
module KIFR
  module Shop
    module Specials
      # Show the specials info popup window (always shows, even if no specials)
      def self.show_info_window(viewport = nil)
        pbPlayDecisionSE
        
        # Always create our own viewport on top of everything
        info_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        info_viewport.z = 99999
        
        window = nil
        
        begin
          # Create window (handles both active specials and no specials)
          window = Window_SpecialsInfo.new(info_viewport)
          window.visible = true
          
          # Force graphics update to show window
          Graphics.update
          
          # Wait for input
          loop do
            Graphics.update
            Input.update
            break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || 
                     Input.trigger?(Input::AUX2) || Input.trigger?(Input::ACTION)
          end
          
        rescue StandardError => e
          Core.debug_log("ERROR in show_info_window: #{e.message}")
          Core.debug_log("Backtrace: #{e.backtrace.first(5).join("\n")}")
        ensure
          # Clean up
          window.dispose if window && !window.disposed?
          info_viewport.dispose if info_viewport && !info_viewport.disposed?
        end
        
        # Clear input buffer
        5.times do
          Graphics.update
          Input.update
        end
        
        true
      end
      
      # Show message when no specials are active (for KIFRDEV compatibility)
      def self.show_no_specials_message
        pbMessage(_INTL("No active specials."))
      end
    end
  end
end

KIFRSettings.debug_log("KIFR::Shop::Specials system loaded") if defined?(KIFRSettings)
