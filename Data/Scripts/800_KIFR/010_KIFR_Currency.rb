#===============================================================================
# KIF Redux Multi-Currency System
# Script Version: 1.2.0
# Author: Stonewall
#===============================================================================
# This module provides a flexible multi-currency system that supports:
# - Poké Dollars (default game currency)
# - Platinum (multiplayer server currency)
# - Battle Points (BP)
# - Custom event currencies
#
# Each currency has:
# - ID (symbol like :money, :platinum, :bp)
# - Display name ("₽", "Pt", "BP")
# - Icon/Sprite (optional graphic - use instead of symbol if set)
# - Balance getter/setter methods
# - Validation rules
#
# Sprite Support:
#   If a currency has an icon set, use KIFR::Currency.format_with_sprite()
#   to get sprite info for rendering, or format() with use_icon=true
#
# Usage:
#   KIFR::Currency.get_balance(:money)
#   KIFR::Currency.can_afford?(:platinum, 100)
#   KIFR::Currency.spend(:bp, 50)
#   KIFR::Currency.add(:money, 1000)
#===============================================================================

module KIFR
  module Currency
    #===========================================================================
    # Currency Registry - Define all available currencies
    #===========================================================================
    CURRENCIES = {}
    
    # Register a new currency
    # @param id [Symbol] Unique identifier (:money, :platinum, :bp, etc.)
    # @param config [Hash] Configuration options
    #   :name [String] Display name ("Poké Dollars", "Platinum", etc.)
    #   :symbol [String] Currency symbol ("$", "Pt", "BP")
    #   :icon [String] Path to icon graphic (optional)
    #   :get_balance [Proc] Lambda to get current balance
    #   :set_balance [Proc] Lambda to set balance (for local currencies)
    #   :can_spend [Proc] Lambda to check if spending is allowed
    #   :spend [Proc] Lambda to actually spend (for server currencies)
    #   :add [Proc] Lambda to add currency (for local currencies)
    #   :max [Integer] Maximum balance (nil = unlimited)
    #   :color [Color] Display color (optional)
    def self.register(id, config)
      CURRENCIES[id] = CurrencyDef.new(id, config)
      Core.debug_log("Registered currency: #{id}") if defined?(Core)
    end
    
    # Get a registered currency definition
    def self.get(id)
      CURRENCIES[id]
    end
    
    # Check if a currency is registered
    def self.exists?(id)
      CURRENCIES.key?(id)
    end
    
    # Get all registered currency IDs
    def self.all_ids
      CURRENCIES.keys
    end
    
    #===========================================================================
    # Currency Operations - Universal interface
    #===========================================================================
    
    # Get the current balance of a currency
    # @param id [Symbol] Currency ID
    # @return [Integer] Current balance, 0 if not available
    def self.get_balance(id)
      currency = get(id)
      return 0 unless currency
      currency.get_balance
    end
    
    # Check if player can afford an amount
    # @param id [Symbol] Currency ID
    # @param amount [Integer] Amount to check
    # @return [Boolean] True if balance >= amount
    def self.can_afford?(id, amount)
      currency = get(id)
      return false unless currency
      currency.can_afford?(amount)
    end
    
    # Spend currency (deduct from balance)
    # @param id [Symbol] Currency ID
    # @param amount [Integer] Amount to spend
    # @param reason [String] Optional reason for logging
    # @return [Boolean] True if successful
    def self.spend(id, amount, reason = "purchase")
      currency = get(id)
      return false unless currency
      currency.spend(amount, reason)
    end
    
    # Add currency to balance
    # @param id [Symbol] Currency ID
    # @param amount [Integer] Amount to add
    # @param reason [String] Optional reason for logging
    # @return [Boolean] True if successful
    def self.add(id, amount, reason = "reward")
      currency = get(id)
      return false unless currency
      currency.add(amount, reason)
    end
    
    # Format an amount for display
    # @param id [Symbol] Currency ID
    # @param amount [Integer] Amount to format
    # @return [String] Formatted string like "$1,000" or "100 Pt"
    def self.format(id, amount)
      currency = get(id)
      return amount.to_s unless currency
      currency.format(amount)
    end
    
    # Get display name for currency
    # @param id [Symbol] Currency ID
    # @return [String] Display name
    def self.name(id)
      currency = get(id)
      return id.to_s unless currency
      currency.name
    end
    
    # Get symbol for currency
    # @param id [Symbol] Currency ID  
    # @return [String] Symbol like "₽" or "Pt"
    def self.symbol(id)
      currency = get(id)
      return "" unless currency
      currency.symbol
    end
    
    # Get a text-window-safe symbol (for Window_AdvancedTextPokemon which can't render some Unicode)
    # @param id [Symbol] Currency ID
    # @return [String] Safe symbol like "$" or "Pt"
    def self.safe_symbol(id)
      currency = get(id)
      return "" unless currency
      currency.safe_symbol
    end
    
    # Get icon/sprite path for currency
    # @param id [Symbol] Currency ID
    # @return [String, nil] Icon path or nil if no icon
    def self.icon(id)
      currency = get(id)
      return nil unless currency
      currency.icon
    end
    
    # Check if currency has a sprite/icon
    # @param id [Symbol] Currency ID
    # @return [Boolean] True if icon is set
    def self.has_icon?(id)
      !icon(id).nil?
    end
    
    # Get formatted display with sprite info (for UI rendering)
    # @param id [Symbol] Currency ID
    # @param amount [Integer] Amount to format
    # @return [Hash] { icon: path_or_nil, symbol: "₽", amount: "1,000", text: "₽ 1,000" }
    def self.format_with_sprite(id, amount)
      currency = get(id)
      return { icon: nil, symbol: "", amount: amount.to_s, text: amount.to_s } unless currency
      currency.format_with_sprite(amount)
    end
    
    #===========================================================================
    # CurrencyDef - Individual currency definition
    #===========================================================================
    class CurrencyDef
      attr_reader :id, :name, :symbol, :safe_symbol, :icon, :max, :color
      
      def initialize(id, config)
        @id = id
        @name = config[:name] || id.to_s.capitalize
        @symbol = config[:symbol] || ""
        @safe_symbol = config[:safe_symbol] || @symbol  # Fallback for text windows
        @icon = config[:icon]  # Path to sprite, e.g., "Graphics/Pictures/Currency/money"
        @max = config[:max]
        @color = config[:color]
        
        # Function hooks
        @get_balance_proc = config[:get_balance]
        @set_balance_proc = config[:set_balance]
        @can_spend_proc = config[:can_spend]
        @spend_proc = config[:spend]
        @add_proc = config[:add]
      end
      
      def get_balance
        return 0 unless @get_balance_proc
        begin
          @get_balance_proc.call
        rescue => e
          KIFR::Currency.log_error("get_balance", @id, e)
          0
        end
      end
      
      def can_afford?(amount)
        return false if amount <= 0
        
        # Custom check if provided
        if @can_spend_proc
          begin
            return @can_spend_proc.call(amount)
          rescue => e
            KIFR::Currency.log_error("can_afford?", @id, e)
            return false
          end
        end
        
        # Default: check balance
        get_balance >= amount
      end
      
      def spend(amount, reason = "purchase")
        return false if amount <= 0
        return false unless can_afford?(amount)
        
        old_balance = get_balance
        
        # Custom spend logic (for server currencies)
        if @spend_proc
          begin
            result = @spend_proc.call(amount, reason)
            KIFR::Currency.debug_log("SPEND #{@id}: #{amount} (#{reason}) - old: #{old_balance}, new: #{get_balance}, success: #{result}")
            return result
          rescue => e
            KIFR::Currency.log_error("spend", @id, e)
            return false
          end
        end
        
        # Default: deduct from balance via setter
        if @set_balance_proc
          begin
            new_balance = [get_balance - amount, 0].max
            @set_balance_proc.call(new_balance)
            KIFR::Currency.debug_log("SPEND #{@id}: #{amount} (#{reason}) - old: #{old_balance}, new: #{new_balance}")
            return true
          rescue => e
            KIFR::Currency.log_error("spend/set", @id, e)
            return false
          end
        end
        
        false
      end
      
      def add(amount, reason = "reward")
        return false if amount <= 0
        
        old_balance = get_balance
        
        # Custom add logic
        if @add_proc
          begin
            result = @add_proc.call(amount, reason)
            KIFR::Currency.debug_log("ADD #{@id}: #{amount} (#{reason}) - old: #{old_balance}, new: #{get_balance}, success: #{result}")
            return result
          rescue => e
            KIFR::Currency.log_error("add", @id, e)
            return false
          end
        end
        
        # Default: add via setter
        if @set_balance_proc
          begin
            new_balance = get_balance + amount
            new_balance = [@max, new_balance].min if @max
            @set_balance_proc.call(new_balance)
            KIFR::Currency.debug_log("ADD #{@id}: #{amount} (#{reason}) - old: #{old_balance}, new: #{new_balance}")
            return true
          rescue => e
            KIFR::Currency.log_error("add/set", @id, e)
            return false
          end
        end
        
        false
      end
      
      # Format amount for display - symbol ALWAYS before price
      # @param amount [Integer] Amount to format
      # @param use_icon [Boolean] If true, returns hash with icon info (for sprite display)
      # @return [String or Hash] Formatted string like "₽ 1,000" or hash with icon info
      def format(amount, use_icon = false)
        formatted = format_number(amount)
        
        if use_icon && @icon
          # Return hash with icon info for sprite rendering
          return { icon: @icon, symbol: @symbol, amount: formatted, text: "#{@symbol} #{formatted}".strip }
        end
        
        # Symbol always comes BEFORE the amount
        "#{@symbol} #{formatted}".strip
      end
      
      # Get just the formatted number (no symbol)
      def format_number(amount)
        amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      end
      
      # Format with full sprite info for UI rendering
      # @param amount [Integer] Amount to format
      # @return [Hash] { icon: path_or_nil, symbol: "₽", amount: "1,000", text: "₽ 1,000" }
      def format_with_sprite(amount)
        formatted = format_number(amount)
        {
          icon: @icon,
          symbol: @symbol,
          amount: formatted,
          text: "#{@symbol} #{formatted}".strip,
          color: @color
        }
      end
      
      # Check if this currency uses a sprite icon
      def has_icon?
        !@icon.nil? && !@icon.empty?
      end
    end
    
    #===========================================================================
    # Error & Debug Logging
    #===========================================================================
    def self.log_error(operation, currency_id, error)
      msg = "Currency error [#{currency_id}] #{operation}: #{error.message}"
      KIFRSettings.debug_log(msg) if defined?(KIFRSettings)
    end
    
    def self.debug_log(message)
      if defined?(KIFRSettings) && KIFRSettings.respond_to?(:debug_log)
        KIFRSettings.debug_log("Economy::Currency: #{message}")
      end
    end
    
    #===========================================================================
    # Register Default Currencies
    #===========================================================================
    def self.register_defaults
      # Poké Dollars (standard currency)
      register(:money, {
        name: "Money",
        symbol: "₽",                     # Pokémon currency symbol (for direct bitmap drawing)
        safe_symbol: "$",                # Fallback for text windows that can't render ₽
        icon: "Graphics/Pictures/Currency/pokedollar",  # Optional sprite
        max: 9_999_999,
        color: Color.new(255, 215, 0), # Gold
        get_balance: -> { 
          defined?($Trainer) && $Trainer ? $Trainer.money : 0 
        },
        set_balance: ->(val) { 
          $Trainer.money = val if defined?($Trainer) && $Trainer
        }
      })
      
      # Battle Points
      register(:bp, {
        name: "Battle Points",
        symbol: "BP",
        icon: "Graphics/Pictures/Currency/bp",  # Optional sprite
        max: 9_999,
        color: Color.new(100, 200, 255), # Light blue
        get_balance: -> {
          if defined?($Trainer) && $Trainer.respond_to?(:battle_points)
            $Trainer.battle_points
          elsif defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:battle_points)
            $PokemonGlobal.battle_points || 0
          else
            0
          end
        },
        set_balance: ->(val) {
          if defined?($Trainer) && $Trainer.respond_to?(:battle_points=)
            $Trainer.battle_points = val
          elsif defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:battle_points=)
            $PokemonGlobal.battle_points = val
          end
        }
      })
      
      # Platinum (Multiplayer server currency)
      register(:platinum, {
        name: "Platinum",
        symbol: "Pt",
        icon: "Graphics/Pictures/Currency/platinum",  # Optional sprite
        color: Color.new(200, 200, 220), # Platinum/silver
        get_balance: -> {
          if defined?(MultiplayerPlatinum)
            # Try cached balance first, then query server
            MultiplayerPlatinum.cached_balance
          else
            0
          end
        },
        can_spend: ->(amount) {
          if defined?(MultiplayerPlatinum)
            MultiplayerPlatinum.can_afford?(amount)
          else
            false
          end
        },
        spend: ->(amount, reason) {
          if defined?(MultiplayerPlatinum)
            MultiplayerPlatinum.spend(amount, reason)
          else
            false
          end
        },
        add: ->(amount, reason) {
          # Platinum is server-authoritative, can't add locally
          # Would need a server command for rewards
          false
        }
      })
      
      # Casino Coins (if game has casino)
      register(:coins, {
        name: "Casino Coins", 
        symbol: "C",
        icon: "Graphics/Pictures/Currency/coins",  # Optional sprite
        max: 99_999,
        color: Color.new(255, 215, 100), # Gold-ish
        get_balance: -> {
          if defined?($Trainer) && $Trainer.respond_to?(:coins)
            $Trainer.coins
          elsif defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:coins)
            $PokemonGlobal.coins || 0
          else
            0
          end
        },
        set_balance: ->(val) {
          if defined?($Trainer) && $Trainer.respond_to?(:coins=)
            $Trainer.coins = val
          elsif defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:coins=)
            $PokemonGlobal.coins = val
          end
        }
      })
    end
  end
end

#===============================================================================
# Initialize default currencies on load
#===============================================================================
KIFR::Currency.register_defaults

#===============================================================================
# Multi-Currency Shop Adapter
# Extends PokemonMartAdapter to support alternative currencies
#===============================================================================
class MultiCurrencyMartAdapter < PokemonMartAdapter
  attr_reader :currency_id, :currency_name
  
  # Initialize with a specific currency
  # @param currency_id [Symbol] Currency to use (:money, :platinum, :bp, etc.)
  def initialize(currency_id = :money)
    @currency_id = currency_id
    @currency = KIFR::Currency.get(currency_id)
    @currency_name = @currency ? @currency.name : "Money"
  end
  
  def getMoney
    KIFR::Currency.get_balance(@currency_id)
  end
  
  def getMoneyString
    KIFR::Currency.format(@currency_id, getMoney)
  end
  
  def setMoney(value)
    current = getMoney
    diff = value - current
    
    if diff > 0
      KIFR::Currency.add(@currency_id, diff, "shop")
    elsif diff < 0
      KIFR::Currency.spend(@currency_id, -diff, "shop")
    end
  end
  
  # Override price display to show correct currency symbol
  def getDisplayPrice(item, selling = false)
    price = getPrice(item, selling)
    KIFR::Currency.format(@currency_id, price)
  end
  
  # Get the currency symbol for UI display
  def getCurrencySymbol
    KIFR::Currency.symbol(@currency_id)
  end
  
  # Get currency color for UI
  def getCurrencyColor
    @currency&.color || Color.new(255, 255, 255)
  end
end

#===============================================================================
# Helper Functions for Events
#===============================================================================
def pbMultiCurrencyMart(stock, currency_id = :money, speech = nil)
  # Validate currency exists
  unless KIFR::Currency.exists?(currency_id)
    pbMessage(_INTL("Error: Unknown currency type."))
    return
  end
  
  currency_name = KIFR::Currency.name(currency_id)
  
  # Default speech
  if speech.nil?
    case currency_id
    when :money
      speech = _INTL("Welcome! How may I help you?")
    when :platinum
      speech = _INTL("Welcome to the Platinum Shop! All prices are in Platinum currency.")
    when :bp
      speech = _INTL("Welcome! You can exchange your Battle Points here.")
    when :coins
      speech = _INTL("Welcome to the Game Corner prize exchange!")
    else
      speech = _INTL("Welcome! Prices are in {1}.", currency_name)
    end
  end
  
  pbMessage(speech)
  
  # Create adapter with specified currency
  adapter = MultiCurrencyMartAdapter.new(currency_id)
  
  # Run the mart
  scene = PokemonMart_Scene.new
  screen = PokemonMartScreen.new(scene, stock, adapter)
  screen.pbBuyScreen
  
  pbMessage(_INTL("Please come again!"))
end

# Convenience functions for specific currencies
def pbPlatinumMart(stock, speech = nil)
  # Check if multiplayer is connected
  if defined?(MultiplayerPlatinum) && KIFR::Currency::Shop.multiplayer_connected?
    # Refresh balance from server before opening shop
    MultiplayerPlatinum.get_balance
    pbMultiCurrencyMart(stock, :platinum, speech)
  else
    pbMessage(_INTL("This shop requires a multiplayer connection."))
  end
end

def pbBPMart(stock, speech = nil)
  pbMultiCurrencyMart(stock, :bp, speech)
end

def pbCoinMart(stock, speech = nil)
  pbMultiCurrencyMart(stock, :coins, speech)
end

#===============================================================================
# Event Commands for Currency Management
#===============================================================================
# Give currency to player
def pbGiveCurrency(currency_id, amount, show_message = true)
  return false unless KIFR::Currency.exists?(currency_id)
  
  result = KIFR::Currency.add(currency_id, amount, "event_reward")
  
  if result && show_message
    currency_name = KIFR::Currency.name(currency_id)
    formatted = KIFR::Currency.format(currency_id, amount)
    pbMessage(_INTL("\\se[Mart buy item]Obtained {1}!", formatted))
  end
  
  result
end

# Take currency from player
def pbTakeCurrency(currency_id, amount, show_message = true)
  return false unless KIFR::Currency.exists?(currency_id)
  return false unless KIFR::Currency.can_afford?(currency_id, amount)
  
  result = KIFR::Currency.spend(currency_id, amount, "event_cost")
  
  if result && show_message
    formatted = KIFR::Currency.format(currency_id, amount)
    pbMessage(_INTL("Paid {1}.", formatted))
  end
  
  result
end

# Check if player has enough currency
def pbHasCurrency?(currency_id, amount)
  KIFR::Currency.can_afford?(currency_id, amount)
end

# Get current balance
def pbGetCurrency(currency_id)
  KIFR::Currency.get_balance(currency_id)
end

# Display current balance
def pbShowCurrencyBalance(currency_id)
  return unless KIFR::Currency.exists?(currency_id)
  
  currency_name = KIFR::Currency.name(currency_id)
  formatted = KIFR::Currency.format(currency_id, KIFR::Currency.get_balance(currency_id))
  
  pbMessage(_INTL("You have {1}.", formatted))
end

#===============================================================================
# Register custom event currency (for special events)
#===============================================================================
def pbRegisterEventCurrency(id, name, symbol, options = {})
  # Store in $PokemonGlobal for persistence
  $PokemonGlobal.event_currencies ||= {}
  $PokemonGlobal.event_currencies[id] ||= 0
  
  KIFR::Currency.register(id, {
    name: name,
    symbol: symbol,
    max: options[:max] || 99_999,
    color: options[:color],
    get_balance: -> { 
      ($PokemonGlobal.event_currencies || {})[id] || 0 
    },
    set_balance: ->(val) {
      $PokemonGlobal.event_currencies ||= {}
      $PokemonGlobal.event_currencies[id] = val
    }
  })
end

#===============================================================================
# PokemonGlobalMetadata Extension for Event Currencies
#===============================================================================
class PokemonGlobalMetadata
  attr_accessor :event_currencies  # Hash of { currency_id => balance }
  attr_accessor :battle_points     # BP storage if not elsewhere
  
  alias kifr_currency_orig_initialize initialize unless method_defined?(:kifr_currency_orig_initialize)
  
  def initialize
    kifr_currency_orig_initialize
    @event_currencies ||= {}
    @battle_points ||= 0
  end
end

#===============================================================================
# Currency Shop Scene Extensions - Show correct currency in shop UI
#===============================================================================
# This module modifies the PokemonMart_Scene to display the correct currency
# when using MultiCurrencyMartAdapter
#===============================================================================
module KIFR
  module Currency
    module ShopUI
      # Get the currency symbol/name for display in shop UI
      def self.get_shop_currency_display(adapter)
        if adapter.is_a?(MultiCurrencyMartAdapter)
          KIFR::Currency.symbol(adapter.currency_id)
        else
          "$" # Default
        end
      end
      
      # Format price for shop display
      def self.format_shop_price(adapter, price)
        if adapter.is_a?(MultiCurrencyMartAdapter)
          KIFR::Currency.format(adapter.currency_id, price)
        else
          "$#{price.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
        end
      end
    end
  end
end

#===============================================================================
# Advanced Currency Shop - With Custom Prices per Item
#===============================================================================
# This allows you to create shops where items have custom prices
# that are different from their normal prices
#
# Example usage:
#   stock = {
#     :POTION => 5,           # 5 platinum for a Potion
#     :SUPERPOTION => 10,
#     :HYPERPOTION => 20,
#     :REVIVE => 30
#   }
#   pbCustomCurrencyMart(stock, :platinum, "Welcome to the Platinum Shop!")
#===============================================================================
def pbCustomCurrencyMart(stock_with_prices, currency_id = :money, speech = nil)
  # Validate currency exists
  unless KIFR::Currency.exists?(currency_id)
    pbMessage(_INTL("Error: Unknown currency type."))
    return
  end
  
  # For platinum, check multiplayer connection
  if currency_id == :platinum
    unless defined?(MultiplayerPlatinum) && KIFR::Currency::Shop.multiplayer_connected?
      pbMessage(_INTL("This shop requires a multiplayer connection."))
      return
    end
    MultiplayerPlatinum.get_balance
  end
  
  currency_name = KIFR::Currency.name(currency_id)
  
  # Default speech
  if speech.nil?
    speech = _INTL("Welcome! All prices are in {1}.", currency_name)
  end
  
  pbMessage(speech)
  
  # Create custom adapter with price overrides
  adapter = CustomPriceMartAdapter.new(currency_id, stock_with_prices)
  
  # Extract just item IDs for stock
  stock = stock_with_prices.keys
  
  # Run the mart
  scene = PokemonMart_Scene.new
  screen = PokemonMartScreen.new(scene, stock, adapter)
  screen.pbBuyScreen
  
  pbMessage(_INTL("Please come again!"))
end

#===============================================================================
# Custom Price Mart Adapter - Supports custom prices per item
#===============================================================================
class CustomPriceMartAdapter < MultiCurrencyMartAdapter
  # Initialize with currency and price overrides
  # @param currency_id [Symbol] Currency to use
  # @param price_map [Hash] Map of item_id => custom_price
  def initialize(currency_id, price_map = {})
    super(currency_id)
    @price_map = {}
    
    # Normalize price map keys to symbols
    price_map.each do |item, price|
      item_id = item.is_a?(Symbol) ? item : GameData::Item.get(item).id rescue item
      @price_map[item_id] = price
    end
  end
  
  # Override getPrice to return custom prices
  def getPrice(item, selling = false)
    return 0 if selling # Can't sell in custom currency shops
    
    item_id = item.is_a?(Symbol) ? item : GameData::Item.get(item).id rescue item
    
    # Return custom price if set
    if @price_map.key?(item_id)
      return @price_map[item_id]
    end
    
    # Fall back to normal price (shouldn't happen in custom shops)
    super
  end
  
  # Disable selling in custom currency shops
  def canSell?
    false
  end
end

#===============================================================================
# Quick Currency Check Dialog - For events/NPCs
#===============================================================================
# Show a dialog asking if player wants to spend currency
# Returns true if confirmed and currency was spent
#
# Example:
#   if pbConfirmCurrencySpend(:platinum, 100, "Buy this rare item?")
#     pbReceiveItem(:RARECANDY)
#   end
#===============================================================================
def pbConfirmCurrencySpend(currency_id, amount, prompt = nil)
  return false unless KIFR::Currency.exists?(currency_id)
  
  formatted = KIFR::Currency.format(currency_id, amount)
  balance = KIFR::Currency.get_balance(currency_id)
  
  # Check if can afford
  unless KIFR::Currency.can_afford?(currency_id, amount)
    pbMessage(_INTL("You don't have enough {1}. (Need {2}, have {3})", 
      KIFR::Currency.name(currency_id),
      formatted,
      KIFR::Currency.format(currency_id, balance)))
    return false
  end
  
  # Default prompt
  prompt ||= _INTL("This costs {1}. Proceed?", formatted)
  
  # Show confirmation
  if pbConfirmMessage(prompt)
    if KIFR::Currency.spend(currency_id, amount, "confirmed_purchase")
      return true
    else
      pbMessage(_INTL("Transaction failed."))
      return false
    end
  end
  
  false
end

#===============================================================================
# Currency Selection Menu - Let player choose which currency to use
#===============================================================================
def pbSelectCurrency(available_currencies = [:money, :platinum, :bp], prompt = nil)
  # Filter to currencies that exist and have balance > 0
  valid = available_currencies.select do |c| 
    KIFR::Currency.exists?(c) && KIFR::Currency.get_balance(c) > 0
  end
  
  return nil if valid.empty?
  return valid[0] if valid.length == 1
  
  prompt ||= _INTL("Which currency would you like to use?")
  
  # Build command list
  commands = valid.map do |c|
    balance = KIFR::Currency.format(c, KIFR::Currency.get_balance(c))
    "#{KIFR::Currency.name(c)} (#{balance})"
  end
  commands << _INTL("Cancel")
  
  choice = pbMessage(prompt, commands, commands.length)
  
  return nil if choice >= valid.length
  valid[choice]
end

#===============================================================================
# Trade Items for Currency - Exchange feature
#===============================================================================
# Allow player to trade items for a specific currency
#
# Example:
#   pbTradeItemsForCurrency(:platinum, {
#     :NUGGET => 5,        # Each Nugget = 5 Platinum
#     :BIGPEARL => 3,
#     :STARDUST => 1
#   })
#===============================================================================
def pbTradeItemsForCurrency(currency_id, trade_values)
  return unless KIFR::Currency.exists?(currency_id)
  
  currency_name = KIFR::Currency.name(currency_id)
  
  # Build list of tradeable items player has
  tradeable = []
  trade_values.each do |item, value|
    item_id = item.is_a?(Symbol) ? item : GameData::Item.get(item).id rescue next
    qty = $bag.quantity(item_id) rescue 0
    next if qty <= 0
    
    item_name = GameData::Item.get(item_id).name rescue item_id.to_s
    tradeable << {
      id: item_id,
      name: item_name,
      qty: qty,
      value: value
    }
  end
  
  if tradeable.empty?
    pbMessage(_INTL("You don't have any items to trade for {1}.", currency_name))
    return
  end
  
  # Show trade menu
  loop do
    commands = tradeable.map do |t|
      formatted_value = KIFR::Currency.format(currency_id, t[:value])
      "#{t[:name]} x#{t[:qty]} (#{formatted_value} each)"
    end
    commands << _INTL("Done")
    
    choice = pbMessage(_INTL("Trade items for {1}?", currency_name), commands, commands.length)
    
    break if choice >= tradeable.length
    
    item = tradeable[choice]
    
    # Ask how many to trade
    max = item[:qty]
    qty = pbChooseNumber(_INTL("How many {1} to trade?", item[:name]), max)
    
    next if qty <= 0
    
    total_value = qty * item[:value]
    formatted_total = KIFR::Currency.format(currency_id, total_value)
    
    if pbConfirmMessage(_INTL("Trade {1} {2} for {3}?", qty, item[:name], formatted_total))
      # Remove items and add currency
      $bag.remove(item[:id], qty)
      KIFR::Currency.add(currency_id, total_value, "item_trade")
      
      pbMessage(_INTL("\\se[Mart buy item]Received {1}!", formatted_total))
      
      # Update quantity
      item[:qty] -= qty
      tradeable.delete(item) if item[:qty] <= 0
      
      break if tradeable.empty?
    end
  end
end

#===============================================================================
# MIXED CURRENCY SHOP SYSTEM
# Allows a single shop to have items priced in different currencies
#===============================================================================
module KIFR
  module Currency
    module Shop
      #=========================================================================
      # CONFIGURATION - Random Currency Conversion
      #=========================================================================
      # Set percentage chances for random currency conversion in normal shops
      # Conversions are PERSISTENT and refresh on the same schedule as Specials
      #
      # Format: { currency_id => { chance: %, min_items: n, max_items: n, price_range: min..max } }
      #
      RANDOM_CONVERSION = {
        # Platinum: 15% chance, 1-3 items, price 5-50 Pt
        platinum: {
          enabled: true,
          chance: 50,              # % chance this triggers at all
          min_items: 1,            # Minimum items to convert
          max_items: 2,            # Maximum items to convert
          price_range: 5..50,      # Random price range for converted items
          require_multiplayer: true  # Only if connected to multiplayer
        },
        # BP: 10% chance, 1-2 items, price 1-20 BP
        bp: {
          enabled: true,
          chance: 50,
          min_items: 1,
          max_items: 2,
          price_range: 1..20,
          require_multiplayer: false
        },
        # Coins: 5% chance, 1-2 items
        coins: {
          enabled: false,          # Disabled by default
          chance: 5,
          min_items: 1,
          max_items: 2,
          price_range: 10..100,
          require_multiplayer: false
        }
      }
      
      # How long currency conversions last (in hours) - syncs with Specials system
      # Set to nil to use the same duration as random specials
      CONVERSION_DURATION_HOURS = nil
      
      # Items that should NEVER be randomly converted to other currencies
      CONVERSION_BLACKLIST = [
        :POKEBALL, :GREATBALL, :ULTRABALL,  # Basic balls should stay money
        :POTION, :SUPERPOTION,               # Basic healing
        :ANTIDOTE, :PARALYZEHEAL, :AWAKENING # Basic status heals
      ]
      
      # Items that are PREFERRED for conversion (higher chance to be picked)
      CONVERSION_PRIORITY = [
        :RARECANDY, :PPUP, :PPMAX,           # Rare items
        :MAXREVIVE, :FULLRESTORE,            # Premium items
        :MASTERBALL                          # Ultra rare
      ]
      
      #=========================================================================
      # Stock Processing - Parse mixed currency stock
      #=========================================================================
      
      # Process stock array to extract currency info
      # Input: [:POTION, :SUPERPOTION, [:RARECANDY, :platinum, 50]]
      # Output: { 
      #   items: [:POTION, :SUPERPOTION, :RARECANDY],
      #   currency_map: { :RARECANDY => { currency: :platinum, price: 50 } }
      # }
      def self.process_stock(stock)
        items = []
        currency_map = {}
        
        stock.each do |entry|
          if entry.is_a?(Array) && entry.length >= 3
            # Extended format: [:ITEM, :currency, price]
            item_id = entry[0]
            currency_id = entry[1]
            price = entry[2]
            
            item_id = normalize_item_id(item_id)
            next unless item_id
            
            items << item_id
            currency_map[item_id] = { currency: currency_id, price: price }
          else
            # Normal format: :ITEM
            item_id = normalize_item_id(entry)
            next unless item_id
            items << item_id
          end
        end
        
        { items: items, currency_map: currency_map }
      end
      
      # Normalize item to symbol ID
      def self.normalize_item_id(item)
        return item if item.is_a?(Symbol)
        begin
          GameData::Item.get(item).id
        rescue
          nil
        end
      end
      
      #=========================================================================
      # Random Currency Conversion - Now PERSISTENT with Specials timing
      #=========================================================================
      
      # Get the conversion duration in seconds (syncs with Specials if nil)
      def self.conversion_duration_seconds
        hours = CONVERSION_DURATION_HOURS
        if hours.nil? && defined?(KIFR::Shop::Specials::RANDOM_DURATION_HOURS)
          hours = KIFR::Shop::Specials::RANDOM_DURATION_HOURS
        end
        hours ||= 5  # Default 5 hours
        hours * 3600
      end
      
      # Get real time in seconds (matches Specials system)
      def self.real_time_seconds
        Time.now.to_i
      end
      
      # Get stored currency conversions from game_system
      def self.stored_conversions
        return {} unless $game_system
        $game_system.kifr_currency_conversions ||= {}
        $game_system.kifr_currency_conversions
      end
      
      # Store currency conversions
      def self.store_conversions(data)
        return unless $game_system
        $game_system.kifr_currency_conversions = data
      end
      
      # Check if conversions have expired
      def self.conversions_expired?
        return true unless $game_system
        stored = stored_conversions
        return true if stored.empty? || !stored[:start_time]
        
        elapsed = real_time_seconds - stored[:start_time]
        elapsed >= conversion_duration_seconds
      end
      
      # Clear expired conversions
      def self.check_conversion_expiration
        if conversions_expired?
          store_conversions({})
          debug_log("Currency conversions expired")
          return true
        end
        false
      end
      
      # Get time remaining on current conversions
      def self.conversion_time_remaining
        stored = stored_conversions
        return 0 if stored.empty? || !stored[:start_time]
        
        elapsed = real_time_seconds - stored[:start_time]
        remaining = conversion_duration_seconds - elapsed
        [remaining, 0].max
      end
      
      # Apply random currency conversion to stock
      # Now uses PERSISTENT storage - conversions last until they expire
      def self.apply_random_conversion(stock)
        debug_log("apply_random_conversion called with #{stock.size} items")
        
        if skip_conversion?
          debug_log("Skipping conversion (Kuray shop or outfit menu)")
          return stock
        end
        
        # Check for expired conversions
        check_conversion_expiration
        
        processed = process_stock(stock)
        items = processed[:items]
        currency_map = processed[:currency_map]
        
        debug_log("Processed stock: #{items.size} items, #{currency_map.size} with explicit currency")
        
        # Load any stored conversions
        stored = stored_conversions
        
        # Apply stored conversions to current stock if not expired
        if !stored.empty? && stored[:items]
          debug_log("Found #{stored[:items].size} stored conversions")
          stored[:items].each do |item_id, info|
            # Only apply if item is in current stock and doesn't have explicit currency
            item_sym = item_id.to_sym rescue item_id
            if items.include?(item_sym) && !currency_map.key?(item_sym)
              currency_map[item_sym] = info
              debug_log("Applied stored conversion: #{item_sym} => #{info[:currency]} @ #{info[:price]}")
            end
          end
        else
          debug_log("No stored conversions found")
        end
        
        # If we already have stored conversions (not expired), use them
        if !stored.empty? && stored[:items] && stored[:items].any?
          debug_log("Using existing stored conversions, skipping new generation")
          return build_mixed_stock(items, currency_map)
        end
        
        # Generate new conversions
        debug_log("Generating new random conversions...")
        new_conversions = {}
        
        RANDOM_CONVERSION.each do |currency_id, config|
          next unless config[:enabled]
          next unless should_convert?(currency_id, config)
          
          # Pick items to convert
          convertible = items.select { |i| can_convert_item?(i, currency_map, new_conversions) }
          next if convertible.empty?
          
          # Prioritize certain items
          prioritized = convertible.select { |i| CONVERSION_PRIORITY.include?(i) }
          convertible = prioritized + (convertible - prioritized)
          
          # Determine how many to convert
          num_items = rand(config[:min_items]..config[:max_items])
          num_items = [num_items, convertible.length].min
          
          # Convert items
          to_convert = convertible.take(num_items)
          to_convert.each do |item_id|
            price = rand(config[:price_range])
            conversion_info = { currency: currency_id, price: price }
            currency_map[item_id] = conversion_info
            new_conversions[item_id] = conversion_info
            
            debug_log("Converted #{item_id} to #{currency_id} @ #{price}")
          end
        end
        
        # Store new conversions with timestamp
        if new_conversions.any?
          store_conversions({
            items: new_conversions,
            start_time: real_time_seconds
          })
          debug_log("Stored #{new_conversions.size} new currency conversions")
        end
        
        # Rebuild stock with currency info
        build_mixed_stock(items, currency_map)
      end
      
      # Force refresh currency conversions (called when Specials refresh)
      def self.refresh_conversions!
        store_conversions({})
        debug_log("Currency conversions force-refreshed")
      end
      
      # Get current conversion status info (for debugging/UI)
      def self.conversion_status
        stored = stored_conversions
        return { active: false, count: 0, items: [], remaining: 0 } if stored.empty? || !stored[:items]
        
        remaining = conversion_time_remaining
        {
          active: remaining > 0,
          count: stored[:items].size,
          items: stored[:items].keys,
          currencies: stored[:items].values.map { |v| v[:currency] }.uniq,
          remaining: remaining,
          remaining_formatted: format_time(remaining)
        }
      end
      
      # Format seconds as time string
      def self.format_time(seconds)
        return "0:00" if seconds <= 0
        hours = seconds / 3600
        minutes = (seconds % 3600) / 60
        if hours > 0
          "#{hours}h #{minutes}m"
        else
          "#{minutes}m"
        end
      end
      
      # Check if any conversions are currently active
      def self.has_active_conversions?
        status = conversion_status
        status[:active] && status[:count] > 0
      end
      
      # Check if we should skip conversion entirely
      def self.skip_conversion?
        return true unless $game_temp
        return true if $game_temp.respond_to?(:fromkurayshop) && $game_temp.fromkurayshop
        return true if $game_temp.respond_to?(:in_outfit_menu) && $game_temp.in_outfit_menu
        false
      end
      
      # Check if conversion should trigger for this currency
      def self.should_convert?(currency_id, config)
        # Check multiplayer requirement
        if config[:require_multiplayer]
          return false unless multiplayer_connected?
        end
        
        # Check currency exists
        return false unless KIFR::Currency.exists?(currency_id)
        
        # Roll chance
        rand(100) < config[:chance]
      end
      
      # Check if connected to multiplayer server
      def self.multiplayer_connected?
        # Check MultiplayerClient (main multiplayer system)
        if defined?(MultiplayerClient)
          connected = MultiplayerClient.instance_variable_get(:@connected) rescue false
          return true if connected
        end
        
        # Fallback: check $multiplayer global if it exists
        if defined?($multiplayer) && $multiplayer.respond_to?(:connected?)
          return $multiplayer.connected?
        end
        
        false
      end
      
      # Check if an item can be converted
      def self.can_convert_item?(item_id, existing_map, new_conversions = {})
        # Already has custom currency
        return false if existing_map.key?(item_id)
        
        # Already converted in this session
        return false if new_conversions.key?(item_id)
        
        # Blacklisted
        return false if CONVERSION_BLACKLIST.include?(item_id)
        
        true
      end
      
      # Build stock array with mixed currency format
      def self.build_mixed_stock(items, currency_map)
        items.map do |item_id|
          if currency_map.key?(item_id)
            info = currency_map[item_id]
            [item_id, info[:currency], info[:price]]
          else
            item_id
          end
        end
      end
      
      def self.debug_log(message)
        if defined?(KIFRSettings) && KIFRSettings.respond_to?(:debug_log)
          KIFRSettings.debug_log("Economy::Shop: #{message}")
        end
      end
    end
  end
end

#===============================================================================
# Mixed Currency Mart Adapter
# Handles shops with items in different currencies
#===============================================================================
class MixedCurrencyMartAdapter < PokemonMartAdapter
  attr_reader :currency_map   # { item_id => { currency: :symbol, price: int } }
  
  def initialize(stock = [])
    super()
    @currency_map = {}
    process_stock(stock) if stock.any?
  end
  
  # Process stock to extract currency info
  def process_stock(stock)
    result = KIFR::Currency::Shop.process_stock(stock)
    @currency_map = result[:currency_map]
  end
  
  # Get the currency for an item
  def get_item_currency(item)
    item_id = normalize_item(item)
    return :money unless @currency_map.key?(item_id)
    @currency_map[item_id][:currency]
  end
  
  # Get custom price for an item (if set)
  def get_custom_price(item)
    item_id = normalize_item(item)
    return nil unless @currency_map.key?(item_id)
    @currency_map[item_id][:price]
  end
  
  # Override getPrice to return custom prices
  def getPrice(item, selling = false)
    # Can't sell non-money items
    return 0 if selling && get_item_currency(item) != :money
    
    # Check for custom price
    custom = get_custom_price(item)
    return custom if custom && !selling
    
    # Fall back to normal price
    super
  end
  
  # Override getDisplayPrice to show correct currency symbol
  # Uses safe_symbol because item list uses text rendering that can't display some Unicode
  def getDisplayPrice(item, selling = false)
    currency_id = get_item_currency(item)
    price = getPrice(item, selling)
    
    # Use safe_symbol for text window compatibility
    if KIFR::Currency.exists?(currency_id)
      symbol = KIFR::Currency.safe_symbol(currency_id)
      formatted_price = price.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      return "#{symbol} #{formatted_price}"
    end
    
    # Fallback
    _INTL("$ {1}", price.to_s_formatted)
  end
  
  # Override getMoney - for mixed shops, we need to handle per-item
  # The main money display shows standard money
  def getMoney
    $Trainer ? $Trainer.money : 0
  end
  
  def setMoney(value)
    $Trainer.money = value if $Trainer
  end
  
  # Get balance for a specific item's currency
  def get_balance_for_item(item)
    currency_id = get_item_currency(item)
    KIFR::Currency.get_balance(currency_id)
  end
  
  # Check if player can afford an item
  def can_afford_item?(item, quantity = 1)
    currency_id = get_item_currency(item)
    price = getPrice(item, false) * quantity
    can = KIFR::Currency.can_afford?(currency_id, price)
    KIFR::Currency.debug_log("CAN_AFFORD? #{item} x#{quantity}: #{currency_id} #{price} - balance: #{KIFR::Currency.get_balance(currency_id)} - result: #{can}")
    can
  end
  
  # Spend currency for an item purchase
  def spend_for_item(item, quantity = 1)
    currency_id = get_item_currency(item)
    price = getPrice(item, false) * quantity
    KIFR::Currency.debug_log("PURCHASE #{item} x#{quantity}: spending #{price} #{currency_id}")
    KIFR::Currency.spend(currency_id, price, "shop_purchase")
  end
  
  # Check if item uses alternate currency
  def uses_alternate_currency?(item)
    get_item_currency(item) != :money
  end
  
  # Override canSell? to disable selling alternate currency items
  def canSell?(item)
    return false if uses_alternate_currency?(item)
    super
  end
  
  private
  
  def normalize_item(item)
    return item if item.is_a?(Symbol)
    begin
      GameData::Item.get(item).id
    rescue
      item
    end
  end
end

#===============================================================================
# Hook into PokemonMartScreen to use MixedCurrencyMartAdapter
#===============================================================================
if defined?(PokemonMartScreen)
  class PokemonMartScreen
    attr_reader :mixed_adapter
    
    unless method_defined?(:kifr_currency_orig_initialize)
      alias :kifr_currency_orig_initialize :initialize
    end
    
    def initialize(scene, stock, adapter = nil)
      # Check if stock has mixed currencies
      has_mixed = stock.any? { |s| s.is_a?(Array) && s.length >= 3 }
      
      # Apply random conversion if enabled and no explicit mixed items
      unless has_mixed
        stock = KIFR::Currency::Shop.apply_random_conversion(stock)
        has_mixed = stock.any? { |s| s.is_a?(Array) && s.length >= 3 }
      end
      
      if has_mixed
        # Create mixed adapter
        @mixed_adapter = MixedCurrencyMartAdapter.new(stock)
        
        # Extract just item IDs for stock
        processed = KIFR::Currency::Shop.process_stock(stock)
        clean_stock = processed[:items]
        
        KIFR::Currency.debug_log("SHOP OPENED - Mixed currency mode, #{clean_stock.size} items, #{@mixed_adapter.currency_map.size} with alt currency")
        
        kifr_currency_orig_initialize(scene, clean_stock, @mixed_adapter)
      else
        @mixed_adapter = nil
        KIFR::Currency.debug_log("SHOP OPENED - Standard mode, #{stock.size} items")
        kifr_currency_orig_initialize(scene, stock, adapter || PokemonMartAdapter.new)
      end
    end
  end
end

#===============================================================================
# Hook into pbBuyScreen to handle mixed currency purchases
#===============================================================================
if defined?(PokemonMartScreen)
  class PokemonMartScreen
    unless method_defined?(:kifr_currency_mixed_orig_pbBuyScreen)
      alias :kifr_currency_mixed_orig_pbBuyScreen :pbBuyScreen
    end
    
    def pbBuyScreen
      # If not using mixed adapter, use original
      unless @mixed_adapter
        return kifr_currency_mixed_orig_pbBuyScreen
      end
      
      # Mixed currency buy screen - fully custom implementation
      @scene.pbStartBuyScene(@stock, @adapter)
      item = nil
      
      loop do
        pbWait(4)
        item = @scene.pbChooseBuyItem
        break if !item
        
        quantity = 0
        itemname = @adapter.getDisplayName(item)
        price = @adapter.getPrice(item)
        currency_id = @mixed_adapter.get_item_currency(item)
        
        # Use safe_symbol for text windows
        currency_symbol = KIFR::Currency.exists?(currency_id) ? 
          KIFR::Currency.safe_symbol(currency_id) : "$"
        
        # Check if player can afford (uses correct currency)
        if !@mixed_adapter.can_afford_item?(item, 1)
          currency_name = KIFR::Currency.exists?(currency_id) ? 
            KIFR::Currency.name(currency_id) : "money"
          pbDisplayPaused(_INTL("You don't have enough {1}.", currency_name))
          next
        end
        
        if GameData::Item.get(item).is_important?
          # Important item - single purchase
          if !pbConfirm(_INTL("Certainly. You want {1}. That will be {2}{3}. OK?",
             itemname, currency_symbol, price.to_s_formatted))
            next
          end
          quantity = 1
        else
          # Regular item - choose quantity
          balance = @mixed_adapter.get_balance_for_item(item)
          maxafford = (price <= 0) ? Settings::BAG_MAX_PER_SLOT : balance / price
          maxafford = Settings::BAG_MAX_PER_SLOT if maxafford > Settings::BAG_MAX_PER_SLOT
          
          quantity = @scene.pbChooseNumber(
             _INTL("{1}? Certainly. How many would you like?", itemname), item, maxafford)
          next if quantity == 0
          
          price *= quantity
          if !pbConfirm(_INTL("{1}, and you want {2}. That will be {3}{4}. OK?",
             itemname, quantity, currency_symbol, price.to_s_formatted))
            next
          end
        end
        
        # Final affordability check with quantity
        if !@mixed_adapter.can_afford_item?(item, quantity)
          currency_name = KIFR::Currency.exists?(currency_id) ? 
            KIFR::Currency.name(currency_id) : "money"
          pbDisplayPaused(_INTL("You don't have enough {1}.", currency_name))
          next
        end
        
        # Add items to bag
        added = 0
        quantity.times do
          break if !@adapter.addItem(item)
          added += 1
        end
        
        if added != quantity
          # Couldn't add all items - remove what we added
          added.times do
            if !@adapter.removeItem(item)
              raise _INTL("Failed to delete stored items")
            end
          end
          pbDisplayPaused(_INTL("You have no more room in the Bag."))
        else
          # Successfully added items - spend the currency
          @mixed_adapter.spend_for_item(item, added)
          @scene.pbRefresh  # Trigger animated money display
          @scene.pbWaitForMoneyAnimation if @scene.respond_to?(:pbWaitForMoneyAnimation)
          
          # Remove important items from stock
          for i in 0...@stock.length
            if GameData::Item.get(@stock[i]).is_important? && $PokemonBag.pbHasItem?(@stock[i])
              @stock[i] = nil
            end
          end
          @stock.compact!
          
          pbDisplayPaused(_INTL("Here you are! Thank you!")) { pbSEPlay("Mart buy item") }
          
          # Premier Ball bonus for bulk Poké Ball purchases
          if $PokemonBag
            if quantity >= 10 && GameData::Item.get(item).is_poke_ball? && GameData::Item.exists?(:PREMIERBALL)
              if @adapter.addItem(GameData::Item.get(:PREMIERBALL))
                pbDisplayPaused(_INTL("I'll throw in a Premier Ball, too."))
              end
            end
          end
        end
      end
      
      @scene.pbEndBuyScene
    end
  end
end

#===============================================================================
# Hook into PokemonMart_Scene#pbChooseNumber for multi-currency support
# Shows the correct currency symbol (BP, Pt, $) in the quantity selection box
#===============================================================================
if defined?(PokemonMart_Scene)
  class PokemonMart_Scene
    unless method_defined?(:kifr_currency_orig_pbChooseNumber)
      alias :kifr_currency_orig_pbChooseNumber :pbChooseNumber
    end
    
    def pbChooseNumber(helptext, item, maximum)
      # Check if we have a mixed adapter with currency info
      adapter = @adapter
      
      # Determine currency for this item
      currency_id = :money  # Default
      if adapter.respond_to?(:get_item_currency)
        currency_id = adapter.get_item_currency(item)
      end
      
      # Get currency symbol - use safe_symbol for Window_AdvancedTextPokemon
      # (it can't render some Unicode characters like ₽)
      currency_symbol = "$"  # Default
      if KIFR::Currency.exists?(currency_id)
        currency_symbol = KIFR::Currency.safe_symbol(currency_id)
      end
      
      # Get price for this item (use custom price if available)
      itemprice = adapter.getPrice(item, !@buying)
      itemprice /= 2 if !@buying
      
      curnumber = 1
      ret = 0
      helpwindow = @sprites["helpwindow"]
      pbDisplay(helptext, true)
      
      using(numwindow = Window_AdvancedTextPokemon.new("")) {
        qty = adapter.getQuantity(item)
        pbPrepareWindow(numwindow)
        numwindow.viewport = @viewport
        numwindow.width = 224
        numwindow.height = 64
        
        # Get text colors based on global frame (dark vs light)
        text_colors = defined?(pbGetGlobalFrameTextColors) ? pbGetGlobalFrameTextColors : [Color.new(88, 88, 80), Color.new(168, 184, 184)]
        numwindow.baseColor = text_colors[0]
        numwindow.shadowColor = text_colors[1]
        
        # Update the persistent In Bag window
        if @sprites["inbagwindow"]
          @sprites["inbagwindow"].text = _INTL("In Bag:<r>{1}  ", qty)
          @sprites["inbagwindow"].visible = true
        end
        
        # Format: "x1   $ 100" or "x1   BP 10" (currency symbol)
        numwindow.text = _INTL("x{1}<r>{2} {3}", curnumber, currency_symbol, (curnumber * itemprice).to_s_formatted)
        pbBottomRight(numwindow)
        numwindow.y -= helpwindow.height
        
        loop do
          Graphics.update
          Input.update
          numwindow.update
          self.update
          
          if Input.repeat?(Input::LEFT)
            pbPlayCursorSE
            curnumber -= 10
            curnumber = 1 if curnumber < 1
            numwindow.text = _INTL("x{1}<r>{2} {3}", curnumber, currency_symbol, (curnumber * itemprice).to_s_formatted)
          elsif Input.repeat?(Input::RIGHT)
            pbPlayCursorSE
            curnumber += 10
            curnumber = maximum if curnumber > maximum
            numwindow.text = _INTL("x{1}<r>{2} {3}", curnumber, currency_symbol, (curnumber * itemprice).to_s_formatted)
          elsif Input.repeat?(Input::UP)
            pbPlayCursorSE
            curnumber += 1
            curnumber = 1 if curnumber > maximum
            numwindow.text = _INTL("x{1}<r>{2} {3}", curnumber, currency_symbol, (curnumber * itemprice).to_s_formatted)
          elsif Input.repeat?(Input::DOWN)
            pbPlayCursorSE
            curnumber -= 1
            curnumber = maximum if curnumber < 1
            numwindow.text = _INTL("x{1}<r>{2} {3}", curnumber, currency_symbol, (curnumber * itemprice).to_s_formatted)
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            ret = curnumber
            break
          elsif Input.trigger?(Input::BACK)
            pbPlayCancelSE
            ret = 0
            break
          end
        end
      }
      helpwindow.visible = false
      return ret
    end
  end
end

#===============================================================================
# Hook into PokemonMart_Scene#pbRefresh to update money display for current item's currency
#===============================================================================
if defined?(PokemonMart_Scene)
  class PokemonMart_Scene
    unless method_defined?(:kifr_currency_orig_pbRefresh)
      alias :kifr_currency_orig_pbRefresh :pbRefresh
    end
    
    def pbRefresh
      # Call original refresh first
      kifr_currency_orig_pbRefresh
      
      # Only apply currency switching for mixed currency adapters
      return unless @adapter.respond_to?(:get_item_currency)
      return unless @sprites["itemwindow"] && @sprites["moneywindow"]
      
      item = @sprites["itemwindow"].item
      return unless item
      
      currency_id = @adapter.get_item_currency(item)
      
      # For regular money items, show standard Money display
      # For alternate currencies (BP, Pt, etc.), show that currency's balance
      if currency_id == :money
        # Reset to standard money display
        if @sprites["moneywindow"].is_a?(Window_AnimatedMoney)
          @sprites["moneywindow"].currency_name = "Money"
          @sprites["moneywindow"].set_target(@adapter.getMoney)
        end
      elsif KIFR::Currency.exists?(currency_id)
        # Show alternate currency balance
        balance = KIFR::Currency.get_balance(currency_id)
        currency_name = KIFR::Currency.name(currency_id)
        
        if @sprites["moneywindow"].is_a?(Window_AnimatedMoney)
          @sprites["moneywindow"].currency_name = currency_name
          @sprites["moneywindow"].set_target(balance)
        else
          formatted = balance.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
          @sprites["moneywindow"].text = _INTL("{1}:\r\n<r>{2}", currency_name, formatted)
        end
      end
    end
  end
end