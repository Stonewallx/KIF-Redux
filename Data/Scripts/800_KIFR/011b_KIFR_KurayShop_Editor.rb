#===============================================================================
# KIF Redux Kuray Shop Editor - In-Game Configuration
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file provides the in-game editor for Kuray Shop configuration:
# - Category management (reorder, rename, enable/disable, add, delete)
# - Item management (search, add, remove, edit prices, favorites)
# - Bulk operations (multiply prices, set sell percentage)
# - Config import/export/reset
# - Streamer's Dream toggle (moved from base game options)
#===============================================================================

#===============================================================================
# Helper for showing command menus with opaque black background
#===============================================================================
def pbKurayShopCommands(prompt, commands, cancel_value = -1, default_index = 0)
  # Show prompt message if provided
  pbMessage(prompt) if prompt && !prompt.empty?
  
  # Use the global opaque command helper if available, otherwise fall back
  if defined?(pbShowCommandsOpaque)
    return pbShowCommandsOpaque(commands, cancel_value, default_index)
  else
    # Fallback to standard message
    return pbMessage("Select:", commands)
  end
end

#===============================================================================
# KURAY SHOP SETTINGS SCENE
# Main settings menu for Kuray Shop configuration
#===============================================================================
class KurayShopSettings_Scene < PokemonOption_Scene
  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    
    # Background
    addBackgroundPlane(@sprites, "bg", "optionsbg", @viewport)
    
    # Title bar
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Kuray Shop Editor"), 0, 0, Graphics.width, 64, @viewport
    )
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    # Help/instructions bar at bottom
    @sprites["helpwindow"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport
    )
    @sprites["helpwindow"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["helpwindow"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["helpwindow"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    # Options window - calculate height to fit between title and help
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["helpwindow"].height
    
    @sprites["optionwindow"] = Window_KIFRScrollable.newWithSize([], 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["optionwindow"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["optionwindow"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["optionwindow"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    refresh_options
    pbFadeInAndShow(@sprites) { pbUpdate }
  end
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
  
  def refresh_options
    @options = build_options
    @sprites["optionwindow"].commands = @options.map { |o| o[:text] }
    @sprites["optionwindow"].index = 0 if @sprites["optionwindow"].index >= @options.length
    update_help
  end
  
  def build_options
    options = []
    
    options << { text: "[CAT]Category Management", type: :header, help: "" }
    options << {
      text: "  Manage Categories",
      type: :manage_categories,
      help: "Reorder, rename, enable/disable categories"
    }
    options << {
      text: "  Add New Category",
      type: :add_category,
      help: "Create a new category for organizing items"
    }
    
    options << { text: "[CAT]Item Management", type: :header, help: "" }
    options << {
      text: "  Edit Items",
      type: :search_items,
      help: "Browse all items - add new or edit existing items in the shop"
    }
    options << {
      text: "  Edit Item Prices",
      type: :edit_prices,
      help: "Customize prices for individual items"
    }
    
    options << { text: "[CAT]Config Management", type: :header, help: "" }
    options << {
      text: "  Presets",
      type: :presets_menu,
      help: "Load, save, import, export, or delete presets"
    }
    
    options << {
      text: "  Reset Kuray Shop",
      type: :reset_config,
      help: "Reset all Kuray Shop settings to defaults"
    }
    
    options
  end
  
  def update_help
    return unless @sprites["helpwindow"]
    idx = @sprites["optionwindow"].index
    return if idx < 0 || idx >= @options.length
    
    help = @options[idx][:help] || ""
    @sprites["helpwindow"].text = help
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdate
      update_help
      
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        result = handle_selection
        break if result == :close
      end
    end
  end
  
  def handle_selection
    idx = @sprites["optionwindow"].index
    return if idx < 0 || idx >= @options.length
    
    option = @options[idx]
    
    case option[:type]
    when :header
      pbPlayCancelSE
    when :manage_categories
      pbPlayDecisionSE
      open_category_manager
    when :add_category
      pbPlayDecisionSE
      add_new_category
    when :search_items
      pbPlayDecisionSE
      open_item_search
    when :edit_prices
      pbPlayDecisionSE
      open_price_editor
    when :presets_menu
      pbPlayDecisionSE
      open_presets_menu
    when :reset_config
      pbPlayDecisionSE
      reset_config_dialog
    end
  end
  
  def open_category_manager
    pbFadeOutIn {
      scene = CategoryManager_Scene.new
      scene.pbStartScene
      scene.pbScene
      scene.pbEndScene
    }
    refresh_options
  end
  
  def add_new_category
    name = pbEnterText(_INTL("Enter category name:"), 0, 20)
    return if name.nil? || name.strip.empty?
    
    if KurayShopData.add_category(name.strip)
      pbMessage(_INTL("Category '{1}' created!", name.strip))
    else
      pbMessage(_INTL("Could not create category."))
    end
    refresh_options
  end
  
  def open_item_search
    pbFadeOutIn {
      scene = ItemBrowser_Scene.new
      scene.pbStartScene
      scene.pbScene
      scene.pbEndScene
    }
    refresh_options
  end
  
  def open_price_editor
    pbFadeOutIn {
      scene = PriceEditor_Scene.new
      scene.pbStartScene
      scene.pbScene
      scene.pbEndScene
    }
    refresh_options
  end
  
  def open_presets_menu
    pbFadeOutIn {
      scene = PresetsMenu_Scene.new
      scene.pbStartScene
      scene.pbScene
      scene.pbEndScene
    }
    refresh_options
  end
  
  def reset_config_dialog
    if pbConfirmMessage(_INTL("Reset all Kuray Shop settings to defaults?"))
      if pbConfirmMessage(_INTL("Are you sure? This cannot be undone!"))
        KurayShopData.reset_config
        pbMessage(_INTL("Kuray Shop settings reset to defaults!"))
        refresh_options
      end
    end
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
# PRESETS MENU SCENE
# Submenu for all preset operations
#===============================================================================
class PresetsMenu_Scene < PokemonOption_Scene
  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    
    addBackgroundPlane(@sprites, "bg", "optionsbg", @viewport)
    
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Presets"), 0, 0, Graphics.width, 64, @viewport
    )
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    @sprites["helpwindow"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport
    )
    @sprites["helpwindow"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["helpwindow"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["helpwindow"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["helpwindow"].height
    
    @sprites["optionwindow"] = Window_KIFRScrollable.newWithSize([], 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["optionwindow"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["optionwindow"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["optionwindow"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    refresh_options
    pbFadeInAndShow(@sprites) { pbUpdate }
  end
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
  
  def refresh_options
    @options = build_options
    @sprites["optionwindow"].commands = @options.map { |o| o[:text] }
    @sprites["optionwindow"].index = 0 if @sprites["optionwindow"].index >= @options.length
    update_help
  end
  
  def build_options
    options = []
    
    options << {
      text: "Load Preset",
      type: :load_preset,
      help: "Apply a saved preset to your shop"
    }
    options << {
      text: "Save as Preset",
      type: :save_preset,
      help: "Save current shop config as a new preset"
    }
    options << {
      text: "Delete Preset",
      type: :delete_preset,
      help: "Delete a custom preset"
    }
    options << {
      text: "Export Preset",
      type: :export_preset,
      help: "Export a preset to a file for sharing"
    }
    options << {
      text: "Import Preset",
      type: :import_preset,
      help: "Import a preset from a file"
    }
    
    options
  end
  
  def update_help
    return unless @sprites["helpwindow"]
    idx = @sprites["optionwindow"].index
    return if idx < 0 || idx >= @options.length
    
    help = @options[idx][:help] || ""
    @sprites["helpwindow"].text = help
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdate
      update_help
      
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        handle_selection
      end
    end
  end
  
  def handle_selection
    idx = @sprites["optionwindow"].index
    return if idx < 0 || idx >= @options.length
    
    option = @options[idx]
    
    case option[:type]
    when :load_preset
      pbPlayDecisionSE
      load_preset_dialog
    when :save_preset
      pbPlayDecisionSE
      save_preset_dialog
    when :delete_preset
      pbPlayDecisionSE
      delete_preset_dialog
    when :export_preset
      pbPlayDecisionSE
      export_preset_dialog
    when :import_preset
      pbPlayDecisionSE
      import_preset_dialog
    end
  end
  
  def load_preset_dialog
    presets = KurayShopData.available_presets
    
    if presets.empty?
      pbMessage(_INTL("No presets available."))
      return
    end
    
    # Build choice list with preset names
    choices = presets.map { |id| 
      preset = KurayShopData.get_preset(id)
      preset ? preset[:name] : id.to_s.capitalize
    }
    choices << "Cancel"
    
    choice = pbKurayShopCommands(nil, choices, -1)
    
    return if choice < 0 || choice >= presets.length  # Cancel selected
    
    preset_id = presets[choice]
    preset = KurayShopData.get_preset(preset_id)
    
    # Confirm load
    if pbConfirmMessage(_INTL("Load Preset?"))
      if KurayShopData.apply_preset(preset_id)
        pbMessage(_INTL("Preset '{1}' loaded successfully!", preset[:name]))
      else
        pbMessage(_INTL("Could not load preset."))
      end
    end
  end
  
  def save_preset_dialog
    name = pbEnterText(_INTL("Enter preset name:"), 0, 20)
    return if name.nil? || name.strip.empty?
    
    # Check if this would be a built-in preset
    preset_id = name.strip.downcase.gsub(/[^a-z0-9]/, '_').to_sym
    if KurayShopData::PRESETS.key?(preset_id)
      pbMessage(_INTL("Cannot overwrite the built-in '{1}' preset.", name.strip))
      return
    end
    
    # Check if custom preset already exists
    if KurayShopData.get_preset(preset_id)
      return unless pbConfirmMessage(_INTL("Preset '{1}' already exists. Overwrite?", name.strip))
    end
    
    if KurayShopData.save_current_as_preset(name.strip)
      pbMessage(_INTL("Preset '{1}' saved!", name.strip))
    else
      pbMessage(_INTL("Could not save preset."))
    end
  end
  
  def delete_preset_dialog
    # Get list of custom presets only (can't delete built-in)
    presets = KurayShopData.custom_presets.keys
    
    if presets.empty?
      pbMessage(_INTL("No custom presets to delete."))
      return
    end
    
    # Build choice list
    choices = presets.map { |id|
      preset = KurayShopData.get_preset(id)
      preset ? preset[:name] : id.to_s
    }
    choices << "Cancel"
    
    choice = pbKurayShopCommands(nil, choices, -1)
    return if choice < 0 || choice >= presets.length
    
    preset_id = presets[choice]
    preset = KurayShopData.get_preset(preset_id)
    preset_name = preset ? preset[:name] : preset_id.to_s
    
    if pbConfirmMessage(_INTL("Delete preset '{1}'?", preset_name))
      if KurayShopData.delete_preset(preset_id)
        pbMessage(_INTL("Preset deleted!"))
      else
        pbMessage(_INTL("Could not delete preset."))
      end
    end
  end
  
  def export_preset_dialog
    # Get list of custom presets (can't export built-in)
    presets = KurayShopData.custom_presets.keys
    
    if presets.empty?
      pbMessage(_INTL("No custom presets to export. Save a preset first."))
      return
    end
    
    # Build choice list
    choices = presets.map { |id|
      preset = KurayShopData.get_preset(id)
      preset ? preset[:name] : id.to_s
    }
    choices << "Cancel"
    
    choice = pbKurayShopCommands(nil, choices, -1)
    return if choice < 0 || choice >= presets.length
    
    preset_id = presets[choice]
    if KurayShopData.export_preset(preset_id)
      pbMessage(_INTL("Preset exported to KIFR/Exports folder!"))
    else
      pbMessage(_INTL("Could not export preset."))
    end
  end
  
  def import_preset_dialog
    exports = KurayShopData.list_preset_exports
    
    if exports.empty?
      pbMessage(_INTL("No preset files found in KIFR/Exports folder."))
      return
    end
    
    exports << "Cancel"
    choice = pbKurayShopCommands(nil, exports, -1)
    
    return if choice < 0 || choice >= exports.length - 1
    
    result = KurayShopData.import_preset(exports[choice])
    if result
      pbMessage(_INTL("Preset '{1}' added to your presets!", result))
    else
      pbMessage(_INTL("Could not import preset."))
    end
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
# CATEGORY MANAGER SCENE
#===============================================================================
class CategoryManager_Scene < PokemonOption_Scene
  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    
    addBackgroundPlane(@sprites, "bg", "optionsbg", @viewport)
    
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Manage Categories"), 0, 0, Graphics.width, 64, @viewport
    )
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    @sprites["helpwindow"] = Window_AdvancedTextPokemon.newWithSize(
      "Left/Right: Reorder | A: Options | B: Back", 0, Graphics.height - 64, Graphics.width, 64, @viewport
    )
    @sprites["helpwindow"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["helpwindow"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["helpwindow"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["helpwindow"].height
    
    @sprites["optionwindow"] = Window_KIFRScrollable.newWithSize([], 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["optionwindow"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["optionwindow"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["optionwindow"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    refresh_categories
    pbFadeInAndShow(@sprites) { pbUpdate }
  end
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
  
  def refresh_categories
    @categories = KurayShopData.categories
    commands = []
    
    @categories.each_with_index do |cat, i|
      status = cat[:enabled] ? "" : " [OFF]"
      item_count = (cat[:items] || []).length
      commands << "#{i + 1}. #{cat[:name]}#{status} (#{item_count} items)"
    end
    
    @sprites["optionwindow"].commands = commands
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdate
      
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        idx = @sprites["optionwindow"].index
        
        if idx >= @categories.length
          pbPlayCloseMenuSE
          break
        else
          handle_category_options(idx)
        end
      elsif Input.trigger?(Input::LEFT)
        move_category_up
      elsif Input.trigger?(Input::RIGHT)
        move_category_down
      end
    end
  end
  
  def move_category_up
    idx = @sprites["optionwindow"].index
    return if idx >= @categories.length || idx <= 0
    
    cat = @categories[idx]
    if KurayShopData.move_category_up(cat[:id])
      pbPlayDecisionSE
      refresh_categories
      @sprites["optionwindow"].index = idx - 1
    end
  end
  
  def move_category_down
    idx = @sprites["optionwindow"].index
    return if idx >= @categories.length - 1
    
    cat = @categories[idx]
    if KurayShopData.move_category_down(cat[:id])
      pbPlayDecisionSE
      refresh_categories
      @sprites["optionwindow"].index = idx + 1
    end
  end
  
  def handle_category_options(idx)
    cat = @categories[idx]
    return unless cat
    
    pbPlayDecisionSE
    
    color_name = KurayShopData.color_name(cat[:color] || :red)
    
    options = [
      cat[:enabled] ? "Disable Category" : "Enable Category",
      "Rename Category",
      "Change Color (#{color_name})",
      "View Items",
      "Delete Category",
      "Cancel"
    ]
    
    choice = pbKurayShopCommands(nil, options, -1)
    
    case choice
    when 0  # Enable/Disable
      KurayShopData.set_category_enabled(cat[:id], !cat[:enabled])
      refresh_categories
    when 1  # Rename
      new_name = pbEnterText(_INTL("Enter new name:"), 0, 20, cat[:name])
      if new_name && !new_name.strip.empty?
        KurayShopData.rename_category(cat[:id], new_name.strip)
        refresh_categories
      end
    when 2  # Change Color
      change_category_color(cat)
    when 3  # View Items
      view_category_items(cat)
    when 4  # Delete
      if pbConfirmMessage(_INTL("Delete category '{1}'?", cat[:name]))
        if pbConfirmMessage(_INTL("Items in this category will be removed. Continue?"))
          KurayShopData.delete_category(cat[:id])
          refresh_categories
        end
      end
    end
  end
  
  def change_category_color(cat)
    colors = KurayShopData.available_colors
    color_names = colors.map { |c| KurayShopData.color_name(c) }
    color_names << "Cancel"
    
    current_idx = colors.index(cat[:color] || :red) || 0
    
    choice = pbKurayShopCommands(nil, color_names, -1, current_idx)
    
    return if choice < 0 || choice >= colors.length
    
    KurayShopData.set_category_color(cat[:id], colors[choice])
    refresh_categories
    pbMessage(_INTL("Category color set to {1}!", color_names[choice]))
  end
  
  def view_category_items(cat)
    items = cat[:items] || []
    
    if items.empty?
      pbMessage(_INTL("This category has no items."))
      return
    end
    
    item_names = items.each_with_index.map { |id, i| "#{i + 1}. #{KurayShopData.get_item_name(id)} (#{id})" }
    item_names << "Back"
    
    loop do
      choice = pbKurayShopCommands(nil, item_names, -1)
      
      break if choice < 0 || choice >= items.length
      
      item_id = items[choice]
      handle_item_options(item_id, cat[:id], choice)
      
      # Refresh item list
      items = (KurayShopData.get_category(cat[:id])[:items] || [])
      item_names = items.each_with_index.map { |id, i| "#{i + 1}. #{KurayShopData.get_item_name(id)} (#{id})" }
      item_names << "Back"
    end
  end
  
  def handle_item_options(item_id, category_id, item_index = nil)
    name = KurayShopData.get_item_name(item_id)
    price = KurayShopData.get_price(item_id)
    price_str = price ? "$#{price[0]} / $#{price[1]}" : "Default"
    fav = KurayShopData.favorite?(item_id) ? " [FAV]" : ""
    
    # Get current position info
    cat = KurayShopData.get_category(category_id)
    items = cat[:items] || []
    current_pos = items.index(item_id) || 0
    total_items = items.length
    pos_str = " (#{current_pos + 1}/#{total_items})"
    
    options = [
      KurayShopData.favorite?(item_id) ? "Remove from Favorites" : "Add to Favorites",
      "Edit Price",
      "Move Up in List",
      "Move Down in List",
      "Move to Category",
      "Remove from Shop",
      "Cancel"
    ]
    
    choice = pbKurayShopCommands(nil, options, -1)
    
    case choice
    when 0  # Toggle favorite
      KurayShopData.toggle_favorite(item_id)
      pbMessage(_INTL("{1} {2} favorites!", name, 
        KurayShopData.favorite?(item_id) ? "added to" : "removed from"))
    when 1  # Edit price
      edit_item_price(item_id)
    when 2  # Move Up
      if KurayShopData.move_item_up_in_category(item_id, category_id)
        pbPlayDecisionSE
      else
        pbPlayBuzzerSE
        pbMessage(_INTL("Item is already at the top!"))
      end
    when 3  # Move Down
      if KurayShopData.move_item_down_in_category(item_id, category_id)
        pbPlayDecisionSE
      else
        pbPlayBuzzerSE
        pbMessage(_INTL("Item is already at the bottom!"))
      end
    when 4  # Move to category
      move_item_dialog(item_id, category_id)
    when 5  # Remove
      if pbConfirmMessage(_INTL("Remove {1} from shop?", name))
        KurayShopData.remove_item_from_category(item_id, category_id)
      end
    end
  end
  
  def edit_item_price(item_id)
    current = KurayShopData.get_price(item_id)
    current_buy = current ? current[0] : 1000
    
    params = ChooseNumberParams.new
    params.setRange(0, 9999999)
    params.setInitialValue(current_buy)
    params.setCancelValue(-1)
    
    new_buy = pbChooseNumber(@sprites["helpwindow"], params)
    return if new_buy == -1
    
    # Ask for sell price
    params2 = ChooseNumberParams.new
    params2.setRange(0, 9999999)
    params2.setInitialValue((new_buy / 2.0).round)
    params2.setCancelValue(-1)
    
    new_sell = pbChooseNumber(@sprites["helpwindow"], params2)
    return if new_sell == -1
    
    KurayShopData.set_custom_price(item_id, new_buy, new_sell)
    pbMessage(_INTL("Price set to ${1} / ${2}", new_buy, new_sell))
  end
  
  def move_item_dialog(item_id, current_category_id)
    categories = KurayShopData.categories.reject { |c| c[:id] == current_category_id }
    
    if categories.empty?
      pbMessage(_INTL("No other categories available."))
      return
    end
    
    cat_names = categories.map { |c| c[:name] }
    cat_names << "Cancel"
    
    choice = pbKurayShopCommands(nil, cat_names, -1)
    return if choice < 0 || choice >= categories.length
    
    target = categories[choice]
    KurayShopData.move_item_to_category(item_id, current_category_id, target[:id])
    pbMessage(_INTL("Item moved to {1}!", target[:name]))
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
# ITEM BROWSER SCENE - Browse all items with categories and search
#===============================================================================
class ItemBrowser_Scene
  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @search_text = ""
    @line_to_item = {}
    @last_idx = -1
  end
  
  def pbStartScene
    load_all_items
    
    # Title bar
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Edit Items"), 0, 0, Graphics.width, 64, @viewport
    )
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    # Description box at bottom (bigger for full descriptions)
    @sprites["descbox"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 128, Graphics.width, 128, @viewport
    )
    @sprites["descbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["descbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["descbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["descbox"].letterbyletter = false
    
    # Item icon sprite (positioned on mid-right of screen, 10% bigger)
    @sprites["itemicon"] = ItemIconSprite.new(Graphics.width - 80, Graphics.height / 2 - 50, nil, @viewport)
    @sprites["itemicon"].zoom_x = 1.1
    @sprites["itemicon"].zoom_y = 1.1
    
    # Category label as plain text sprite (centered below item icon)
    @sprites["catlabel"] = Sprite.new(@viewport)
    @sprites["catlabel"].bitmap = Bitmap.new(200, 32)
    @sprites["catlabel"].x = Graphics.width - 80 - 100  # Center below item (item is at -80, so -100 to center 200px width)
    @sprites["catlabel"].y = Graphics.height / 2 + 10
    @sprites["catlabel"].z = 100
    @cat_label_text = ""
    
    # Build content
    @lines = build_content
    
    # Scrollable content area
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["descbox"].height
    
    @sprites["content"] = Window_KIFRScrollable.newWithSize(
      @lines, 0, content_y, Graphics.width - 160, content_height, @viewport
    )
    @sprites["content"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["content"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["content"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["content"].index = 0
    
    update_display
    pbFadeInAndShow(@sprites)
  end
  
  def load_all_items
    @all_items = []
    
    # Load all items from the game's item database
    begin
      # Try using GameData::Item if available
      if defined?(GameData::Item)
        GameData::Item.each do |item_data|
          is_hidden = (item_data.is_hidden_item? rescue false)
          next if is_hidden
          
          # Get display name with move name for TMs/HMs
          display_name = item_data.name
          is_machine = (item_data.is_machine? rescue false)
          if is_machine
            move_id = (item_data.move rescue nil)
            if move_id && defined?(GameData::Move)
              move_data = (GameData::Move.get(move_id) rescue nil)
              if move_data
                display_name = "#{item_data.name} - #{move_data.name}"
              end
            end
          end
          
          @all_items << {
            id: item_data.id,
            name: display_name,
            desc: item_data.description,
            pocket: item_data.pocket || 0,
            price: item_data.price || 0
          }
        end
      elsif defined?(pbGetItemData)
        # Loop through item IDs
        (1..999).each do |id|
          begin
            data = pbGetItemData(id)
            if data && data[0]  # Has a name
              @all_items << {
                id: id,
                name: data[0],
                desc: data[1] || "",
                pocket: data[2] || 0,
                price: data[4] || 0
              }
            end
          rescue
            # Item doesn't exist
          end
        end
      end
    rescue => e
      # Fallback - just use IDs
      KIFRSettings.debug_log("ItemBrowser: Error loading items: #{e.message}") if defined?(KIFRSettings)
    end
    
    # Sort by name
    @all_items.sort_by! { |i| i[:name].to_s.downcase }
  end
  
  def update_display
    idx = @sprites["content"] ? @sprites["content"].index : 0
    return if idx == @last_idx
    @last_idx = idx
    
    if @line_to_item[idx]
      item = @line_to_item[idx]
      # Show item description
      desc = item[:desc] || "No description available."
      @sprites["descbox"].text = desc
      
      # Show item icon
      @sprites["itemicon"].item = item[:id]
      @sprites["itemicon"].visible = true
      
      # Show category if in shop
      cat_name = get_item_category(item[:id])
      if cat_name
        draw_category_label("[#{cat_name}]")
        @sprites["catlabel"].visible = true
      else
        @sprites["catlabel"].visible = false
      end
    else
      if @search_text != ""
        @sprites["descbox"].text = _INTL("Searching: {1}", @search_text)
      else
        @sprites["descbox"].text = _INTL("C: Select | Sp: Search | A: Clear | B: Back")
      end
      @sprites["itemicon"].visible = false
      @sprites["catlabel"].visible = false
    end
  end
  
  def draw_category_label(text)
    return if @cat_label_text == text  # Don't redraw if same text
    @cat_label_text = text
    
    bitmap = @sprites["catlabel"].bitmap
    bitmap.clear
    
    # Set font
    bitmap.font.name = "Power Green Small"
    bitmap.font.size = 22
    
    # Calculate text width to center it
    text_width = bitmap.text_size(text).width
    x = (bitmap.width - text_width) / 2
    
    # Draw shadow first (offset by 1,1)
    bitmap.font.color = Color.new(32, 96, 32)
    bitmap.draw_text(x + 1, 1, text_width + 4, 28, text)
    
    # Draw main text
    bitmap.font.color = Color.new(64, 200, 64)
    bitmap.draw_text(x, 0, text_width + 4, 28, text)
  end
  
  def get_item_category(item_id)
    return nil unless defined?(KurayShopData)
    
    # Get both Symbol and Integer versions of the item ID for flexible matching
    item_int = convert_item_id_to_int(item_id)
    item_sym = convert_item_id_to_sym(item_id)
    
    KurayShopData.categories.each do |cat|
      cat_items = (cat[:items] || [])
      # Check both Integer and Symbol - categories might store either format
      if (item_int && cat_items.include?(item_int)) || 
         (item_sym && cat_items.include?(item_sym)) ||
         cat_items.include?(item_id)
        return cat[:name]
      end
    end
    nil
  end
  
  # Helper to convert item ID (Symbol or Integer) to Integer
  def convert_item_id_to_int(item_id)
    return item_id if item_id.is_a?(Integer)
    return nil unless item_id.is_a?(Symbol)
    
    # Use GameData::Item to get the ID number
    if defined?(GameData::Item)
      item_data = GameData::Item.try_get(item_id)
      return item_data.id_number if item_data && item_data.respond_to?(:id_number)
    end
    # Fallback to getID if available
    (getID(PBItems, item_id) rescue nil)
  end
  
  # Helper to convert item ID (Symbol or Integer) to Symbol
  def convert_item_id_to_sym(item_id)
    return item_id if item_id.is_a?(Symbol)
    return nil unless item_id.is_a?(Integer)
    
    # Use GameData::Item to get the Symbol ID
    if defined?(GameData::Item)
      item_data = GameData::Item.try_get(item_id)
      return item_data.id if item_data
    end
    nil
  end
  
  def item_in_shop?(item_id)
    get_item_category(item_id) != nil
  end
  
  def refresh_display
    @last_idx = -1  # Force update
    @lines = build_content
    @sprites["content"].commands = @lines
    @sprites["content"].index = [@sprites["content"].index, @lines.length - 1].min
    update_display
  end
  
  def build_content
    lines = []
    @line_to_item = {}
    @line_to_category = {}
    
    # Filter items if searching
    filtered_items = @all_items
    if @search_text != ""
      search_lower = @search_text.downcase
      filtered_items = @all_items.select do |item|
        item[:name].downcase.include?(search_lower) ||
        item[:id].to_s == @search_text
      end
    end
    
    # Show flat list of all items (sorted by name)
    if filtered_items.empty?
      lines << "No items found"
    else
      if @search_text != ""
        lines << "Search Results (#{filtered_items.length})"
      end
      filtered_items.each do |item|
        line_idx = lines.length
        lines << item[:name].to_s
        @line_to_item[line_idx] = item
      end
    end
    
    lines
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
      update_display
      
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        handle_selection
      elsif Input.trigger?(Input::SPECIAL)  # Special button - Search
        do_search
      elsif Input.trigger?(Input::ACTION)  # A button - Clear search
        if @search_text != ""
          @search_text = ""
          refresh_display
        end
      elsif Input.repeat?(Input::LEFT)
        # Move up by 5 (hold to scroll fast)
        idx = @sprites["content"].index
        new_idx = [idx - 5, 0].max
        if new_idx != idx
          @sprites["content"].index = new_idx
          pbPlayCursorSE
        end
      elsif Input.repeat?(Input::RIGHT)
        # Move down by 5 (hold to scroll fast)
        idx = @sprites["content"].index
        max_idx = @lines.length - 1
        new_idx = [idx + 5, max_idx].min
        if new_idx != idx
          @sprites["content"].index = new_idx
          pbPlayCursorSE
        end
      end
    end
  end
  
  def handle_selection
    idx = @sprites["content"].index
    
    # Check if it's an item
    if @line_to_item[idx]
      item = @line_to_item[idx]
      handle_item_selection(item)
      return
    end
    
    pbPlayCancelSE
  end
  
  def handle_item_selection(item)
    pbPlayDecisionSE
    
    # Get both formats for flexible matching
    item_int = convert_item_id_to_int(item[:id])
    item_sym = convert_item_id_to_sym(item[:id])
    in_shop = item_in_shop?(item[:id])
    
    if in_shop
      # Item already in shop - find which category
      cat_id = nil
      cat_name = "Unknown"
      matched_id = nil  # Track which ID format we found
      
      KurayShopData.categories.each do |cat|
        cat_items = (cat[:items] || [])
        if item_int && cat_items.include?(item_int)
          cat_id = cat[:id]
          cat_name = cat[:name]
          matched_id = item_int
          break
        elsif item_sym && cat_items.include?(item_sym)
          cat_id = cat[:id]
          cat_name = cat[:name]
          matched_id = item_sym
          break
        elsif cat_items.include?(item[:id])
          cat_id = cat[:id]
          cat_name = cat[:name]
          matched_id = item[:id]
          break
        end
      end
      
      options = [
        "Remove from Shop",
        "Cancel"
      ]
      
      choice = pbKurayShopCommands(nil, options, -1)
      
      case choice
      when 0
        if pbConfirmMessage(_INTL("Remove {1} from {2}?", item[:name], cat_name))
          KurayShopData.remove_item_from_category(matched_id || item_int || item[:id], cat_id)
          pbMessage(_INTL("{1} removed!", item[:name]))
          refresh_display
        end
      end
    else
      # Item not in shop - offer to add
      categories = KurayShopData.categories
      cat_names = categories.map { |c| c[:name] }
      cat_names << "Cancel"
      
      # Show command window on the right side of the screen
      choice = show_right_commands(cat_names, -1)
      
      # Only add if they picked a valid category (not Cancel or B pressed)
      if choice >= 0 && choice < categories.length
        cat = categories[choice]
        # Convert Symbol ID to integer for storage
        add_id = convert_item_id_to_int(item[:id])
        if add_id && KurayShopData.add_item_to_category(add_id, cat[:id])
          pbMessage(_INTL("{1} added to {2}!", item[:name], cat[:name]))
          refresh_display
        else
          pbMessage(_INTL("Could not add item."))
        end
      end
    end
  end
  
  def show_right_commands(commands, cmdIfCancel = 0)
    # Create a black background sprite
    bg = Sprite.new(@viewport)
    bg.z = 99998
    
    cmdwindow = Window_CommandPokemon.new(commands)
    cmdwindow.z = 99999
    cmdwindow.visible = true
    cmdwindow.resizeToFit(cmdwindow.commands)
    # Position on right side of screen
    cmdwindow.x = Graphics.width - cmdwindow.width
    cmdwindow.y = (Graphics.height - cmdwindow.height) / 2
    cmdwindow.index = 0
    
    # Create background bitmap sized to window
    bg.bitmap = Bitmap.new(cmdwindow.width + 8, cmdwindow.height + 8)
    bg.bitmap.fill_rect(0, 0, bg.bitmap.width, bg.bitmap.height, Color.new(0, 0, 0, 220))
    bg.x = cmdwindow.x - 4
    bg.y = cmdwindow.y - 4
    
    command = 0
    loop do
      Graphics.update
      Input.update
      cmdwindow.update
      # Don't update main sprites - prevents cursor movement in background
      
      if Input.trigger?(Input::BACK)
        if cmdIfCancel < 0
          command = cmdIfCancel
          break
        elsif cmdIfCancel > 0
          command = cmdIfCancel - 1
          break
        end
      end
      if Input.trigger?(Input::USE)
        command = cmdwindow.index
        break
      end
    end
    
    cmdwindow.dispose
    bg.bitmap.dispose
    bg.dispose
    return command
  end
  
  def do_search
    query = pbEnterText(_INTL("Search for item:"), 0, 30, @search_text)
    return if query.nil?
    
    @search_text = query.strip
    refresh_display
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
# PRICE EDITOR SCENE
#===============================================================================
class PriceEditor_Scene < PokemonOption_Scene
  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @selected_category = 0
    @last_idx = -1
    
    addBackgroundPlane(@sprites, "bg", "optionsbg", @viewport)
    
    # Title at top
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Item Price Editor"), 0, 0, Graphics.width, 64, @viewport
    )
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    # Help/info at bottom
    @sprites["descbox"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport
    )
    @sprites["descbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["descbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["descbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    content_y = 64  # After title
    content_height = Graphics.height - 64 - 64  # Between title and description
    
    @sprites["optionwindow"] = Window_KIFRScrollable.newWithSize([], 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["optionwindow"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["optionwindow"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["optionwindow"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    refresh_items
    update_description
    pbFadeInAndShow(@sprites) { pbUpdate }
  end
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
    update_description
  end
  
  def update_description
    idx = @sprites["optionwindow"] ? @sprites["optionwindow"].index : 0
    return if idx == @last_idx
    @last_idx = idx
    
    # Adjust index for items (first row is category header)
    item_idx = idx - 1
    if item_idx >= 0 && item_idx < @items.length
      item_id = @items[item_idx]
      default_price = get_default_price(item_id)
      @sprites["descbox"].text = _INTL("Default Price: ${1} / ${2}", default_price[0], default_price[1])
    else
      @sprites["descbox"].text = "Left/Right: Change Category | C: Edit | B: Back"
    end
  end
  
  def refresh_items
    @items = []
    commands = []
    
    # Get categories
    categories = KurayShopData.categories
    if categories.empty?
      commands << "[CTR]No categories found"
      @sprites["optionwindow"].commands = commands
      return
    end
    
    @selected_category = @selected_category % categories.length
    cat = categories[@selected_category]
    
    # Category header as first row (red, centered)
    commands << "[CAT]#{cat[:name]}"
    
    # Build item list with prices and TM/HM names
    (cat[:items] || []).each do |item_id|
      custom_price = KurayShopData.get_price(item_id)
      default_price = get_default_price(item_id)
      
      if custom_price
        price_str = "$#{custom_price[0]} / $#{custom_price[1]}"
      else
        price_str = "$#{default_price[0]} / $#{default_price[1]}"
      end
      
      custom = KurayShopData.has_custom_price?(item_id) ? "*" : ""
      name = get_item_display_name(item_id)
      
      @items << item_id
      # [VAL] format: left text | right text
      commands << "[VAL]#{name}#{custom}|#{price_str}"
    end
    
    if @items.empty?
      commands << "[CTR]No items in this category"
    end
    
    @sprites["optionwindow"].commands = commands
    @sprites["optionwindow"].index = 0 if @sprites["optionwindow"].index >= commands.length
  end
  
  def get_item_display_name(item_id)
    begin
      if defined?(GameData::Item)
        item_data = GameData::Item.get(item_id)
        if item_data
          # Add move name for TMs/HMs
          is_machine = (item_data.is_machine? rescue false)
          if is_machine
            move_id = (item_data.move rescue nil)
            if move_id && defined?(GameData::Move)
              move_data = (GameData::Move.get(move_id) rescue nil)
              if move_data
                return "#{item_data.name} - #{move_data.name}"
              end
            end
          end
          return item_data.name
        end
      end
    rescue
    end
    KurayShopData.get_item_name(item_id)
  end
  
  def get_default_price(item_id)
    begin
      if defined?(GameData::Item)
        item_data = GameData::Item.get(item_id)
        buy = item_data.price || 0
        sell = (buy / 2.0).round
        return [buy, sell]
      elsif defined?(pbGetItemData)
        data = pbGetItemData(item_id)
        if data
          buy = data[4] || 0
          sell = (buy / 2.0).round
          return [buy, sell]
        end
      end
    rescue
    end
    [0, 0]
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdate
      
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        idx = @sprites["optionwindow"].index
        if idx == 0
          # Category row - do nothing on select
          pbPlayCancelSE
        elsif idx > 0 && idx <= @items.length
          edit_price(@items[idx - 1])
        end
      elsif Input.trigger?(Input::LEFT)
        change_category(-1)
      elsif Input.trigger?(Input::RIGHT)
        change_category(1)
      end
    end
  end
  
  def change_category(dir)
    categories = KurayShopData.categories
    return if categories.empty?
    
    @selected_category = (@selected_category + dir) % categories.length
    pbPlayDecisionSE
    refresh_items
  end
  
  def edit_price(item_id)
    pbPlayDecisionSE
    
    name = KurayShopData.get_item_name(item_id)
    current = KurayShopData.get_price(item_id)
    has_custom = KurayShopData.has_custom_price?(item_id)
    
    # Build options with descriptions
    options = []
    descriptions = []
    
    options << "Set Buy Price"
    descriptions << "Change how much this item costs to purchase."
    
    options << "Set Sell Price"
    descriptions << "Change how much you receive when selling this item."
    
    options << "Set Both"
    descriptions << "Set both buy and sell prices at once."
    
    if has_custom
      options << "Reset to Default"
      descriptions << "Remove custom pricing and use the game's default price."
    end
    
    options << "Cancel"
    descriptions << "Return without making changes."
    
    # Show opaque command window with description in bottom box
    choice = show_price_commands(options, descriptions, -1)
    return if choice < 0 || choice >= options.length - 1  # Cancel or B pressed
    
    case options[choice]
    when "Set Buy Price"
      current_buy = current ? current[0] : 1000
      params = ChooseNumberParams.new
      params.setRange(0, 9999999)
      params.setInitialValue(current_buy)
      params.setCancelValue(-1)
      
      new_buy = pbChooseNumber(@sprites["descbox"], params)
      if new_buy >= 0
        sell = current ? current[1] : (new_buy / 2.0).round
        KurayShopData.set_custom_price(item_id, new_buy, sell)
        refresh_items
      end
    when "Set Sell Price"
      current_sell = current ? current[1] : 500
      params = ChooseNumberParams.new
      params.setRange(0, 9999999)
      params.setInitialValue(current_sell)
      params.setCancelValue(-1)
      
      new_sell = pbChooseNumber(@sprites["descbox"], params)
      if new_sell >= 0
        buy = current ? current[0] : (new_sell * 2)
        KurayShopData.set_custom_price(item_id, buy, new_sell)
        refresh_items
      end
    when "Set Both"
      current_buy = current ? current[0] : 1000
      params = ChooseNumberParams.new
      params.setRange(0, 9999999)
      params.setInitialValue(current_buy)
      params.setCancelValue(-1)
      
      new_buy = pbChooseNumber(@sprites["descbox"], params)
      return if new_buy < 0
      
      params2 = ChooseNumberParams.new
      params2.setRange(0, 9999999)
      params2.setInitialValue((new_buy / 2.0).round)
      params2.setCancelValue(-1)
      
      new_sell = pbChooseNumber(@sprites["descbox"], params2)
      return if new_sell < 0
      
      KurayShopData.set_custom_price(item_id, new_buy, new_sell)
      refresh_items
    when "Reset to Default"
      KurayShopData.remove_custom_price(item_id)
      refresh_items
    end
  end
  
  def show_price_commands(commands, descriptions, cmdIfCancel = 0, defaultIndex = 0)
    # Create black background sprite
    bg = Sprite.new(@viewport)
    bg.z = 99998
    
    cmdwindow = Window_CommandPokemon.new(commands)
    cmdwindow.z = 99999
    cmdwindow.visible = true
    cmdwindow.resizeToFit(cmdwindow.commands)
    # Center the window
    cmdwindow.x = (Graphics.width - cmdwindow.width) / 2
    cmdwindow.y = (Graphics.height - cmdwindow.height) / 2 - 32
    cmdwindow.index = defaultIndex
    
    # Create background bitmap sized to window
    bg.bitmap = Bitmap.new(cmdwindow.width + 8, cmdwindow.height + 8)
    bg.bitmap.fill_rect(0, 0, bg.bitmap.width, bg.bitmap.height, Color.new(0, 0, 0, 220))
    bg.x = cmdwindow.x - 4
    bg.y = cmdwindow.y - 4
    
    # Update description for initial selection
    @sprites["descbox"].text = descriptions[cmdwindow.index] if descriptions[cmdwindow.index]
    
    command = 0
    loop do
      Graphics.update
      Input.update
      cmdwindow.update
      
      # Update description when selection changes
      if descriptions[cmdwindow.index]
        @sprites["descbox"].text = descriptions[cmdwindow.index]
      end
      
      if Input.trigger?(Input::BACK)
        if cmdIfCancel < 0
          command = cmdIfCancel
          break
        elsif cmdIfCancel > 0
          command = cmdIfCancel - 1
          break
        end
      end
      if Input.trigger?(Input::USE)
        command = cmdwindow.index
        break
      end
    end
    
    cmdwindow.dispose
    bg.bitmap.dispose
    bg.dispose
    return command
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
# KURAY SHOP SETTINGS SCREEN (Entry Point)
#===============================================================================
class KurayShopSettingsScreen
  def initialize(scene)
    @scene = scene
  end
  
  def pbStartScreen
    @scene.pbStartScene
    ret = @scene.pbScene
    @scene.pbEndScene
    return ret
  end
end

# Convenience method
def pbKurayShopSettings
  scene = KurayShopSettings_Scene.new
  screen = KurayShopSettingsScreen.new(scene)
  screen.pbStartScreen
end

#===============================================================================
# DEBUG LOG
#===============================================================================
if defined?(KIFRSettings)
  KIFRSettings.debug_log("KurayShopEditor: Module loaded successfully")
end
