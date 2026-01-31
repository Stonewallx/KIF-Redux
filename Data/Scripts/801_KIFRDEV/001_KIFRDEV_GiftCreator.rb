#===============================================================================
# KIF Redux Developer Tools - Gift Creator & Editor
# Script Version: 1.3.0
# Author: Stonewall
#===============================================================================
# In-game tool for creating and editing scheduled event gifts.
# Created gifts are saved to 012a_KIFR_EventGifts.rb
#===============================================================================
# CONTROLS:
#   C / Enter    - Edit selected field
#   B / Esc      - Back / Exit
#===============================================================================

#===============================================================================
# Shared helper for command windows with opaque black background
#===============================================================================
def pbShowCommandsOpaque(commands, cancel_value = -1, default_index = 0, viewport = nil)
  # Create viewport if not provided
  vp = viewport || Viewport.new(0, 0, Graphics.width, Graphics.height)
  vp.z = 99999 unless viewport
  
  # Create a black background sprite
  bg = Sprite.new(vp)
  bg.z = 99998
  
  # Create command window
  cmdwindow = Window_CommandPokemon.new(commands)
  cmdwindow.z = 99999
  cmdwindow.viewport = vp
  cmdwindow.index = default_index
  
  # Position centered
  cmdwindow.x = (Graphics.width - cmdwindow.width) / 2
  cmdwindow.y = (Graphics.height - cmdwindow.height) / 2
  
  # Create background bitmap sized to window
  bg.bitmap = Bitmap.new(cmdwindow.width + 8, cmdwindow.height + 8)
  bg.bitmap.fill_rect(0, 0, bg.bitmap.width, bg.bitmap.height, Color.new(0, 0, 0, 220))
  bg.x = cmdwindow.x - 4
  bg.y = cmdwindow.y - 4
  
  result = 0
  loop do
    Graphics.update
    Input.update
    cmdwindow.update
    
    if Input.trigger?(Input::BACK)
      result = cancel_value
      break
    elsif Input.trigger?(Input::USE)
      result = cmdwindow.index
      break
    end
  end
  
  cmdwindow.dispose
  bg.bitmap.dispose
  bg.dispose
  vp.dispose unless viewport  # Only dispose if we created it
  
  # Clear input to prevent back button from propagating
  Input.update
  
  return result
end

class KIFRDEV_GiftCreator
  # Header text for centered sections (padded for visual centering)
  HEADER_REWARDS = "             --- Rewards ---"
  HEADER_CONDITIONS = "           --- Conditions ---"
  HEADER_ACTIONS = "             --- Actions ---"
  
  def initialize(gift_to_edit = nil)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @saved = false  # Track if the gift has been saved
    
    # Gift data being created
    @gift = {
      id: "",
      name: "",
      source: "Event",
      start_date: Time.now.strftime("%m-%d-%y"),
      end_date: nil,
      frequency: :once,  # :once, :daily, :weekly, :monthly, :yearly
      rewards: {
        items: [],
        pokemon: [],
        money: 0,
        coins: 0
      },
      conditions: {
        min_badges: 0,
        min_playtime: 0,
        flag: nil
      }
    }
    
    # Load existing gift if provided
    load_gift_for_editing(gift_to_edit) if gift_to_edit
  end
  
  # Load an existing gift into the editor
  def load_gift_for_editing(gift_entry)
    gift_id = gift_entry[:id]
    gift = gift_entry[:data]
    
    @gift[:id] = gift_id.to_s
    @gift[:name] = gift[:name] || ""
    @gift[:source] = gift[:source] || "Event"
    @gift[:start_date] = gift[:start_date] || Time.now.strftime("%m-%d-%y")
    @gift[:end_date] = gift[:end_date]
    @gift[:frequency] = gift[:frequency] || :once
    @gift[:rewards][:items] = (gift[:rewards][:items] || []).dup
    @gift[:rewards][:pokemon] = (gift[:rewards][:pokemon] || []).dup
    @gift[:rewards][:money] = gift[:rewards][:money] || 0
    @gift[:rewards][:coins] = gift[:rewards][:coins] || 0
    @gift[:conditions][:min_badges] = gift[:conditions][:min_badges] || 0 if gift[:conditions]
    @gift[:conditions][:min_playtime] = gift[:conditions][:min_playtime] || 0 if gift[:conditions]
    @gift[:conditions][:flag] = gift[:conditions][:flag] if gift[:conditions]
    
    @saved = true  # Already exists in file
  end
  
  #-----------------------------------------------------------------------------
  # Number input helper - properly uses ChooseNumberParams
  #-----------------------------------------------------------------------------
  def choose_number(prompt, max, default = 0, min = 0)
    params = ChooseNumberParams.new
    params.setRange(min, max)
    params.setDefaultValue(default)
    return pbMessageChooseNumber(prompt, params)
  end
  
  #-----------------------------------------------------------------------------
  # Full species list including fusions - for Gift Creator only
  #-----------------------------------------------------------------------------
  def choose_from_full_species_list(default = nil)
    commands = []
    GameData::Species.each do |s|
      next if s.form != 0  # Skip alternate forms
      commands.push([s.id_number, s.real_name, s.id])
    end
    commands.sort! { |a, b| a[0] <=> b[0] }  # Sort by dex number
    return pbChooseList(commands, default, nil, -1)
  end
  
  def pbStartScene
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Gift Creator"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    @sprites["textbox"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].text = _INTL("C: Select | B: Back")
    
    build_options
    
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["textbox"].height
    
    @sprites["content"] = Window_CommandPokemon.newWithSize(
      @options, 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["content"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["content"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["content"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["content"].index = 0
    
    pbFadeInAndShow(@sprites)
  end
  
  def build_options
    items_str = @gift[:rewards][:items].map { |i, q| "#{q}x #{GameData::Item.get(i).name rescue i}" }.join(", ")
    items_str = "None" if items_str.empty?
    
    pokemon_str = @gift[:rewards][:pokemon].map { |p| GameData::Species.get(p[:species]).name rescue p[:species] }.join(", ")
    pokemon_str = "None" if pokemon_str.empty?
    
    end_date_str = @gift[:end_date] || "Never"
    freq_str = frequency_display(@gift[:frequency])
    
    @options = [
      _INTL("Gift ID: {1}", @gift[:id].empty? ? "(Not Set)" : @gift[:id]),
      _INTL("Name: {1}", @gift[:name].empty? ? "(Not Set)" : @gift[:name]),
      _INTL("Source: {1}", @gift[:source]),
      _INTL("Start Date: {1}", @gift[:start_date]),
      _INTL("End Date: {1}", end_date_str),
      _INTL("Frequency: {1}", freq_str),
      HEADER_REWARDS,
      _INTL("Items: {1}", items_str),
      _INTL("Pokemon: {1}", pokemon_str),
      _INTL("Money: ${1}", @gift[:rewards][:money]),
      _INTL("Coins: {1}", @gift[:rewards][:coins]),
      HEADER_CONDITIONS,
      _INTL("Min Badges: {1}", @gift[:conditions][:min_badges]),
      _INTL("Min Playtime: {1}h", @gift[:conditions][:min_playtime]),
      _INTL("Required Flag: {1}", @gift[:conditions][:flag] ? "Switch #{@gift[:conditions][:flag]}" : "None"),
      HEADER_ACTIONS,
      "Preview Gift",
      "Save Gift to File",
      "Clear All",
      "Back"
    ]
  end
  
  def frequency_display(freq)
    case freq
    when :once then "One Time"
    when :daily then "Daily"
    when :weekly then "Weekly"
    when :monthly then "Monthly"
    when :yearly then "Yearly"
    else "One Time"
    end
  end
  
  def refresh_display
    build_options
    @sprites["content"].commands = @options
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
      
      if Input.trigger?(Input::USE)
        handle_selection(@sprites["content"].index)
      elsif Input.trigger?(Input::BACK)
        if confirm_exit?
          break
        end
      end
    end
  end
  
  def handle_selection(index)
    case index
    when 0 then edit_id
    when 1 then edit_name
    when 2 then edit_source
    when 3 then edit_start_date
    when 4 then edit_end_date
    when 5 then edit_frequency
    when 6  # Section header - skip
      pbPlayBuzzerSE
      return
    when 7 then edit_items
    when 8 then edit_pokemon
    when 9 then edit_money
    when 10 then edit_coins
    when 11 # Section header - skip
      pbPlayBuzzerSE
      return
    when 12 then edit_min_badges
    when 13 then edit_min_playtime
    when 14 then edit_flag
    when 15 # Section header - skip
      pbPlayBuzzerSE
      return
    when 16 then preview_gift
    when 17 then save_gift_to_file
    when 18 then clear_all
    when 19 then return if confirm_exit?
    end
    refresh_display
  end
  
  def edit_id
    current = @gift[:id]
    new_val = pbEnterText(_INTL("Enter Gift ID (snake_case):"), 0, 30, current)
    if new_val && !new_val.empty?
      # Convert to snake_case
      @gift[:id] = new_val.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')
    end
  end
  
  def edit_name
    current = @gift[:name]
    new_val = pbEnterText(_INTL("Enter Gift Name:"), 0, 40, current)
    @gift[:name] = new_val if new_val
  end
  
  def edit_source
    sources = ["Event", "Holiday", "Promo", "Mystery", "Seasonal", "Special", "Anniversary", "< Back"]
    current_idx = sources.index(@gift[:source]) || 0
    choice = pbShowCommandsOpaque(sources, -1, current_idx)
    return if choice < 0 || choice == sources.length - 1  # Back
    @gift[:source] = sources[choice]
  end
  
  def edit_start_date
    current = @gift[:start_date]
    new_val = pbEnterText(_INTL("Enter Start Date (MM-DD-YY):"), 0, 8, current)
    if new_val && new_val =~ /^\d{2}-\d{2}-\d{2}$/
      @gift[:start_date] = new_val
    else
      Kernel.pbMessage(_INTL("Invalid date format! Use MM-DD-YY"))
    end
  end
  
  def edit_end_date
    choices = ["Set End Date", "No Expiration", "< Back"]
    choice = pbShowCommandsOpaque(choices, -1)
    return if choice < 0 || choice == 2  # Back
    
    if choice == 0
      current = @gift[:end_date] || Time.now.strftime("%m-%d-%y")
      new_val = pbEnterText(_INTL("Enter End Date (MM-DD-YY):"), 0, 8, current)
      if new_val && new_val =~ /^\d{2}-\d{2}-\d{2}$/
        @gift[:end_date] = new_val
      elsif new_val && !new_val.empty?
        Kernel.pbMessage(_INTL("Invalid date format! Use MM-DD-YY"))
      end
    elsif choice == 1
      @gift[:end_date] = nil
    end
  end
  
  def edit_frequency
    choices = [
      "One Time (can only claim once)",
      "Daily (resets every day)",
      "Weekly (resets every week)",
      "Monthly (resets every month)",
      "Yearly (resets every year)",
      "< Back"
    ]
    
    current_idx = case @gift[:frequency]
                  when :once then 0
                  when :daily then 1
                  when :weekly then 2
                  when :monthly then 3
                  when :yearly then 4
                  else 0
                  end
    
    choice = pbShowCommandsOpaque(choices, -1, current_idx)
    return if choice < 0 || choice == 5
    
    @gift[:frequency] = case choice
                        when 0 then :once
                        when 1 then :daily
                        when 2 then :weekly
                        when 3 then :monthly
                        when 4 then :yearly
                        else :once
                        end
  end
  
  def edit_items
    choices = ["Add Item", "Remove Item", "Clear All Items", "< Back"]
    loop do
      refresh_display
      choice = pbShowCommandsOpaque(choices, -1)  # -1 = B button returns -1
      break if choice < 0  # Back button pressed
      case choice
      when 0 then add_item_reward
      when 1 then remove_item_reward
      when 2
        @gift[:rewards][:items] = []
        Kernel.pbMessage(_INTL("All items cleared."))
      when 3 then break
      end
    end
  end
  
  def add_item_reward
    # Use custom item selection with search support
    item = choose_item_with_search
    if item && item != -1 && item != :NONE
      qty = choose_number(_INTL("How many {1}?", GameData::Item.get(item).name), 99, 1, 1)
      if qty && qty > 0
        @gift[:rewards][:items] << [item, qty]
        Kernel.pbMessage(_INTL("Added {1}x {2}", qty, GameData::Item.get(item).name))
      end
    end
    refresh_display
  end
  
  # Custom item selection with search support (Ctrl to search)
  def choose_item_with_search(default = nil)
    choices = [
      "Browse Item List (Z to sort)",
      "Search by Name",
      "< Cancel"
    ]
    
    choice = pbShowCommandsOpaque(choices, -1)
    
    case choice
    when 0  # Browse list
      return pbChooseItemList(default)
    when 1  # Search by name
      search = pbEnterText(_INTL("Enter item name:"), 0, 20, "")
      return nil if search.nil? || search.empty?
      
      matches = []
      GameData::Item.each do |item|
        matches << [item.name, item.id] if item.name.downcase.include?(search.downcase)
      end
      
      if matches.empty?
        Kernel.pbMessage(_INTL("No items found matching '{1}'", search))
        return nil
      end
      
      matches.sort_by! { |m| m[0] }
      names = matches.map { |m| m[0] }
      names << "< Cancel"
      
      sel = pbShowCommandsOpaque(names, -1)
      return (sel >= 0 && sel < matches.length) ? matches[sel][1] : nil
    else
      return nil
    end
  end
  
  def remove_item_reward
    return if @gift[:rewards][:items].empty?
    
    names = @gift[:rewards][:items].map { |i, q| "#{q}x #{GameData::Item.get(i).name rescue i}" }
    names << "Cancel"
    choice = pbShowCommandsOpaque(names, 0)
    if choice >= 0 && choice < @gift[:rewards][:items].length
      removed = @gift[:rewards][:items].delete_at(choice)
      Kernel.pbMessage(_INTL("Removed {1}x {2}", removed[1], removed[0]))
    end
  end
  
  def edit_pokemon
    choices = ["Add Pokemon", "Edit Pokemon", "Remove Pokemon", "Clear All Pokemon", "< Back"]
    loop do
      refresh_display
      choice = pbShowCommandsOpaque(choices, -1)
      break if choice < 0  # Back button pressed
      case choice
      when 0 then add_pokemon_reward
      when 1 then edit_existing_pokemon
      when 2 then remove_pokemon_reward
      when 3
        @gift[:rewards][:pokemon] = []
        Kernel.pbMessage(_INTL("All Pokemon cleared."))
      when 4 then break
      end
    end
  end
  
  def edit_existing_pokemon
    return if @gift[:rewards][:pokemon].empty?
    
    names = @gift[:rewards][:pokemon].map do |p|
      name = GameData::Species.get(p[:species]).name rescue p[:species]
      "Lv.#{p[:level]} #{name}#{p[:shiny] ? ' (Shiny)' : ''}"
    end
    names << "< Cancel"
    
    choice = pbShowCommandsOpaque(names, -1)
    return if choice < 0 || choice >= @gift[:rewards][:pokemon].length
    
    # Edit the selected Pokemon (pass true for is_editing_existing)
    poke_data = @gift[:rewards][:pokemon][choice]
    edit_pokemon_details(poke_data, true)
    # Changes are made directly to the hash, so no need to re-assign
  end
  
  def add_pokemon_reward
    species = choose_pokemon_species
    return unless species
    
    # Create Pokemon data with defaults
    poke_data = {
      species: species,
      level: 5,
      shiny: false,
      nature: nil,        # nil = random
      ability_index: nil, # nil = random
      custom_ability: nil, # nil = use ability_index, otherwise specific ability symbol
      ivs: nil,           # nil = random
      evs: nil,           # nil = all 0
      moves: nil,         # nil = default moves
      gender: nil,        # nil = random
      item: nil,          # nil = no item
      nickname: nil       # nil = no nickname
    }
    
    # Open Pokemon editor for this gift Pokemon - track if user confirms
    confirmed = edit_pokemon_details(poke_data)
    
    # Only add if they confirmed with Done (not cancelled)
    if confirmed
      @gift[:rewards][:pokemon] << poke_data
      shiny_str = poke_data[:shiny] ? " (Shiny)" : ""
      Kernel.pbMessage(_INTL("Added Lv.{1} {2}{3}", poke_data[:level], 
        GameData::Species.get(species).name, shiny_str))
    end
    
    refresh_display
  end
  
  # Choose Pokemon by list, dex number, or name search
  def choose_pokemon_species(default = nil)
    choices = [
      "Browse Species List",
      "Enter Dex Number",
      "Search by Name",
      "Create Fusion (Head + Body)",
      "< Cancel"
    ]
    
    choice = pbShowCommandsOpaque(choices, -1)
    
    case choice
    when 0  # Browse list - use custom full species list including fusions
      species = choose_from_full_species_list(default)
      return species
    when 1  # Dex number
      dex_num = choose_number(_INTL("Enter National Dex Number:"), 999999, default ? (GameData::Species.get(default).id_number rescue 1) : 1, 1)
      return nil if dex_num.nil? || dex_num < 0  # Cancelled
      
      # Find species by dex number
      GameData::Species.each do |s|
        next if s.form != 0
        if s.id_number == dex_num
          Kernel.pbMessage(_INTL("Selected: {1}", s.name))
          return s.id
        end
      end
      Kernel.pbMessage(_INTL("No Pokemon found with Dex #{dex_num}"))
      return nil
    when 2  # Search by name
      search = pbEnterText(_INTL("Enter Pokemon name:"), 0, 20, "")
      return nil if search.nil? || search.empty?
      
      matches = []
      GameData::Species.each do |s|
        next if s.form != 0
        matches << [s.name, s.id] if s.name.downcase.include?(search.downcase)
      end
      
      if matches.empty?
        Kernel.pbMessage(_INTL("No Pokemon found matching '{1}'", search))
        return nil
      end
      
      matches.sort_by! { |m| m[0] }
      names = matches.map { |m| m[0] }
      names << "< Cancel"
      
      sel = pbShowCommandsOpaque(names, -1)
      return (sel >= 0 && sel < matches.length) ? matches[sel][1] : nil
    when 3  # Create Fusion
      return create_fusion_species
    else
      return nil
    end
  end
  
  # Create a fusion species by selecting head and body Pokemon
  def create_fusion_species
    # Check if fusion system is available
    unless defined?(NB_POKEMON)
      Kernel.pbMessage(_INTL("Fusion system not available (NB_POKEMON not defined)"))
      return nil
    end
    
    Kernel.pbMessage(_INTL("Creating a fusion Pokemon...\\nSelect the HEAD Pokemon first."))
    
    # Select head Pokemon (must be base species, not a fusion)
    head_species = choose_base_species_for_fusion("Select HEAD Pokemon:")
    return nil unless head_species
    
    head_data = GameData::Species.get(head_species) rescue nil
    return nil unless head_data
    head_id = head_data.id_number
    
    # Validate head is a base species
    if head_id > NB_POKEMON
      Kernel.pbMessage(_INTL("Head must be a base Pokemon (Dex 1-{1}), not a fusion!", NB_POKEMON))
      return nil
    end
    
    Kernel.pbMessage(_INTL("Head: {1}\\nNow select the BODY Pokemon.", head_data.name))
    
    # Select body Pokemon
    body_species = choose_base_species_for_fusion("Select BODY Pokemon:")
    return nil unless body_species
    
    body_data = GameData::Species.get(body_species) rescue nil
    return nil unless body_data
    body_id = body_data.id_number
    
    # Validate body is a base species
    if body_id > NB_POKEMON
      Kernel.pbMessage(_INTL("Body must be a base Pokemon (Dex 1-{1}), not a fusion!", NB_POKEMON))
      return nil
    end
    
    # Calculate fusion species ID: head_id * NB_POKEMON + body_id
    fusion_id = head_id * NB_POKEMON + body_id
    
    # Verify the fusion exists in GameData
    fusion_data = GameData::Species.try_get(fusion_id)
    if fusion_data
      Kernel.pbMessage(_INTL("Created fusion: {1}\\n(Head: {2}, Body: {3})\\nDex #: {4}", 
        fusion_data.name, head_data.name, body_data.name, fusion_id))
      return fusion_data.id
    else
      # Fusion might still work even if not in GameData - try to create by symbol
      fusion_symbol = "#{head_id}_#{body_id}".to_sym
      Kernel.pbMessage(_INTL("Fusion {1}/{2} created.\\nDex #: {3}\\n(Note: May not have custom sprite)", 
        head_data.name, body_data.name, fusion_id))
      return fusion_symbol
    end
  end
  
  # Choose a base (non-fusion) species for fusion creation
  def choose_base_species_for_fusion(prompt)
    choices = [
      "Browse Base Species",
      "Enter Dex Number (1-#{NB_POKEMON rescue 420})",
      "Search by Name",
      "< Cancel"
    ]
    
    Kernel.pbMessage(prompt) if prompt
    choice = pbShowCommandsOpaque(choices, -1)
    
    case choice
    when 0  # Browse - only base species
      commands = []
      max_dex = NB_POKEMON rescue 420
      GameData::Species.each do |s|
        next if s.form != 0
        next if s.id_number > max_dex  # Skip fusions
        commands.push([s.id_number, s.real_name, s.id])
      end
      commands.sort! { |a, b| a[0] <=> b[0] }
      return pbChooseList(commands, nil, nil, -1)
    when 1  # Dex number
      max_dex = NB_POKEMON rescue 420
      dex_num = choose_number(_INTL("Enter Dex Number (1-{1}):", max_dex), max_dex, 1, 1)
      return nil if dex_num.nil? || dex_num < 1
      
      GameData::Species.each do |s|
        next if s.form != 0
        if s.id_number == dex_num
          return s.id
        end
      end
      Kernel.pbMessage(_INTL("No Pokemon found with Dex #{dex_num}"))
      return nil
    when 2  # Search
      search = pbEnterText(_INTL("Enter Pokemon name:"), 0, 20, "")
      return nil if search.nil? || search.empty?
      
      max_dex = NB_POKEMON rescue 420
      matches = []
      GameData::Species.each do |s|
        next if s.form != 0
        next if s.id_number > max_dex  # Skip fusions
        matches << [s.name, s.id] if s.name.downcase.include?(search.downcase)
      end
      
      if matches.empty?
        Kernel.pbMessage(_INTL("No base Pokemon found matching '{1}'", search))
        return nil
      end
      
      matches.sort_by! { |m| m[0] }
      names = matches.map { |m| m[0] }
      names << "< Cancel"
      
      sel = pbShowCommandsOpaque(names, -1)
      return (sel >= 0 && sel < matches.length) ? matches[sel][1] : nil
    else
      return nil
    end
  end
  
  def edit_pokemon_details(poke_data, is_editing_existing = false)
    loop do
      species_name = GameData::Species.get(poke_data[:species]).name rescue poke_data[:species].to_s
      nature_name = poke_data[:nature] ? get_nature_with_stats(poke_data[:nature]) : "Random"
      ability_str = get_ability_display(poke_data)
      gender_str = case poke_data[:gender]
                   when 0 then "Male"
                   when 1 then "Female"
                   else "Random"
                   end
      ivs_str = format_ivs_display(poke_data[:ivs])
      evs_str = poke_data[:evs] ? poke_data[:evs].join("/") : "None"
      moves_str = poke_data[:moves] ? poke_data[:moves].length.to_s + " moves" : "Default"
      item_str = poke_data[:item] ? (GameData::Item.get(poke_data[:item]).name rescue poke_data[:item].to_s) : "None"
      
      cancel_text = is_editing_existing ? "< Back (Keep Changes)" : "< Cancel (Don't Add)"
      done_text = is_editing_existing ? "--- Save Changes ---" : "--- Done ---"
      
      options = [
        _INTL("Species: {1}", species_name),
        _INTL("Level: {1}", poke_data[:level]),
        _INTL("Shiny: {1}", poke_data[:shiny] ? "Yes" : "No"),
        _INTL("Nature: {1}", nature_name),
        _INTL("Ability: {1}", ability_str),
        _INTL("Gender: {1}", gender_str),
        _INTL("IVs: {1}", ivs_str),
        _INTL("EVs: {1}", evs_str),
        _INTL("Moves: {1}", moves_str),
        _INTL("Held Item: {1}", item_str),
        _INTL("Nickname: {1}", poke_data[:nickname] || "None"),
        done_text,
        cancel_text
      ]
      
      choice = pbShowCommandsOpaque(options, -1)
      return true if choice == options.length - 2   # Done/Save - confirm
      
      # Cancel/Back or B button
      if choice < 0 || choice == options.length - 1
        if is_editing_existing
          # For editing, just exit - changes are already saved to the hash
          return true
        else
          # For adding, confirm discard
          if pbConfirmMessage(_INTL("Discard this Pokemon?"))
            return false
          else
            next  # Stay in editor
          end
        end
      end
      
      case choice
      when 0  # Species
        new_species = choose_pokemon_species(poke_data[:species])
        poke_data[:species] = new_species if new_species
      when 1  # Level
        poke_data[:level] = choose_number(_INTL("Set level:"), 100, poke_data[:level], 1)
      when 2  # Shiny
        poke_data[:shiny] = !poke_data[:shiny]
      when 3  # Nature
        edit_pokemon_nature(poke_data)
      when 4  # Ability
        edit_pokemon_ability(poke_data)
      when 5  # Gender
        genders = ["Random", "Male", "Female"]
        g_choice = pbShowCommandsOpaque(genders, -1)
        if g_choice >= 0
          poke_data[:gender] = case g_choice
                               when 1 then 0
                               when 2 then 1
                               else nil
                               end
        end
      when 6  # IVs
        edit_pokemon_ivs(poke_data)
      when 7  # EVs
        edit_pokemon_evs(poke_data)
      when 8  # Moves
        edit_pokemon_moves(poke_data)
      when 9  # Held Item
        item = choose_item_with_search(poke_data[:item])
        poke_data[:item] = (item && item != -1) ? item : nil
      when 10 # Nickname
        nick = pbEnterText(_INTL("Enter nickname:"), 0, 12, poke_data[:nickname] || "")
        poke_data[:nickname] = nick.empty? ? nil : nick
      end
    end
  end
  
  def edit_pokemon_nature(poke_data)
    natures = [["Random", nil]]
    GameData::Nature.each { |n| natures << [get_nature_with_stats(n.id), n.id] }
    
    names = natures.map { |n| n[0] }
    current_idx = 0
    if poke_data[:nature]
      natures.each_with_index { |n, i| current_idx = i if n[1] == poke_data[:nature] }
    end
    
    choice = pbShowCommandsOpaque(names, -1, current_idx)
    poke_data[:nature] = natures[choice][1] if choice >= 0
  end
  
  # Get nature name with stat changes
  def get_nature_with_stats(nature_id)
    nature = GameData::Nature.get(nature_id) rescue nil
    return nature_id.to_s unless nature
    
    stat_up = nature.stat_changes.find { |s| s[1] > 0 }
    stat_down = nature.stat_changes.find { |s| s[1] < 0 }
    
    if stat_up && stat_down
      up_name = stat_short_name(stat_up[0])
      down_name = stat_short_name(stat_down[0])
      return "#{nature.name} (+#{up_name}/-#{down_name})"
    else
      return "#{nature.name} (Neutral)"
    end
  end
  
  def stat_short_name(stat)
    case stat
    when :ATTACK then "Atk"
    when :DEFENSE then "Def"
    when :SPECIAL_ATTACK then "SpA"
    when :SPECIAL_DEFENSE then "SpD"
    when :SPEED then "Spe"
    else stat.to_s
    end
  end
  
  def edit_pokemon_ability(poke_data)
    species_data = GameData::Species.get(poke_data[:species]) rescue nil
    
    abilities = [["Random", nil, :random]]
    
    # Check if this is a fusion Pokemon
    is_fusion = false
    head_data = nil
    body_data = nil
    
    if species_data && defined?(NB_POKEMON)
      is_fusion = species_data.id_number > NB_POKEMON
      
      if is_fusion && defined?(getBasePokemonID)
        # Get head and body species for fusion
        head_id = getBasePokemonID(poke_data[:species], false) rescue nil
        body_id = getBasePokemonID(poke_data[:species], true) rescue nil
        
        head_data = GameData::Species.try_get(head_id) if head_id
        body_data = GameData::Species.try_get(body_id) if body_id
      end
    end
    
    if is_fusion && head_data && body_data
      # FUSION: Show abilities from both head and body Pokemon
      abilities << ["--- Head (#{head_data.name}) ---", nil, :header]
      
      if head_data.abilities[0]
        ability_name = GameData::Ability.get(head_data.abilities[0]).name rescue head_data.abilities[0].to_s
        abilities << ["  Slot 1: #{ability_name}", head_data.abilities[0], :custom]
      end
      if head_data.abilities[1]
        ability_name = GameData::Ability.get(head_data.abilities[1]).name rescue head_data.abilities[1].to_s
        abilities << ["  Slot 2: #{ability_name}", head_data.abilities[1], :custom]
      end
      if head_data.hidden_abilities && head_data.hidden_abilities[0]
        ability_name = GameData::Ability.get(head_data.hidden_abilities[0]).name rescue head_data.hidden_abilities[0].to_s
        abilities << ["  Hidden: #{ability_name}", head_data.hidden_abilities[0], :custom]
      end
      
      abilities << ["--- Body (#{body_data.name}) ---", nil, :header]
      
      if body_data.abilities[0]
        ability_name = GameData::Ability.get(body_data.abilities[0]).name rescue body_data.abilities[0].to_s
        abilities << ["  Slot 1: #{ability_name}", body_data.abilities[0], :custom]
      end
      if body_data.abilities[1]
        ability_name = GameData::Ability.get(body_data.abilities[1]).name rescue body_data.abilities[1].to_s
        abilities << ["  Slot 2: #{ability_name}", body_data.abilities[1], :custom]
      end
      if body_data.hidden_abilities && body_data.hidden_abilities[0]
        ability_name = GameData::Ability.get(body_data.hidden_abilities[0]).name rescue body_data.hidden_abilities[0].to_s
        abilities << ["  Hidden: #{ability_name}", body_data.hidden_abilities[0], :custom]
      end
    elsif species_data
      # NON-FUSION: Show normal abilities
      if species_data.abilities[0]
        ability_name = GameData::Ability.get(species_data.abilities[0]).name rescue species_data.abilities[0].to_s
        abilities << ["Slot 1: #{ability_name}", 0, :slot]
      end
      if species_data.abilities[1]
        ability_name = GameData::Ability.get(species_data.abilities[1]).name rescue species_data.abilities[1].to_s
        abilities << ["Slot 2: #{ability_name}", 1, :slot]
      end
      if species_data.hidden_abilities && species_data.hidden_abilities[0]
        ability_name = GameData::Ability.get(species_data.hidden_abilities[0]).name rescue species_data.hidden_abilities[0].to_s
        abilities << ["Hidden: #{ability_name}", 2, :slot]
      end
    else
      # Fallback if species data unavailable
      abilities << ["Ability Slot 1", 0, :slot]
      abilities << ["Ability Slot 2", 1, :slot]
      abilities << ["Hidden Ability", 2, :slot]
    end
    
    # Add Custom Ability option
    abilities << ["--- Custom Ability ---", nil, :header]
    abilities << ["Choose Any Ability...", nil, :choose_custom]
    abilities << ["< Back", nil, :back]
    
    names = abilities.map { |a| a[0] }
    choice = pbShowCommandsOpaque(names, -1)
    
    return if choice < 0  # Cancelled
    
    selected = abilities[choice]
    type = selected[2]
    
    case type
    when :random
      poke_data[:ability_index] = nil
      poke_data[:custom_ability] = nil
    when :header
      # Do nothing for headers, just play buzzer
      pbPlayBuzzerSE
    when :slot
      poke_data[:ability_index] = selected[1]
      poke_data[:custom_ability] = nil
    when :custom
      # For fusions - set the specific ability directly
      poke_data[:ability_index] = nil
      poke_data[:custom_ability] = selected[1]
    when :choose_custom
      custom_ability = choose_any_ability
      if custom_ability
        poke_data[:ability_index] = nil
        poke_data[:custom_ability] = custom_ability
      end
    when :back
      return
    end
  end
  
  # Choose any ability from the game
  def choose_any_ability
    choices = [
      "Browse All Abilities",
      "Search by Name",
      "< Cancel"
    ]
    
    choice = pbShowCommandsOpaque(choices, -1)
    
    case choice
    when 0  # Browse all abilities
      abilities = []
      GameData::Ability.each do |a|
        abilities << [a.name, a.id]
      end
      abilities.sort_by! { |a| a[0] }
      
      names = abilities.map { |a| a[0] }
      names << "< Cancel"
      
      sel = pbShowCommandsOpaque(names, -1)
      return (sel >= 0 && sel < abilities.length) ? abilities[sel][1] : nil
      
    when 1  # Search by name
      search = pbEnterText(_INTL("Enter ability name:"), 0, 20, "")
      return nil if search.nil? || search.empty?
      
      matches = []
      GameData::Ability.each do |a|
        matches << [a.name, a.id] if a.name.downcase.include?(search.downcase)
      end
      
      if matches.empty?
        Kernel.pbMessage(_INTL("No abilities found matching '{1}'", search))
        return nil
      end
      
      matches.sort_by! { |m| m[0] }
      names = matches.map { |m| m[0] }
      names << "< Cancel"
      
      sel = pbShowCommandsOpaque(names, -1)
      return (sel >= 0 && sel < matches.length) ? matches[sel][1] : nil
    else
      return nil
    end
  end
  
  # Get ability display name for current selection
  def get_ability_display(poke_data)
    # Check for custom ability first
    if poke_data[:custom_ability]
      ability_name = GameData::Ability.get(poke_data[:custom_ability]).name rescue poke_data[:custom_ability].to_s
      return "Custom: #{ability_name}"
    end
    
    return "Random" unless poke_data[:ability_index]
    
    species_data = GameData::Species.get(poke_data[:species]) rescue nil
    return "Slot #{poke_data[:ability_index] + 1}" unless species_data
    
    ability_id = case poke_data[:ability_index]
                 when 0 then species_data.abilities[0]
                 when 1 then species_data.abilities[1]
                 when 2 then species_data.hidden_abilities[0] if species_data.hidden_abilities
                 end
    
    return "Slot #{poke_data[:ability_index] + 1}" unless ability_id
    
    ability_name = GameData::Ability.get(ability_id).name rescue ability_id.to_s
    slot_name = poke_data[:ability_index] == 2 ? "Hidden" : "Slot #{poke_data[:ability_index] + 1}"
    "#{slot_name}: #{ability_name}"
  end
  
  def edit_pokemon_ivs(poke_data)
    choices = [
      "Set All to 31 (Perfect)",
      "Set All to 0",
      "Set Random",
      "Edit Individual Stats",
      "< Back"
    ]
    
    choice = pbShowCommandsOpaque(choices, -1)
    case choice
    when 0
      poke_data[:ivs] = [31, 31, 31, 31, 31, 31]
    when 1
      poke_data[:ivs] = [0, 0, 0, 0, 0, 0]
    when 2
      poke_data[:ivs] = nil
    when 3
      edit_individual_stats(poke_data, :ivs, 31)
    end
  end
  
  def edit_pokemon_evs(poke_data)
    choices = [
      "Clear All (0)",
      "Max Attack (252 Atk, 252 Spe, 4 HP)",
      "Max Sp.Atk (252 SpA, 252 Spe, 4 HP)",
      "Max Defense (252 HP, 252 Def, 4 SpD)",
      "Edit Individual Stats",
      "< Back"
    ]
    
    choice = pbShowCommandsOpaque(choices, -1)
    case choice
    when 0
      poke_data[:evs] = nil  # Will be 0s
    when 1
      poke_data[:evs] = [4, 252, 0, 0, 0, 252]  # HP, Atk, Def, SpA, SpD, Spe
    when 2
      poke_data[:evs] = [4, 0, 0, 252, 0, 252]
    when 3
      poke_data[:evs] = [252, 0, 252, 0, 4, 0]
    when 4
      edit_individual_stats(poke_data, :evs, 252)
    end
  end
  
  def edit_individual_stats(poke_data, stat_type, max_val)
    stat_names = ["HP", "Attack", "Defense", "Sp.Atk", "Sp.Def", "Speed"]
    
    # Initialize if nil - use :random symbol for random stats
    poke_data[stat_type] ||= [:random, :random, :random, :random, :random, :random] if stat_type == :ivs
    poke_data[stat_type] ||= [0, 0, 0, 0, 0, 0] if stat_type == :evs
    
    loop do
      options = stat_names.map.with_index do |name, i|
        val = poke_data[stat_type][i]
        display_val = val == :random ? "Random" : val.to_s
        "#{name}: #{display_val}"
      end
      options << "Set All Random" if stat_type == :ivs
      options << "< Back"
      
      choice = pbShowCommandsOpaque(options, -1)
      
      # Handle Set All Random option for IVs
      if stat_type == :ivs && choice == stat_names.length
        poke_data[stat_type] = [:random, :random, :random, :random, :random, :random]
        next
      end
      
      break if choice < 0 || choice >= stat_names.length
      
      # For IVs, offer random option
      if stat_type == :ivs
        iv_choices = ["Set Specific Value", "Set Random", "< Cancel"]
        iv_choice = pbShowCommandsOpaque(iv_choices, -1)
        
        case iv_choice
        when 0
          current = poke_data[stat_type][choice]
          current = 0 if current == :random
          new_val = choose_number(_INTL("Set {1}:", stat_names[choice]), max_val, current, 0)
          poke_data[stat_type][choice] = new_val if new_val
        when 1
          poke_data[stat_type][choice] = :random
        end
      else
        # EVs don't need random option
        current = poke_data[stat_type][choice]
        new_val = choose_number(_INTL("Set {1}:", stat_names[choice]), max_val, current, 0)
        poke_data[stat_type][choice] = new_val if new_val
      end
    end
  end
  
  # Format IVs for display, handling :random values
  def format_ivs_display(ivs)
    return "Random" unless ivs
    return "Random" if ivs.all? { |v| v == :random }
    return "Perfect (31)" if ivs.all? { |v| v == 31 }
    return "Zero (0)" if ivs.all? { |v| v == 0 }
    
    ivs.map { |v| v == :random ? "?" : v.to_s }.join("/")
  end
  
  def edit_pokemon_moves(poke_data)
    choices = [
      "Use Default Moves",
      "Set Custom Moves",
      "< Back"
    ]
    
    choice = pbShowCommandsOpaque(choices, -1)
    return if choice < 0 || choice == 2
    
    if choice == 0
      poke_data[:moves] = nil
      return
    end
    
    # Set custom moves
    poke_data[:moves] ||= []
    
    loop do
      move_names = poke_data[:moves].map do |m|
        GameData::Move.get(m).name rescue m.to_s
      end
      
      while move_names.length < 4
        move_names << "(Empty)"
      end
      
      options = move_names.map.with_index { |name, i| "Move #{i + 1}: #{name}" }
      options << "Clear All Moves"
      options << "< Done"
      
      choice = pbShowCommandsOpaque(options, -1)
      break if choice < 0 || choice == options.length - 1
      
      if choice == options.length - 2  # Clear all
        poke_data[:moves] = []
      elsif choice < 4
        # Edit move slot
        move = pbChooseMoveList
        if move && move != -1
          poke_data[:moves][choice] = move
        else
          poke_data[:moves][choice] = nil
        end
        poke_data[:moves].compact!
      end
    end
  end
  
  def remove_pokemon_reward
    return if @gift[:rewards][:pokemon].empty?
    
    names = @gift[:rewards][:pokemon].map do |p|
      name = GameData::Species.get(p[:species]).name rescue p[:species]
      "Lv.#{p[:level]} #{name}#{p[:shiny] ? ' (Shiny)' : ''}"
    end
    names << "Cancel"
    choice = pbShowCommandsOpaque(names, 0)
    if choice >= 0 && choice < @gift[:rewards][:pokemon].length
      @gift[:rewards][:pokemon].delete_at(choice)
      Kernel.pbMessage(_INTL("Pokemon removed."))
    end
  end
  
  def edit_money
    current = @gift[:rewards][:money]
    new_val = choose_number(_INTL("Enter money amount:"), 999999, current, 0)
    @gift[:rewards][:money] = new_val if new_val
  end
  
  def edit_coins
    current = @gift[:rewards][:coins]
    new_val = choose_number(_INTL("Enter coins amount:"), 99999, current, 0)
    @gift[:rewards][:coins] = new_val if new_val
  end
  
  def edit_min_badges
    current = @gift[:conditions][:min_badges]
    new_val = choose_number(_INTL("Minimum badges required (0 = none):"), 8, current, 0)
    @gift[:conditions][:min_badges] = new_val if new_val
  end
  
  def edit_min_playtime
    current = @gift[:conditions][:min_playtime]
    new_val = choose_number(_INTL("Minimum playtime in hours (0 = none):"), 999, current, 0)
    @gift[:conditions][:min_playtime] = new_val if new_val
  end
  
  def edit_flag
    # Show helpful options for flag selection
    choices = [
      "Enter Switch Number...",
      "View Common Switches",
      "No Flag Required",
      "< Back"
    ]
    choice = pbShowCommandsOpaque(choices, -1)
    return if choice < 0  # Back pressed
    
    case choice
    when 0
      # Manual entry
      current = @gift[:conditions][:flag] || 1
      new_val = choose_number(_INTL("Game Switch number (1-5000):"), 5000, current, 1)
      @gift[:conditions][:flag] = (new_val && new_val > 0) ? new_val : nil
    when 1
      # Show common switches list
      show_common_switches
    when 2
      @gift[:conditions][:flag] = nil
    end
  end
  
  def show_common_switches
    # Build list of commonly used switches with their current state
    common_switches = [
      [1, "Switch 1 (often story progress)"],
      [2, "Switch 2"],
      [5, "Switch 5"],
      [10, "Switch 10"],
      [20, "Switch 20"],
      [50, "Switch 50"],
      [100, "Switch 100"],
      [200, "Switch 200"],
      [500, "Switch 500"]
    ]
    
    # Add current state to each
    switch_list = common_switches.map do |num, desc|
      state = ($game_switches && $game_switches[num]) ? "ON" : "OFF"
      "#{desc} [#{state}]"
    end
    switch_list << "Enter Custom Number..."
    switch_list << "< Back"
    
    choice = pbShowCommandsOpaque(switch_list, -1)
    return if choice < 0 || choice == switch_list.length - 1  # Back
    
    if choice == switch_list.length - 2
      # Custom number
      new_val = choose_number(_INTL("Game Switch number (1-5000):"), 5000, 1, 1)
      @gift[:conditions][:flag] = (new_val && new_val > 0) ? new_val : nil
    elsif choice < common_switches.length
      @gift[:conditions][:flag] = common_switches[choice][0]
      Kernel.pbMessage(_INTL("Flag set to Switch {1}", common_switches[choice][0]))
    end
  end
  
  def preview_gift
    # Build preview text
    items_str = @gift[:rewards][:items].map { |i, q| "#{q}x #{GameData::Item.get(i).name rescue i}" }.join(", ")
    items_str = "None" if items_str.empty?
    
    pokemon_str = @gift[:rewards][:pokemon].map do |p|
      name = GameData::Species.get(p[:species]).name rescue p[:species]
      details = ["Lv.#{p[:level]} #{name}"]
      details << "Shiny" if p[:shiny]
      details << GameData::Nature.get(p[:nature]).name if p[:nature]
      details << "Perfect IVs" if p[:ivs] == [31,31,31,31,31,31]
      details.join(" ")
    end.join(", ")
    pokemon_str = "None" if pokemon_str.empty?
    
    end_date_str = @gift[:end_date] || "Never expires"
    
    msg = _INTL("=== GIFT PREVIEW ===\n")
    msg += _INTL("ID: {1}\n", @gift[:id])
    msg += _INTL("Name: {1}\n", @gift[:name])
    msg += _INTL("Source: {1}\n", @gift[:source])
    msg += _INTL("Dates: {1} to {2}\n", @gift[:start_date], end_date_str)
    msg += _INTL("Frequency: {1}\n", frequency_display(@gift[:frequency]))
    msg += _INTL("Items: {1}\n", items_str)
    msg += _INTL("Pokemon: {1}\n", pokemon_str)
    msg += _INTL("Money: ${1}\n", @gift[:rewards][:money])
    msg += _INTL("Coins: {1}\n", @gift[:rewards][:coins])
    
    if @gift[:conditions][:min_badges] > 0 || @gift[:conditions][:min_playtime] > 0 || @gift[:conditions][:flag]
      msg += _INTL("Conditions: ")
      conds = []
      conds << "#{@gift[:conditions][:min_badges]}+ badges" if @gift[:conditions][:min_badges] > 0
      conds << "#{@gift[:conditions][:min_playtime]}+ hours" if @gift[:conditions][:min_playtime] > 0
      conds << "Flag #{@gift[:conditions][:flag]}" if @gift[:conditions][:flag]
      msg += conds.join(", ")
    end
    
    Kernel.pbMessage(msg)
  end
  
  def validate_gift
    errors = []
    errors << "Gift ID is required" if @gift[:id].empty?
    errors << "Gift Name is required" if @gift[:name].empty?
    errors << "Start Date is required" if @gift[:start_date].empty?
    
    has_rewards = !@gift[:rewards][:items].empty? || 
                  !@gift[:rewards][:pokemon].empty? ||
                  @gift[:rewards][:money] > 0 ||
                  @gift[:rewards][:coins] > 0
    errors << "At least one reward is required" unless has_rewards
    
    errors
  end
  
  def save_gift_to_file
    errors = validate_gift
    unless errors.empty?
      Kernel.pbMessage(_INTL("Cannot save gift:\n{1}", errors.join("\n")))
      return
    end
    
    # Check if gift ID already exists
    file_path = "Data/Scripts/800_KIFR/012a_KIFR_EventGifts.rb"
    existing_gift_found = false
    
    begin
      content = File.read(file_path)
      # Look for the gift ID as a hash key
      existing_gift_found = content.include?("#{@gift[:id]}:")
    rescue
      # File doesn't exist or can't be read, continue with save
    end
    
    if existing_gift_found
      choice = pbShowCommandsOpaque(["Overwrite existing gift", "Cancel"], -1)
      return if choice != 0
      
      # Remove the existing gift from the file
      remove_existing_gift_from_file(@gift[:id])
    else
      unless pbConfirmMessage(_INTL("Save gift '{1}' to EventGifts file?", @gift[:name]))
        return
      end
    end
    
    # Build the Ruby code for this gift
    code = build_gift_code
    
    # Append to the file
    begin
      # Read current file
      content = File.read(file_path)
      
      # Find the SCHEDULED_GIFTS hash and insert before its closing brace
      # We need to find the closing "}" that ends the hash, which is followed by
      # the "# Don't freeze" comment
      
      # Strategy: Find the line with just "    }" that closes the SCHEDULED_GIFTS hash
      # This is the line right before "# Don't freeze"
      
      lines = content.split("\n")
      insertion_index = nil
      
      # Find the closing brace of SCHEDULED_GIFTS
      # Look for a line that is just whitespace + "}" and is followed by the freeze comment
      lines.each_with_index do |line, idx|
        # Check if this line closes the hash (just "    }" with proper indentation)
        if line.strip == "}" && idx + 1 < lines.length
          next_line = lines[idx + 1]
          # Verify it's the SCHEDULED_GIFTS closing by checking for the freeze comment nearby
          if next_line.include?("Don't freeze") || next_line.include?("SCHEDULED_GIFTS.freeze")
            insertion_index = idx
            break
          end
        end
      end
      
      # Fallback: look for "YOUR GIFTS BELOW" marker and find next closing brace
      if insertion_index.nil?
        marker_idx = lines.index { |l| l.include?("YOUR GIFTS BELOW") }
        if marker_idx
          # Find the next line that's just a closing brace at the right indent level
          (marker_idx + 1...lines.length).each do |idx|
            if lines[idx].strip == "}"
              insertion_index = idx
              break
            end
          end
        end
      end
      
      if insertion_index.nil?
        Kernel.pbMessage(_INTL("Could not find insertion point in file.\nPlease add gift manually."))
        return
      end
      
      # Insert the gift code before the closing brace
      # Add a blank line before if the previous line isn't blank or a comment
      prev_line = lines[insertion_index - 1] if insertion_index > 0
      needs_blank = prev_line && !prev_line.strip.empty? && !prev_line.strip.start_with?("#")
      
      gift_lines = code.split("\n")
      gift_lines.unshift("") if needs_blank  # Add blank line before gift
      
      lines.insert(insertion_index, *gift_lines)
      
      new_content = lines.join("\n")
      
      # Write the file
      File.write(file_path, new_content)
      
      # Also add to runtime so it's immediately available
      Gifts::Events.add_scheduled_gift(@gift[:id], build_gift_hash)
      
      @saved = true  # Mark as saved
      Kernel.pbMessage(_INTL("Gift saved successfully!\nID: {1}", @gift[:id]))
      
      # Ask if they want to create another
      if pbConfirmMessage(_INTL("Create another gift?"))
        clear_all
      end
      
    rescue => e
      Kernel.pbMessage(_INTL("Error saving gift: {1}", e.message))
      KIFRDEV.debug_log("GiftCreator: Save error - #{e.message}\n#{e.backtrace.first(3).join("\n")}")
    end
  end
  
  # Remove an existing gift from the file by ID
  def remove_existing_gift_from_file(gift_id)
    file_path = "Data/Scripts/800_KIFR/012a_KIFR_EventGifts.rb"
    
    begin
      content = File.read(file_path)
      lines = content.split("\n")
      
      # Find the start of this gift entry
      gift_start = nil
      lines.each_with_index do |line, idx|
        if line.match?(/^\s*#{Regexp.escape(gift_id.to_s)}:\s*\{/)
          gift_start = idx
          break
        end
      end
      
      return unless gift_start  # Gift not found
      
      # Find the end of this gift entry (matching closing brace + comma)
      brace_depth = 0
      gift_end = gift_start
      started = false
      
      (gift_start...lines.length).each do |idx|
        line = lines[idx]
        brace_depth += line.count('{')
        brace_depth -= line.count('}')
        started = true if brace_depth > 0
        
        if started && brace_depth == 0
          gift_end = idx
          break
        end
      end
      
      # Remove the gift lines (including any blank line before it)
      start_remove = gift_start
      start_remove -= 1 if gift_start > 0 && lines[gift_start - 1].strip.empty?
      
      lines.slice!(start_remove..gift_end)
      
      # Write back
      File.write(file_path, lines.join("\n"))
      
      # Also remove from runtime
      if defined?(Gifts::Events::SCHEDULED_GIFTS)
        Gifts::Events::SCHEDULED_GIFTS.delete(gift_id.to_sym)
      end
      
    rescue => e
      KIFRDEV.debug_log("GiftCreator: Remove error - #{e.message}")
    end
  end
  
  def build_gift_hash
    gift_hash = {
      name: @gift[:name],
      source: @gift[:source],
      start_date: @gift[:start_date],
      end_date: @gift[:end_date],
      rewards: {}
    }
    
    # Add rewards
    gift_hash[:rewards][:items] = @gift[:rewards][:items].dup unless @gift[:rewards][:items].empty?
    gift_hash[:rewards][:pokemon] = @gift[:rewards][:pokemon].dup unless @gift[:rewards][:pokemon].empty?
    gift_hash[:rewards][:money] = @gift[:rewards][:money] if @gift[:rewards][:money] > 0
    gift_hash[:rewards][:coins] = @gift[:rewards][:coins] if @gift[:rewards][:coins] > 0
    
    # Add frequency if not default
    gift_hash[:frequency] = @gift[:frequency] if @gift[:frequency] && @gift[:frequency] != :once
    
    # Add conditions if any
    if @gift[:conditions][:min_badges] > 0 || @gift[:conditions][:min_playtime] > 0 || @gift[:conditions][:flag]
      gift_hash[:conditions] = {}
      gift_hash[:conditions][:min_badges] = @gift[:conditions][:min_badges] if @gift[:conditions][:min_badges] > 0
      gift_hash[:conditions][:min_playtime] = @gift[:conditions][:min_playtime] if @gift[:conditions][:min_playtime] > 0
      gift_hash[:conditions][:flag] = @gift[:conditions][:flag] if @gift[:conditions][:flag]
    end
    
    gift_hash
  end
  
  def build_gift_code
    lines = []
    lines << "      #{@gift[:id]}: {"
    lines << "        name: \"#{@gift[:name]}\","
    lines << "        source: \"#{@gift[:source]}\","
    lines << "        start_date: \"#{@gift[:start_date]}\","
    lines << "        end_date: #{@gift[:end_date] ? "\"#{@gift[:end_date]}\"" : 'nil'},"
    lines << "        frequency: :#{@gift[:frequency]}," if @gift[:frequency] && @gift[:frequency] != :once
    lines << "        rewards: {"
    
    # Items
    unless @gift[:rewards][:items].empty?
      items_str = @gift[:rewards][:items].map do |i, q|
        item_id = i.is_a?(Symbol) ? i : (i.respond_to?(:id) ? i.id : i)
        "[:#{item_id}, #{q}]"
      end.join(", ")
      lines << "          items: [#{items_str}],"
    end
    
    # Pokemon
    unless @gift[:rewards][:pokemon].empty?
      poke_strs = @gift[:rewards][:pokemon].map do |p|
        # Convert species to symbol ID if it's an object
        species_id = p[:species].is_a?(Symbol) ? p[:species] : (p[:species].respond_to?(:id) ? p[:species].id : p[:species])
        parts = ["species: :#{species_id}", "level: #{p[:level]}"]
        parts << "shiny: true" if p[:shiny]
        if p[:nature]
          nature_id = p[:nature].is_a?(Symbol) ? p[:nature] : (p[:nature].respond_to?(:id) ? p[:nature].id : p[:nature])
          parts << "nature: :#{nature_id}"
        end
        # Custom ability takes precedence over ability_index
        if p[:custom_ability]
          ability_id = p[:custom_ability].is_a?(Symbol) ? p[:custom_ability] : (p[:custom_ability].respond_to?(:id) ? p[:custom_ability].id : p[:custom_ability])
          parts << "custom_ability: :#{ability_id}"
        elsif p[:ability_index]
          parts << "ability_index: #{p[:ability_index]}"
        end
        parts << "gender: #{p[:gender]}" if p[:gender]
        # Handle IVs with :random support
        if p[:ivs] && !p[:ivs].all? { |v| v == :random }
          # Convert :random to nil in output, actual numbers stay as-is
          iv_str = p[:ivs].map { |v| v == :random ? "nil" : v.to_s }.join(", ")
          parts << "ivs: [#{iv_str}]"
        end
        parts << "evs: #{p[:evs].inspect}" if p[:evs]
        if p[:moves] && p[:moves].any?
          move_ids = p[:moves].map { |m| m.is_a?(Symbol) ? ":#{m}" : (m.respond_to?(:id) ? ":#{m.id}" : ":#{m}") }
          parts << "moves: [#{move_ids.join(', ')}]"
        end
        if p[:item]
          item_id = p[:item].is_a?(Symbol) ? p[:item] : (p[:item].respond_to?(:id) ? p[:item].id : p[:item])
          parts << "item: :#{item_id}"
        end
        parts << "nickname: \"#{p[:nickname]}\"" if p[:nickname]
        "{ #{parts.join(', ')} }"
      end
      lines << "          pokemon: [#{poke_strs.join(', ')}],"
    end
    
    # Money & Coins
    lines << "          money: #{@gift[:rewards][:money]}," if @gift[:rewards][:money] > 0
    lines << "          coins: #{@gift[:rewards][:coins]}," if @gift[:rewards][:coins] > 0
    
    lines << "        },"
    
    # Conditions
    if @gift[:conditions][:min_badges] > 0 || @gift[:conditions][:min_playtime] > 0 || @gift[:conditions][:flag]
      lines << "        conditions: {"
      lines << "          min_badges: #{@gift[:conditions][:min_badges]}," if @gift[:conditions][:min_badges] > 0
      lines << "          min_playtime: #{@gift[:conditions][:min_playtime]}," if @gift[:conditions][:min_playtime] > 0
      lines << "          flag: #{@gift[:conditions][:flag]}," if @gift[:conditions][:flag]
      lines << "        }"
    end
    
    lines << "      },"
    
    lines.join("\n")
  end
  
  def clear_all
    @gift = {
      id: "",
      name: "",
      source: "Event",
      start_date: Time.now.strftime("%m-%d-%y"),
      end_date: nil,
      frequency: :once,
      rewards: {
        items: [],
        pokemon: [],
        money: 0,
        coins: 0
      },
      conditions: {
        min_badges: 0,
        min_playtime: 0,
        flag: nil
      }
    }
    refresh_display
    Kernel.pbMessage(_INTL("All fields cleared."))
  end
  
  def confirm_exit?
    # If already saved, no need to confirm
    return true if @saved
    
    # Check if there's any data entered
    has_data = !@gift[:id].empty? || !@gift[:name].empty? || 
               !@gift[:rewards][:items].empty? || !@gift[:rewards][:pokemon].empty? ||
               @gift[:rewards][:money] > 0 || @gift[:rewards][:coins] > 0
    
    if has_data
      return pbConfirmMessage(_INTL("Discard unsaved changes?"))
    end
    true
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  def self.show(gift_to_edit = nil)
    scene = KIFRDEV_GiftCreator.new(gift_to_edit)
    scene.pbStartScene
    scene.pbScene
    scene.pbEndScene
  end
end

#===============================================================================
# GIFT LIST - View and manage existing scheduled gifts
#===============================================================================
class KIFRDEV_GiftList
  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
  end
  
  def pbStartScene
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Gift List"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    @sprites["textbox"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].text = _INTL("Select a gift to manage")
    
    build_gift_list
    
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["textbox"].height
    
    @sprites["content"] = Window_CommandPokemon.newWithSize(
      @gift_names, 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["content"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["content"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["content"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["content"].index = 0
    
    pbFadeInAndShow(@sprites)
  end
  
  def build_gift_list
    @gifts = []
    @gift_names = []
    
    # Get gifts from SCHEDULED_GIFTS
    if defined?(Gifts::Events::SCHEDULED_GIFTS)
      Gifts::Events::SCHEDULED_GIFTS.each do |id, data|
        @gifts << { id: id, data: data }
        name = data[:name] || id.to_s
        @gift_names << name
      end
    end
    
    if @gift_names.empty?
      @gift_names << "(No gifts defined)"
    end
    @gift_names << "< Back"
  end
  
  def refresh_display
    build_gift_list
    @sprites["content"].commands = @gift_names
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
      
      if Input.trigger?(Input::USE)
        idx = @sprites["content"].index
        if idx >= @gifts.length
          break  # Back selected or no gifts
        elsif @gifts[idx]
          action = manage_gift(@gifts[idx])
          break if action == :exit_to_creator  # Exit list if opening in creator
          refresh_display
        end
      elsif Input.trigger?(Input::BACK)
        break
      end
    end
  end
  
  def manage_gift(gift_entry)
    gift_id = gift_entry[:id]
    gift = gift_entry[:data]
    freq = gift[:frequency] || :once
    
    # Build options based on gift frequency
    choices = ["Open in Gift Creator"]
    
    # Only show Resend option for one-time gifts that have been received
    if freq == :once && Gifts::Events.received?(gift_id)
      choices << "Resend Gift"
    end
    
    choices << "Delete Gift"
    choices << "< Back"
    
    choice = pbShowCommandsOpaque(choices, -1)
    return nil if choice < 0 || choice == choices.length - 1  # Back
    
    selected_action = choices[choice]
    
    if selected_action == "Open in Gift Creator"
      # Close this scene and open in Gift Creator
      pbEndScene
      KIFRDEV_GiftCreator.show(gift_entry)
      return :exit_to_creator
    elsif selected_action.start_with?("Resend")
      if pbConfirmMessage(_INTL("Reset received status for '{1}'?\nThis will allow the player to receive it again.", gift[:name]))
        # Remove from received list
        Gifts::Events.received_events.delete(gift_id.to_sym)
        Kernel.pbMessage(_INTL("Gift '{1}' can now be received again.", gift[:name]))
      end
    elsif selected_action == "Delete Gift"
      if pbConfirmMessage(_INTL("Delete gift '{1}'?\nThis will remove it from the file!", gift[:name]))
        # Remove from runtime
        Gifts::Events::SCHEDULED_GIFTS.delete(gift_id)
        
        # Remove from the file
        if remove_gift_from_file(gift_id)
          Kernel.pbMessage(_INTL("Gift '{1}' permanently deleted.", gift[:name]))
        else
          Kernel.pbMessage(_INTL("Gift removed from runtime.\nCouldn't update file - may need manual edit."))
        end
      end
    end
    
    nil
  end
  
  def remove_gift_from_file(gift_id)
    file_path = "Data/Scripts/800_KIFR/012a_KIFR_EventGifts.rb"
    
    begin
      return false unless File.exist?(file_path)
      
      content = File.read(file_path)
      
      # Match the gift entry pattern: "gift_id: { ... }," with potential multi-line content
      # This regex finds the gift block from "gift_id: {" to the matching closing "},"
      gift_id_str = gift_id.to_s
      
      # Find the start of this gift entry
      start_pattern = /^(\s*)#{Regexp.escape(gift_id_str)}:\s*\{/m
      match = content.match(start_pattern)
      
      return false unless match
      
      start_pos = match.begin(0)
      indent = match[1]
      
      # Find the matching closing brace by counting braces
      search_start = match.end(0)
      brace_count = 1
      pos = search_start
      
      while brace_count > 0 && pos < content.length
        char = content[pos]
        brace_count += 1 if char == '{'
        brace_count -= 1 if char == '}'
        pos += 1
      end
      
      # Include the trailing comma and newline if present
      end_pos = pos
      end_pos += 1 while content[end_pos] =~ /[,\s]/ && content[end_pos] != "\n"
      end_pos += 1 if content[end_pos] == "\n"
      
      # Also remove any blank line before if the entry had one
      if start_pos > 0 && content[start_pos - 1] == "\n"
        # Check if there's another newline (blank line)
        if start_pos > 1 && content[start_pos - 2] == "\n"
          start_pos -= 1
        end
      end
      
      # Remove the gift entry
      new_content = content[0...start_pos] + content[end_pos..-1]
      
      # Write back
      File.write(file_path, new_content)
      
      Gifts.debug_log("GiftEditor: Removed gift '#{gift_id}' from #{file_path}")
      true
    rescue => e
      Gifts.debug_log("GiftEditor: Error removing gift from file: #{e.message}")
      false
    end
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  def self.show
    scene = KIFRDEV_GiftList.new
    scene.pbStartScene
    scene.pbScene
    scene.pbEndScene
  end
end

# Alias for backwards compatibility
KIFRDEV_GiftEditor = KIFRDEV_GiftList

KIFRDEV.debug_log("Gift Creator & Gift List modules loaded") if defined?(KIFRDEV)
