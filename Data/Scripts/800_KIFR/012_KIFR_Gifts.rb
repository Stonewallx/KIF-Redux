#===============================================================================
# KIF Redux Gifts - Gift Pokemon & Item System
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file contains the comprehensive gift system:
# - Gifts::Pokemon - Gift Pokemon with custom OT, IV/EV presets
# - Gifts::Items - Gift items with quantity support
# - Gifts::Bundles - Gift bundles (multiple items/Pokemon)
# - Gifts::Rewards - Achievement-based rewards
# - Gifts::Starters - Starter Pokemon handling
# - Gifts::Mystery - Mystery gift support
#===============================================================================

module Gifts
  #=============================================================================
  # MILESTONE CATEGORY ORDER
  # Edit this array to change the display order of milestone categories
  # Available categories: :badge, :pokedex, :fusion, :shiny, :battle, :money
  #=============================================================================
  CATEGORY_ORDER = [:badge, :pokedex, :fusion, :shiny, :battle, :money]
  
  #=============================================================================
  # DEBUG LOGGING HELPER
  #=============================================================================
  def self.debug_log(message)
    if defined?(KIFRSettings) && KIFRSettings.respond_to?(:debug_log)
      KIFRSettings.debug_log("Economy::Gifts: #{message}")
    end
  end

  #=============================================================================
  # POKEMON MODULE - Gift Pokemon System
  #=============================================================================
  module Pokemon
    # IV/EV Preset configurations
    PRESETS = {
      perfect: { ivs: [31, 31, 31, 31, 31, 31], evs: [0, 0, 0, 0, 0, 0] },
      good: { ivs: [25, 25, 25, 25, 25, 25], evs: [0, 0, 0, 0, 0, 0] },
      average: { ivs: [15, 15, 15, 15, 15, 15], evs: [0, 0, 0, 0, 0, 0] },
      random: { ivs: nil, evs: [0, 0, 0, 0, 0, 0] },
      trained_physical: { ivs: [31, 31, 31, 31, 31, 31], evs: [4, 252, 0, 0, 0, 252] },
      trained_special: { ivs: [31, 31, 31, 31, 31, 31], evs: [4, 0, 0, 252, 0, 252] },
      trained_tank: { ivs: [31, 31, 31, 31, 31, 31], evs: [252, 0, 252, 0, 4, 0] }
    }.freeze
    
    # Default OT configuration
    DEFAULT_OT = {
      name: nil,      # nil = player's name
      id: nil,        # nil = player's ID
      gender: nil     # nil = player's gender
    }.freeze
    
    class << self
      # Give a Pokemon to the player
      # @param species [Symbol, Integer] Pokemon species
      # @param options [Hash] Configuration options
      # @param silent [Boolean] Suppress messages
      # @return [Pokemon, nil] The gifted Pokemon or nil if failed
      def give(species, options = {}, silent: false)
        return nil unless $Trainer
        
        # Parse options
        level = options[:level] || 5
        preset = options[:preset] || :random
        custom_ot = options[:custom_ot] || false
        ot_name = options[:ot_name]
        shiny = options[:shiny] || false
        ability_index = options[:ability_index]
        custom_ability = options[:custom_ability]  # Direct ability symbol override
        nature = options[:nature]
        moves = options[:moves]
        form = options[:form] || 0
        gender = options[:gender]
        nickname = options[:nickname]
        item = options[:item]
        ivs = options[:ivs]  # Direct IV array [HP, Atk, Def, SpA, SpD, Spe]
        evs = options[:evs]  # Direct EV array [HP, Atk, Def, SpA, SpD, Spe]
        
        # Create the Pokemon
        begin
          pkmn = ::Pokemon.new(species, level)
          
          # Apply preset IVs/EVs (only if no direct IVs/EVs specified)
          apply_preset(pkmn, preset) unless ivs || evs
          
          # Apply direct IVs if provided (nil values in array = keep random)
          if ivs && ivs.is_a?(Array) && ivs.length == 6
            [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each_with_index do |stat, i|
              # Only set if value is not nil (nil means keep the random value)
              pkmn.iv[stat] = ivs[i] if ivs[i] && ivs[i] != :random
            end
          end
          
          # Apply direct EVs if provided
          if evs && evs.is_a?(Array) && evs.length == 6
            [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each_with_index do |stat, i|
              pkmn.ev[stat] = evs[i] if evs[i]
            end
          end
          
          # Recalculate stats after IV/EV changes
          pkmn.calc_stats if ivs || evs
          
          # Custom OT
          if custom_ot && ot_name
            pkmn.owner = ::Pokemon::Owner.new(
              $Trainer.id,
              ot_name,
              $Trainer.gender,
              0
            )
          end
          
          # Shiny
          pkmn.shiny = true if shiny
          
          # Ability - custom_ability takes precedence over ability_index
          if custom_ability
            # Set ability directly by symbol (works for fusions and any ability)
            ability_data = GameData::Ability.try_get(custom_ability)
            pkmn.ability = ability_data.id if ability_data
          elsif ability_index
            pkmn.ability_index = ability_index
          end
          
          # Nature
          if nature
            nature_data = GameData::Nature.try_get(nature)
            pkmn.nature = nature_data.id if nature_data
          end
          
          # Moves
          if moves && moves.is_a?(Array)
            pkmn.moves.clear
            moves.each do |move|
              move_data = GameData::Move.try_get(move)
              pkmn.learn_move(move_data.id) if move_data
            end
          end
          
          # Form
          pkmn.form = form if form > 0
          
          # Gender (supports :male/:female symbols or 0/1 integers)
          if gender
            if gender.is_a?(Integer)
              pkmn.gender = gender
            else
              pkmn.gender = gender == :male ? 0 : (gender == :female ? 1 : 2)
            end
          end
          
          # Nickname
          pkmn.name = nickname if nickname
          
          # Held item
          if item
            item_data = GameData::Item.try_get(item)
            pkmn.item = item_data.id if item_data
          end
          
          # Add to party or PC
          if $Trainer.party_full?
            $PokemonStorage.pbStoreCaught(pkmn)
            Kernel.pbMessage(_INTL("{1} was sent to the PC.", pkmn.name)) if !silent && defined?(Kernel.pbMessage)
          else
            $Trainer.party.push(pkmn)
          end
          
          # Track statistics
          Statistics.record_pokemon(species, shiny)
          
          Gifts.debug_log("Pokemon given: #{species} (Lv#{level}, shiny=#{shiny})")
          return pkmn
        rescue => e
          Gifts.debug_log("ERROR: Failed to give #{species} - #{e.message}")
          return nil
        end
      end
      
      # Apply IV/EV preset to a Pokemon
      def apply_preset(pkmn, preset_name)
        preset = PRESETS[preset_name]
        return unless preset
        
        # Apply IVs
        if preset[:ivs]
          [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each_with_index do |stat, i|
            pkmn.iv[stat] = preset[:ivs][i]
          end
        end
        
        # Apply EVs
        if preset[:evs]
          [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each_with_index do |stat, i|
            pkmn.ev[stat] = preset[:evs][i]
          end
        end
        
        pkmn.calc_stats
      end
      
      # Give multiple Pokemon at once
      def give_multiple(pokemon_list)
        results = []
        pokemon_list.each do |entry|
          species = entry[:species] || entry[0]
          options = entry.is_a?(Hash) ? entry.reject { |k, _| k == :species } : {}
          results << give(species, options)
        end
        results.compact
      end
    end
  end

  #=============================================================================
  # ITEMS MODULE - Gift Items System
  #=============================================================================
  module Items
    class << self
      # Give an item to the player
      # @param item [Symbol, Integer] Item ID
      # @param quantity [Integer] Number of items
      # @param silent [Boolean] Suppress message
      # @return [Boolean] Success
      def give(item, quantity = 1, silent: false)
        item_data = GameData::Item.try_get(item) rescue nil
        return false unless item_data
        
        if silent
          # Use bag directly for silent adding
          if defined?($PokemonBag) && $PokemonBag
            $PokemonBag.pbStoreItem(item_data.id, quantity)
          elsif defined?($bag) && $bag.respond_to?(:pbStoreItem)
            $bag.pbStoreItem(item_data.id, quantity)
          else
            return false
          end
        else
          # Use pbReceiveItem for message display
          if defined?(pbReceiveItem)
            pbReceiveItem(item_data.id, quantity)
          elsif defined?(Kernel.pbReceiveItem)
            Kernel.pbReceiveItem(item_data.id, quantity)
          else
            # Fallback to bag + message
            if defined?($PokemonBag) && $PokemonBag
              $PokemonBag.pbStoreItem(item_data.id, quantity)
            elsif defined?($bag) && $bag.respond_to?(:pbStoreItem)
              $bag.pbStoreItem(item_data.id, quantity)
            else
              return false
            end
            if quantity > 1
              Kernel.pbMessage(_INTL("You received {1} {2}!", quantity, item_data.name_plural))
            else
              Kernel.pbMessage(_INTL("You received {1}!", item_data.name))
            end
          end
        end
        
        # Track statistics
        Statistics.record_item(item_data.id, quantity)
        
        # Also track in ShopData for economy milestones
        ShopData::Statistics.record_gift_items(quantity) if defined?(ShopData::Statistics)
        
        true
      end
      
      # Give multiple different items at once
      def give_multiple(items_list, silent: false)
        results = []
        items_list.each do |entry|
          if entry.is_a?(Array)
            item, quantity = entry
            results << give(item, quantity || 1, silent: silent)
          else
            results << give(entry, 1, silent: silent)
          end
        end
        results.all?
      end
      
      # Give money to the player
      def give_money(amount, silent: false)
        return false unless $Trainer
        return false if amount <= 0
        
        $Trainer.money += amount
        
        unless silent
          Kernel.pbMessage(_INTL("You received ${1}!", amount.to_s_formatted))
        end
        
        Statistics.record_money(amount)
        
        # Also track in ShopData for economy milestones
        ShopData::Statistics.record_gift_money(amount) if defined?(ShopData::Statistics)
        
        true
      end
    end
  end

  #=============================================================================
  # BUNDLES MODULE - Gift Bundles (Packages)
  #=============================================================================
  module Bundles
    # Predefined gift bundles
    PREDEFINED = {
      starter_pack: {
        name: "Starter Pack",
        description: "Essential items for new trainers",
        items: [
          [:POTION, 5],
          [:POKEBALL, 10],
          [:ANTIDOTE, 3]
        ],
        money: 3000
      },
      medicine_pack: {
        name: "Medicine Pack",
        items: [
          [:POTION, 10],
          [:SUPERPOTION, 5],
          [:ANTIDOTE, 5],
          [:PARALYZEHEAL, 5],
          [:AWAKENING, 5],
          [:BURNHEAL, 5],
          [:ICEHEAL, 5]
        ]
      },
      pokeball_pack: {
        name: "Pokeball Pack",
        items: [
          [:POKEBALL, 20],
          [:GREATBALL, 10],
          [:ULTRABALL, 5]
        ]
      },
      evolution_pack: {
        name: "Evolution Pack",
        items: [
          [:FIRESTONE, 1],
          [:THUNDERSTONE, 1],
          [:WATERSTONE, 1],
          [:LEAFSTONE, 1],
          [:MOONSTONE, 1],
          [:SUNSTONE, 1]
        ]
      },
      training_pack: {
        name: "Training Pack",
        items: [
          [:EXPCANDYXS, 10],
          [:EXPCANDYS, 5],
          [:EXPCANDYM, 3],
          [:RARECANDY, 1]
        ]
      },
      battle_pack: {
        name: "Battle Pack",
        items: [
          [:XATTACK, 5],
          [:XDEFENSE, 5],
          [:XSPEED, 5],
          [:XSPECIAL, 5],
          [:XACCURACY, 5],
          [:DIREHIT, 5]
        ]
      }
    }.freeze
    
    class << self
      # Give a predefined bundle
      def give(bundle_name, silent: false)
        bundle = PREDEFINED[bundle_name] || custom_bundles[bundle_name]
        return false unless bundle
        
        unless silent
          Kernel.pbMessage(_INTL("You received the {1}!", bundle[:name]))
        end
        
        # Give items
        if bundle[:items]
          bundle[:items].each do |item, quantity|
            Items.give(item, quantity || 1, silent: true)
          end
        end
        
        # Give Pokemon
        if bundle[:pokemon]
          bundle[:pokemon].each do |poke_data|
            Pokemon.give(poke_data[:species], poke_data)
          end
        end
        
        # Give money
        if bundle[:money]
          Items.give_money(bundle[:money], silent: true)
        end
        
        true
      end
      
      # Custom bundles storage
      def custom_bundles
        @custom_bundles ||= {}
      end
      
      # Create a custom bundle
      def create(name, config)
        custom_bundles[name.to_sym] = {
          name: config[:name] || name.to_s,
          description: config[:description] || "",
          items: config[:items] || [],
          pokemon: config[:pokemon] || [],
          money: config[:money] || 0
        }
      end
      
      # Get all available bundles
      def all
        PREDEFINED.merge(custom_bundles)
      end
    end
  end

  #=============================================================================
  # REWARDS MODULE - Achievement-Based Milestone Rewards
  #=============================================================================
  module Rewards
    # Milestone reward triggers - comprehensive list
    TRIGGERS = {
      # Badge Milestones - Kanto (1-8)
      badge_1: { name: "Boulder Badge", description: "Defeat Brock in Pewter City", items: [[:SUPERPOTION, 3], [:GREATBALL, 3]] },
      badge_2: { name: "Cascade Badge", description: "Defeat Misty in Cerulean City", items: [[:GREATBALL, 5], [:REPEL, 3]] },
      badge_3: { name: "Thunder Badge", description: "Defeat Lt. Surge in Vermilion City", items: [[:HYPERPOTION, 3], [:SUPERREPEL, 3]] },
      badge_4: { name: "Rainbow Badge", description: "Defeat Erika in Celadon City", items: [[:ULTRABALL, 5], [:FULLHEAL, 3]] },
      badge_5: { name: "Soul Badge", description: "Defeat Koga in Fuchsia City", items: [[:MAXPOTION, 3], [:MAXREPEL, 3]] },
      badge_6: { name: "Marsh Badge", description: "Defeat Sabrina in Saffron City", items: [[:FULLRESTORE, 3], [:MAXREPEL, 5]] },
      badge_7: { name: "Volcano Badge", description: "Defeat Blaine on Cinnabar Island", items: [[:REVIVE, 3], [:HYPERPOTION, 5]] },
      badge_8: { name: "Earth Badge", description: "Defeat the Viridian Gym Leader", items: [[:MAXREVIVE, 2], [:FULLRESTORE, 5]] },
      # Badge Milestones - Johto (9-16)
      badge_9: { name: "Zephyr Badge", description: "Defeat Falkner in Violet City", items: [[:ULTRABALL, 5], [:SITRUSBERRY, 3]] },
      badge_10: { name: "Hive Badge", description: "Defeat Bugsy in Azalea Town", items: [[:NETBALL, 5], [:SILVERPOWDER, 1]] },
      badge_11: { name: "Plain Badge", description: "Defeat Whitney in Goldenrod City", items: [[:HYPERPOTION, 5], [:RARECANDY, 2]] },
      badge_12: { name: "Fog Badge", description: "Defeat Morty in Ecruteak City", items: [[:DUSKBALL, 5], [:SPELLTAG, 1]] },
      badge_13: { name: "Storm Badge", description: "Defeat Chuck in Cianwood City", items: [[:MAXPOTION, 5], [:BLACKBELT, 1]] },
      badge_14: { name: "Mineral Badge", description: "Defeat Jasmine in Olivine City", items: [[:FULLRESTORE, 3], [:METALCOAT, 1]] },
      badge_15: { name: "Glacier Badge", description: "Defeat Pryce in Mahogany Town", items: [[:MAXREVIVE, 2], [:NEVERMELTICE, 1]] },
      badge_16: { name: "Rising Badge", description: "Defeat Clair in Blackthorn City", items: [[:MAXREVIVE, 3], [:DRAGONFANG, 1], [:RARECANDY, 5]] },
      
      # Pokedex Milestones (including fusions)
      first_catch: { name: "First Catch", description: "Catch your first Pokemon", items: [[:POKEBALL, 10]] },
      pokedex_10: { name: "Novice Collector", description: "Own 10 different Pokemon", items: [[:GREATBALL, 10]] },
      pokedex_25: { name: "Pokemon Enthusiast", description: "Own 25 different Pokemon", items: [[:ULTRABALL, 5], [:POTION, 5]] },
      pokedex_50: { name: "Dedicated Trainer", description: "Own 50 different Pokemon", items: [[:ULTRABALL, 10], [:SUPERPOTION, 5]] },
      pokedex_100: { name: "Pokemon Expert", description: "Own 100 different Pokemon", items: [[:RARECANDY, 3], [:PPUP, 1]] },
      pokedex_200: { name: "Master Collector", description: "Own 200 different Pokemon", items: [[:RARECANDY, 5], [:PPUP, 2]] },
      pokedex_300: { name: "Dex Enthusiast", description: "Own 300 different Pokemon", items: [[:RARECANDY, 5], [:PPMAX, 1]] },
      pokedex_400: { name: "Fusion Fanatic", description: "Own 400 different Pokemon", items: [[:RARECANDY, 5], [:ABILITYCAPSULE, 1]] },
      pokedex_500: { name: "Living Dex Aspirant", description: "Own 500 different Pokemon", items: [[:RARECANDY, 10], [:BOTTLECAP, 1]] },
      pokedex_750: { name: "Dex Completionist", description: "Own 750 different Pokemon", items: [[:RARECANDY, 10], [:BOTTLECAP, 3]] },
      pokedex_1000: { name: "Ultimate Collector", description: "Own 1000 different Pokemon", items: [[:MASTERBALL, 1], [:GOLDBOTTLECAP, 1]] },
      
      # Battle Milestones
      first_battle: { name: "First Victory", description: "Win your first trainer battle", items: [[:POTION, 5]] },
      battles_10: { name: "Rising Challenger", description: "Win 10 trainer battles", items: [[:SUPERPOTION, 5]] },
      battles_25: { name: "Skilled Fighter", description: "Win 25 trainer battles", items: [[:HYPERPOTION, 3], [:REVIVE, 1]] },
      battles_50: { name: "Battle Veteran", description: "Win 50 trainer battles", items: [[:HYPERPOTION, 5], [:REVIVE, 2]] },
      battles_100: { name: "Battle Expert", description: "Win 100 trainer battles", items: [[:FULLRESTORE, 3], [:REVIVE, 3]] },
      battles_250: { name: "Battle Master", description: "Win 250 trainer battles", items: [[:FULLRESTORE, 5], [:MAXREVIVE, 1]] },
      battles_500: { name: "Champion's Rival", description: "Win 500 trainer battles", items: [[:FULLRESTORE, 10], [:MAXREVIVE, 3]] },
      battles_1000: { name: "Legendary Fighter", description: "Win 1000 trainer battles", items: [[:FULLRESTORE, 15], [:MAXREVIVE, 5], [:RARECANDY, 10]] },
      
      # Fusion Milestones
      first_fusion: { name: "Fusion Pioneer", description: "Create your first fusion", items: [[:DNASPLICERS, 2]] },
      fusions_10: { name: "Fusion Apprentice", description: "Create 10 fusions", items: [[:DNASPLICERS, 3], [:RARECANDY, 2]] },
      fusions_25: { name: "Fusion Scientist", description: "Create 25 fusions", items: [[:DNASPLICERS, 5], [:RARECANDY, 3]] },
      fusions_50: { name: "Fusion Expert", description: "Create 50 fusions", items: [[:DNASPLICERS, 5], [:PPUP, 2]] },
      fusions_100: { name: "Fusion Master", description: "Create 100 fusions", items: [[:DNASPLICERS, 10], [:ABILITYCAPSULE, 1]] },
      fusions_250: { name: "Fusion Architect", description: "Create 250 fusions", items: [[:DNASPLICERS, 10], [:BOTTLECAP, 2]] },
      
      # Shiny Milestones
      first_shiny: { name: "Shiny Hunter", description: "Catch your first shiny Pokemon", items: [[:RARECANDY, 3]] },
      shinies_5: { name: "Shiny Seeker", description: "Catch 5 shiny Pokemon", items: [[:RARECANDY, 5], [:PPUP, 1]] },
      shinies_10: { name: "Shiny Enthusiast", description: "Catch 10 shiny Pokemon", items: [[:RARECANDY, 5], [:BOTTLECAP, 1]] },
      shinies_25: { name: "Shiny Collector", description: "Catch 25 shiny Pokemon", items: [[:RARECANDY, 10], [:ABILITYCAPSULE, 1]] },
      shinies_50: { name: "Shiny Expert", description: "Catch 50 shiny Pokemon", items: [[:BOTTLECAP, 3], [:PPMAX, 1]] },
      shinies_100: { name: "Shiny Master", description: "Catch 100 shiny Pokemon", items: [[:GOLDBOTTLECAP, 1], [:MASTERBALL, 1]] },
      
      # Economy Milestones - Money (max money is 999,999)
      money_10000: { name: "Pocket Change", description: "Have $10,000 at once", money: 1000 },
      money_50000: { name: "Comfortable", description: "Have $50,000 at once", money: 2500, items: [[:NUGGET, 1]] },
      money_100000: { name: "Well Off", description: "Have $100,000 at once", money: 5000, items: [[:NUGGET, 2]] },
      money_250000: { name: "Wealthy Trainer", description: "Have $250,000 at once", money: 10000, items: [[:BIGNUGGET, 1]] },
      money_500000: { name: "Pokemon Tycoon", description: "Have $500,000 at once", money: 25000, items: [[:BIGNUGGET, 2]] },
      money_999999: { name: "Maxed Out", description: "Reach the money cap of $999,999", money: 50000, items: [[:BIGNUGGET, 3]] },
      
      # Economy Milestones - Items Bought
      items_bought_500: { name: "Regular Customer", description: "Buy 500 items from shops", money: 5000 },
      items_bought_1000: { name: "Frequent Shopper", description: "Buy 1,000 items from shops", money: 15000, items: [[:RARECANDY, 3]] },
      items_bought_2500: { name: "Shopping Addict", description: "Buy 2,500 items from shops", money: 50000, items: [[:PPUP, 5]] },
      items_bought_5000: { name: "Master Consumer", description: "Buy 5,000 items from shops", money: 100000, items: [[:MASTERBALL, 1]] },
      
      # Economy Milestones - Items Sold
      items_sold_500: { name: "Street Vendor", description: "Sell 500 items to shops", money: 5000 },
      items_sold_1000: { name: "Merchant", description: "Sell 1,000 items to shops", money: 15000, items: [[:NUGGET, 3]] },
      items_sold_2500: { name: "Trader", description: "Sell 2,500 items to shops", money: 50000, items: [[:BIGNUGGET, 5]] },
      items_sold_5000: { name: "Tycoon", description: "Sell 5,000 items to shops", money: 100000, items: [[:ABILITYCAPSULE, 1]] }
    }.freeze
    
    class << self
      def claimed_rewards
        $game_system.claimed_rewards ||= []
      end
      
      # Check if a reward has been claimed
      def claimed?(trigger_name)
        claimed_rewards.include?(trigger_name.to_sym)
      end
      
      # Claim a reward
      def claim(trigger_name, silent: false)
        trigger = TRIGGERS[trigger_name.to_sym]
        return false unless trigger
        return false if claimed?(trigger_name)
        
        # Mark as claimed
        claimed_rewards << trigger_name.to_sym
        
        unless silent
          Kernel.pbMessage(_INTL("Congratulations! {1} reward!", trigger[:name]))
        end
        
        # Give items
        if trigger[:items]
          trigger[:items].each do |item, quantity|
            Items.give(item, quantity || 1, silent: true)
          end
        end
        
        # Give Pokemon
        if trigger[:pokemon]
          trigger[:pokemon].each do |poke_data|
            Pokemon.give(poke_data[:species], poke_data)
          end
        end
        
        # Give money
        if trigger[:money]
          Items.give_money(trigger[:money], silent: true)
        end
        
        true
      end
      
      # Send a milestone reward to the Gift Inbox (doesn't give items directly)
      def send_to_inbox(trigger_name)
        trigger = TRIGGERS[trigger_name.to_sym]
        return false unless trigger
        return false if claimed?(trigger_name)
        return false unless milestone_unlocked?(trigger_name)
        
        # Mark as claimed so it can't be sent again
        claimed_rewards << trigger_name.to_sym
        
        # Count reward types to determine if we need a bundle
        reward_types = 0
        reward_types += 1 if trigger[:items] && trigger[:items].any?
        reward_types += 1 if trigger[:money] && trigger[:money] > 0
        reward_types += 1 if trigger[:pokemon] && trigger[:pokemon].any?
        
        item_count = trigger[:items] ? trigger[:items].length : 0
        
        # Use bundle if multiple reward types OR multiple items
        if reward_types > 1 || item_count > 1
          rewards = {
            items: trigger[:items],
            money: trigger[:money],
            pokemon: trigger[:pokemon]
          }
          Inbox.add_bundle(rewards, trigger[:name], "Milestone")
        else
          # Single reward type with single item - add individually
          if trigger[:items] && trigger[:items].any?
            Inbox.add_items(trigger[:items], trigger[:name], "Milestone")
          elsif trigger[:money] && trigger[:money] > 0
            Inbox.add_money(trigger[:money], trigger[:name], "Milestone")
          elsif trigger[:pokemon] && trigger[:pokemon].any?
            trigger[:pokemon].each do |poke_data|
              Inbox.add_pokemon(poke_data[:species], poke_data, trigger[:name], "Milestone")
            end
          end
        end
        
        Gifts.debug_log("Rewards: Sent #{trigger[:name]} to Gift Inbox")
        true
      end
      
      # Check and auto-claim badge rewards
      def check_badge_rewards
        return unless $Trainer
        
        badge_count = $Trainer.badge_count rescue 0
        
        (1..badge_count).each do |badge|
          trigger = "badge_#{badge}".to_sym
          claim(trigger) unless claimed?(trigger)
        end
      end
      
      # Check and auto-claim Pokedex rewards
      def check_pokedex_rewards
        return unless $Trainer
        
        caught = $Trainer.pokedex.owned_count rescue 0
        
        claim(:first_catch) if caught >= 1 && !claimed?(:first_catch)
        claim(:pokedex_10) if caught >= 10 && !claimed?(:pokedex_10)
        claim(:pokedex_25) if caught >= 25 && !claimed?(:pokedex_25)
        claim(:pokedex_50) if caught >= 50 && !claimed?(:pokedex_50)
        claim(:pokedex_100) if caught >= 100 && !claimed?(:pokedex_100)
        claim(:pokedex_150) if caught >= 150 && !claimed?(:pokedex_150)
        claim(:pokedex_200) if caught >= 200 && !claimed?(:pokedex_200)
      end
      
      # Get all milestones with their status
      def all_milestones
        TRIGGERS.map do |key, data|
          {
            key: key,
            name: data[:name],
            description: data[:description] || "",
            items: data[:items] || [],
            money: data[:money] || 0,
            pokemon: data[:pokemon] || [],
            claimed: claimed?(key),
            unlocked: milestone_unlocked?(key)
          }
        end
      end
      
      # Check if a milestone is unlocked (conditions met)
      def milestone_unlocked?(trigger_name)
        return true if claimed?(trigger_name)  # Already claimed = was unlocked
        return false unless $Trainer
        
        badge_count = $Trainer.badge_count rescue 0
        pokedex_count = $Trainer.pokedex.owned_count rescue 0
        money = $Trainer.money rescue 0
        fusion_count = count_fusions
        shiny_count = count_shinies
        battle_count = count_battles
        items_bought_count = (defined?(ShopData::Statistics) ? ShopData::Statistics.items_bought_count : 0) rescue 0
        items_sold_count = (defined?(ShopData::Statistics) ? ShopData::Statistics.items_sold_count : 0) rescue 0
        
        case trigger_name.to_sym
        # Badge Milestones - Kanto
        when :badge_1 then badge_count >= 1
        when :badge_2 then badge_count >= 2
        when :badge_3 then badge_count >= 3
        when :badge_4 then badge_count >= 4
        when :badge_5 then badge_count >= 5
        when :badge_6 then badge_count >= 6
        when :badge_7 then badge_count >= 7
        when :badge_8 then badge_count >= 8
        # Badge Milestones - Johto
        when :badge_9 then badge_count >= 9
        when :badge_10 then badge_count >= 10
        when :badge_11 then badge_count >= 11
        when :badge_12 then badge_count >= 12
        when :badge_13 then badge_count >= 13
        when :badge_14 then badge_count >= 14
        when :badge_15 then badge_count >= 15
        when :badge_16 then badge_count >= 16
        # Pokedex Milestones
        when :first_catch then pokedex_count >= 1
        when :pokedex_10 then pokedex_count >= 10
        when :pokedex_25 then pokedex_count >= 25
        when :pokedex_50 then pokedex_count >= 50
        when :pokedex_100 then pokedex_count >= 100
        when :pokedex_200 then pokedex_count >= 200
        when :pokedex_300 then pokedex_count >= 300
        when :pokedex_400 then pokedex_count >= 400
        when :pokedex_500 then pokedex_count >= 500
        when :pokedex_750 then pokedex_count >= 750
        when :pokedex_1000 then pokedex_count >= 1000
        # Economy Milestones - Money
        when :money_10000 then money >= 10000
        when :money_50000 then money >= 50000
        when :money_100000 then money >= 100000
        when :money_250000 then money >= 250000
        when :money_500000 then money >= 500000
        when :money_999999 then money >= 999999
        # Economy Milestones - Items Bought
        when :items_bought_500 then items_bought_count >= 500
        when :items_bought_1000 then items_bought_count >= 1000
        when :items_bought_2500 then items_bought_count >= 2500
        when :items_bought_5000 then items_bought_count >= 5000
        # Economy Milestones - Items Sold
        when :items_sold_500 then items_sold_count >= 500
        when :items_sold_1000 then items_sold_count >= 1000
        when :items_sold_2500 then items_sold_count >= 2500
        when :items_sold_5000 then items_sold_count >= 5000
        # Fusion Milestones
        when :first_fusion then fusion_count >= 1
        when :fusions_10 then fusion_count >= 10
        when :fusions_25 then fusion_count >= 25
        when :fusions_50 then fusion_count >= 50
        when :fusions_100 then fusion_count >= 100
        when :fusions_250 then fusion_count >= 250
        # Shiny Milestones
        when :first_shiny then shiny_count >= 1
        when :shinies_5 then shiny_count >= 5
        when :shinies_10 then shiny_count >= 10
        when :shinies_25 then shiny_count >= 25
        when :shinies_50 then shiny_count >= 50
        when :shinies_100 then shiny_count >= 100
        # Battle Milestones
        when :first_battle then battle_count >= 1
        when :battles_10 then battle_count >= 10
        when :battles_25 then battle_count >= 25
        when :battles_50 then battle_count >= 50
        when :battles_100 then battle_count >= 100
        when :battles_250 then battle_count >= 250
        when :battles_500 then battle_count >= 500
        when :battles_1000 then battle_count >= 1000
        else false  # Unknown milestones are locked by default
        end
      end
      
      # Count unlocked but unclaimed milestones
      def unclaimed_count
        count = 0
        TRIGGERS.keys.each do |key|
          count += 1 if milestone_unlocked?(key) && !claimed?(key)
        end
        count
      end
      
      # Check if there are any unclaimed milestones
      def has_unclaimed?
        TRIGGERS.keys.any? { |key| milestone_unlocked?(key) && !claimed?(key) }
      end
      
      # Get lifetime fusion count (only increases, never decreases)
      def count_fusions
        $game_system.kifr_fusions_created ||= 0
      end
      
      # Get lifetime shiny caught count (only increases, never decreases)
      def count_shinies
        $game_system.kifr_shinies_caught ||= 0
      end
      
      # Increment fusion count (call this when a fusion is created)
      def record_fusion_created
        $game_system.kifr_fusions_created ||= 0
        $game_system.kifr_fusions_created += 1
        Gifts.debug_log("Rewards: Fusion created - Total: #{$game_system.kifr_fusions_created}")
      end
      
      # Increment shiny caught count (call this when a shiny is caught)
      def record_shiny_caught
        $game_system.kifr_shinies_caught ||= 0
        $game_system.kifr_shinies_caught += 1
        Gifts.debug_log("Rewards: Shiny caught - Total: #{$game_system.kifr_shinies_caught}")
      end
      
      # Increment battle win count (call this when a trainer battle is won)
      def record_battle_won
        $game_system.kifr_battles_won ||= 0
        $game_system.kifr_battles_won += 1
        Gifts.debug_log("Rewards: Battle won - Total: #{$game_system.kifr_battles_won}")
      end
      
      # Get lifetime battle win count
      def count_battles
        $game_system.kifr_battles_won ||= 0
      end
      
      # Increment battle loss count (call this when a trainer battle is lost)
      def record_battle_lost
        $game_system.kifr_battles_lost ||= 0
        $game_system.kifr_battles_lost += 1
        Gifts.debug_log("Rewards: Battle lost - Total: #{$game_system.kifr_battles_lost}")
      end
      
      # Get lifetime battle loss count
      def count_battles_lost
        $game_system.kifr_battles_lost ||= 0
      end
    end
  end

  #=============================================================================
  # EVENTS MODULE - Scheduled Event Gifts
  #=============================================================================
  # Event gift definitions are stored in 012a_KIFR_EventGifts.rb
  # This module handles the delivery logic.
  # 
  # Frequency options:
  #   :once    - One time only (default)
  #   :daily   - Can receive once per day
  #   :weekly  - Can receive once per week
  #   :monthly - Can receive once per month
  #   :yearly  - Can receive once per year
  #=============================================================================
  module Events
    # SCHEDULED_GIFTS is defined in 012a_KIFR_EventGifts.rb
    # This allows runtime additions from the Gift Creator tool
    
    # Frequency periods in seconds
    FREQUENCY_PERIODS = {
      once: nil,           # Never repeats
      daily: 86400,        # 24 hours
      weekly: 604800,      # 7 days
      monthly: 2592000,    # ~30 days
      yearly: 31536000     # 365 days
    }
    
    class << self
      # Get the scheduled gifts hash (from 012a file)
      def scheduled_gifts
        return SCHEDULED_GIFTS if defined?(SCHEDULED_GIFTS)
        {}
      end
      
      # Get hash of received events with timestamps
      # Format: { event_id: timestamp_or_true }
      def received_events
        $game_system.received_events ||= {}
        # Convert old array format to hash if needed
        if $game_system.received_events.is_a?(Array)
          old_events = $game_system.received_events
          $game_system.received_events = {}
          old_events.each { |e| $game_system.received_events[e.to_sym] = true }
        end
        $game_system.received_events
      end
      
      # Check if an event has been received (considering frequency)
      def received?(event_id, event = nil)
        event_sym = event_id.to_sym
        last_received = received_events[event_sym]
        return false unless last_received
        
        # Get frequency from event data
        event ||= scheduled_gifts[event_sym]
        frequency = event[:frequency] if event
        frequency ||= :once
        
        # One-time gifts - if received at all, can't receive again
        return true if frequency == :once
        return true if last_received == true  # Old format, treat as once
        
        # Check if enough time has passed for recurring gifts
        period = FREQUENCY_PERIODS[frequency]
        return true unless period  # Unknown frequency, treat as once
        
        # Compare timestamps
        time_since = Time.now.to_i - last_received.to_i
        time_since < period
      end
      
      # Mark an event as received with timestamp
      def mark_received(event_id)
        received_events[event_id.to_sym] = Time.now.to_i
      end
      
      # Parse date string "MM-DD-YY" to comparable format
      def parse_date(date_str)
        return nil unless date_str
        if date_str =~ /^(\d{2})-(\d{2})-(\d{2})$/
          month, day, year = $1.to_i, $2.to_i, $3.to_i
          # Convert 2-digit year to 4-digit (26 -> 2026)
          year += 2000 if year < 100
          return Time.new(year, month, day) rescue nil
        end
        nil
      end
      
      # Get current date for comparison
      def current_date
        Time.now
      end
      
      # Check if an event is currently active (within date range)
      def event_active?(event)
        start_date = parse_date(event[:start_date])
        end_date = parse_date(event[:end_date])
        now = current_date
        
        # Must have a start date
        return false unless start_date
        
        # Check if we're past the start date
        return false if now < start_date
        
        # Check if we're before the end date (if specified)
        if end_date
          # Add 1 day to end_date to include the full end day
          return false if now >= (end_date + 86400)
        end
        
        true
      end
      
      # Check if player meets event conditions
      def conditions_met?(event)
        conditions = event[:conditions] || {}
        
        # Check minimum badges
        if conditions[:min_badges] && conditions[:min_badges] > 0
          badge_count = $Trainer.badge_count rescue 0
          return false if badge_count < conditions[:min_badges]
        end
        
        # Check minimum playtime (in hours)
        if conditions[:min_playtime] && conditions[:min_playtime] > 0
          playtime_hours = ($PokemonGlobal.playtime || 0) / 3600.0 rescue 0
          return false if playtime_hours < conditions[:min_playtime]
        end
        
        # Check game flag/switch
        if conditions[:flag] && conditions[:flag] > 0
          return false unless $game_switches[conditions[:flag]] rescue false
        end
        
        true
      end
      
      # Deliver a single event gift to the inbox
      def deliver_event(event_id, event)
        return false if received?(event_id)
        return false unless event_active?(event)
        return false unless conditions_met?(event)
        
        rewards = event[:rewards] || {}
        name = event[:name] || "Event Gift"
        source = event[:source] || "Event"
        
        # Count how many reward types we have
        reward_types = 0
        reward_types += 1 if rewards[:items] && rewards[:items].any?
        reward_types += 1 if rewards[:money] && rewards[:money] > 0
        reward_types += 1 if rewards[:coins] && rewards[:coins] > 0
        reward_types += 1 if rewards[:pokemon] && rewards[:pokemon].any?
        reward_types += 1 if rewards[:eggs] && rewards[:eggs].any?
        
        # Count individual items
        item_count = rewards[:items] ? rewards[:items].length : 0
        
        # Use bundle if multiple reward types OR multiple items
        # This keeps gifts organized in the inbox
        if reward_types > 1 || item_count > 1
          Inbox.add_bundle(rewards, name, source)
        else
          # Single reward type, deliver individually
          if rewards[:items] && rewards[:items].any?
            Inbox.add_items(rewards[:items], name, source)
          end
          
          if rewards[:money] && rewards[:money] > 0
            Inbox.add_money(rewards[:money], name, source)
          end
          
          if rewards[:coins] && rewards[:coins] > 0
            Inbox.add_coins(rewards[:coins], name, source)
          end
          
          if rewards[:pokemon] && rewards[:pokemon].any?
            rewards[:pokemon].each do |poke_data|
              Inbox.add_pokemon(poke_data[:species], poke_data, name, source)
            end
          end
          
          if rewards[:eggs] && rewards[:eggs].any?
            rewards[:eggs].each do |egg_data|
              Inbox.add_egg(egg_data[:species], egg_data, name, source)
            end
          end
        end
        
        # Mark as received
        mark_received(event_id)
        
        Gifts.debug_log("Events: Delivered '#{name}' (#{event_id})")
        true
      end
      
      # Check all scheduled gifts and deliver any that are ready
      def check_and_deliver
        delivered_count = 0
        gifts = scheduled_gifts
        
        gifts.each do |event_id, event|
          if deliver_event(event_id, event)
            delivered_count += 1
          end
        end
        
        Gifts.debug_log("Events: Checked #{gifts.length} events, delivered #{delivered_count}")
        delivered_count
      end
      
      # Add a new gift to the scheduled gifts (used by Gift Creator)
      def add_scheduled_gift(id, gift_data)
        return false unless defined?(SCHEDULED_GIFTS)
        SCHEDULED_GIFTS[id.to_sym] = gift_data
        Gifts.debug_log("Events: Added new scheduled gift '#{id}'")
        true
      end
    end
  end

  #=============================================================================
  # INBOX MODULE - Gift Inbox System for Claimable Gifts
  #=============================================================================
  module Inbox
    class << self
      # Get the inbox data
      def data
        $game_system.gift_inbox ||= []
      end
      
      # Add a gift to the inbox
      # @param gift_type [Symbol] :item, :pokemon, :money, :bundle
      # @param gift_data [Hash] Gift details
      # @param reason [String] Why this gift was given (display name)
      # @param source [String] Source category (Milestone, Event, Mystery, etc.)
      def add(gift_type, gift_data, reason = "Gift", source = "Gift")
        entry = {
          id: Time.now.to_i.to_s + rand(1000).to_s,
          type: gift_type,
          data: gift_data,
          reason: reason,
          source: source,
          date: Time.now.strftime("%m-%d-%y"),
          claimed: false,
          seen: false
        }
        data << entry
        Gifts.debug_log("Inbox: Added #{gift_type} gift - #{reason} (#{source})")
        entry[:id]
      end
      
      # Add an item to the inbox
      def add_item(item, quantity = 1, reason = "Item Gift", source = "Gift")
        add(:item, { item: item, quantity: quantity }, reason, source)
      end
      
      # Add multiple items to the inbox as one gift
      def add_items(items_array, reason = "Item Bundle", source = "Gift")
        add(:items, { items: items_array }, reason, source)
      end
      
      # Add a Pokemon to the inbox
      def add_pokemon(species, options = {}, reason = "Pokemon Gift", source = "Gift")
        add(:pokemon, { species: species, options: options }, reason, source)
      end
      
      # Add a Pokemon egg to the inbox
      # @param species [Symbol, nil] Species for the egg (nil = random)
      # @param options [Hash] Egg options (steps, shiny chance, etc.)
      def add_egg(species = nil, options = {}, reason = "Egg Gift", source = "Gift")
        add(:egg, { species: species, options: options }, reason, source)
      end
      
      # Add money to the inbox
      def add_money(amount, reason = "Money Gift", source = "Gift")
        add(:money, { amount: amount }, reason, source)
      end
      
      # Add Game Corner coins to the inbox
      def add_coins(amount, reason = "Coins Gift", source = "Gift")
        add(:coins, { amount: amount }, reason, source)
      end
      
      # Add a reward bundle (multiple reward types in one gift)
      # @param rewards [Hash] All rewards { items: [...], pokemon: [...], money: N, coins: N }
      # @param reason [String] Display name
      # @param source [String] Source category
      def add_bundle(rewards, reason = "Reward Bundle", source = "Gift")
        add(:bundle, { rewards: rewards }, reason, source)
      end
      
      # Get all unclaimed gifts
      def unclaimed
        data.select { |g| !g[:claimed] }
      end
      
      # Get all claimed gifts
      def claimed
        data.select { |g| g[:claimed] }
      end
      
      # Count unclaimed gifts
      def count
        unclaimed.length
      end
      
      # Check if inbox has unclaimed gifts
      def has_gifts?
        count > 0
      end
      
      # Get all unseen gifts (not yet viewed in Milestone Rewards)
      def unseen
        data.select { |g| !g[:seen] && !g[:claimed] }
      end
      
      # Count unseen gifts
      def unseen_count
        unseen.length
      end
      
      # Check if there are unseen gifts
      def has_unseen?
        unseen_count > 0
      end
      
      # Mark all gifts as seen
      def mark_all_seen
        data.each { |g| g[:seen] = true }
        Gifts.debug_log("Inbox: Marked all gifts as seen")
      end
      
      # Claim a specific gift by ID
      def claim(gift_id, silent: false)
        gift = data.find { |g| g[:id] == gift_id && !g[:claimed] }
        return false unless gift
        
        success = deliver_gift(gift, silent: silent)
        if success
          gift[:claimed] = true
          gift[:claimed_date] = Time.now.strftime("%m-%d-%y")
          Gifts.debug_log("Inbox: Claimed gift #{gift_id} - #{gift[:reason]}")
          Kernel.pbMessage(_INTL("Your gift was claimed!")) unless silent
        end
        success
      end
      
      # Claim all unclaimed gifts
      def claim_all
        count = 0
        unclaimed.each do |gift|
          count += 1 if claim(gift[:id], silent: true)
        end
        Kernel.pbMessage(_INTL("All gifts have been claimed!")) if count > 0
        count
      end
      
      # Deliver the actual gift contents
      def deliver_gift(gift, silent: false)
        case gift[:type]
        when :item
          Items.give(gift[:data][:item], gift[:data][:quantity] || 1, silent: true)
        when :items
          items_data = gift[:data][:items]
          return false unless items_data && items_data.is_a?(Array)
          
          items_data.each do |entry|
            if entry.is_a?(Array)
              # Format: [:ITEM, quantity]
              item = entry[0]
              qty = entry[1] || 1
            elsif entry.is_a?(Hash)
              # Format: { item: :ITEM, quantity: N }
              item = entry[:item]
              qty = entry[:quantity] || 1
            else
              # Direct item symbol
              item = entry
              qty = 1
            end
            Items.give(item, qty, silent: true)
          end
          true
        when :pokemon
          Pokemon.give(gift[:data][:species], gift[:data][:options] || {}, silent: silent)
        when :egg
          # Generate egg Pokemon
          species = gift[:data][:species]
          options = gift[:data][:options] || {}
          
          # If no species specified, pick random from common Pokemon
          unless species
            common_pokemon = [:BULBASAUR, :CHARMANDER, :SQUIRTLE, :PIKACHU, :EEVEE, :TOGEPI]
            species = common_pokemon.sample
          end
          
          level = 1
          pkmn = ::Pokemon.new(species, level)
          pkmn.egg_steps = options[:steps] || pkmn.species_data.hatch_steps
          pkmn.obtain_method = 1  # Egg
          pkmn.shiny = true if options[:shiny]
          
          if $Trainer.party_full?
            $PokemonStorage.pbStoreCaught(pkmn)
          else
            $Trainer.party.push(pkmn)
          end
          true
        when :coins
          amount = gift[:data][:amount] || 0
          if $Trainer.respond_to?(:coins=)
            $Trainer.coins += amount
            true
          else
            false
          end
        when :money
          Items.give_money(gift[:data][:amount], silent: true)
        when :bundle
          # Bundle contains multiple reward types
          rewards = gift[:data][:rewards] || {}
          success = true
          
          # Deliver items
          if rewards[:items] && rewards[:items].is_a?(Array)
            rewards[:items].each do |entry|
              if entry.is_a?(Array)
                Items.give(entry[0], entry[1] || 1, silent: true)
              elsif entry.is_a?(Hash)
                Items.give(entry[:item], entry[:quantity] || 1, silent: true)
              end
            end
          end
          
          # Deliver Pokemon
          if rewards[:pokemon] && rewards[:pokemon].is_a?(Array)
            rewards[:pokemon].each do |poke|
              Pokemon.give(poke[:species], poke, silent: true)
            end
          end
          
          # Deliver eggs
          if rewards[:eggs] && rewards[:eggs].is_a?(Array)
            rewards[:eggs].each do |egg|
              species = egg[:species]
              # Similar egg code as :egg type
              unless species
                common_pokemon = [:BULBASAUR, :CHARMANDER, :SQUIRTLE, :PIKACHU, :EEVEE, :TOGEPI]
                species = common_pokemon.sample
              end
              pkmn = ::Pokemon.new(species, 1)
              pkmn.egg_steps = egg[:steps] || pkmn.species_data.hatch_steps
              pkmn.obtain_method = 1
              pkmn.shiny = true if egg[:shiny]
              if $Trainer.party_full?
                $PokemonStorage.pbStoreCaught(pkmn)
              else
                $Trainer.party.push(pkmn)
              end
            end
          end
          
          # Deliver money
          if rewards[:money] && rewards[:money] > 0
            Items.give_money(rewards[:money], silent: true)
          end
          
          # Deliver coins
          if rewards[:coins] && rewards[:coins] > 0 && $Trainer.respond_to?(:coins=)
            $Trainer.coins += rewards[:coins]
          end
          
          success
        else
          false
        end
      end
      
      # Get gift display info
      def gift_description(gift)
        case gift[:type]
        when :item
          item_data = GameData::Item.try_get(gift[:data][:item]) rescue nil
          item_name = item_data ? item_data.name : gift[:data][:item].to_s
          "#{gift[:data][:quantity]}x #{item_name}"
        when :items
          items_text = gift[:data][:items].map do |item, qty|
            item_data = GameData::Item.try_get(item) rescue nil
            item_name = item_data ? item_data.name : item.to_s
            "#{qty || 1}x #{item_name}"
          end.join(", ")
          items_text
        when :pokemon
          species_data = GameData::Species.try_get(gift[:data][:species]) rescue nil
          species_name = species_data ? species_data.name : gift[:data][:species].to_s
          "Pokemon: #{species_name}"
        when :egg
          if gift[:data][:species]
            species_data = GameData::Species.try_get(gift[:data][:species]) rescue nil
            species_name = species_data ? species_data.name : gift[:data][:species].to_s
            "#{species_name} Egg"
          else
            "Mystery Egg"
          end
        when :coins
          "#{gift[:data][:amount].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} Coins"
        when :money
          "$#{gift[:data][:amount].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
        when :bundle
          "Reward Bundle"
        else
          "Unknown Gift"
        end
      end
      
      # Get detailed bundle contents description
      def bundle_details(gift)
        return [] unless gift[:type] == :bundle
        rewards = gift[:data][:rewards] || {}
        details = []
        
        # Items
        if rewards[:items] && rewards[:items].is_a?(Array)
          rewards[:items].each do |entry|
            if entry.is_a?(Array)
              item_data = GameData::Item.try_get(entry[0]) rescue nil
              item_name = item_data ? item_data.name : entry[0].to_s
              details << "#{entry[1] || 1}x #{item_name}"
            elsif entry.is_a?(Hash)
              item_data = GameData::Item.try_get(entry[:item]) rescue nil
              item_name = item_data ? item_data.name : entry[:item].to_s
              details << "#{entry[:quantity] || 1}x #{item_name}"
            end
          end
        end
        
        # Pokemon
        if rewards[:pokemon] && rewards[:pokemon].is_a?(Array)
          rewards[:pokemon].each do |poke|
            species_data = GameData::Species.try_get(poke[:species]) rescue nil
            species_name = species_data ? species_data.name : poke[:species].to_s
            level = poke[:level] || 5
            shiny_str = poke[:shiny] ? " (Shiny)" : ""
            details << "Lv.#{level} #{species_name}#{shiny_str}"
          end
        end
        
        # Eggs
        if rewards[:eggs] && rewards[:eggs].is_a?(Array)
          rewards[:eggs].each do |egg|
            if egg[:species]
              species_data = GameData::Species.try_get(egg[:species]) rescue nil
              species_name = species_data ? species_data.name : egg[:species].to_s
              details << "#{species_name} Egg"
            else
              details << "Mystery Egg"
            end
          end
        end
        
        # Money
        if rewards[:money] && rewards[:money] > 0
          formatted = rewards[:money].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
          details << "$#{formatted}"
        end
        
        # Coins
        if rewards[:coins] && rewards[:coins] > 0
          formatted = rewards[:coins].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
          details << "#{formatted} Coins"
        end
        
        details
      end
      
      # Clear all claimed gifts (cleanup)
      def clear_claimed
        data.reject! { |g| g[:claimed] }
      end
    end
  end

  #=============================================================================
  # STARTERS MODULE - Starter Pokemon Handling
  #=============================================================================
  module Starters
    # Starter Pokemon configurations per generation
    GENERATIONS = {
      gen1: [:BULBASAUR, :CHARMANDER, :SQUIRTLE],
      gen2: [:CHIKORITA, :CYNDAQUIL, :TOTODILE],
      gen3: [:TREECKO, :TORCHIC, :MUDKIP],
      gen4: [:TURTWIG, :CHIMCHAR, :PIPLUP],
      gen5: [:SNIVY, :TEPIG, :OSHAWOTT],
      gen6: [:CHESPIN, :FENNEKIN, :FROAKIE],
      gen7: [:ROWLET, :LITTEN, :POPPLIO],
      gen8: [:GROOKEY, :SCORBUNNY, :SOBBLE],
      gen9: [:SPRIGATITO, :FUECOCO, :QUAXLY]
    }.freeze
    
    class << self
      # Get starter selection mode
      def selection_mode
        return :normal unless defined?(KIFRSettings)
        modes = [:normal, :random, :any]
        mode_idx = KIFRSettings.get(:starter_mode, 0)
        modes[mode_idx] || :normal
      end
      
      # Get available starters based on mode
      def available_starters(generation = nil)
        case selection_mode
        when :random
          # Random starter from all available
          all = GENERATIONS.values.flatten
          [all.sample]
        when :any
          # All starters available
          GENERATIONS.values.flatten
        else
          # Normal - specified generation or Gen 1
          gen = generation || :gen1
          GENERATIONS[gen] || GENERATIONS[:gen1]
        end
      end
      
      # Give starter Pokemon
      def give_starter(species, options = {})
        options[:level] ||= 5
        options[:preset] ||= :good
        
        Pokemon.give(species, options)
      end
      
      # Random starter from a generation
      def random_from_generation(generation = :gen1, options = {})
        starters = GENERATIONS[generation] || GENERATIONS[:gen1]
        species = starters.sample
        give_starter(species, options)
      end
    end
  end

  #=============================================================================
  # MYSTERY MODULE - Mystery Gift Support
  #=============================================================================
  module Mystery
    class << self
      def gifts_data
        $game_system.mystery_gifts ||= {}
      end
      
      # Check if a mystery gift code is valid
      def valid_code?(code)
        # Could be connected to an online service
        # For now, just check format
        code.is_a?(String) && code.length >= 4
      end
      
      # Redeem a mystery gift code
      def redeem(code)
        return false unless valid_code?(code)
        return false if redeemed?(code)
        
        # Mark as redeemed
        gifts_data[code] = { redeemed_at: Time.now.to_i }
        
        # TODO: Fetch gift data from server or local database
        # For now, just mark as redeemed
        
        true
      end
      
      # Check if code has been redeemed
      def redeemed?(code)
        gifts_data.key?(code)
      end
      
      # Get all redeemed codes
      def redeemed_codes
        gifts_data.keys
      end
    end
  end

  #=============================================================================
  # STATISTICS MODULE - Gift Tracking
  #=============================================================================
  module Statistics
    class << self
      def data
        $game_system.gift_stats ||= {
          pokemon_received: {},
          items_received: {},
          money_received: 0,
          shinies_received: 0,
          bundles_received: 0
        }
      end
      
      def record_pokemon(species, shiny = false)
        data[:pokemon_received][species] ||= 0
        data[:pokemon_received][species] += 1
        data[:shinies_received] += 1 if shiny
      end
      
      def record_item(item_id, quantity)
        data[:items_received][item_id] ||= 0
        data[:items_received][item_id] += quantity
      end
      
      def record_money(amount)
        data[:money_received] += amount
      end
      
      def record_bundle
        data[:bundles_received] += 1
      end
      
      def summary
        {
          total_pokemon: data[:pokemon_received].values.sum,
          unique_pokemon: data[:pokemon_received].keys.length,
          total_items: data[:items_received].values.sum,
          unique_items: data[:items_received].keys.length,
          money_received: data[:money_received],
          shinies: data[:shinies_received],
          bundles: data[:bundles_received]
        }
      end
      
      def reset
        $game_system.gift_stats = {
          pokemon_received: {},
          items_received: {},
          money_received: 0,
          shinies_received: 0,
          bundles_received: 0
        }
        Gifts.debug_log("Statistics: All gift statistics have been reset")
      end
    end
  end
end

#===============================================================================
# GAME_SYSTEM EXTENSIONS
#===============================================================================
class Game_System
  attr_accessor :claimed_rewards
  attr_accessor :received_events
  attr_accessor :mystery_gifts
  attr_accessor :gift_stats
  attr_accessor :gift_inbox
  attr_accessor :kifr_fusions_created
  attr_accessor :kifr_shinies_caught
  attr_accessor :kifr_battles_won
  attr_accessor :kifr_battles_lost
end

#===============================================================================
# KIFR SETTINGS REGISTRATION
#===============================================================================
begin
  if defined?(KIFRSettings)
    # Initialize defaults
    KIFRSettings.set_default(:starter_mode, 0)
    
    KIFRSettings.debug_log("Gifts: Module loaded - Pokemon, Items, Bundles, Rewards, Mystery systems ready")
  end
rescue => e
  KIFRSettings.debug_log("Gifts: ERROR: Setup failed - #{e.message}") if defined?(KIFRSettings)
end

#===============================================================================
# SHINY CATCH TRACKING HOOK - Track shinies caught in battle
#===============================================================================
# This module provides a method to call when a Pokemon is caught
# The actual hook needs to be in the battle system or catch code
module KIFRShinyTracker
  class << self
    # Call this when a Pokemon is successfully caught
    def on_pokemon_caught(pokemon)
      return unless pokemon
      return unless pokemon.respond_to?(:shiny?)
      
      if pokemon.shiny?
        Gifts::Rewards.record_shiny_caught if defined?(Gifts::Rewards)
        Gifts.debug_log("ShinyTracker: Shiny Pokemon caught!") if defined?(Gifts)
      end
    end
  end
end

#===============================================================================
# GIFT NOTIFICATION WINDOW - Shows "New Gifts!" with pause menu
#===============================================================================
class GiftNotificationWindow
  def initialize
    count = Gifts::Inbox.unseen_count rescue 0
    text = _INTL("New Gifts! ({1})", count)
    
    @window = Window_AdvancedTextPokemon.new(text)
    @window.resizeToFit(text, Graphics.width)
    # Start off-screen to the left
    @window.x = -@window.width
    @window.y = 130  # Position below location box
    @window.viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @window.viewport.z = 99999
    @frames = 0
    @target_x = 0  # Slide in to left edge
  end
  
  # Class method to check if notification should show
  def self.should_show?
    Gifts::Inbox.has_unseen? rescue false
  end

  def disposed?
    @window.disposed?
  end

  def dispose
    @window.dispose
  end

  def update
    return if @window.disposed?
    @window.update
    
    if $game_temp.message_window_showing
      @window.dispose
      return
    end
    
    if @frames > Graphics.frame_rate * 2
      # Slide out to the left
      @window.x -= 4
      @window.dispose if @window.x + @window.width < 0
    else
      # Slide in from the left
      @window.x += 4 if @window.x < @target_x
      @frames += 1
    end
  end
end