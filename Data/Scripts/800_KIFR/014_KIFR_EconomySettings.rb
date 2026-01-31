#===============================================================================
# KIF Redux Economy Settings - Scene-Based Submenus
# Script Version: 2.0.0
# Author: Stonewall
#===============================================================================
# This file contains scene-based settings submenus for all economy features.
# Each scene extends PokemonOption_Scene for consistency with KIFR patterns.
# All scenes are registered in the "Economy" category via KIFRSettings.register()
#===============================================================================

#===============================================================================
# CUSTOM WINDOW FOR SCROLLABLE INFO SCENES
# Renders category headers (lines starting with [CAT]) using KIFR category theme
#===============================================================================
class Window_KIFRScrollable < Window_CommandPokemon
  # Prefixes for special rendering
  CATEGORY_PREFIX = "[CAT]"  # Category header (centered, theme color)
  CENTER_PREFIX = "[CTR]"    # Centered text (normal color)
  VALUE_PREFIX = "[VAL]"     # Label|Value format (label left, value right - 50/50 split)
  WIDE_VALUE_PREFIX = "[WID]" # Label|Value format with wider value area (30/70 split)
  GIFT_HEADER_PREFIX = "[GHD]" # Gift header: just the name (red, centered)
  GIFT_ROW_PREFIX = "[GR3]"    # Gift row 3-col: type|date|rewards (left|center|right)
  
  def drawItem(index, _count, rect)
    text = @commands[index]
    
    # Check if this is a category header
    if text.start_with?(CATEGORY_PREFIX)
      rect = drawCursor(index, rect)
      pbSetSystemFont(self.contents)
      
      # Get KIFR category theme color
      category_theme_idx = $PokemonSystem.kifr_category_theme rescue 3
      category_theme_idx ||= 3  # Default Red
      
      if defined?(COLOR_THEMES)
        theme_key = COLOR_THEMES.keys[category_theme_idx]
        theme = COLOR_THEMES[theme_key] if theme_key
      end
      
      # Use theme colors or fallback to default
      if theme && theme[:base] && theme[:shadow]
        baseColor = theme[:base]
        shadowColor = theme[:shadow]
      else
        baseColor = Color.new(240, 120, 120)  # Default red
        shadowColor = Color.new(92, 44, 44)
      end
      
      # Remove prefix and draw centered
      header_text = text.sub(CATEGORY_PREFIX, "")
      pbDrawShadowText(self.contents, rect.x, rect.y, rect.width, rect.height, 
                       header_text, baseColor, shadowColor, 1)  # 1 = center alignment
      return
    end
    
    # Check if this is centered text (normal color)
    if text.start_with?(CENTER_PREFIX)
      rect = drawCursor(index, rect)
      pbSetSystemFont(self.contents)
      
      # Use standard text colors
      baseColor = self.baseColor
      shadowColor = self.shadowColor
      
      # Remove prefix and draw centered
      centered_text = text.sub(CENTER_PREFIX, "")
      pbDrawShadowText(self.contents, rect.x, rect.y, rect.width, rect.height, 
                       centered_text, baseColor, shadowColor, 1)  # 1 = center alignment
      return
    end
    
    # Check if this is a label|value format (label left, value right)
    if text.start_with?(VALUE_PREFIX)
      rect = drawCursor(index, rect)
      pbSetSystemFont(self.contents)
      
      # Use standard text colors
      baseColor = self.baseColor
      shadowColor = self.shadowColor
      
      # Parse label|value
      content = text.sub(VALUE_PREFIX, "")
      parts = content.split("|", 2)
      label = parts[0] || ""
      value = parts[1] || ""
      
      # Draw label on left
      pbDrawShadowText(self.contents, rect.x, rect.y, rect.width / 2, rect.height, 
                       label, baseColor, shadowColor, 0)  # 0 = left alignment
      
      # Draw value on right (in right half of rect)
      pbDrawShadowText(self.contents, rect.x + rect.width / 2, rect.y, rect.width / 2 - 8, rect.height, 
                       value, baseColor, shadowColor, 2)  # 2 = right alignment
      return
    end
    
    # Check if this is a wide label|value format (30/70 split for longer values)
    if text.start_with?(WIDE_VALUE_PREFIX)
      rect = drawCursor(index, rect)
      pbSetSystemFont(self.contents)
      
      # Use standard text colors
      baseColor = self.baseColor
      shadowColor = self.shadowColor
      
      # Parse label|value
      content = text.sub(WIDE_VALUE_PREFIX, "")
      parts = content.split("|", 2)
      label = parts[0] || ""
      value = parts[1] || ""
      
      # 30% for label, 70% for value
      label_width = (rect.width * 0.30).to_i
      value_width = rect.width - label_width - 8
      
      # Draw label on left
      pbDrawShadowText(self.contents, rect.x, rect.y, label_width, rect.height, 
                       label, baseColor, shadowColor, 0)  # 0 = left alignment
      
      # Draw value on right with more space
      pbDrawShadowText(self.contents, rect.x + label_width, rect.y, value_width, rect.height, 
                       value, baseColor, shadowColor, 2)  # 2 = right alignment
      return
    end
    
    # Check if this is a gift header (just name in red, centered)
    if text.start_with?(GIFT_HEADER_PREFIX)
      rect = drawCursor(index, rect)
      pbSetSystemFont(self.contents)
      
      # Parse just name
      name_str = text.sub(GIFT_HEADER_PREFIX, "")
      
      # Get theme color for name
      category_theme_idx = $PokemonSystem.kifr_category_theme rescue 3
      category_theme_idx ||= 3
      red_base = Color.new(240, 120, 120)
      red_shadow = Color.new(92, 44, 44)
      if defined?(COLOR_THEMES)
        theme_key = COLOR_THEMES.keys[category_theme_idx]
        theme = COLOR_THEMES[theme_key] if theme_key
        if theme && theme[:base] && theme[:shadow]
          red_base = theme[:base]
          red_shadow = theme[:shadow]
        end
      end
      
      # Draw name centered in red
      pbDrawShadowText(self.contents, rect.x, rect.y, rect.width, rect.height,
                       name_str, red_base, red_shadow, 1)  # 1 = center alignment
      return
    end
    
    # Check if this is a gift row with 3 columns (type|date|rewards)
    if text.start_with?(GIFT_ROW_PREFIX)
      rect = drawCursor(index, rect)
      pbSetSystemFont(self.contents)
      
      # Parse type|date|rewards
      content = text.sub(GIFT_ROW_PREFIX, "")
      parts = content.split("|", 3)
      type_str = parts[0] || ""
      date_str = parts[1] || ""
      rewards_str = parts[2] || ""
      
      # Colors
      baseColor = self.baseColor
      shadowColor = self.shadowColor
      
      # Calculate widths: 25% type, 30% date (centered), 45% rewards
      type_width = (rect.width * 0.25).to_i
      date_width = (rect.width * 0.30).to_i
      rewards_width = rect.width - type_width - date_width - 8
      
      # Draw type on left
      pbDrawShadowText(self.contents, rect.x, rect.y, type_width, rect.height,
                       type_str, baseColor, shadowColor, 0)  # 0 = left alignment
      
      # Draw date in center (shifted 10 pixels right to better center between columns)
      pbDrawShadowText(self.contents, rect.x + type_width + 10, rect.y, date_width, rect.height,
                       date_str, baseColor, shadowColor, 1)  # 1 = center alignment
      
      # Draw rewards on right
      pbDrawShadowText(self.contents, rect.x + type_width + date_width, rect.y, rewards_width, rect.height,
                       rewards_str, baseColor, shadowColor, 2)  # 2 = right alignment
      return
    end
    
    # Default rendering for normal lines
    super(index, _count, rect)
  end
end

#===============================================================================
# KURAY SHOP SETTINGS SCENE
# Now redirects to the full KurayShop Editor from 011b_KIFR_KurayShop_Editor.rb
#===============================================================================
class KIFR_KurayShopSettingsScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    # Set defaults if not already set
    KIFRSettings.set_default(:kuray_show_ids, false)
    
    #---------------------------------------------------------------------------
    # STREAMER'S DREAM TOGGLE (moved from base game KIF Settings)
    #---------------------------------------------------------------------------
    options << EnumOption.new(
      _INTL("Streamer's Dream"),
      [_INTL("Off"), _INTL("On")],
      proc { 
        val = 0
        if defined?($PokemonSystem) && $PokemonSystem.respond_to?(:kuraystreamerdream)
          val = $PokemonSystem.kuraystreamerdream
        end
        val || 0
      },
      proc { |value| 
        if defined?($PokemonSystem) && $PokemonSystem.respond_to?(:kuraystreamerdream=)
          $PokemonSystem.kuraystreamerdream = value
        end
      },
      _INTL("Free Pokeballs, TMs, and Eggs in Kuray Shop")
    )
    
    #---------------------------------------------------------------------------
    # OPEN KURAY SHOP EDITOR BUTTON
    #---------------------------------------------------------------------------
    options << ButtonOption.new(_INTL("Open Shop Editor"),
      proc {
        pbFadeOutIn {
          if defined?(pbKurayShopSettings)
            pbKurayShopSettings
          else
            Kernel.pbMessage(_INTL("Kuray Shop Editor is not available."))
          end
        }
      },
      _INTL("Full editor: manage categories, items, and prices"))
    
    return options
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create title (invisible initially)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Kuray Shop Settings"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    
    # Create double row description box (96px)
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
    
    # Apply color theme
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
end

#===============================================================================
# SHOP FEATURES SETTINGS SCENE (Stock, Deals, Cart, etc.)
#===============================================================================
class KIFR_ShopFeaturesSettingsScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    # Note: This settings scene is currently not used.
    # Limited Stock, Daily Deals, Weekly Specials, Shopping Cart features are not implemented.
    # Bulk Discounts are always enabled (hardcoded in EconomyMod::BulkDiscounts).
    # Shop Categories are always enabled.
    
    return options
  end
  
  def pbStartScene(inloadscreen = false)
    super(inloadscreen)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Shop Features"), 0, 0, Graphics.width, 64, @viewport)
  end
end

#===============================================================================
# SHOP DATA SETTINGS SCENE (Favorites, History, Wishlist)
#===============================================================================
class KIFR_ShopDataSettingsScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    # Set defaults if not already set
    KIFRSettings.set_default(:shop_favorites, 1)
    KIFRSettings.set_default(:shop_favorites_max, 20)
    KIFRSettings.set_default(:shop_history, 1)
    KIFRSettings.set_default(:shop_history_max, 50)
    KIFRSettings.set_default(:shop_wishlist, 1)
    KIFRSettings.set_default(:shop_wishlist_max, 10)
    KIFRSettings.set_default(:shop_notifications, 1)
    KIFRSettings.set_default(:shop_price_colors, 1)
    KIFRSettings.set_default(:shop_preview_panel, 1)
    KIFRSettings.set_default(:shop_sort_mode, 0)
    KIFRSettings.set_default(:shop_track_statistics, 1)
    
    #---------------------------------------------------------------------------
    # FAVORITES
    #---------------------------------------------------------------------------
    options << EnumOption.new(
      _INTL("Item Favorites"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:shop_favorites, 1) },
      proc { |value| KIFRSettings.set(:shop_favorites, value) },
      _INTL("Mark items as favorites for quick access")
    )
    
    options << EnumOption.new(
      _INTL("Max Favorites"),
      ["10", "20", "50", "100", "Unlimited"],
      proc { 
        max = KIFRSettings.get(:shop_favorites_max, 20)
        [10, 20, 50, 100, 999].index(max) || 1
      },
      proc { |value| 
        max = [10, 20, 50, 100, 999][value] || 20
        KIFRSettings.set(:shop_favorites_max, max)
      },
      _INTL("Maximum number of favorite items")
    )
    
    #---------------------------------------------------------------------------
    # HISTORY
    #---------------------------------------------------------------------------
    options << EnumOption.new(
      _INTL("Purchase History"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:shop_history, 1) },
      proc { |value| KIFRSettings.set(:shop_history, value) },
      _INTL("Track purchase and sale history")
    )
    
    options << EnumOption.new(
      _INTL("History Entries"),
      ["25", "50", "100", "200", "Unlimited"],
      proc { 
        max = KIFRSettings.get(:shop_history_max, 50)
        [25, 50, 100, 200, 999].index(max) || 1
      },
      proc { |value| 
        max = [25, 50, 100, 200, 999][value] || 50
        KIFRSettings.set(:shop_history_max, max)
      },
      _INTL("Maximum history entries to keep")
    )
    
    #---------------------------------------------------------------------------
    # WISHLIST
    #---------------------------------------------------------------------------
    options << EnumOption.new(
      _INTL("Item Wishlist"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:shop_wishlist, 1) },
      proc { |value| KIFRSettings.set(:shop_wishlist, value) },
      _INTL("Track items you want to buy later")
    )
    
    options << EnumOption.new(
      _INTL("Max Wishlist Items"),
      ["5", "10", "20", "50"],
      proc { 
        max = KIFRSettings.get(:shop_wishlist_max, 10)
        [5, 10, 20, 50].index(max) || 1
      },
      proc { |value| 
        max = [5, 10, 20, 50][value] || 10
        KIFRSettings.set(:shop_wishlist_max, max)
      },
      _INTL("Maximum wishlist items")
    )
    
    #---------------------------------------------------------------------------
    # UI OPTIONS
    #---------------------------------------------------------------------------
    options << EnumOption.new(
      _INTL("Notifications"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:shop_notifications, 1) },
      proc { |value| KIFRSettings.set(:shop_notifications, value) },
      _INTL("Show notifications for deals and wishlist items")
    )
    
    options << EnumOption.new(
      _INTL("Price Colors"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:shop_price_colors, 1) },
      proc { |value| KIFRSettings.set(:shop_price_colors, value) },
      _INTL("Color-code prices (green=sale, red=markup)")
    )
    
    options << EnumOption.new(
      _INTL("Preview Panel"),
      [_INTL("Off"), _INTL("Compact"), _INTL("Full")],
      proc { KIFRSettings.get(:shop_preview_panel, 1) },
      proc { |value| KIFRSettings.set(:shop_preview_panel, value) },
      _INTL("Item preview panel style")
    )
    
    options << EnumOption.new(
      _INTL("Default Sort"),
      [_INTL("Default"), _INTL("Name"), _INTL("Price ↑"), _INTL("Price ↓"), _INTL("Type")],
      proc { KIFRSettings.get(:shop_sort_mode, 0) },
      proc { |value| KIFRSettings.set(:shop_sort_mode, value) },
      _INTL("Default sorting mode for shop items")
    )
    
    options << EnumOption.new(
      _INTL("Track Statistics"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:shop_track_statistics, 1) },
      proc { |value| KIFRSettings.set(:shop_track_statistics, value) },
      _INTL("Track shopping statistics and analytics")
    )
    
    #---------------------------------------------------------------------------
    # DATA MANAGEMENT
    #---------------------------------------------------------------------------
    options << ButtonOption.new(
      _INTL("View Favorites"),
      proc { pbViewFavorites },
      _INTL("View and manage your favorite items")
    )
    
    options << ButtonOption.new(
      _INTL("View Wishlist"),
      proc { pbViewWishlist },
      _INTL("View and manage your wishlist")
    )
    
    options << ButtonOption.new(
      _INTL("Clear History"),
      proc { pbClearHistory },
      _INTL("Clear purchase/sale history")
    )
    
    return options
  end
  
  def pbViewFavorites
    if defined?(ShopData::Favorites)
      list = ShopData::Favorites.list
      if list.empty?
        Kernel.pbMessage(_INTL("No favorites saved yet."))
      else
        names = list.map { |item| EconomyMod::Core.item_name(item) rescue "Item ##{item}" }
        names << _INTL("Back")
        
        loop do
          choice = Kernel.pbShowCommands(nil, names, -1, 0)
          break if choice < 0 || choice >= list.length
          
          item = list[choice]
          if Kernel.pbConfirmMessage(_INTL("Remove {1} from favorites?", names[choice]))
            ShopData::Favorites.remove(item)
            names.delete_at(choice)
            list = ShopData::Favorites.list
            break if list.empty?
          end
        end
      end
    else
      Kernel.pbMessage(_INTL("Favorites system not available."))
    end
  end
  
  def pbViewWishlist
    if defined?(ShopData::Wishlist)
      list = ShopData::Wishlist.list
      if list.empty?
        Kernel.pbMessage(_INTL("Your wishlist is empty."))
      else
        names = list.map { |entry| 
          name = EconomyMod::Core.item_name(entry[:item]) rescue "Item ##{entry[:item]}"
          price_str = entry[:target_price] ? " (≤$#{entry[:target_price]})" : ""
          "#{name}#{price_str}"
        }
        names << _INTL("Back")
        
        loop do
          choice = Kernel.pbShowCommands(nil, names, -1, 0)
          break if choice < 0 || choice >= list.length
          
          entry = list[choice]
          if Kernel.pbConfirmMessage(_INTL("Remove from wishlist?"))
            ShopData::Wishlist.remove(entry[:item])
            names.delete_at(choice)
            list = ShopData::Wishlist.list
            break if list.empty?
          end
        end
      end
    else
      Kernel.pbMessage(_INTL("Wishlist system not available."))
    end
  end
  
  def pbClearHistory
    if Kernel.pbConfirmMessage(_INTL("Clear all purchase history? This cannot be undone."))
      ShopData::History.clear if defined?(ShopData::History)
      Kernel.pbMessage(_INTL("History cleared."))
    end
  end
  
  def pbStartScene(inloadscreen = false)
    super(inloadscreen)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Shop Data Settings"), 0, 0, Graphics.width, 64, @viewport)
  end
end

#===============================================================================
# GIFT SYSTEM SETTINGS SCENE
#===============================================================================
class KIFR_GiftSettingsScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    # Set defaults
    KIFRSettings.set_default(:gift_notifications, 1)
    
    #---------------------------------------------------------------------------
    # VIEW GIFTS
    #---------------------------------------------------------------------------
    options << ButtonOption.new(
      _INTL("Milestones"),
      proc { pbViewMilestoneRewards },
      _INTL("See all milestones and your progress")
    )
    
    options << ButtonOption.new(
      _INTL("Gift Inbox"),
      proc { pbOpenGiftInbox },
      _INTL("View and claim your pending gifts")
    )
    
    #---------------------------------------------------------------------------
    # SETTINGS
    #---------------------------------------------------------------------------
    options << EnumOption.new(
      _INTL("Gift Notifications"),
      [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:gift_notifications, 1) },
      proc { |value| KIFRSettings.set(:gift_notifications, value) },
      _INTL("Show notification when new rewards are available")
    )
    
    return options
  end
  
  def pbOpenGiftInbox
    if defined?(Gifts::Inbox)
      # Mark all gifts as seen when viewing inbox
      Gifts::Inbox.mark_all_seen
      pbFadeOutIn {
        KIFR_GiftInboxScene.show
      }
    else
      Kernel.pbMessage(_INTL("Gift Inbox not available."))
    end
  end
  
  def pbViewMilestoneRewards
    if defined?(Gifts::Rewards)
      pbFadeOutIn {
        KIFR_MilestoneRewardsScene.show
      }
    else
      Kernel.pbMessage(_INTL("Reward system not available."))
    end
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create title (invisible initially)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Gift System Settings"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    
    # Create double row description box (96px)
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
    
    # Apply color theme
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
          
          current = @sprites["option"].index
          option = @PokemonOptions[current]
          
          if option.is_a?(ButtonOption) && option.respond_to?(:callback) && option.callback
            option.callback.call
          end
        end
        
        # Update description based on current selection
        current = @sprites["option"].index
        if current >= 0 && current < @PokemonOptions.length
          desc = @PokemonOptions[current].description rescue ""
          @sprites["textbox"].text = desc if @sprites["textbox"]
        elsif current == @PokemonOptions.length
          @sprites["textbox"].text = _INTL("Return to Economy settings.") if @sprites["textbox"]
        end
      end
    }
  end
end

#===============================================================================
# GIFT INBOX SCENE - View and claim pending gifts
#===============================================================================
class KIFR_GiftInboxScene
  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @gifts = []
  end
  
  def pbStartScene
    refresh_gifts
    
    # Title bar
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Gift Inbox ({1})", @gifts.length), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    # Instructions at bottom
    @sprites["textbox"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    update_instructions
    
    # Build content
    @lines = build_content
    
    # Scrollable content area
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["textbox"].height
    
    @sprites["content"] = Window_KIFRScrollable.newWithSize(
      @lines, 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["content"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["content"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["content"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["content"].index = 0
    
    pbFadeInAndShow(@sprites)
  end
  
  def refresh_gifts
    @gifts = Gifts::Inbox.unclaimed rescue []
  end
  
  def update_instructions
    if @gifts.empty?
      @sprites["textbox"].text = _INTL("B: Back")
    else
      @sprites["textbox"].text = _INTL("C: Claim | A: Claim All | B: Back")
    end
  end
  
  def build_content
    lines = []
    @line_to_gift = {}  # Map line index to gift index
    
    if @gifts.empty?
      lines << "[CTR]Your inbox is empty!"
      lines << ""
      lines << "[CTR]Gifts from events and"
      lines << "[CTR]other sources appear here."
    else
      @gifts.each_with_index do |gift, i|
        # Format date: convert YYYY-MM-DD to MM-DD-YY
        date_str = gift[:date] || ""
        if date_str =~ /^(\d{4})-(\d{2})-(\d{2})$/
          date_str = "#{$2}-#{$3}-#{$1[2..3]}"
        end
        
        # Get gift name - strip any "Milestone: " or similar prefix from old gifts
        name_str = gift[:reason] || "Gift"
        
        # Gift type is the SOURCE (Milestone, Event, etc.) - NOT the reward type (item, items, pokemon)
        # For old gifts, infer from reason prefix, otherwise default to "Gift"
        if gift[:source]
          gift_type = gift[:source].to_s.capitalize
        elsif name_str =~ /^Milestone:/i
          gift_type = "Milestone"
        elsif name_str =~ /^Event:/i
          gift_type = "Event"
        elsif name_str =~ /^Mystery:/i
          gift_type = "Mystery"
        else
          gift_type = "Gift"
        end
        
        # Strip the prefix from the name for display
        name_str = name_str.sub(/^Milestone:\s*/i, "")
        name_str = name_str.sub(/^Event:\s*/i, "")
        name_str = name_str.sub(/^Mystery:\s*/i, "")
        
        # Get reward description
        reward_str = Gifts::Inbox.gift_description(gift)
        
        # Row 1: Name (red), centered
        # Format: [GHD]name
        lines << "[GHD]#{name_str}"
        @line_to_gift[lines.length - 1] = i
        
        # Row 2: Gift Type (left) - Date (center) - Rewards (right)
        # Format: [GR3]type|date|rewards
        lines << "[GR3]#{gift_type}|[#{date_str}]|#{reward_str}"
        @line_to_gift[lines.length - 1] = i
      end
    end
    
    lines
  end
  
  def refresh_display
    refresh_gifts
    @sprites["title"].text = _INTL("Gift Inbox ({1})", @gifts.length)
    update_instructions
    @lines = build_content
    @sprites["content"].commands = @lines
    @sprites["content"].index = 0 if @sprites["content"].index >= @lines.length
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
      
      if Input.trigger?(Input::BACK)
        break
      elsif Input.trigger?(Input::USE) && !@gifts.empty?
        # Claim selected gift (based on cursor position)
        gift_index = get_gift_index_from_cursor
        if gift_index && gift_index < @gifts.length
          gift = @gifts[gift_index]
          
          # For bundles, show details first
          if gift[:type] == :bundle
            show_bundle_details(gift)
          else
            if Gifts::Inbox.claim(gift[:id])
              pbPlayDecisionSE
              refresh_display
            end
          end
        end
      elsif Input.trigger?(Input::ACTION) && !@gifts.empty?
        # Claim all gifts
        if pbConfirmMessage(_INTL("Claim all {1} gift(s)?", @gifts.length))
          claimed = Gifts::Inbox.claim_all
          pbPlayDecisionSE
          Kernel.pbMessage(_INTL("Claimed {1} gift(s)!", claimed))
          refresh_display
        end
      end
    end
  end
  
  def get_gift_index_from_cursor
    # Use the line_to_gift mapping we built
    cursor_pos = @sprites["content"].index
    @line_to_gift[cursor_pos]
  end
  
  def show_bundle_details(gift)
    # Get detailed list of bundle contents
    details = Gifts::Inbox.bundle_details(gift)
    
    if details.empty?
      Kernel.pbMessage(_INTL("This bundle appears to be empty."))
      return
    end
    
    # Combine rewards into comma-separated lists, split into multiple messages if too long
    # Max ~55 chars per line to fit nicely in dialog box
    max_line_length = 55
    
    lines = []
    current_line = ""
    
    details.each_with_index do |item, i|
      separator = (i == 0) ? "" : ", "
      test_line = current_line + separator + item
      
      if test_line.length > max_line_length && !current_line.empty?
        lines << current_line
        current_line = item
      else
        current_line = test_line
      end
    end
    lines << current_line unless current_line.empty?
    
    # Show in 1-2 dialog boxes
    if lines.length <= 2
      msg = "This bundle contains: " + lines.join(", ")
      Kernel.pbMessage(_INTL("{1}", msg))
    else
      # First half
      half = (lines.length / 2.0).ceil
      msg1 = "This bundle contains: " + lines[0...half].join(", ")
      Kernel.pbMessage(_INTL("{1}", msg1))
      # Second half
      msg2 = lines[half..-1].join(", ")
      Kernel.pbMessage(_INTL("{1}", msg2))
    end
    
    # Ask if they want to claim
    if pbConfirmMessage(_INTL("Claim this reward bundle?"))
      if Gifts::Inbox.claim(gift[:id])
        pbPlayDecisionSE
        refresh_display
      end
    end
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  def self.show
    scene = KIFR_GiftInboxScene.new
    scene.pbStartScene
    scene.pbScene
    scene.pbEndScene
  end
end

#===============================================================================
# MILESTONE REWARDS SCENE - View all milestones and progress
#===============================================================================
class KIFR_MilestoneRewardsScene
  # Category definitions with display names
  CATEGORIES = {
    badge: { name: "Badge Milestones", filter: ->(m) { m[:key].to_s.start_with?("badge_") } },
    pokedex: { name: "Pokedex Milestones", filter: ->(m) { m[:key].to_s.start_with?("pokedex_") || m[:key] == :first_catch } },
    fusion: { name: "Fusion Milestones", filter: ->(m) { m[:key].to_s.start_with?("fusion") || m[:key] == :first_fusion } },
    shiny: { name: "Shiny Milestones", filter: ->(m) { m[:key].to_s.start_with?("shin") || m[:key] == :first_shiny } },
    battle: { name: "Battle Milestones", filter: ->(m) { m[:key].to_s.start_with?("battle") || m[:key] == :first_battle } },
    money: { name: "Economy Milestones", filter: ->(m) { 
      key = m[:key].to_s
      key.start_with?("money_") || key.start_with?("items_bought_") || key.start_with?("items_sold_")
    }}
  }
  
  # Get ordered categories from Gifts::CATEGORY_ORDER
  def self.ordered_categories
    order = Gifts::CATEGORY_ORDER rescue [:badge, :pokedex, :fusion, :shiny, :battle, :money]
    # Filter to only valid categories and add any missing ones at the end
    valid = order.select { |k| CATEGORIES.key?(k) }
    missing = CATEGORIES.keys - valid
    valid + missing
  end
  
  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @expanded_categories = {}  # Track which categories are expanded
    @search_text = ""
    @line_to_milestone = {}    # Maps line index to milestone data
    @line_to_category = {}     # Maps line index to category key
    
    # Start with all categories COLLAPSED by default
    CATEGORIES.keys.each { |cat| @expanded_categories[cat] = false }
  end
  
  def pbStartScene
    refresh_data
    
    # Title bar
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Milestones ({1}/{2})", @claimed, @total), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    # Instructions/Description box at bottom (shows controls OR description when on milestone)
    @sprites["textbox"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    update_textbox
    
    # Build content
    @lines = build_content
    
    # Scrollable content area
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["textbox"].height
    
    @sprites["content"] = Window_KIFRScrollable.newWithSize(
      @lines, 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["content"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["content"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["content"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["content"].index = 0
    
    pbFadeInAndShow(@sprites)
  end
  
  def update_textbox
    idx = @sprites["content"] ? @sprites["content"].index : 0
    
    # Check if cursor is on a milestone line - show description
    if @line_to_milestone[idx]
      milestone = @line_to_milestone[idx]
      @sprites["textbox"].text = milestone[:description] || "No description available."
    else
      # Show controls
      if @search_text != ""
        @sprites["textbox"].text = _INTL("Searching: {1} | X: Clear | B: Back", @search_text)
      elsif @unlocked > 0
        @sprites["textbox"].text = _INTL("C: Claim | A: Claim All | R: Search | B: Back")
      else
        @sprites["textbox"].text = _INTL("R: Search | B: Back")
      end
    end
  end
  
  def refresh_data
    @milestones = Gifts::Rewards.all_milestones rescue []
    @total = @milestones.length
    @claimed = @milestones.count { |m| m[:claimed] }
    @unlocked = @milestones.count { |m| m[:unlocked] && !m[:claimed] }
  end
  
  def refresh_display
    refresh_data
    @sprites["title"].text = _INTL("Milestones ({1}/{2})", @claimed, @total)
    @lines = build_content
    @sprites["content"].commands = @lines
    @sprites["content"].index = [@sprites["content"].index, @lines.length - 1].min
    update_textbox
  end
  
  def build_content
    lines = []
    @line_to_milestone = {}
    @line_to_category = {}
    
    # Filter milestones if searching
    filtered_milestones = @milestones
    if @search_text != ""
      search_lower = @search_text.downcase
      filtered_milestones = @milestones.select do |m|
        m[:name].downcase.include?(search_lower) ||
        (m[:description] || "").downcase.include?(search_lower)
      end
    end
    
    # Summary section (only if not searching)
    if @search_text == ""
      lines << "[CAT]Progress"
      lines << "[VAL]Claimed:|#{@claimed}/#{@total}"
      lines << "[VAL]Ready to Claim:|#{@unlocked}"
      lines << "[VAL]Locked:|#{@total - @claimed - @unlocked}"
      
      # Categories (all collapsed by default, can toggle with C) - use configured order
      self.class.ordered_categories.each do |cat_key|
        cat_data = CATEGORIES[cat_key]
        next unless cat_data
        cat_milestones = filtered_milestones.select { |m| cat_data[:filter].call(m) }
        next if cat_milestones.empty?
        
        # Category header
        claimed_count = cat_milestones.count { |m| m[:claimed] }
        unclaimed_ready = cat_milestones.count { |m| m[:unlocked] && !m[:claimed] }
        
        @line_to_category[lines.length] = cat_key
        
        # Add ! on both sides if there are unclaimed ready rewards
        if unclaimed_ready > 0
          lines << "[CAT]! #{cat_data[:name]} (#{claimed_count}/#{cat_milestones.length}) !"
        else
          lines << "[CAT]#{cat_data[:name]} (#{claimed_count}/#{cat_milestones.length})"
        end
        
        # Show milestones if expanded
        if @expanded_categories[cat_key]
          cat_milestones.each do |m|
            @line_to_milestone[lines.length] = m
            lines << format_milestone(m)
          end
        end
      end
    else
      # Search results
      lines << "[CAT]Search Results (#{filtered_milestones.length})"
      lines << ""
      
      if filtered_milestones.empty?
        lines << "[CTR]No milestones match your search."
      else
        filtered_milestones.each do |m|
          @line_to_milestone[lines.length] = m
          lines << format_milestone(m)
        end
      end
    end
    
    lines
  end
  
  def format_milestone(milestone)
    status = if milestone[:claimed]
      "[CLAIMED]"
    elsif milestone[:unlocked]
      "[READY!]"
    else
      "[LOCKED]"
    end
    
    "[VAL]  #{milestone[:name]}|#{status}"
  end
  
  def pbScene
    last_index = -1
    
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
      
      # Update textbox when cursor moves (shows description or controls)
      if @sprites["content"].index != last_index
        last_index = @sprites["content"].index
        update_textbox
      end
      
      if Input.trigger?(Input::BACK)
        if @search_text != ""
          # Clear search first
          @search_text = ""
          refresh_display
        else
          break
        end
      elsif Input.trigger?(Input::USE)
        handle_use_button
      elsif Input.trigger?(Input::ACTION) && @unlocked > 0 && @search_text == ""
        # Send all ready milestones to inbox
        if pbConfirmMessage(_INTL("Send all {1} ready reward(s) to Gift Inbox?", @unlocked))
          count = 0
          @milestones.each do |m|
            if m[:unlocked] && !m[:claimed]
              send_to_inbox(m)
              count += 1
            end
          end
          pbPlayDecisionSE
          Kernel.pbMessage(_INTL("Sent {1} reward(s) to your Gift Inbox!", count))
          refresh_display
        end
      elsif Input.trigger?(Input::AUX2)  # R button for search
        open_search
      elsif Input.trigger?(Input::SPECIAL)  # X button to clear search
        if @search_text != ""
          @search_text = ""
          refresh_display
        end
      end
    end
  end
  
  def handle_use_button
    idx = @sprites["content"].index
    
    # Check if on a category header - toggle expand/collapse
    if @line_to_category[idx]
      cat_key = @line_to_category[idx]
      @expanded_categories[cat_key] = !@expanded_categories[cat_key]
      pbPlayDecisionSE
      refresh_display
      return
    end
    
    # Check if on a milestone - try to claim it
    if @line_to_milestone[idx]
      milestone = @line_to_milestone[idx]
      if milestone[:unlocked] && !milestone[:claimed]
        send_to_inbox(milestone)
        pbPlayDecisionSE
        Kernel.pbMessage(_INTL("Sent {1} reward to your Gift Inbox!", milestone[:name]))
        refresh_display
      elsif milestone[:claimed]
        Kernel.pbMessage(_INTL("This reward has already been claimed."))
      else
        Kernel.pbMessage(_INTL("This reward is still locked.\n{1}", milestone[:description] || ""))
      end
    end
  end
  
  def open_search
    @search_text = pbEnterText(_INTL("Search milestones..."), 0, 20, @search_text)
    @search_text ||= ""
    refresh_display
  end
  
  def send_to_inbox(milestone)
    Gifts::Rewards.send_to_inbox(milestone[:key])
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  def self.show
    scene = KIFR_MilestoneRewardsScene.new
    scene.pbStartScene
    scene.pbScene
    scene.pbEndScene
  end
end

#===============================================================================
# ECONOMY STATISTICS SCENE - Scrollable view with category headers
#===============================================================================
class KIFR_EconomyStatisticsScene
  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
  end
  
  def pbStartScene
    # Title
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Economy Statistics"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    # Instructions at bottom
    @sprites["textbox"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].text = _INTL("A: Export | Z: Reset | B: Back")
    
    # Content area
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["textbox"].height
    
    @content_lines = build_statistics_content
    
    @sprites["content"] = Window_KIFRScrollable.newWithSize(
      @content_lines, 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["content"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["content"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["content"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["content"].index = 0
    
    pbFadeInAndShow(@sprites)
  end
  
  def build_statistics_content
    lines = []
    stats = ShopData::Statistics.summary rescue nil
    
    # Money section
    lines << "[CAT]Money"
    if stats
      lines << "[VAL]Total Spent:|${#{format_money(stats[:total_spent])}}"
      lines << "[VAL]Total Earned:|${#{format_money(stats[:total_earned])}}"
      lines << "[VAL]Money from Battles:|${#{format_money(stats[:money_from_battles])}}"
      lines << "[VAL]Saved from Discounts:|${#{format_money(stats[:saved_from_discounts])}}"
      lines << "[VAL]Lost to Markups:|${#{format_money(stats[:markup_losses])}}"
      lines << "[VAL]Money from Gifts:|${#{format_money(stats[:money_from_gifts])}}"
    else
      lines << "No money data available yet."
    end
    
    # Items section
    lines << "[CAT]Items"
    if stats
      lines << "[VAL]Items Bought:|#{stats[:items_bought] || 0}"
      lines << "[VAL]Items Sold:|#{stats[:items_sold] || 0}"
      lines << "[VAL]Unique Bought:|#{stats[:unique_bought] || 0}"
      lines << "[VAL]Unique Sold:|#{stats[:unique_sold] || 0}"
      lines << "[VAL]Free Items:|#{stats[:free_items] || 0}"
      lines << "[VAL]Items from Gifts:|#{stats[:items_from_gifts] || 0}"
    else
      lines << "No item data available yet."
    end
    
    # Activity section
    lines << "[CAT]Activity"
    if stats
      lines << "[VAL]Total Transactions:|#{stats[:transactions] || 0}"
      lines << "[VAL]Shops Visited:|#{stats[:shops_visited] || 0}"
      lines << "[VAL]Kuray Shop Visits:|#{stats[:kuray_visits] || 0}"
      lines << "[VAL]Regular Shop Visits:|#{stats[:regular_visits] || 0}"
    else
      lines << "No activity data available yet."
    end
    
    # Kuray Shop section
    lines << "[CAT]Kuray Shop"
    if defined?(KurayShop::Statistics)
      kuray_stats = KurayShop::Statistics.summary rescue nil
      if kuray_stats
        lines << "[VAL]Eggs Purchased:|#{kuray_stats[:eggs_bought] || 0}"
        lines << "[VAL]Unique Items Bought:|#{kuray_stats[:unique_items_bought] || 0}"
        lines << "[VAL]Unique Items Sold:|#{kuray_stats[:unique_items_sold] || 0}"
        lines << "[VAL]Total Spent:|${#{format_money(kuray_stats[:total_spent])}}"
      else
        lines << "No Kuray Shop data available yet."
      end
    else
      lines << "Kuray Shop statistics not available."
    end
    
    lines
  end
  
  def format_money(amount)
    return "0" unless amount
    amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
      
      # A button = Export
      if Input.trigger?(Input::ACTION)
        pbExportStats
        
      # Z button = Reset
      elsif Input.trigger?(Input::SPECIAL)
        pbResetStats
        
      # Exit
      elsif Input.trigger?(Input::BACK)
        break
      end
    end
  end
  
  def pbExportStats
    if Kernel.pbConfirmMessage(_INTL("Export economy statistics to file?"))
      begin
        # Use KIFR folder in base directory
        kifr_folder = KIFRSettings.kifr_folder rescue nil
        if kifr_folder
          filename = File.join(kifr_folder, "Economy_Stats_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt")
        else
          filename = "Economy_Stats_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt"
        end
        stats = ShopData::Statistics.summary rescue {}
        
        File.open(filename, "w") do |f|
          f.puts "=== Economy Statistics Export ==="
          f.puts "Date: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
          f.puts ""
          f.puts "Total Spent: $#{stats[:total_spent] || 0}"
          f.puts "Total Earned: $#{stats[:total_earned] || 0}"
          f.puts "Net Balance: $#{stats[:net] || 0}"
          f.puts ""
          f.puts "Items Bought: #{stats[:items_bought] || 0}"
          f.puts "Items Sold: #{stats[:items_sold] || 0}"
          f.puts "Transactions: #{stats[:transactions] || 0}"
          f.puts ""
          f.puts "Regular Mart Visits: #{stats[:regular_visits] || 0}"
          f.puts "Kuray Shop Visits: #{stats[:kuray_visits] || 0}"
        end
        
        Kernel.pbMessage(_INTL("Statistics exported to {1}", filename))
      rescue => e
        Kernel.pbMessage(_INTL("Export failed: {1}", e.message))
      end
    end
  end
  
  def pbResetStats
    if Kernel.pbConfirmMessage(_INTL("Reset ALL economy statistics? This cannot be undone!"))
      if Kernel.pbConfirmMessage(_INTL("Are you absolutely sure?"))
        ShopData::Statistics.reset if defined?(ShopData::Statistics) && ShopData::Statistics.respond_to?(:reset)
        ShopData::History.clear if defined?(ShopData::History) && ShopData::History.respond_to?(:clear)
        KurayShop::Statistics.reset if defined?(KurayShop::Statistics) && KurayShop::Statistics.respond_to?(:reset)
        Gifts::Statistics.reset if defined?(Gifts::Statistics) && Gifts::Statistics.respond_to?(:reset)
        
        Kernel.pbMessage(_INTL("All economy statistics have been reset."))
        
        # Refresh content display
        @content_lines = build_statistics_content
        @sprites["content"].commands = @content_lines
        @sprites["content"].index = 0
        @sprites["content"].refresh
      end
    end
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  # Class method to easily show the scene
  def self.show
    pbFadeOutIn {
      scene = KIFR_EconomyStatisticsScene.new
      scene.pbStartScene
      scene.pbScene
      scene.pbEndScene
    }
  end
end

#===============================================================================
# MODULE INITIALIZATION
#===============================================================================
KIFRSettings.debug_log("EconomySettings: Scene classes loaded") if defined?(KIFRSettings)
