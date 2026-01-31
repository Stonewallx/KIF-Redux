#===============================================================================
# KIF Redux Developer Tools - Specials Creator
# Script Version: 2.1.0
# Author: Stonewall
#===============================================================================
# This file provides:
# - Clear Specials option in shop Buy/Sell menu
# - Specials Creator tool for creating custom sales/markups
#
# Updated for v3.1 Hybrid Specials System:
# - Events (Custom/Themed) are GLOBAL - affect all shops
# - Random specials are PER-SHOP - each shop has its own randoms
#===============================================================================

module KIFRDEV_Specials
  def self.debug_log(message)
    KIFRDEV.debug_log("Specials: #{message}") if defined?(KIFRDEV)
  end
  
  #=============================================================================
  # ACTIVE SPECIALS MANAGEMENT - Hybrid Global Event + Per-Shop Random System
  #=============================================================================
  
  # Check if there's an active special (event or random for current shop)
  def self.has_active_special?
    return false unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.has_active_special?
  end
  
  # Check if there's an active event (Custom or Themed) - GLOBAL
  def self.has_active_event?
    return false unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.has_active_event?
  end
  
  # Check if there's an active sale (event or random for current shop)
  def self.has_active_sale?
    return false unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.has_active_sale?
  end
  
  # Check if there's an active markup (event or random for current shop)
  def self.has_active_markup?
    return false unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.has_active_markup?
  end
  
  # Clear specials (event + current shop's randoms)
  def self.clear_special
    return unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.clear_special
  end
  
  # Clear ALL specials including all shop randoms
  def self.clear_all_specials
    return unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.clear_all_specials
  end
  
  # Clear event only (GLOBAL)
  def self.clear_event
    return unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.clear_event
  end
  
  # Clear sale (event sale items or current shop's random sale)
  def self.clear_sale
    return unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.clear_sale
  end
  
  # Clear markup (event markup items or current shop's random markup)
  def self.clear_markup
    return unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.clear_markup
  end
  
  # Get description of current specials
  def self.get_special_description
    return nil unless defined?(KIFR::Shop::Specials)
    return nil unless KIFR::Shop::Specials.has_active_special?
    
    lines = []
    
    # Check if it's an event or random specials
    if KIFR::Shop::Specials.has_active_event?
      event = KIFR::Shop::Specials.active_event
      lines << format_event_description(event) if event
    else
      # Random specials (per-shop)
      if KIFR::Shop::Specials.has_active_sale?
        data = KIFR::Shop::Specials.active_sale
        lines << format_slot_description(data, "SALE") if data
      end
      
      if KIFR::Shop::Specials.has_active_markup?
        lines << "---" if lines.any?
        data = KIFR::Shop::Specials.active_markup
        lines << format_slot_description(data, "MARKUP") if data
      end
    end
    
    lines.flatten.join("\n")
  end
  
  def self.format_event_description(event)
    return nil unless event
    
    lines = []
    lines << _INTL("EVENT: {1}", event[:name])
    lines << _INTL("Source: {1}", event[:source] == :custom ? "Custom" : "Themed")
    
    # Show sales
    if event[:sale_items] && !event[:sale_items].empty?
      sale_pockets = KIFR::Shop::Specials::Core.pocket_names(event[:sale_pockets] || [])
      lines << _INTL("Sales: {1} items ({2})", event[:sale_items].size, 
                     sale_pockets.any? ? sale_pockets.join(', ') : "Various")
    end
    
    # Show markups
    if event[:markup_items] && !event[:markup_items].empty?
      markup_pockets = KIFR::Shop::Specials::Core.pocket_names(event[:markup_pockets] || [])
      lines << _INTL("Markups: {1} items ({2})", event[:markup_items].size,
                     markup_pockets.any? ? markup_pockets.join(', ') : "Various")
    end
    
    lines
  end
  
  def self.format_slot_description(data, type_str)
    return nil unless data
    
    lines = []
    lines << _INTL("{1}: {2}", type_str, data[:name])
    
    # Show categories
    if data[:pockets] && data[:pockets].is_a?(Array) && data[:pockets].any?
      pocket_names = KIFR::Shop::Specials::Core.pocket_names(data[:pockets])
      lines << _INTL("Categories: {1}", pocket_names.join(', '))
    elsif data[:items] && data[:items].any?
      item_names = data[:items].keys.first(3).map { |id| KIFR::Shop::Specials::Core.item_name(id) }
      if data[:items].length > 3
        lines << _INTL("Items: {1}...", item_names.join(', '))
      else
        lines << _INTL("Items: {1}", item_names.join(', '))
      end
    end
    
    # Show discount
    if data[:items] && data[:items].any?
      pcts = data[:items].values.uniq
      if pcts.length == 1
        lines << _INTL("Percent: {1}%", pcts.first)
      else
        lines << _INTL("Percent: {1}%-{2}%", pcts.min, pcts.max)
      end
    end
    
    # Show source
    source_names = { random: "Random", themed: "Themed", custom: "Custom Event" }
    lines << _INTL("Source: {1}", source_names[data[:source]] || "Unknown")
    
    lines
  end
  
  #=============================================================================
  # CUSTOM SPECIALS MANAGEMENT
  #=============================================================================
  
  # Get list of custom specials
  def self.get_custom_specials
    return [] unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.custom_specials
  end
  
  # Add a custom special
  def self.add_custom_special(data)
    return false unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.add_custom_special(data)
    true
  end
  
  # Remove a custom special
  def self.remove_custom_special(id)
    return false unless defined?(KIFR::Shop::Specials)
    KIFR::Shop::Specials.remove_custom_special(id)
    true
  end
end

#===============================================================================
# SPECIALS CREATOR SCENE
#===============================================================================
class KIFRDEV_SpecialsCreator
  def self.show
    scene = KIFRDEV_SpecialsCreatorScene.new
    screen = PokemonOptionScreen.new(scene)
    screen.pbStartScreen
  end
end

class KIFRDEV_SpecialsCreatorScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    #---------------------------------------------------------------------------
    # CLEAR SPECIALS
    #---------------------------------------------------------------------------
    options << ButtonOption.new(
      _INTL("Clear Active Specials"),
      proc {
        if KIFRDEV_Specials.has_active_special?
          # Just clear immediately without asking
          KIFRDEV_Specials.clear_special
          Kernel.pbMessage(_INTL("All specials cleared."))
        else
          Kernel.pbMessage(_INTL("No active specials to clear."))
        end
      },
      _INTL("Clear active event or random specials")
    )
    
    #---------------------------------------------------------------------------
    # CREATE NEW SPECIALS
    #---------------------------------------------------------------------------
    options << ButtonOption.new(
      _INTL("Create Custom Event"),
      proc { create_custom_event },
      _INTL("Create a new custom event (can have sales AND markups)")
    )
    
    #---------------------------------------------------------------------------
    # MANAGE CUSTOM SPECIALS
    #---------------------------------------------------------------------------
    options << ButtonOption.new(
      _INTL("View Custom Events"),
      proc { view_custom_specials },
      _INTL("View and manage custom events")
    )
    
    #---------------------------------------------------------------------------
    # QUICK ACTIONS
    #---------------------------------------------------------------------------
    options << ButtonOption.new(
      _INTL("Force Random Sale"),
      proc { force_random_special(:sale) },
      _INTL("Immediately activate a random sale (clears event)")
    )
    
    options << ButtonOption.new(
      _INTL("Force Random Markup"),
      proc { force_random_special(:markup) },
      _INTL("Immediately activate a random markup (clears event)")
    )
    
    options << ButtonOption.new(
      _INTL("Force Themed Event"),
      proc { force_themed_event },
      _INTL("Choose and activate a themed event")
    )
    
    return options
  end
  
  def create_custom_event
    # Get ID
    id = Kernel.pbMessageFreeText(_INTL("Enter event ID (e.g., summer_event_2026):"), "", false, 30)
    return if id.nil? || id.empty?
    id = id.gsub(/\s+/, '_').downcase.to_sym
    
    # Get name
    name = Kernel.pbMessageFreeText(_INTL("Enter display name:"), "", false, 50)
    return if name.nil? || name.empty?
    
    # Get start date
    start_date = Kernel.pbMessageFreeText(_INTL("Enter start date (YYYY-MM-DD):"), Time.now.strftime("%Y-%m-%d"), false, 10)
    return if start_date.nil? || start_date.empty?
    
    # Get end date
    end_date = Kernel.pbMessageFreeText(_INTL("Enter end date (YYYY-MM-DD):"), start_date, false, 10)
    return if end_date.nil? || end_date.empty?
    
    # Get hours (optional)
    use_hours = Kernel.pbConfirmMessage(_INTL("Limit to specific hours?"))
    hours = nil
    if use_hours
      start_hour = Kernel.pbMessageFreeText(_INTL("Start hour (0-23):"), "0", false, 2).to_i
      end_hour = Kernel.pbMessageFreeText(_INTL("End hour (0-23):"), "23", false, 2).to_i
      hours = [start_hour, end_hour]
    end
    
    # Get priority
    priority = Kernel.pbMessageFreeText(_INTL("Enter priority (100=high):"), "100", false, 3).to_i
    
    pocket_names = KIFR::Shop::Specials::POCKET_NAMES
    
    #---------------------------------------------------------------------------
    # CURRENCY CONFIGURATION (NEW!)
    #---------------------------------------------------------------------------
    event_currency = :money
    currency_items = {}
    
    if Kernel.pbConfirmMessage(_INTL("Use alternate currency for this event?"))
      currency_options = get_available_currencies
      currency_choice = Kernel.pbMessage(_INTL("Select event currency:"), currency_options.map { |c| c[:name] } + ["Cancel"], currency_options.length + 1)
      
      if currency_choice < currency_options.length
        event_currency = currency_options[currency_choice][:id]
        
        # Ask about per-item pricing
        if Kernel.pbConfirmMessage(_INTL("Set custom prices for specific items?"))
          currency_items = configure_currency_items(event_currency)
        end
      end
    end
    
    # SALE CONFIGURATION
    sale_pockets = []
    sale_percent = nil
    
    if Kernel.pbConfirmMessage(_INTL("Add SALE items to this event?"))
      sale_pockets = select_pockets("Select SALE categories:", pocket_names)
      if sale_pockets && (sale_pockets == :all || sale_pockets.any?)
        sale_percent = Kernel.pbMessageFreeText(_INTL("Enter sale discount percent:"), "20", false, 2).to_i
        sale_percent = [[sale_percent, 5].max, 90].min
      end
    end
    
    # MARKUP CONFIGURATION
    markup_pockets = []
    markup_percent = nil
    
    if Kernel.pbConfirmMessage(_INTL("Add MARKUP items to this event?"))
      markup_pockets = select_pockets("Select MARKUP categories:", pocket_names)
      if markup_pockets && (markup_pockets == :all || markup_pockets.any?)
        markup_percent = Kernel.pbMessageFreeText(_INTL("Enter markup percent:"), "15", false, 2).to_i
        markup_percent = [[markup_percent, 5].max, 90].min
      end
    end
    
    # Validate - must have at least one
    if (sale_pockets.nil? || (sale_pockets != :all && sale_pockets.empty?)) &&
       (markup_pockets.nil? || (markup_pockets != :all && markup_pockets.empty?))
      Kernel.pbMessage(_INTL("Event must have at least sales or markups."))
      return
    end
    
    # Create the special with new format
    special_data = {
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      hours: hours,
      priority: priority
    }
    
    # Add sale config if present
    if sale_pockets && (sale_pockets == :all || sale_pockets.any?)
      special_data[:sale_pockets] = sale_pockets
      special_data[:sale_percent] = sale_percent
    end
    
    # Add markup config if present
    if markup_pockets && (markup_pockets == :all || markup_pockets.any?)
      special_data[:markup_pockets] = markup_pockets
      special_data[:markup_percent] = markup_percent
    end
    
    # Add currency config if not default
    if event_currency != :money
      special_data[:currency] = event_currency
    end
    
    if currency_items.any?
      special_data[:currency_items] = currency_items
    end
    
    if KIFRDEV_Specials.add_custom_special(special_data)
      desc = []
      desc << "Sales: #{sale_pockets == :all ? 'All' : sale_pockets.length} categories at #{sale_percent}% off" if sale_percent
      desc << "Markups: #{markup_pockets == :all ? 'All' : markup_pockets.length} categories at +#{markup_percent}%" if markup_percent
      desc << "Currency: #{KIFR::Currency.name(event_currency)}" if event_currency != :money
      desc << "Custom prices: #{currency_items.length} items" if currency_items.any?
      Kernel.pbMessage(_INTL("Created event: {1}\n{2}", name, desc.join("\n")))
    else
      Kernel.pbMessage(_INTL("Failed to create event."))
    end
  end
  
  # Get list of available currencies for selection
  def get_available_currencies
    currencies = []
    
    if defined?(KIFR::Currency)
      KIFR::Currency.all_ids.each do |id|
        next if id == :money  # Skip default money
        currencies << {
          id: id,
          name: KIFR::Currency.name(id),
          symbol: KIFR::Currency.symbol(id)
        }
      end
    end
    
    # Add fallback if currency system not loaded
    if currencies.empty?
      currencies << { id: :platinum, name: "Platinum", symbol: "Pt" }
      currencies << { id: :bp, name: "Battle Points", symbol: "BP" }
    end
    
    currencies
  end
  
  # Configure per-item currency pricing
  def configure_currency_items(default_currency)
    items = {}
    
    loop do
      actions = ["Add Item", "Done"]
      actions.insert(1, "View Items (#{items.length})") if items.any?
      
      choice = Kernel.pbMessage(_INTL("Configure item prices:"), actions, actions.length)
      
      case choice
      when 0  # Add Item
        item_name = Kernel.pbMessageFreeText(_INTL("Enter item ID (e.g., RARECANDY):"), "", false, 30)
        next if item_name.nil? || item_name.empty?
        
        item_id = item_name.upcase.to_sym
        
        # Verify item exists
        begin
          item_data = GameData::Item.get(item_id)
        rescue
          Kernel.pbMessage(_INTL("Item not found: {1}", item_name))
          next
        end
        
        # Get price
        price = Kernel.pbMessageFreeText(_INTL("Enter price in {1}:", KIFR::Currency.name(default_currency)), "10", false, 5).to_i
        
        if price > 0
          items[item_id] = { currency: default_currency, price: price }
          Kernel.pbMessage(_INTL("Added: {1} = {2} {3}", item_data.name, price, KIFR::Currency.symbol(default_currency)))
        end
        
      when 1  # View Items (if items exist) or Done
        if items.any?
          item_list = items.map do |id, info|
            "#{GameData::Item.get(id).name rescue id}: #{info[:price]} #{KIFR::Currency.symbol(info[:currency])}"
          end
          Kernel.pbMessage(item_list.join("\n"))
        else
          break  # Done
        end
        
      else  # Done
        break
      end
    end
    
    items
  end
  
  def select_pockets(prompt, pocket_names)
    pocket_choices = pocket_names.values + ["All Pockets", "Done"]
    chosen_pockets = []
    
    loop do
      choice = Kernel.pbMessage(_INTL("{1}", prompt), pocket_choices, pocket_choices.length)
      
      if choice == pocket_choices.length - 1  # Done
        break
      elsif choice == pocket_choices.length - 2  # All Pockets
        return :all
      else
        pocket_id = pocket_names.keys[choice]
        if !chosen_pockets.include?(pocket_id)
          chosen_pockets << pocket_id
          Kernel.pbMessage(_INTL("Added: {1}", pocket_names[pocket_id]))
        else
          chosen_pockets.delete(pocket_id)
          Kernel.pbMessage(_INTL("Removed: {1}", pocket_names[pocket_id]))
        end
      end
    end
    
    chosen_pockets
  end
  
  def view_custom_specials
    specials = KIFRDEV_Specials.get_custom_specials
    
    if specials.empty?
      Kernel.pbMessage(_INTL("No custom events defined."))
      return
    end
    
    choices = specials.map do |s|
      has_sale = s[:sale_pockets] && (s[:sale_pockets] == :all || s[:sale_pockets].any?)
      has_markup = s[:markup_pockets] && (s[:markup_pockets] == :all || s[:markup_pockets].any?)
      type_str = if has_sale && has_markup
                   "[S+M]"
                 elsif has_sale
                   "[S]"
                 elsif has_markup
                   "[M]"
                 else
                   "[?]"
                 end
      "#{type_str} #{s[:name]}"
    end
    choices << "Cancel"
    
    loop do
      choice = Kernel.pbMessage(_INTL("Custom Events ({1}):", specials.length), choices, choices.length)
      break if choice == choices.length - 1
      
      special = specials[choice]
      show_special_details(special)
    end
  end
  
  def show_special_details(special)
    has_sale = special[:sale_pockets] && (special[:sale_pockets] == :all || special[:sale_pockets].any?)
    has_markup = special[:markup_pockets] && (special[:markup_pockets] == :all || special[:markup_pockets].any?)
    
    type_str = if has_sale && has_markup
                 "Mixed (Sales + Markups)"
               elsif has_sale
                 "Sale Only"
               elsif has_markup
                 "Markup Only"
               else
                 "Unknown"
               end
    
    hours_str = special[:hours] ? "#{special[:hours][0]}:00 - #{special[:hours][1]}:00" : "All Day"
    
    info = [_INTL("Name: {1}", special[:name])]
    info << _INTL("Type: {1}", type_str)
    info << _INTL("Dates: {1} to {2}", special[:start_date], special[:end_date])
    info << _INTL("Hours: {1}", hours_str)
    
    if has_sale
      sale_pockets_str = special[:sale_pockets] == :all ? "All" : 
                        special[:sale_pockets].map { |p| KIFR::Shop::Specials::POCKET_NAMES[p] }.join(', ')
      info << _INTL("Sale Categories: {1} at {2}% off", sale_pockets_str, special[:sale_percent] || 0)
    end
    
    if has_markup
      markup_pockets_str = special[:markup_pockets] == :all ? "All" : 
                          special[:markup_pockets].map { |p| KIFR::Shop::Specials::POCKET_NAMES[p] }.join(', ')
      info << _INTL("Markup Categories: {1} at +{2}%", markup_pockets_str, special[:markup_percent] || 0)
    end
    
    # Currency info (NEW!)
    if special[:currency] && special[:currency] != :money
      currency_name = defined?(KIFR::Currency) ? KIFR::Currency.name(special[:currency]) : special[:currency].to_s
      info << _INTL("Currency: {1}", currency_name)
    end
    
    if special[:currency_items] && special[:currency_items].any?
      info << _INTL("Custom Prices: {1} items", special[:currency_items].length)
    end
    
    info << _INTL("Priority: {1}", special[:priority])
    
    actions = ["Close", "Delete"]
    choice = Kernel.pbMessage(info.join("\n"), actions, 1)
    
    if choice == 1  # Delete
      if Kernel.pbConfirmMessage(_INTL("Delete {1}?", special[:name]))
        KIFRDEV_Specials.remove_custom_special(special[:id])
        Kernel.pbMessage(_INTL("Deleted."))
      end
    end
  end
  
  def force_random_special(type)
    # Random specials require no event to be active
    if KIFRDEV_Specials.has_active_event?
      if Kernel.pbConfirmMessage(_INTL("An event is active. Clear it to use random specials?"))
        KIFRDEV_Specials.clear_event
      else
        return
      end
    end
    
    # Check if random slot is already occupied
    if type == :sale && KIFR::Shop::Specials.has_random_sale?
      if !Kernel.pbConfirmMessage(_INTL("Random sale already active. Replace it?"))
        return
      end
      $game_system.kifr_random_sale = nil
    elsif type == :markup && KIFR::Shop::Specials.has_random_markup?
      if !Kernel.pbConfirmMessage(_INTL("Random markup already active. Replace it?"))
        return
      end
      $game_system.kifr_random_markup = nil
    end
    
    # Get some sample items
    all_items = GameData::Item.keys.first(50)
    
    # Exclude items from the other random slot
    if type == :sale && KIFR::Shop::Specials.has_random_markup?
      rm = $game_system.kifr_random_markup
      all_items -= rm[:items].keys if rm && rm[:items]
    elsif type == :markup && KIFR::Shop::Specials.has_random_sale?
      rs = $game_system.kifr_random_sale
      all_items -= rs[:items].keys if rs && rs[:items]
    end
    
    num_items = rand(1..2)
    chosen = all_items.sample(num_items)
    
    items_hash = {}
    chosen.each do |item|
      percent = rand(KIFR::Shop::Specials::RANDOM_MIN_PERCENT..KIFR::Shop::Specials::RANDOM_MAX_PERCENT)
      items_hash[item] = percent
    end
    
    item_names = chosen.map { |i| KIFR::Shop::Specials::Core.item_name(i) }
    name = type == :sale ? "#{item_names.first} Sale" : "#{item_names.first} Markup"
    
    # Use new random slot format
    special_data = {
      name: name,
      items: items_hash,
      start_time: KIFR::Shop::Specials::Core.real_time_seconds,
      duration: KIFR::Shop::Specials::RANDOM_DURATION_HOURS * 3600
    }
    
    # Assign to correct random slot
    if type == :markup
      $game_system.kifr_random_markup = special_data
    else
      $game_system.kifr_random_sale = special_data
    end
    
    type_str = type == :sale ? "sale" : "markup"
    Kernel.pbMessage(_INTL("Activated random {1}: {2}", type_str, name))
  end
  
  def force_themed_event
    themes = KIFR::Shop::Specials::THEMED_SPECIALS
    choices = themes.map do |id, t|
      has_sale = t[:sale_pockets] && t[:sale_pockets].any?
      has_markup = t[:markup_pockets] && t[:markup_pockets].any?
      type_str = if has_sale && has_markup
                   "[S+M]"
                 elsif has_markup
                   "[M]"
                 else
                   "[S]"
                 end
      "#{type_str} #{t[:name]}"
    end
    choices << "Cancel"
    
    choice = Kernel.pbMessage(_INTL("Choose themed event:"), choices, choices.length)
    return if choice == choices.length - 1
    
    theme_id = themes.keys[choice]
    theme = themes[theme_id]
    
    # Clear existing event
    if KIFRDEV_Specials.has_active_event?
      if !Kernel.pbConfirmMessage(_INTL("Event already active. Replace it?"))
        return
      end
    end
    # Also clear random slots since event takes priority
    KIFRDEV_Specials.clear_special
    
    # Build sale items
    sale_items = {}
    sale_pockets = theme[:sale_pockets] || []
    sale_range = theme[:sale_percent] || (5..30)
    sale_percent = sale_range.is_a?(Range) ? rand(sale_range) : sale_range
    
    if sale_pockets.any?
      GameData::Item.each do |item|
        pocket = item.pocket rescue nil
        sale_items[item.id] = sale_percent if pocket && sale_pockets.include?(pocket)
        break if sale_items.length >= 20  # Limit for performance
      end
    end
    
    # Build markup items
    markup_items = {}
    markup_pockets = theme[:markup_pockets] || []
    markup_range = theme[:markup_percent] || (5..30)
    markup_percent = markup_range.is_a?(Range) ? rand(markup_range) : markup_range
    
    if markup_pockets.any?
      GameData::Item.each do |item|
        pocket = item.pocket rescue nil
        markup_items[item.id] = markup_percent if pocket && markup_pockets.include?(pocket)
        break if markup_items.length >= 20  # Limit for performance
      end
    end
    
    # Use new event format
    $game_system.kifr_active_event = {
      source: :themed,
      name: theme[:name],
      sale_items: sale_items,
      markup_items: markup_items,
      sale_pockets: sale_pockets,
      markup_pockets: markup_pockets,
      start_time: KIFR::Shop::Specials::Core.real_time_seconds,
      duration: KIFR::Shop::Specials::THEMED_DURATION_HOURS * 3600,
      priority: KIFR::Shop::Specials::THEMED_PRIORITY,
      theme_id: theme_id
    }
    
    desc = []
    desc << "#{sale_items.size} items #{sale_percent}% off" if sale_items.any?
    desc << "#{markup_items.size} items +#{markup_percent}%" if markup_items.any?
    Kernel.pbMessage(_INTL("Activated: {1}\n{2}", theme[:name], desc.join(", ")))
  end
  
  def pbStartScene(inloadscreen = false)
    super(inloadscreen)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Specials Creator"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
  end
end

#===============================================================================
# Hook into pbPokemonMart to add "Clear Specials" option
#===============================================================================
alias kifrdev_specials_orig_pbPokemonMart pbPokemonMart unless defined?(kifrdev_specials_orig_pbPokemonMart)

def pbPokemonMart(stock, speech = nil, cantsell = false)
  # If randomization is on, apply it
  if $game_switches[SWITCH_RANDOM_ITEMS_GENERAL] && $game_switches[SWITCH_RANDOM_SHOP_ITEMS]
    stock = replaceShopStockWithRandomized(stock)
  end
  
  # Filter out owned important items
  for i in 0...stock.length
    stock[i] = GameData::Item.get(stock[i]).id
    stock[i] = nil if GameData::Item.get(stock[i]).is_important? && $PokemonBag.pbHasItem?(stock[i])
  end
  stock.compact!
  
  # Set up shop key for per-shop randoms BEFORE checking specials
  if defined?(KIFR::Shop::Specials)
    shop_key = KIFR::Shop::Specials.generate_shop_key(stock)
    KIFR::Shop::Specials.current_shop_key = shop_key
  end
  
  # Check if dev tools are available and there's an active special
  show_clear_option = defined?(KIFRDEV) && KIFRDEV.enabled? && 
                      defined?(KIFRDEV_Specials) && KIFRDEV_Specials.has_active_special?
  
  # Build command list
  commands = []
  cmdBuy  = -1
  cmdSell = -1
  cmdClearSpecials = -1
  cmdQuit = -1
  
  commands[cmdBuy = commands.length] = _INTL("Buy")
  commands[cmdSell = commands.length] = _INTL("Sell") if !cantsell
  
  # Add Clear Specials option if dev tools are enabled and specials exist
  if show_clear_option
    commands[cmdClearSpecials = commands.length] = _INTL("Clear Specials")
  end
  
  commands[cmdQuit = commands.length] = _INTL("Quit")
  
  cmd = pbMessage(
    speech ? speech : _INTL("Welcome! How may I serve you?"),
    commands, cmdQuit + 1)
  
  loop do
    if cmdBuy >= 0 && cmd == cmdBuy
      scene = PokemonMart_Scene.new
      screen = PokemonMartScreen.new(scene, stock)
      screen.pbBuyScreen
    elsif cmdSell >= 0 && cmd == cmdSell
      scene = PokemonMart_Scene.new
      screen = PokemonMartScreen.new(scene, stock)
      screen.pbSellScreen
    elsif cmdClearSpecials >= 0 && cmd == cmdClearSpecials
      # Automatically clear without asking (clears event + this shop's randoms)
      KIFRDEV_Specials.clear_special
      pbMessage(_INTL("Specials cleared."))
      show_clear_option = false
      
      # Rebuild commands to remove Clear Specials option
      commands = []
      cmdBuy = -1
      cmdSell = -1
      cmdClearSpecials = -1
      cmdQuit = -1
      commands[cmdBuy = commands.length] = _INTL("Buy")
      commands[cmdSell = commands.length] = _INTL("Sell") if !cantsell
      commands[cmdQuit = commands.length] = _INTL("Quit")
    else
      pbMessage(_INTL("Please come again!"))
      break
    end
    
    cmd = pbMessage(_INTL("Is there anything else I can help you with?"),
      commands, cmdQuit + 1)
  end
  
  $game_temp.clear_mart_prices
end

#===============================================================================
# Add to KIFRDEV Core menu
#===============================================================================
if defined?(KIFR_DevToolsScene)
  class KIFR_DevToolsScene
    unless method_defined?(:kifrdev_specials_orig_pbGetOptions)
      alias :kifrdev_specials_orig_pbGetOptions :pbGetOptions
    end
    
    def pbGetOptions(inloadscreen = false)
      options = kifrdev_specials_orig_pbGetOptions(inloadscreen)
      
      # Insert Specials Creator after Gift tools
      specials_option = ButtonOption.new(
        _INTL("Specials Creator"),
        proc { 
          if defined?(KIFRDEV_SpecialsCreator)
            pbFadeOutIn { KIFRDEV_SpecialsCreator.show }
          else
            Kernel.pbMessage(_INTL("Specials Creator not loaded!"))
          end
        },
        _INTL("Create and manage shop sales/markups")
      )
      
      # Find position after Gift List (index 1) or at start
      insert_pos = [options.length, 2].min
      options.insert(insert_pos, specials_option)
      
      return options
    end
  end
end

KIFRDEV.debug_log("Specials Creator loaded") if defined?(KIFRDEV)

