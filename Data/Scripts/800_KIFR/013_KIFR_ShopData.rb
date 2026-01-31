#===============================================================================
# KIF Redux Shop Data - Shared Data, Favorites & Global Statistics
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file contains:
# - ShopData::Favorites - Item favorites system (works in ALL shops)
# - ShopData::Statistics - Global shop statistics
# - ShopData::History - Purchase/sale history
# - ShopData::Wishlist - Item wishlist
#===============================================================================

module ShopData
  #=============================================================================
  # DEBUG LOGGING HELPER
  #=============================================================================
  def self.debug_log(message)
    if defined?(KIFRSettings) && KIFRSettings.respond_to?(:debug_log)
      KIFRSettings.debug_log("Economy::ShopData: #{message}")
    end
  end

  #=============================================================================
  # FAVORITES MODULE - Item Favorites (All Shops)
  #=============================================================================
  module Favorites
    MAX_FAVORITES = 50
    
    class << self
      def enabled?
        return true unless defined?(KIFRSettings)
        KIFRSettings.get(:shop_favorites, 1) == 1
      end
      
      # Get favorites list
      def list
        $game_system.shop_favorites ||= []
      end
      
      # Check if item is favorited
      def favorited?(item_id)
        return false unless enabled?
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        list.include?(item_id)
      end
      
      # Toggle favorite status
      def toggle(item_id)
        return false unless enabled?
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        
        if favorited?(item_id)
          remove(item_id)
        else
          add(item_id)
        end
      end
      
      # Add to favorites
      def add(item_id)
        return false unless enabled?
        return false if list.length >= MAX_FAVORITES
        
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        return false if favorited?(item_id)
        
        list << item_id
        true
      end
      
      # Remove from favorites
      def remove(item_id)
        return false unless enabled?
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        
        list.delete(item_id)
        true
      end
      
      # Clear all favorites
      def clear
        $game_system.shop_favorites = []
      end
      
      # Get favorited items in a stock list
      def in_stock(stock)
        return [] unless enabled?
        
        stock.select do |item|
          next false if item.is_a?(String) || item.is_a?(Symbol)
          next false if item.is_a?(Hash) && item[:header]
          
          item_id = EconomyMod::Core.item_to_id(item) rescue item
          favorited?(item_id)
        end
      end
      
      # Sort stock with favorites first
      def sort_favorites_first(stock)
        return stock unless enabled?
        
        favs = []
        others = []
        
        stock.each do |item|
          if item.is_a?(String) || item.is_a?(Symbol) || (item.is_a?(Hash) && item[:header])
            others << item
          else
            item_id = EconomyMod::Core.item_to_id(item) rescue item
            if favorited?(item_id)
              favs << item
            else
              others << item
            end
          end
        end
        
        result = []
        if favs.any?
          result << { header: "FAVORITES", count: favs.length }
          result.concat(favs)
        end
        result.concat(others)
        result
      end
    end
  end

  #=============================================================================
  # STATISTICS MODULE - Global Shop Statistics
  #=============================================================================
  module Statistics
    class << self
      def data
        $game_system.global_shop_stats ||= {
          total_spent: 0,
          total_earned: 0,
          items_bought: {},
          items_sold: {},
          shops_visited: 0,
          kuray_visits: 0,
          regular_visits: 0,
          first_purchase_time: nil,
          last_purchase_time: nil,
          saved_from_discounts: 0,  # Combined sale + bulk savings
          markup_losses: 0,
          free_items_claimed: 0,
          transactions: 0,
          money_from_gifts: 0,      # Money received from gift system
          items_from_gifts: 0,      # Items received from gift system
          money_from_battles: 0     # Money received from trainer battles
        }
        # Migrate old save data - add missing keys
        $game_system.global_shop_stats[:money_from_gifts] ||= 0
        $game_system.global_shop_stats[:items_from_gifts] ||= 0
        $game_system.global_shop_stats[:free_items_claimed] ||= 0
        $game_system.global_shop_stats[:money_from_battles] ||= 0
        $game_system.global_shop_stats
      end
      
      # Record a purchase
      def record_purchase(item_id, quantity, total_price, shop_type = :regular, options = {})
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        current_time = (EconomyMod::Core.current_time_seconds rescue Time.now.to_i)
        
        data[:total_spent] += total_price
        data[:items_bought][item_id] ||= { count: 0, total_spent: 0 }
        data[:items_bought][item_id][:count] += quantity
        data[:items_bought][item_id][:total_spent] += total_price
        
        data[:first_purchase_time] ||= current_time
        data[:last_purchase_time] = current_time
        data[:transactions] += 1
        
        # Track savings/losses (combined into saved_from_discounts)
        discount_savings = (options[:sale_savings] || 0) + (options[:bulk_savings] || 0)
        data[:saved_from_discounts] += discount_savings if discount_savings > 0
        data[:markup_losses] += options[:markup_cost] if options[:markup_cost]
        data[:free_items_claimed] += quantity if total_price == 0
        
        ShopData.debug_log("Purchase recorded: #{quantity}x item #{item_id} for $#{total_price}")
        
        # Check economy milestones
        check_economy_milestones
      end
      
      # Record a sale
      def record_sale(item_id, quantity, total_price, shop_type = :regular)
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        
        data[:total_earned] += total_price
        data[:items_sold][item_id] ||= { count: 0, total_earned: 0 }
        data[:items_sold][item_id][:count] += quantity
        data[:items_sold][item_id][:total_earned] += total_price
        data[:transactions] += 1
        
        ShopData.debug_log("Sale recorded: #{quantity}x item #{item_id} for $#{total_price}")
        
        # Check economy milestones
        check_economy_milestones
      end
      
      # Record a shop visit
      def record_visit(kuray_shop = false)
        data[:shops_visited] += 1
        if kuray_shop
          data[:kuray_visits] += 1
        else
          data[:regular_visits] += 1
        end
        ShopData.debug_log("Shop visit recorded (kuray=#{kuray_shop})")
      end
      
      # Record money received from gifts
      def record_gift_money(amount)
        data[:money_from_gifts] += amount
        ShopData.debug_log("Gift money recorded: $#{amount}")
      end
      
      # Record items received from gifts
      def record_gift_items(quantity)
        data[:items_from_gifts] += quantity
        ShopData.debug_log("Gift items recorded: #{quantity}")
      end
      
      # Record money received from battles
      def record_battle_money(amount)
        return unless amount && amount > 0
        data[:money_from_battles] += amount
        data[:total_earned] += amount
        ShopData.debug_log("Battle money recorded: $#{amount}")
      end
      
      # Check and trigger economy milestones
      def check_economy_milestones
        return unless defined?(Gifts::Rewards)
        
        items_bought_count = data[:items_bought].values.sum { |v| v.is_a?(Hash) ? (v[:count] || 0) : (v || 0) }
        items_sold_count = data[:items_sold].values.sum { |v| v.is_a?(Hash) ? (v[:count] || 0) : (v || 0) }
        
        # Check buying milestones
        [:items_bought_500, :items_bought_1000, :items_bought_2500, :items_bought_5000].each do |key|
          if Gifts::Rewards.milestone_unlocked?(key) && !Gifts::Rewards.claimed?(key)
            ShopData.debug_log("Economy milestone unlocked: #{key}")
          end
        end
        
        # Check selling milestones
        [:items_sold_500, :items_sold_1000, :items_sold_2500, :items_sold_5000].each do |key|
          if Gifts::Rewards.milestone_unlocked?(key) && !Gifts::Rewards.claimed?(key)
            ShopData.debug_log("Economy milestone unlocked: #{key}")
          end
        end
      end
      
      # Get total items bought count
      def items_bought_count
        data[:items_bought].values.sum { |v| v.is_a?(Hash) ? (v[:count] || 0) : (v || 0) }
      end
      
      # Get total items sold count
      def items_sold_count
        data[:items_sold].values.sum { |v| v.is_a?(Hash) ? (v[:count] || 0) : (v || 0) }
      end
      
      # Get summary statistics
      def summary
        bought_count = items_bought_count
        sold_count = items_sold_count
        
        {
          total_spent: data[:total_spent],
          total_earned: data[:total_earned],
          net: data[:total_earned] - data[:total_spent],
          items_bought: bought_count,
          items_sold: sold_count,
          unique_bought: data[:items_bought].keys.length,
          unique_sold: data[:items_sold].keys.length,
          shops_visited: data[:shops_visited],
          kuray_visits: data[:kuray_visits],
          regular_visits: data[:regular_visits],
          saved_from_discounts: data[:saved_from_discounts],
          markup_losses: data[:markup_losses],
          free_items: data[:free_items_claimed],
          transactions: data[:transactions],
          money_from_gifts: data[:money_from_gifts],
          items_from_gifts: data[:items_from_gifts],
          money_from_battles: data[:money_from_battles]
        }
      end
      
      # Reset all statistics
      def reset
        $game_system.global_shop_stats = nil
        ShopData.debug_log("All shop statistics have been reset")
      end
    end
  end

  #=============================================================================
  # HISTORY MODULE - Purchase/Sale History
  #=============================================================================
  module History
    MAX_HISTORY = 100
    
    class << self
      def enabled?
        return true unless defined?(KIFRSettings)
        KIFRSettings.get(:shop_history, 1) == 1
      end
      
      # Get history list
      def list
        $game_system.shop_history ||= []
      end
      
      # Add a purchase to history
      def add_purchase(item_id, quantity, price, shop_type = :regular)
        return unless enabled?
        
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        current_time = (EconomyMod::Core.current_time_seconds rescue Time.now.to_i)
        
        entry = {
          type: :purchase,
          item: item_id,
          quantity: quantity,
          price: price,
          total: price * quantity,
          shop: shop_type,
          time: current_time
        }
        
        list.unshift(entry)
        list.pop while list.length > MAX_HISTORY
      end
      
      # Add a sale to history
      def add_sale(item_id, quantity, price, shop_type = :regular)
        return unless enabled?
        
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        current_time = (EconomyMod::Core.current_time_seconds rescue Time.now.to_i)
        
        entry = {
          type: :sale,
          item: item_id,
          quantity: quantity,
          price: price,
          total: price * quantity,
          shop: shop_type,
          time: current_time
        }
        
        list.unshift(entry)
        list.pop while list.length > MAX_HISTORY
      end
      
      # Get recent purchases
      def recent_purchases(limit = 10)
        list.select { |e| e[:type] == :purchase }.first(limit)
      end
      
      # Get recent sales
      def recent_sales(limit = 10)
        list.select { |e| e[:type] == :sale }.first(limit)
      end
      
      # Get history for a specific item
      def for_item(item_id, limit = 10)
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        list.select { |e| e[:item] == item_id }.first(limit)
      end
      
      # Get today's history
      def today
        today_start = EconomyMod::Core.daily_seed rescue (Time.now.to_i / 86400 * 86400)
        list.select { |e| e[:time] >= today_start }
      end
      
      # Clear history
      def clear
        $game_system.shop_history = []
      end
    end
  end

  #=============================================================================
  # WISHLIST MODULE - Items to Buy Later
  #=============================================================================
  module Wishlist
    MAX_WISHLIST = 25
    
    class << self
      def enabled?
        return true unless defined?(KIFRSettings)
        KIFRSettings.get(:shop_wishlist, 1) == 1
      end
      
      # Get wishlist
      def list
        $game_system.shop_wishlist ||= []
      end
      
      # Check if item is on wishlist
      def on_wishlist?(item_id)
        return false unless enabled?
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        list.any? { |e| e[:item] == item_id }
      end
      
      # Add to wishlist
      def add(item_id, target_quantity = 1, notes = nil)
        return false unless enabled?
        return false if list.length >= MAX_WISHLIST
        
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        return false if on_wishlist?(item_id)
        
        current_time = (EconomyMod::Core.current_time_seconds rescue Time.now.to_i)
        
        list << {
          item: item_id,
          quantity: target_quantity,
          notes: notes,
          added_at: current_time
        }
        true
      end
      
      # Remove from wishlist
      def remove(item_id)
        return false unless enabled?
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        
        list.reject! { |e| e[:item] == item_id }
        true
      end
      
      # Toggle wishlist status
      def toggle(item_id)
        return false unless enabled?
        item_id = EconomyMod::Core.item_to_id(item_id) rescue item_id
        
        if on_wishlist?(item_id)
          remove(item_id)
        else
          add(item_id)
        end
      end
      
      # Get wishlist items available in current stock
      def available_in_stock(stock)
        return [] unless enabled?
        
        available = []
        list.each do |wish|
          stock.each do |item|
            next if item.is_a?(String) || item.is_a?(Symbol)
            next if item.is_a?(Hash) && item[:header]
            
            item_id = EconomyMod::Core.item_to_id(item) rescue item
            if item_id == wish[:item]
              available << wish
              break
            end
          end
        end
        available
      end
      
      # Clear wishlist
      def clear
        $game_system.shop_wishlist = []
      end
    end
  end

  #=============================================================================
  # NOTIFICATIONS MODULE - Shop Notifications
  #=============================================================================
  module Notifications
    class << self
      def enabled?
        return true unless defined?(KIFRSettings)
        KIFRSettings.get(:shop_notifications, 1) == 1
      end
      
      # Get pending notifications for current shop
      def pending(stock)
        return [] unless enabled?
        
        notifications = []
        
        # Check wishlist items available
        wishlist_available = Wishlist.available_in_stock(stock)
        if wishlist_available.any?
          names = wishlist_available.map do |w|
            EconomyMod::Core.item_name(w[:item])
          end.first(3)
          
          if wishlist_available.length > 3
            notifications << _INTL("Wishlist items available: {1} and {2} more!", names.join(", "), wishlist_available.length - 3)
          else
            notifications << _INTL("Wishlist items available: {1}!", names.join(", "))
          end
        end
        
        # Check if there's an active sale (regular marts only)
        if !KurayShop.in_kuray_shop? && defined?(EconomyMod::Sale) && EconomyMod::Sale.active?
          notifications << _INTL("Sale active! {1}% off!", EconomyMod::Sale.current_percentage)
        end
        
        # Check daily deals (regular marts only)
        if !KurayShop.in_kuray_shop? && defined?(Shop::Deals) && Shop::Deals.enabled?
          deals_text = Shop::Deals.deals_summary_text(stock)
          notifications << deals_text if deals_text
        end
        
        notifications
      end
      
      # Show pending notifications
      def show(stock)
        return unless enabled?
        
        pending(stock).each do |msg|
          Kernel.pbMessage(msg) if defined?(Kernel.pbMessage)
        end
      end
    end
  end
end

#===============================================================================
# GAME_SYSTEM EXTENSIONS
#===============================================================================
class Game_System
  attr_accessor :shop_favorites
  attr_accessor :global_shop_stats
  attr_accessor :shop_history
  attr_accessor :shop_wishlist
end

#===============================================================================
# INTEGRATION HOOKS - Track Purchases/Sales
#===============================================================================
if defined?(PokemonMartAdapter)
  class PokemonMartAdapter
    unless method_defined?(:kifr_shopdata_orig_getPrice)
      alias_method :kifr_shopdata_orig_getPrice, :getPrice
    end
    
    # Hook already exists from other modules, just making sure we don't break it
  end
end

# Hook into PokemonMartScreen to track purchases and sales
class PokemonMartScreen
  unless method_defined?(:kifr_shopdata_orig_pbBuyScreen)
    alias_method :kifr_shopdata_orig_pbBuyScreen, :pbBuyScreen
  end
  
  unless method_defined?(:kifr_shopdata_orig_pbSellScreen)
    alias_method :kifr_shopdata_orig_pbSellScreen, :pbSellScreen
  end
  
  def pbBuyScreen
    # Skip tracking if in Kuray Shop (handled by 011a_KIFR_KurayShop.rb)
    is_kuray = (defined?(KurayShop) && KurayShop.in_kuray_shop?) rescue false
    if is_kuray
      return kifr_shopdata_orig_pbBuyScreen
    end
    
    # Track shop visit when entering buy screen (regular shops only)
    begin
      ShopData::Statistics.record_visit(false) if defined?(ShopData::Statistics)
    rescue => e
      ShopData.debug_log("Visit tracking error: #{e.message}") if defined?(ShopData)
    end
    
    # Store initial money for tracking
    @kifr_initial_money = @adapter.getMoney rescue 0
    @kifr_initial_bag_state = $PokemonBag ? $PokemonBag.pockets.map { |p| p.dup rescue [] } : []
    
    result = kifr_shopdata_orig_pbBuyScreen
    
    # Track purchases by comparing money spent
    begin
      if defined?(ShopData::Statistics)
        final_money = @adapter.getMoney rescue 0
        money_spent = @kifr_initial_money - final_money
        
        if money_spent > 0
          # Determine items purchased by comparing bag contents
          items_purchased = detect_bag_changes(@kifr_initial_bag_state, true)
          
          items_purchased.each do |item_id, quantity|
            # Calculate per-item price
            item_price = @adapter.getPrice(item_id) rescue 0
            total_item_price = item_price * quantity
            
            ShopData::Statistics.record_purchase(item_id, quantity, total_item_price, :regular)
            ShopData::History.add_purchase(item_id, quantity, item_price, :regular) if defined?(ShopData::History)
          end
          
          ShopData.debug_log("Tracked #{items_purchased.length} different items purchased for $#{money_spent}")
        end
      end
    rescue => e
      ShopData.debug_log("Purchase tracking error: #{e.message}") if defined?(ShopData)
    end
    
    result
  end
  
  def pbSellScreen
    # Skip tracking if in Kuray Shop (handled separately)
    is_kuray = (defined?(KurayShop) && KurayShop.in_kuray_shop?) rescue false
    
    # Store initial money for tracking
    @kifr_initial_money = @adapter.getMoney rescue 0
    @kifr_initial_bag_state = $PokemonBag ? $PokemonBag.pockets.map { |p| p.dup rescue [] } : []
    
    result = kifr_shopdata_orig_pbSellScreen
    
    # Track sales by comparing money earned (skip for Kuray Shop)
    begin
      if defined?(ShopData::Statistics) && !is_kuray
        final_money = @adapter.getMoney rescue 0
        money_earned = final_money - @kifr_initial_money
        
        if money_earned > 0
          # Determine items sold by comparing bag contents
          items_sold = detect_bag_changes(@kifr_initial_bag_state, false)
          
          items_sold.each do |item_id, quantity|
            # Calculate per-item price
            base_price = GameData::Item.get(item_id).price rescue 0
            sell_price = base_price / 2  # Standard sell price is half
            total_item_price = sell_price * quantity
            
            ShopData::Statistics.record_sale(item_id, quantity, total_item_price, :regular)
            ShopData::History.add_sale(item_id, quantity, sell_price, :regular) if defined?(ShopData::History)
          end
          
          ShopData.debug_log("Tracked #{items_sold.length} different items sold for $#{money_earned}")
        end
      end
    rescue => e
      ShopData.debug_log("Sale tracking error: #{e.message}") if defined?(ShopData)
    end
    
    result
  end
  
  # Helper method to detect bag changes
  def detect_bag_changes(initial_state, is_purchase)
    changes = {}
    return changes unless $PokemonBag
    
    begin
      current_state = $PokemonBag.pockets.map { |p| p.dup rescue [] }
      
      # Build hash of initial items
      initial_items = {}
      initial_state.each do |pocket|
        next unless pocket.is_a?(Array)
        pocket.each do |entry|
          next unless entry.is_a?(Array) && entry.length >= 2
          item_id = entry[0]
          quantity = entry[1]
          initial_items[item_id] ||= 0
          initial_items[item_id] += quantity
        end
      end
      
      # Build hash of current items
      current_items = {}
      current_state.each do |pocket|
        next unless pocket.is_a?(Array)
        pocket.each do |entry|
          next unless entry.is_a?(Array) && entry.length >= 2
          item_id = entry[0]
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
      ShopData.debug_log("Bag change detection error: #{e.message}") if defined?(ShopData)
    end
    
    changes
  end
end

#===============================================================================
# KIFR SETTINGS REGISTRATION
#===============================================================================
begin
  if defined?(KIFRSettings)
    # Initialize defaults
    KIFRSettings.set_default(:shop_favorites, 1)
    KIFRSettings.set_default(:shop_history, 1)
    KIFRSettings.set_default(:shop_wishlist, 1)
    KIFRSettings.set_default(:shop_notifications, 1)
    
    KIFRSettings.debug_log("ShopData: Module loaded - Favorites, Statistics, History, Wishlist, Notifications ready")
  end
rescue => e
  KIFRSettings.debug_log("ShopData: ERROR: Setup failed - #{e.message}") if defined?(KIFRSettings)
end

#===============================================================================
# BATTLE MONEY TRACKING HOOK
#===============================================================================
# Note: The actual battle money multiplier logic is in 010a_KIFR_Economy.rb
# This hook tracks money gained for statistics only
# Since 010a loads before 013, the chain is:
#   pbGainMoney -> kifr_shopdata (tracking) -> kifr_economy (multiplier) -> original
if defined?(PokeBattle_Battle)
  class PokeBattle_Battle
    # Only alias if we haven't already AND if the economy hook exists
    # This ensures proper chaining: shopdata -> economy -> original
    if method_defined?(:kifr_economy_orig_pbGainMoney) && !method_defined?(:kifr_shopdata_orig_pbGainMoney)
      alias_method :kifr_shopdata_orig_pbGainMoney, :pbGainMoney
      
      def pbGainMoney
        # Track money before the gain
        old_money = pbPlayer.money rescue 0
        
        # Call the economy hook (which applies multiplier and calls original)
        kifr_shopdata_orig_pbGainMoney
        
        # Track the difference
        new_money = pbPlayer.money rescue 0
        gained = new_money - old_money
        
        if gained > 0 && defined?(ShopData::Statistics)
          ShopData::Statistics.record_battle_money(gained)
        end
      end
    elsif !method_defined?(:kifr_shopdata_orig_pbGainMoney)
      # Economy hook doesn't exist, just do tracking on original
      alias_method :kifr_shopdata_orig_pbGainMoney, :pbGainMoney
      
      def pbGainMoney
        old_money = pbPlayer.money rescue 0
        kifr_shopdata_orig_pbGainMoney
        new_money = pbPlayer.money rescue 0
        gained = new_money - old_money
        
        if gained > 0 && defined?(ShopData::Statistics)
          ShopData::Statistics.record_battle_money(gained)
        end
      end
    end
  end
end
