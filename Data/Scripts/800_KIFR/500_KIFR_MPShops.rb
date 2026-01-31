#===============================================================================
# KIFR Multiplayer Shop Sync
# Script Version: 1.1.0
# Author: Stonewall
#===============================================================================
# Syncs shop specials between squad members in multiplayer:
# - Squad LEADER's shop specials are broadcast to all squad members
# - Squad MEMBERS receive and use the leader's specials when shopping
# - Ensures consistent shop experience for the entire squad
#
# Protocol:
# - KIFR_SHOP_SYNC:<hex> - Leader broadcasts their current shop specials
# - KIFR_SHOP_REQ:<shop_key> - Member requests specials from leader
#
# REQUIRED: Add this line to 002_Client.rb in the FROM: elsif chain (~line 2305):
#
#   elsif payload.start_with?("KIFR_")
#     MultiplayerClient.handle_kifr_from_message(sid, payload) if MultiplayerClient.respond_to?(:handle_kifr_from_message)
#
# SECURITY:
# - Uses MiniJSON (safer than Marshal - no arbitrary code execution)
# - Size limits on incoming data (50KB max)
# - Data validation before applying
# - Only simple types: strings, integers, arrays, hashes
#===============================================================================

module KIFR
  module MP
    module ShopSync
      # Security limits
      MAX_MESSAGE_SIZE = 50_000  # 50KB max for shop sync data
      MAX_ITEMS_PER_SPECIAL = 100  # Max items in a sale/markup
      
      # Cache for leader's shop specials (for members)
      @leader_specials = nil
      @leader_specials_time = nil
      @specials_received = false
      
      # Cache of generated specials (for leader to respond to requests)
      @generated_specials_cache = {}
      
      # How long to cache specials (matches specials duration of 5 hours)
      CACHE_DURATION = 18000  # 5 hours (same as RANDOM_DURATION_HOURS)
      
      class << self
        attr_accessor :leader_specials, :leader_specials_time, :specials_received
        attr_accessor :generated_specials_cache
        
        #=====================================================================
        # MULTIPLAYER DETECTION
        #=====================================================================
        
        def multiplayer_available?
          # Note: MultiplayerClient doesn't have a connected? method - use instance_variable_get
          defined?(MultiplayerClient) && MultiplayerClient.instance_variable_get(:@connected)
        end
        
        def in_squad?
          return false unless multiplayer_available?
          MultiplayerClient.in_squad?
        end
        
        def is_leader?
          return false unless in_squad?
          MultiplayerClient.is_leader?
        end
        
        def is_member?
          in_squad? && !is_leader?
        end
        
        def session_id
          return nil unless multiplayer_available?
          MultiplayerClient.session_id rescue nil
        end
        
        #=====================================================================
        # SECURITY VALIDATION
        #=====================================================================
        
        # Validate incoming shop sync data
        def validate_sync_data(data)
          return false unless data.is_a?(Hash)
          
          # Required fields
          return false unless data[:shop_key].is_a?(String) && data[:shop_key].length < 100
          return false unless data[:timestamp].is_a?(Integer)
          
          # Validate event data if present
          if data[:event]
            return false unless validate_special_data(data[:event], :event)
          end
          
          # Validate sale data if present
          if data[:sale]
            return false unless validate_special_data(data[:sale], :sale)
          end
          
          # Validate markup data if present
          if data[:markup]
            return false unless validate_special_data(data[:markup], :markup)
          end
          
          true
        end
        
        def validate_special_data(special, type)
          return false unless special.is_a?(Hash)
          return false unless special[:name].is_a?(String) && special[:name].length < 100
          
          # Validate items hash
          if special[:items]
            return false unless special[:items].is_a?(Hash)
            return false if special[:items].length > MAX_ITEMS_PER_SPECIAL
            special[:items].each do |k, v|
              return false unless k.is_a?(String) || k.is_a?(Symbol)
              return false unless v.is_a?(Integer) && v >= 0 && v <= 100
            end
          end
          
          # Event-specific validation
          if type == :event
            if special[:sale_items]
              return false unless special[:sale_items].is_a?(Hash)
              return false if special[:sale_items].length > MAX_ITEMS_PER_SPECIAL
            end
            if special[:markup_items]
              return false unless special[:markup_items].is_a?(Hash)
              return false if special[:markup_items].length > MAX_ITEMS_PER_SPECIAL
            end
          end
          
          true
        end
        
        #=====================================================================
        # SPECIALS SERIALIZATION
        #=====================================================================
        
        # Serialize current shop specials to JSON-compatible hash
        def serialize_specials(shop_key)
          return nil unless defined?(KIFR::Shop::Specials)
          
          data = {
            shop_key: shop_key,
            timestamp: Time.now.to_i,
            event: nil,
            sale: nil,
            markup: nil
          }
          
          # Get event data (global)
          if KIFR::Shop::Specials.has_active_event?
            event = KIFR::Shop::Specials.active_event
            if event
              data[:event] = {
                source: event[:source].to_s,
                name: event[:name],
                sale_items: hash_to_string_keys(event[:sale_items] || {}),
                markup_items: hash_to_string_keys(event[:markup_items] || {}),
                sale_pockets: event[:sale_pockets] || [],
                markup_pockets: event[:markup_pockets] || [],
                start_time: event[:start_time],
                duration: event[:duration],
                priority: event[:priority]
              }
            end
          end
          
          # Get random sale data (per-shop)
          sale = KIFR::Shop::Specials.random_sale
          if sale
            data[:sale] = {
              name: sale[:name],
              items: hash_to_string_keys(sale[:items] || {}),
              start_time: sale[:start_time],
              duration: sale[:duration]
            }
          end
          
          # Get random markup data (per-shop)
          markup = KIFR::Shop::Specials.random_markup
          if markup
            data[:markup] = {
              name: markup[:name],
              items: hash_to_string_keys(markup[:items] || {}),
              start_time: markup[:start_time],
              duration: markup[:duration]
            }
          end
          
          data
        end
        
        # Deserialize and apply received specials
        def apply_received_specials(data, shop_key)
          return false unless defined?(KIFR::Shop::Specials) && data
          
          debug_log("Applying leader's specials for shop #{shop_key}")
          
          # Set shop key
          KIFR::Shop::Specials.current_shop_key = shop_key
          
          # Apply event if present
          if data[:event]
            evt = data[:event]
            KIFR::Shop::Specials.active_event = {
              source: evt[:source].to_sym,
              name: evt[:name],
              sale_items: string_keys_to_symbols(evt[:sale_items] || {}),
              markup_items: string_keys_to_symbols(evt[:markup_items] || {}),
              sale_pockets: evt[:sale_pockets] || [],
              markup_pockets: evt[:markup_pockets] || [],
              start_time: evt[:start_time],
              duration: evt[:duration],
              priority: evt[:priority]
            }
            debug_log("Applied event: #{evt[:name]}")
          else
            KIFR::Shop::Specials.active_event = nil
          end
          
          # Apply random sale if present (only if no event)
          if data[:sale] && !data[:event]
            KIFR::Shop::Specials.random_sale = {
              name: data[:sale][:name],
              items: string_keys_to_symbols(data[:sale][:items] || {}),
              start_time: data[:sale][:start_time],
              duration: data[:sale][:duration]
            }
            debug_log("Applied sale: #{data[:sale][:name]}")
          end
          
          # Apply random markup if present (only if no event)
          if data[:markup] && !data[:event]
            KIFR::Shop::Specials.random_markup = {
              name: data[:markup][:name],
              items: string_keys_to_symbols(data[:markup][:items] || {}),
              start_time: data[:markup][:start_time],
              duration: data[:markup][:duration]
            }
            debug_log("Applied markup: #{data[:markup][:name]}")
          end
          
          true
        end
        
        #=====================================================================
        # NETWORK COMMUNICATION
        #=====================================================================
        
        # Leader broadcasts their specials to squad
        def broadcast_specials(shop_key)
          return unless is_leader? && multiplayer_available?
          
          data = serialize_specials(shop_key)
          return unless data
          
          # Cache the generated specials so we can respond to member requests later
          @generated_specials_cache ||= {}
          @generated_specials_cache[shop_key] = {
            data: data,
            time: Time.now.to_i
          }
          
          begin
            json = MiniJSON.dump(data)
            hex = BinHex.encode(json)
            # NOTE: Server must relay KIFR_SHOP_SYNC to squad members
            # Add KIFR_ prefix handling to server similar to COOP_ messages
            MultiplayerClient.send_data("KIFR_SHOP_SYNC:#{hex}")
            debug_log("Broadcast shop specials to squad (key: #{shop_key})")
            debug_log("Sent KIFR_SHOP_SYNC (#{hex.length} chars) for shop #{shop_key}")
          rescue => e
            debug_log("Failed to broadcast specials: #{e.message}")
          end
        end
        
        # Member requests specials from leader
        def request_specials(shop_key)
          return unless is_member? && multiplayer_available?
          
          begin
            MultiplayerClient.send_data("KIFR_SHOP_REQ:#{shop_key}")
            debug_log("Requested specials from leader for shop #{shop_key}")
            debug_log("Sent KIFR_SHOP_REQ:#{shop_key}")
          rescue => e
            debug_log("Failed to request specials: #{e.message}")
          end
        end
        
        # Handle received specials (called from network handler)
        def handle_shop_sync(hex_data)
          begin
            # Security: Size check
            if hex_data.to_s.length > MAX_MESSAGE_SIZE * 2
              debug_log("Rejected shop sync: data too large (#{hex_data.length} chars)")
              return
            end
            
            json = BinHex.decode(hex_data)
            data = MiniJSON.parse(json)
            
            # Convert string keys to symbols for nested hashes
            data = symbolize_keys(data)
            
            # Security: Validate data structure
            unless validate_sync_data(data)
              debug_log("Rejected shop sync: invalid data structure")
              return
            end
            
            @leader_specials = data
            @leader_specials_time = Time.now.to_i
            @specials_received = true
            
            debug_log("Received shop specials from leader (key: #{data[:shop_key]})")
          rescue => e
            debug_log("Failed to parse received specials: #{e.message}")
          end
        end
        
        # Handle specials request (leader receives this)
        # If leader has cached specials for this shop, send them
        # If not, generate new specials for this shop and send them
        def handle_shop_request(from_sid, shop_key)
          return unless is_leader?
          
          # Security: Validate shop_key
          return if shop_key.to_s.length > 100
          
          @generated_specials_cache ||= {}
          
          # Check if we have cached specials for this shop key
          cached = @generated_specials_cache[shop_key]
          if cached && (Time.now.to_i - cached[:time]) < CACHE_DURATION
            # Use cached specials
            debug_log("Using cached specials for #{shop_key} (requested by #{from_sid})")
            send_cached_specials(cached[:data])
          else
            # Generate new specials for this shop
            debug_log("Generating new specials for #{shop_key} (requested by #{from_sid})")
            generate_specials_for_request(shop_key)
          end
        end
        
        # Send cached specials data directly
        def send_cached_specials(data)
          return unless multiplayer_available? && data
          
          begin
            json = MiniJSON.dump(data)
            hex = BinHex.encode(json)
            MultiplayerClient.send_data("KIFR_SHOP_SYNC:#{hex}")
            debug_log("Sent cached specials to squad")
          rescue => e
            debug_log("Failed to send cached specials: #{e.message}")
          end
        end
        
        # Generate specials for a shop when requested by a member
        # This runs the activation logic on the leader's side for the given shop key
        def generate_specials_for_request(shop_key)
          return unless defined?(KIFR::Shop::Specials)
          
          # Temporarily set the shop key so specials generate for that shop
          old_key = KIFR::Shop::Specials.current_shop_key
          KIFR::Shop::Specials.current_shop_key = shop_key
          
          # Activate random specials (skip if there's already an active event)
          # Events are global, so they'll apply regardless
          unless KIFR::Shop::Specials.has_active_event?
            # Generate random sale/markup for this shop key
            # We call the internal methods directly since we don't have stock
            generate_random_for_shop_key(shop_key)
          end
          
          # Serialize and broadcast
          data = serialize_specials(shop_key)
          if data
            # Cache it
            @generated_specials_cache ||= {}
            @generated_specials_cache[shop_key] = {
              data: data,
              time: Time.now.to_i
            }
            
            # Send to squad
            send_cached_specials(data)
          end
          
          # Restore old shop key
          KIFR::Shop::Specials.current_shop_key = old_key
        end
        
        # Generate random specials for a specific shop key without stock
        def generate_random_for_shop_key(shop_key)
          return unless defined?(KIFR::Shop::Specials)
          
          # Check if this shop already has randoms stored
          existing = KIFR::Shop::Specials.get_shop_randoms(shop_key)
          if existing
            # Load existing randoms
            if existing[:sale]
              KIFR::Shop::Specials.random_sale = existing[:sale]
              debug_log("Loaded existing sale for #{shop_key}: #{existing[:sale][:name]}")
            end
            if existing[:markup]
              KIFR::Shop::Specials.random_markup = existing[:markup]
              debug_log("Loaded existing markup for #{shop_key}: #{existing[:markup][:name]}")
            end
            return
          end
          
          # No existing randoms - generate new ones
          # Since we don't have stock, we'll generate with random items from settings
          # This creates a "generic" special that will apply to whatever items the shop has
          
          settings = KIFR::Shop::Specials.settings
          return unless settings && settings[:random_sale]
          
          now = KIFR::Shop::Specials::Core.current_time
          
          # Try to generate a sale
          if rand(100) < (settings[:random_sale][:chance] || 15)
            sale_name = (settings[:random_sale][:names] || ["Flash Sale"]).sample
            discount = rand((settings[:random_sale][:discount_range] || (10..30)))
            duration = (settings[:random_sale][:duration] || 1800)
            
            # Generate sale for random pockets (1-2 pockets)
            available_pockets = [1, 2, 3, 4, 5]  # Item pockets
            selected_pockets = available_pockets.sample(rand(1..2))
            
            sale_data = {
              name: sale_name,
              items: {},  # Will be filtered by stock when applied
              pockets: selected_pockets,
              discount: discount,
              start_time: now,
              duration: duration
            }
            
            KIFR::Shop::Specials.random_sale = sale_data
            KIFR::Shop::Specials.store_shop_random(shop_key, :sale, sale_data)
            debug_log("Generated sale for #{shop_key}: #{sale_name} (#{discount}% off pockets #{selected_pockets.inspect})")
          end
          
          # Try to generate a markup
          if rand(100) < (settings[:random_markup][:chance] || 10)
            markup_name = (settings[:random_markup][:names] || ["Supply Shortage"]).sample
            increase = rand((settings[:random_markup][:increase_range] || (10..25)))
            duration = (settings[:random_markup][:duration] || 1800)
            
            # Generate markup for random pockets (1 pocket)
            available_pockets = [1, 2, 3, 4]
            selected_pockets = available_pockets.sample(1)
            
            markup_data = {
              name: markup_name,
              items: {},
              pockets: selected_pockets,
              increase: increase,
              start_time: now,
              duration: duration
            }
            
            KIFR::Shop::Specials.random_markup = markup_data
            KIFR::Shop::Specials.store_shop_random(shop_key, :markup, markup_data)
            debug_log("Generated markup for #{shop_key}: #{markup_name} (#{increase}% up on pockets #{selected_pockets.inspect})")
          end
        end
        
        #=====================================================================
        # SHOP INTEGRATION
        #=====================================================================
        
        # Called when entering a shop - decides whether to sync or use local
        def on_enter_shop(stock)
          # Debug: Log multiplayer state
          debug_log("on_enter_shop called")
          debug_log("  multiplayer_available? = #{multiplayer_available?}")
          debug_log("  in_squad? = #{in_squad?}")
          debug_log("  is_leader? = #{is_leader?}")
          debug_log("  is_member? = #{is_member?}")
          
          return :local unless in_squad?
          
          shop_key = generate_shop_key(stock)
          debug_log("  shop_key = #{shop_key}")
          
          if is_leader?
            # Leader generates specials normally, then broadcasts to squad
            debug_log("Leader entering shop #{shop_key} - will broadcast after activation")
            debug_log("Returning :leader")
            return :leader
          else
            # Member checks for cached leader specials
            if should_use_leader_specials?(shop_key)
              apply_received_specials(@leader_specials, shop_key)
              debug_log("Member using leader's specials for #{shop_key}")
              debug_log("Returning :synced (using cached)")
              return :synced
            else
              # Request specials from leader
              request_specials(shop_key)
              debug_log("Member requesting specials for #{shop_key}")
              debug_log("Returning :requested")
              return :requested
            end
          end
        end
        
        # Called after leader's specials are activated
        def on_leader_specials_activated(shop_key)
          return unless is_leader?
          broadcast_specials(shop_key)
        end
        
        # Check if cached leader specials are valid for this shop
        def should_use_leader_specials?(shop_key)
          return false unless @leader_specials && @leader_specials_time
          return false unless @leader_specials[:shop_key] == shop_key
          
          # Check if cache is still fresh
          age = Time.now.to_i - @leader_specials_time
          age < CACHE_DURATION
        end
        
        # Clear cached specials
        def clear_cache
          @leader_specials = nil
          @leader_specials_time = nil
          @specials_received = false
          @generated_specials_cache = {}
        end
        
        #=====================================================================
        # HELPER METHODS
        #=====================================================================
        
        def generate_shop_key(stock)
          return nil unless defined?(KIFR::Shop::Specials)
          KIFR::Shop::Specials.generate_shop_key(stock)
        end
        
        def hash_to_string_keys(hash)
          return {} unless hash.is_a?(Hash)
          result = {}
          hash.each { |k, v| result[k.to_s] = v }
          result
        end
        
        def string_keys_to_symbols(hash)
          return {} unless hash.is_a?(Hash)
          result = {}
          hash.each { |k, v| result[k.to_sym] = v }
          result
        end
        
        def symbolize_keys(obj)
          case obj
          when Hash
            result = {}
            obj.each { |k, v| result[k.to_s.to_sym] = symbolize_keys(v) }
            result
          when Array
            obj.map { |v| symbolize_keys(v) }
          else
            obj
          end
        end
        
        def debug_log(message)
          return unless defined?(KIFRSettings) && KIFRSettings.respond_to?(:debug_log)
          KIFRSettings.debug_log("MP::ShopSync: #{message}")
        end
      end
    end
  end
end

#===============================================================================
# HOOK: Specials Activation - Broadcast after leader generates specials
#===============================================================================
if defined?(KIFR::Shop::Specials)
  module KIFR
    module Shop
      module Specials
        class << self
          # Alias the original activation method
          unless method_defined?(:mp_orig_maybe_activate_special)
            alias mp_orig_maybe_activate_special maybe_activate_special
          end
          
          def maybe_activate_special(stock)
            # Check multiplayer sync mode
            sync_mode = KIFR::MP::ShopSync.on_enter_shop(stock)
            
            case sync_mode
            when :synced
              # Member using leader's specials - skip normal activation
              Core.debug_log("MP: Using synced specials from leader")
              return
            when :leader
              # Leader - run normal activation then broadcast
              mp_orig_maybe_activate_special(stock)
              shop_key = current_shop_key
              KIFR::MP::ShopSync.on_leader_specials_activated(shop_key)
              return
            when :requested
              # Member requested specials - run normal activation as fallback
              # (will be overwritten if leader responds in time)
              mp_orig_maybe_activate_special(stock)
              return
            else
              # Not in squad or multiplayer - normal behavior
              mp_orig_maybe_activate_special(stock)
            end
          end
        end
      end
    end
  end
end

#===============================================================================
# KIFR MESSAGE HANDLER SYSTEM
#===============================================================================
# Global registry for KIFR multiplayer message handlers
# Other KIFR modules can register their own handlers here
#===============================================================================
module KIFRMPHandlers
  @handlers = {}
  
  class << self
    # Register a handler for messages starting with a prefix
    def register(prefix, &block)
      @handlers[prefix] = block
      KIFRSettings.debug_log("KIFRMPHandlers: Registered handler for #{prefix}") if defined?(KIFRSettings)
    end
    
    # Process a message, returns true if handled
    def process(from_sid, payload)
      return false unless payload.is_a?(String)
      
      @handlers.each do |prefix, handler|
        if payload.start_with?(prefix)
          begin
            handler.call(from_sid, payload.sub(prefix, ""))
            return true
          rescue => e
            if defined?(KIFRSettings)
              KIFRSettings.debug_log("KIFRMPHandlers: Error in #{prefix} handler: #{e.message}")
            end
          end
        end
      end
      
      false
    end
    
    # List registered handlers (for debugging)
    def registered_handlers
      @handlers.keys
    end
  end
end

# Register KIFR Shop Sync handlers
KIFRMPHandlers.register("KIFR_SHOP_SYNC:") do |from_sid, data|
  KIFRSettings.debug_log("MP::ShopSync: Received KIFR_SHOP_SYNC from #{from_sid}") if defined?(KIFRSettings)
  KIFR::MP::ShopSync.handle_shop_sync(data)
end

KIFRMPHandlers.register("KIFR_SHOP_REQ:") do |from_sid, data|
  KIFRSettings.debug_log("MP::ShopSync: Received KIFR_SHOP_REQ from #{from_sid}: #{data}") if defined?(KIFRSettings)
  KIFR::MP::ShopSync.handle_shop_request(from_sid, data)
end

#===============================================================================
# MULTIPLAYER CLIENT EXTENSION
#===============================================================================
# Adds the handle_kifr_from_message method to MultiplayerClient
# This is called from the single line added to 002_Client.rb
#===============================================================================
if defined?(MultiplayerClient)
  module MultiplayerClient
    class << self
      # Handle KIFR messages received from network
      # Called from: elsif payload.start_with?("KIFR_") in 002_Client.rb
      def handle_kifr_from_message(from_sid, payload)
        KIFRSettings.debug_log("MP::ShopSync: handle_kifr_from_message called: from=#{from_sid}, payload=#{payload[0..50]}...") if defined?(KIFRSettings)
        
        return false unless payload.is_a?(String) && payload.start_with?("KIFR_")
        
        # Route to KIFR handlers
        if defined?(KIFRMPHandlers) && KIFRMPHandlers.respond_to?(:process)
          begin
            KIFRSettings.debug_log("MP::ShopSync: Routing to KIFRMPHandlers.process") if defined?(KIFRSettings)
            result = KIFRMPHandlers.process(from_sid, payload)
            KIFRSettings.debug_log("MP::ShopSync: KIFRMPHandlers.process result: #{result}") if defined?(KIFRSettings)
            return result
          rescue => e
            KIFRSettings.debug_log("MP::ShopSync: Error: #{e.message}\n#{e.backtrace[0..3].join("\n")}") if defined?(KIFRSettings)
            return false
          end
        else
          KIFRSettings.debug_log("MP::ShopSync: KIFRMPHandlers not defined!") if defined?(KIFRSettings)
        end
        
        false
      end
    end
  end
end

#===============================================================================
# EVENT: Squad state changes
#===============================================================================
# Clear shop sync cache when leaving squad
if defined?(EventManager)
  EventManager.subscribe(:squad_left) do
    KIFR::MP::ShopSync.clear_cache
    KIFR::MP::ShopSync.debug_log("Cleared shop sync cache (left squad)")
  end
  
  EventManager.subscribe(:squad_kicked) do
    KIFR::MP::ShopSync.clear_cache
    KIFR::MP::ShopSync.debug_log("Cleared shop sync cache (kicked from squad)")
  end
end

#===============================================================================
# INITIALIZATION
#===============================================================================
KIFRSettings.debug_log("KIFR MP Shop Sync loaded (v1.1.0 - with security validation)") if defined?(KIFRSettings)
