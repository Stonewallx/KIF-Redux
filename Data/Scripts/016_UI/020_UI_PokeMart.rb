#===============================================================================
# Abstraction layer for Pokemon Essentials
#===============================================================================
class PokemonMartAdapter
  def getMoney
    return $Trainer.money
  end

  def getMoneyString
    return pbGetGoldString
  end

  def setMoney(value)
    $Trainer.money=value
  end

  def getInventory
    return $PokemonBag
  end

  def getName(item)
    return GameData::Item.get(item).name
  end

  def getDisplayName(item)
    item_name = getName(item)
    if GameData::Item.get(item).is_machine?
      machine = GameData::Item.get(item).move
      item_name = _INTL("{1} {2}", item_name, GameData::Move.get(machine).name)
    end
    return item_name
  end

  def getDescription(item)
    return GameData::Item.get(item).description
  end

  def getItemIcon(item)
    return (item) ? GameData::Item.icon_filename(item) : nil
  end

  # Unused
  def getItemIconRect(_item)
    return Rect.new(0, 0, 48, 48)
  end

  def getQuantity(item)
    return $PokemonBag.pbQuantity(item)
  end

  def showQuantity?(item)
    return !GameData::Item.get(item).is_important?
  end

  def getPrice(item, selling = false)
    if $game_temp.mart_prices && $game_temp.mart_prices[item]
      if selling
        return $game_temp.mart_prices[item][1] if $game_temp.mart_prices[item][1] >= 0
      elsif $game_temp.mart_prices[item][0] == -1
        return 0
      else
        return $game_temp.mart_prices[item][0] if $game_temp.mart_prices[item][0] > 0
      end
    end
    return GameData::Item.get(item).price
  end

  def getDisplayPrice(item, selling = false)
    price = getPrice(item, selling).to_s_formatted
    return _INTL("$ {1}", price)
  end

  def canSell?(item)
    return getPrice(item, true) > 0 && !GameData::Item.get(item).is_important?
  end

  def addItem(item)
    return $PokemonBag.pbStoreItem(item)
  end

  def removeItem(item)
    return $PokemonBag.pbDeleteItem(item)
  end

  def getBaseColorOverride(item)
    return nil
  end

  def getShadowColorOverride(item)
    return nil
  end

  #specialType is a symbol
  def getSpecialItemCaption(specialType)
    return nil
  end

  def getSpecialItemDescription(specialType)
    return nil
  end

  def doSpecialItemAction(specialType)
    return nil
  end

  def getSpecialItemBaseColor(specialType)
    return nil
  end

  def getSpecialItemShadowColor(specialType)
    return nil
  end
  
  #-----------------------------------------------------------------------------
  # Enhanced Mart: Get item's pocket/category
  #-----------------------------------------------------------------------------
  def getItemPocket(item)
    return GameData::Item.get(item).pocket rescue 1
  end

end

#===============================================================================
# Enhanced Mart Category System
#===============================================================================
module EnhancedMart
  # Category definitions - order determines page order
  # Pocket IDs match Settings.bag_pocket_names (left to right in bag):
  # 1=Items, 2=Medicine, 3=Poké Balls, 4=TMs&HMs, 5=Berries, 6=Mail, 7=Battle Items, 8=Key Items
  CATEGORIES = {
    1 => { name: "Items",        priority: 1 },   # General items
    2 => { name: "Medicine",     priority: 2 },   # Healing items
    3 => { name: "Poké Balls",   priority: 3 },   # Balls
    4 => { name: "TMs & HMs",    priority: 4 },   # Machines
    5 => { name: "Berries",      priority: 5 },   # Berries
    6 => { name: "Mail",         priority: 6 },   # Mail
    7 => { name: "Battle Items", priority: 7 },   # X items, etc.
    8 => { name: "Key Items",    priority: 8 },   # Key items (rare in shops)
  }
  
  # Money animation settings
  MONEY_ANIM_DURATION = 0.5   # seconds
  MONEY_ANIM_STEPS = 20       # number of ticks during animation
  
  #-----------------------------------------------------------------------------
  # Organize stock into categories
  #-----------------------------------------------------------------------------
  def self.categorize_stock(stock, adapter)
    categorized = {}
    
    stock.each do |item|
      next if item.nil?
      pocket = adapter.getItemPocket(item)
      categorized[pocket] ||= []
      categorized[pocket] << item
    end
    
    # Sort categories by priority and filter empty ones
    sorted_categories = CATEGORIES.keys
      .select { |pocket| categorized[pocket] && !categorized[pocket].empty? }
      .sort_by { |pocket| CATEGORIES[pocket][:priority] }
    
    return categorized, sorted_categories
  end
  
  #-----------------------------------------------------------------------------
  # Get category name
  #-----------------------------------------------------------------------------
  def self.category_name(pocket)
    return CATEGORIES[pocket][:name] rescue "Items"
  end
end

#===============================================================================
# Buy and Sell adapters
#===============================================================================
class BuyAdapter
  def initialize(adapter)
    @adapter = adapter
  end

  def getDisplayName(item)
    @adapter.getDisplayName(item)
  end

  def getDisplayPrice(item)
    @adapter.getDisplayPrice(item, false)
  end

  def getQuantity(item)
    @adapter.getQuantity(item)
  end

  def getBaseColorOverride(item)
    return @adapter.getBaseColorOverride(item)
  end

  def getShadowColorOverride(item)
    return @adapter.getShadowColorOverride(item)
  end

  def isSelling?
    return false
  end

  def getSpecialItemCaption(specialType)
    return @adapter.getSpecialItemCaption(specialType)
  end

  def getSpecialItemBaseColor(specialType)
    return @adapter.getSpecialItemBaseColor(specialType)
  end

  def getSpecialItemShadowColor(specialType)
    return @adapter.getSpecialItemShadowColor(specialType)
  end

  def getAdapter()
    return @adapter
  end
end

#===============================================================================
#
#===============================================================================
class SellAdapter
  def initialize(adapter)
    @adapter = adapter
  end

  def getDisplayName(item)
    @adapter.getDisplayName(item)
  end

  def getDisplayPrice(item)
    if @adapter.showQuantity?(item)
      return sprintf("x%d", @adapter.getQuantity(item))
    else
      return ""
    end
  end

  def getBaseColorOverride(item)
    return @adapter.getBaseColorOverride(item)
  end

  def getShadowColorOverride(item)
    return @adapter.getShadowColorOverride(item)
  end

  def isSelling?
    return true
  end
end

#===============================================================================
# Enhanced Pokémon Mart Window - No CANCEL, supports category pages
#===============================================================================
class Window_PokemonMart < Window_DrawableCommand
  attr_accessor :category_name
  attr_accessor :current_page
  attr_accessor :total_pages
  attr_accessor :item_name_offset  # X offset for item names (independent of prices)
  attr_accessor :price_offset      # X offset for prices (independent of names)
  attr_accessor :is_kuray_shop     # Whether this is Kuray Shop (affects cursor size)
  attr_accessor :is_specials_page  # Whether currently showing Specials page
  
  # Custom cursor colors - now loaded from KIFR settings
  CURSOR_RADIUS = 4                                  # Corner radius
  
  # Get cursor fill color from KIFR settings
  def cursor_color
    return Color.new(100, 180, 220, 180) unless defined?(SHOP_CURSOR_COLORS)  # Default blue
    index = ($PokemonSystem.kifr_shop_cursor_color rescue 0) || 0
    index = 0 if index < 0 || index >= SHOP_CURSOR_COLORS.length
    SHOP_CURSOR_COLORS[index][:fill]
  end
  
  # Get cursor border color from KIFR settings
  def cursor_border
    return Color.new(60, 140, 200, 220) unless defined?(SHOP_CURSOR_COLORS)  # Default blue border
    index = ($PokemonSystem.kifr_shop_cursor_color rescue 0) || 0
    index = 0 if index < 0 || index >= SHOP_CURSOR_COLORS.length
    SHOP_CURSOR_COLORS[index][:border]
  end
  
  def initialize(stock, adapter, x, y, width, height, viewport = nil)
    @stock       = stock
    @adapter     = adapter
    @category_name = nil
    @current_page = 1
    @total_pages = 1
    @item_name_offset = 0  # Default: no offset
    @price_offset = 0      # Default: no offset
    @is_kuray_shop = false # Default: regular shop
    super(x, y, width, height, viewport)
    # Keep @selarrow from parent (for proper disposal) - our drawCursor overrides the drawing
    @baseColor   = Color.new(88,88,80)
    @shadowColor = Color.new(168,184,184)
    self.windowskin = nil
    self.contents.clear if self.contents
  end
  
  # Hide the default window cursor rect
  def update_cursor_rect
    if @index < 0
      self.cursor_rect.empty
      return
    end
    # Calculate scroll position (from parent's priv_update_cursor_rect)
    row = @index / @column_max
    new_top_row = row - ((self.page_row_max - 1) / 2).floor
    new_top_row = [[new_top_row, self.row_max - self.page_row_max].min, 0].max
    self.top_row = new_top_row if self.top_row != new_top_row
    # Hide the cursor rect
    self.cursor_rect.empty
  end
  
  # Draw a rounded rectangle
  def draw_rounded_rect(bitmap, x, y, width, height, radius, fill_color, border_color = nil)
    # Clamp radius to half the smallest dimension
    radius = [radius, width / 2, height / 2].min
    
    # Draw filled rounded rectangle using a single approach to avoid line artifacts
    # Fill the entire center area first
    bitmap.fill_rect(x + radius, y + radius, width - radius * 2, height - radius * 2, fill_color)
    # Fill the edge strips (excluding corners)
    bitmap.fill_rect(x + radius, y, width - radius * 2, radius, fill_color)  # Top strip
    bitmap.fill_rect(x + radius, y + height - radius, width - radius * 2, radius, fill_color)  # Bottom strip
    bitmap.fill_rect(x, y + radius, radius, height - radius * 2, fill_color)  # Left strip
    bitmap.fill_rect(x + width - radius, y + radius, radius, height - radius * 2, fill_color)  # Right strip
    
    # Draw rounded corners using circle quadrants
    draw_corner(bitmap, x + radius, y + radius, radius, fill_color, :top_left)
    draw_corner(bitmap, x + width - radius - 1, y + radius, radius, fill_color, :top_right)
    draw_corner(bitmap, x + radius, y + height - radius - 1, radius, fill_color, :bottom_left)
    draw_corner(bitmap, x + width - radius - 1, y + height - radius - 1, radius, fill_color, :bottom_right)
    
    # Draw border if specified
    if border_color
      # Top and bottom edges
      bitmap.fill_rect(x + radius, y, width - radius * 2, 2, border_color)
      bitmap.fill_rect(x + radius, y + height - 2, width - radius * 2, 2, border_color)
      # Left and right edges
      bitmap.fill_rect(x, y + radius, 2, height - radius * 2, border_color)
      bitmap.fill_rect(x + width - 2, y + radius, 2, height - radius * 2, border_color)
    end
  end
  
  # Draw a corner quadrant of a circle
  def draw_corner(bitmap, cx, cy, radius, color, corner)
    (0..radius).each do |dx|
      (0..radius).each do |dy|
        # Check if point is within circle
        if dx * dx + dy * dy <= radius * radius
          case corner
          when :top_left
            bitmap.fill_rect(cx - dx, cy - dy, 1, 1, color)
          when :top_right
            bitmap.fill_rect(cx + dx, cy - dy, 1, 1, color)
          when :bottom_left
            bitmap.fill_rect(cx - dx, cy + dy, 1, 1, color)
          when :bottom_right
            bitmap.fill_rect(cx + dx, cy + dy, 1, 1, color)
          end
        end
      end
    end
  end
  
  # Override drawCursor to draw our custom rounded rectangle cursor
  def drawCursor(index, rect)
    if self.index == index
      # Draw custom rounded cursor around the entire row
      padding = 2
      # For regular shop, make cursor 21px shorter on left side (15 + 6)
      left_inset = @is_kuray_shop ? 0 : 21
      cursor_x = rect.x - padding + left_inset
      cursor_y = rect.y + padding
      cursor_width = rect.width + padding * 2 - 4 - left_inset
      cursor_height = rect.height - padding * 2  # 2px bigger than before
      
      draw_rounded_rect(
        self.contents,
        cursor_x, cursor_y,
        cursor_width, cursor_height,
        CURSOR_RADIUS,
        cursor_color,  # Use method to get color from KIFR settings
        nil  # No border - prevents line artifacts
      )
    end
    # Offset the rect by 16 to account for where the arrow used to be
    # This keeps item text aligned with the category header
    rect.x += 16
    rect.width -= 16
    return rect
  end
  
  # Use parent's update for scrolling - LEFT/RIGHT are handled in pbChooseBuyItem before this
  
  def stock=(value)
    @stock = value
    refresh
  end

  def itemCount
    return @stock.length  # No CANCEL button
  end

  def item
    return (self.index >= @stock.length) ? nil : @stock[self.index]
  end

  def drawItem(index, count, rect)
    textpos = []
    rect = drawCursor(index, rect)
    ypos = rect.y
    
    # No CANCEL - all items are actual stock
    if index < @stock.length
      item = @stock[index]
      if item.is_a?(Symbol) && @adapter.respond_to?(:getAdapter) && @adapter.getAdapter().is_a?(OutfitsMartAdapter)
        itemname = @adapter.getSpecialItemCaption(item)
        baseColor = @adapter.getSpecialItemBaseColor(item) ? @adapter.getSpecialItemBaseColor(item) : self.baseColor
        shadowColor = @adapter.getSpecialItemShadowColor(item) ? @adapter.getSpecialItemShadowColor(item) : self.shadowColor
        textpos.push([itemname, rect.x + @item_name_offset, ypos - 4, false, baseColor, shadowColor])
      else
        itemname = @adapter.getDisplayName(item)

        baseColorOverride = @adapter.getBaseColorOverride(item)
        shadowColorOverride = @adapter.getShadowColorOverride(item)

        baseColor = baseColorOverride ? baseColorOverride : self.baseColor
        shadowColor = shadowColorOverride ? shadowColorOverride : self.shadowColor

        qty = @adapter.getDisplayPrice(item)
        sizeQty = self.contents.text_size(qty).width
        xQty = rect.x + rect.width - sizeQty - 2 - 16 + @price_offset  # Prices use offset
        textpos.push([itemname, rect.x + @item_name_offset, ypos - 4, false, baseColor, shadowColor])  # Names use offset
        textpos.push([qty, xQty, ypos - 4, false, baseColor, shadowColor])
      end
    end
    pbDrawTextPositions(self.contents, textpos)
  end
end

#===============================================================================
# Animated Money Window
#===============================================================================
class Window_AnimatedMoney < Window_AdvancedTextPokemon
  attr_accessor :target_money
  attr_accessor :display_money
  attr_accessor :currency_name
  
  def initialize(initial_money, currency_name = "Money")
    super("")
    @display_money = initial_money
    @target_money = initial_money
    @currency_name = currency_name
    @anim_start_time = nil
    @anim_start_money = initial_money
    @anim_duration = EnhancedMart::MONEY_ANIM_DURATION
    # Store text colors for animation updates
    @stored_base_color = nil
    @stored_shadow_color = nil
    update_text
  end
  
  # Override to store colors when set
  def baseColor=(value)
    @stored_base_color = value
    super(value)
  end
  
  def shadowColor=(value)
    @stored_shadow_color = value
    super(value)
  end
  
  def set_target(new_money)
    return if new_money == @target_money
    @anim_start_time = System.uptime
    @anim_start_money = @display_money
    @target_money = new_money
  end
  
  def update
    super
    return if @display_money == @target_money
    return unless @anim_start_time
    
    elapsed = System.uptime - @anim_start_time
    progress = [elapsed / @anim_duration, 1.0].min
    
    # Ease-out animation (starts fast, slows down)
    eased_progress = 1.0 - ((1.0 - progress) ** 2)
    
    diff = @target_money - @anim_start_money
    @display_money = (@anim_start_money + (diff * eased_progress)).round
    
    if progress >= 1.0
      @display_money = @target_money
      @anim_start_time = nil
    end
    
    update_text
  end
  
  def update_text
    # Restore stored colors before setting text (setting text may reset them)
    if @stored_base_color
      self.contents.font.color = @stored_base_color if self.contents
    end
    self.text = _INTL("{1}:\r\n<r>{2}", @currency_name, @display_money.to_s_formatted)
    # Re-apply colors after text update
    if @stored_base_color && @stored_shadow_color
      @baseColor = @stored_base_color
      @shadowColor = @stored_shadow_color
    end
  end
  
  def animating?
    return @display_money != @target_money
  end
end

#===============================================================================
# Enhanced PokemonMart_Scene with category pages and animated money
#===============================================================================
class PokemonMart_Scene
  def initialize(currency_name="Money")
    @currency_name = currency_name
    @current_category_index = 0
    @categorized_stock = {}
    @category_order = []
  end

  def update
    pbUpdateSpriteHash(@sprites)
    @subscene.pbUpdate if @subscene
    # Update animated money
    @sprites["moneywindow"].update if @sprites["moneywindow"].is_a?(Window_AnimatedMoney)
  end

  def pbRefresh
    if @subscene
      @subscene.pbRefresh
    else
      itemwindow = @sprites["itemwindow"]
      @sprites["icon"].item = itemwindow.item
      
      # Update description
      if itemwindow.item
        @sprites["itemtextwindow"].text = @adapter.getDescription(itemwindow.item)
      else
        @sprites["itemtextwindow"].text = _INTL("Press B to exit.")
      end
      
      # Update In Bag display
      if itemwindow.item && @sprites["inbagwindow"]
        # Only show quantity for actual items (symbols), not category headers or special items
        item = itemwindow.item
        if item.is_a?(Symbol)
          # Get quantity from bag - use $PokemonBag directly for reliability
          qty = $PokemonBag.pbQuantity(item) rescue 0
          @sprites["inbagwindow"].text = _INTL("In Bag:<r>{1}  ", qty)
        else
          @sprites["inbagwindow"].text = _INTL("In Bag:<r>-  ")
        end
      elsif @sprites["inbagwindow"]
        @sprites["inbagwindow"].text = _INTL("In Bag:<r>0  ")
      end
      
      # Update page header
      update_page_header
      
      itemwindow.refresh
    end
    
    # Update money display (for non-animated or target sync)
    if @sprites["moneywindow"].is_a?(Window_AnimatedMoney)
      @sprites["moneywindow"].set_target(@adapter.getMoney)
    else
      @sprites["moneywindow"].text = _INTL("{2}:\r\n<r>{1}", @adapter.getMoneyString, @currency_name)
    end
  end
  
  def update_page_header
    return unless @sprites["pageheader"] && @category_order.length > 0
    
    category_pocket = @category_order[@current_category_index]
    category_name = EnhancedMart.category_name(category_pocket)
    page_num = "Page #{@current_category_index + 1}/#{@category_order.length}"
    
    # Clear and redraw
    bitmap = @sprites["pageheader"].bitmap
    bitmap.clear
    
    # Colors matching the item list (Arcky's colors)
    baseColor = Color.new(88, 88, 80)
    shadowColor = Color.new(168, 184, 184)
    
    # Positioning: category at Y=23, page numbers at Y=19 (4px higher), underline at Y=39
    pbDrawTextPositions(bitmap, [
      [category_name, Graphics.width - 300, 23, 0, baseColor, shadowColor],
      [page_num, 490, 19, 1, baseColor, shadowColor],
      ["-----------------------", Graphics.width - 300, 39, 0, baseColor, shadowColor]
    ])
  end

  def scroll_map()
    pbScrollMap(6, 5, 5)
  end

  def scroll_back_map()
    pbScrollMap(4, 5, 5)
  end

  #-----------------------------------------------------------------------------
  # Enhanced: Setup categories from stock
  #-----------------------------------------------------------------------------
  def setup_categories(stock, adapter)
    @categorized_stock, @category_order = EnhancedMart.categorize_stock(stock, adapter)
    @current_category_index = 0
  end
  
  def current_category_stock
    return [] if @category_order.empty?
    pocket = @category_order[@current_category_index]
    return @categorized_stock[pocket] || []
  end
  
  def switch_category(direction)
    return if !@category_order || @category_order.length <= 1
    
    old_index = @current_category_index
    @current_category_index += direction
    @current_category_index = 0 if @current_category_index >= @category_order.length
    @current_category_index = @category_order.length - 1 if @current_category_index < 0
    
    return if old_index == @current_category_index
    
    pbPlayCursorSE
    
    # Update page header
    update_page_header
    
    # Dispose old window and create new one (Arcky's method)
    # Only used for regular shops (Kuray shop doesn't have categories)
    new_stock = current_category_stock
    @sprites["itemwindow"].dispose
    @sprites["itemwindow"] = Window_PokemonMart.new(
      new_stock, @winAdapter, 
      Graphics.width - 316 - 16 - 10, 42, 330 + 16, Graphics.height - 156
    )
    @sprites["itemwindow"].viewport = @viewport
    @sprites["itemwindow"].index = 0
    @sprites["itemwindow"].item_name_offset = -6  # Match regular shop offset (-10 + 4)
    @sprites["itemwindow"].price_offset = 10     # Match regular shop offset
    # Check if this is the Specials page (pocket 99)
    current_pocket = @category_order[@current_category_index]
    @sprites["itemwindow"].is_specials_page = (current_pocket == 99)
    @sprites["itemwindow"].refresh
    
    pbRefresh
  end

  #KurayX Creating kuray shop
  def pbStartBuyOrSellScene(buying, stock, adapter)
    # Scroll right before showing screen
    if !$game_temp.fromkurayshop
      scroll_map()
    end
    
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @stock = stock
    @adapter = adapter
    @sprites = {}
    
    # Background
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    if $game_temp.fromkurayshop
      @sprites["background"].setBitmap("Graphics/Pictures/martScreenKuray")
    else
      @sprites["background"].setBitmap("Graphics/Pictures/martScreen")
    end
    
    # Item icon
    @sprites["icon"] = ItemIconSprite.new(36, Graphics.height - 50, nil, @viewport)
    
    # Setup categories (for buying only, selling uses bag)
    # Skip categories for outfit shops (clothes, hats, hair) - they don't use item categories
    is_outfit_shop = defined?(OutfitsMartAdapter) && adapter.is_a?(OutfitsMartAdapter)
    if buying && !$game_temp.fromkurayshop && !is_outfit_shop
      setup_categories(stock, adapter)
      display_stock = current_category_stock
    else
      @category_order = []
      display_stock = stock
    end
    
    # Calculate item window position
    # Regular shop with categories: yMin=42, yMax=156
    # Regular shop without categories: yMin=10, yMax=128  
    # Kuray shop: uses original Arcky positioning
    if $game_temp.fromkurayshop
      # Kuray Shop - original positioning
      item_window_x = Graphics.width - 316 - 16
      item_window_y = 10
      item_window_width = 330 + 16
      item_window_height = Graphics.height - 128
      item_name_offset = 0
      price_offset = 0
    else
      # Regular shop positioning
      item_window_x = Graphics.width - 316 - 16 - 10
      item_window_y = 10
      item_window_width = 330 + 16
      item_window_height = Graphics.height - 128
      item_name_offset = -10 + 4  # Was -10, now +4 from that = -6 (right 4 pixels from before)
      price_offset = 10           # Move prices right 10 pixels
      if buying && @category_order.length >= 1
        item_window_y = 42
        item_window_height = Graphics.height - 156
      end
    end
    
    # Item window
    @winAdapter = buying ? BuyAdapter.new(adapter) : SellAdapter.new(adapter)
    @sprites["itemwindow"] = Window_PokemonMart.new(display_stock, @winAdapter,
       item_window_x, item_window_y, item_window_width, item_window_height)
    @sprites["itemwindow"].viewport = @viewport
    @sprites["itemwindow"].index = 0
    @sprites["itemwindow"].item_name_offset = item_name_offset
    @sprites["itemwindow"].price_offset = price_offset
    @sprites["itemwindow"].is_kuray_shop = $game_temp.fromkurayshop ? true : false
    # Check if starting on Specials page (pocket 99)
    if buying && @category_order.length >= 1
      current_pocket = @category_order[@current_category_index]
      @sprites["itemwindow"].is_specials_page = (current_pocket == 99)
    else
      @sprites["itemwindow"].is_specials_page = false
    end
    @sprites["itemwindow"].refresh
    
    # Item description window
    @sprites["itemtextwindow"] = Window_UnformattedTextPokemon.newWithSize("",
       64, Graphics.height - 96 - 16, Graphics.width - 64, 128, @viewport)
    pbPrepareWindow(@sprites["itemtextwindow"])
    @sprites["itemtextwindow"].baseColor = Color.new(248, 248, 248)
    @sprites["itemtextwindow"].shadowColor = Color.new(0, 0, 0)
    @sprites["itemtextwindow"].windowskin = nil
    
    # Help window (for messages)
    @sprites["helpwindow"] = Window_AdvancedTextPokemon.new("")
    pbPrepareWindow(@sprites["helpwindow"])
    @sprites["helpwindow"].visible = false
    @sprites["helpwindow"].viewport = @viewport
    pbBottomLeftLines(@sprites["helpwindow"], 1)
    
    # Get text colors based on global frame (dark vs light)
    text_colors = defined?(pbGetGlobalFrameTextColors) ? pbGetGlobalFrameTextColors : [Color.new(88, 88, 80), Color.new(168, 184, 184)]
    
    # Animated Money window
    @sprites["moneywindow"] = Window_AnimatedMoney.new(adapter.getMoney, @currency_name)
    pbPrepareWindow(@sprites["moneywindow"])
    @sprites["moneywindow"].visible = true
    @sprites["moneywindow"].viewport = @viewport
    @sprites["moneywindow"].x = 0
    @sprites["moneywindow"].y = 0
    @sprites["moneywindow"].width = 190
    @sprites["moneywindow"].height = 96
    @sprites["moneywindow"].baseColor = text_colors[0]
    @sprites["moneywindow"].shadowColor = text_colors[1]
    
    # In Bag window (only for regular item shops, not outfits, and only when buying)
    is_outfit_shop = defined?(OutfitsMartAdapter) && adapter.is_a?(OutfitsMartAdapter)
    if !is_outfit_shop && buying
      @sprites["inbagwindow"] = Window_AdvancedTextPokemon.new("")
      pbPrepareWindow(@sprites["inbagwindow"])
      @sprites["inbagwindow"].visible = true
      @sprites["inbagwindow"].viewport = @viewport
      @sprites["inbagwindow"].x = 0
      @sprites["inbagwindow"].y = 216  # Adjusted position
      @sprites["inbagwindow"].width = 190
      @sprites["inbagwindow"].height = 64
      @sprites["inbagwindow"].baseColor = text_colors[0]
      @sprites["inbagwindow"].shadowColor = text_colors[1]
      # Set initial text
      @sprites["inbagwindow"].text = _INTL("In Bag:<r>0  ")
    end
    
    # Page/Category header sprite (show for buying with categories, even if just 1)
    if buying && @category_order.length >= 1 && !$game_temp.fromkurayshop
      @sprites["pageheader"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @sprites["pageheader"].z = 100
      pbSetSystemFont(@sprites["pageheader"].bitmap)
    end
    
    pbDeactivateWindows(@sprites)
    @buying = buying
    pbRefresh
    Graphics.frame_reset
    
    if $game_temp.fromkurayshop
      pbUnlockEggs()
    end
  end

  def pbUnlockEggs()
    # pbDisplayPaused(_INTL("Test."))
    # $PokemonSystem.gymrewardeggs
    # $PokemonSystem.trainerprogress
    can_get_egg = true
    if !$PokemonSystem.gymrewardeggs
      can_get_egg = false
    end
    if can_get_egg
      if $PokemonSystem.gymrewardeggs < 1
        can_get_egg = false
      end
    end
    if !$PokemonSystem.trainerprogress.include?("0")
      $PokemonSystem.trainerprogress.push("0")
      pbDisplayPaused(_INTL("You unlocked Starter K-Eggs!"))
      if can_get_egg
        pbGiveEgg(2022)
      end
    end
    for i in 1..8
      smartUnlock(i)
    end
    if !$PokemonSystem.trainerprogress.include?("9") && $game_variables[VAR_STAT_NB_ELITE_FOUR] >= 1
      $PokemonSystem.trainerprogress.push("9")
      pbDisplayPaused(_INTL("You unlocked Elite 4 K-Eggs!"))
      if can_get_egg
        pbGiveEgg(2031)
      end
    end
  end

  def smartUnlock(id=1)
    can_get_egg = true
    if !$PokemonSystem.gymrewardeggs
      can_get_egg = false
    end
    if can_get_egg
      if $PokemonSystem.gymrewardeggs < 1
        can_get_egg = false
      end
    end
    all_ids = [$game_switches[SWITCH_GOT_BADGE_1], $game_switches[SWITCH_GOT_BADGE_2], $game_switches[SWITCH_GOT_BADGE_3], $game_switches[SWITCH_GOT_BADGE_4], $game_switches[SWITCH_GOT_BADGE_5], $game_switches[SWITCH_GOT_BADGE_6], $game_switches[SWITCH_GOT_BADGE_7], $game_switches[SWITCH_GOT_BADGE_8]]
    
    if all_ids[id-1] && !$PokemonSystem.trainerprogress.include?(id.to_s)
      $PokemonSystem.trainerprogress.push(id.to_s)
      if id == 1
        pbDisplayPaused(_INTL("You unlocked 1 Badge K-Eggs!"))
      else
        pbDisplayPaused(_INTL("You unlocked {1} Badges K-Eggs!", id))
      end
      if can_get_egg
        pbGiveEgg(2022+id)
      end
    end
  end

  def pbGiveEgg(item_id)
    item = GameData::Item.get(item_id)
    $PokemonBag.pbStoreItem(item_id, $PokemonSystem.gymrewardeggs)
    if $PokemonSystem.gymrewardeggs > 1
      pbDisplayPaused(_INTL("You received {2}x {1}s!", item.name, $PokemonSystem.gymrewardeggs))
    else
      pbDisplayPaused(_INTL("You received a {1}!", item.name))
    end
  end

  def pbStartBuyScene(stock, adapter)
    pbStartBuyOrSellScene(true, stock, adapter)
  end

  def pbStartSellScene(bag, adapter)
    if $PokemonBag
      pbStartSellScene2(bag, adapter)
    else
      pbStartBuyOrSellScene(false, bag, adapter)
    end
  end

  def pbStartSellScene2(bag, adapter)
    @subscene = PokemonBag_Scene.new
    @adapter = adapter
    @viewport2 = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport2.z = 99999
    numFrames = Graphics.frame_rate * 4 / 10
    alphaDiff = (255.0 / numFrames).ceil
    for j in 0..numFrames
      col = Color.new(0, 0, 0, j * alphaDiff)
      @viewport2.color = col
      Graphics.update
      Input.update
    end
    @subscene.pbStartScene(bag)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @sprites["helpwindow"] = Window_AdvancedTextPokemon.new("")
    pbPrepareWindow(@sprites["helpwindow"])
    @sprites["helpwindow"].visible = false
    @sprites["helpwindow"].viewport = @viewport
    pbBottomLeftLines(@sprites["helpwindow"], 1)
    
    # Get text colors based on global frame (dark vs light)
    text_colors = defined?(pbGetGlobalFrameTextColors) ? pbGetGlobalFrameTextColors : [Color.new(88, 88, 80), Color.new(168, 184, 184)]
    
    # Use animated money window for sell scene too
    @sprites["moneywindow"] = Window_AnimatedMoney.new(adapter.getMoney, @currency_name)
    @sprites["moneywindow"].visible = false
    @sprites["moneywindow"].viewport = @viewport
    @sprites["moneywindow"].x = 0
    @sprites["moneywindow"].y = 0
    @sprites["moneywindow"].width = 186
    @sprites["moneywindow"].height = 96
    @sprites["moneywindow"].baseColor = text_colors[0]
    @sprites["moneywindow"].shadowColor = text_colors[1]
    pbDeactivateWindows(@sprites)
    @buying = false
    pbRefresh
  end

  #KurayX Creating kuray shop
  def pbEndBuyScene
    pbDisposeSpriteHash(@sprites)
    Kernel.pbClearText()
    @viewport.dispose
    # Scroll left after showing screen
    if !$game_temp.fromkurayshop
      scroll_back_map()
    end
  end

  #KurayX Creating kuray shop
  def pbEndSellScene
    @subscene.pbEndScene if @subscene
    pbDisposeSpriteHash(@sprites)
    if @viewport2
      numFrames = Graphics.frame_rate * 4 / 10
      alphaDiff = (255.0 / numFrames).ceil
      for j in 0..numFrames
        col = Color.new(0, 0, 0, (numFrames - j) * alphaDiff)
        @viewport2.color = col
        Graphics.update
        Input.update
      end
      @viewport2.dispose
    end
    @viewport.dispose
    pbScrollMap(4, 5, 5) if !@subscene && !$game_temp.fromkurayshop
  end

  def pbPrepareWindow(window)
    window.visible = true
    window.letterbyletter = false
  end

  def pbShowMoney
    pbRefresh
    @sprites["moneywindow"].visible = true
  end

  def pbHideMoney
    pbRefresh
    @sprites["moneywindow"].visible = false
  end
  
  # Wait for the animated money display to finish animating
  def pbWaitForMoneyAnimation
    return unless @sprites["moneywindow"].is_a?(Window_AnimatedMoney)
    while @sprites["moneywindow"].animating?
      Graphics.update
      Input.update
      self.update
    end
  end

  def pbDisplay(msg, brief = false)
    cw = @sprites["helpwindow"]
    cw.letterbyletter = true
    cw.text = msg
    pbBottomLeftLines(cw, 2)
    cw.visible = true
    i = 0
    pbPlayDecisionSE
    loop do
      Graphics.update
      Input.update
      self.update
      if !cw.busy?
        return if brief
        pbRefresh if i == 0
      end
      if Input.trigger?(Input::USE) && cw.busy?
        cw.resume
      end
      return if i >= Graphics.frame_rate * 3 / 2
      i += 1 if !cw.busy?
    end
  end

  def pbDisplayPaused(msg)
    cw = @sprites["helpwindow"]
    cw.letterbyletter = true
    cw.text = msg
    pbBottomLeftLines(cw, 2)
    cw.visible = true
    yielded = false
    pbPlayDecisionSE
    loop do
      Graphics.update
      Input.update
      wasbusy = cw.busy?
      self.update
      if !cw.busy? && !yielded
        yield if block_given?   # For playing SE as soon as the message is all shown
        yielded = true
      end
      pbRefresh if !cw.busy? && wasbusy
      if Input.trigger?(Input::USE) && cw.resume && !cw.busy?
        @sprites["helpwindow"].visible = false
        return
      end
    end
  end

  def pbConfirm(msg)
    dw = @sprites["helpwindow"]
    dw.letterbyletter = true
    dw.text = msg
    dw.visible = true
    pbBottomLeftLines(dw, 2)
    commands = [_INTL("Yes"), _INTL("No")]
    cw = Window_CommandPokemon.new(commands)
    cw.viewport = @viewport
    pbBottomRight(cw)
    cw.y -= dw.height
    cw.index = 0
    pbPlayDecisionSE
    loop do
      cw.visible = !dw.busy?
      Graphics.update
      Input.update
      cw.update
      self.update
      if Input.trigger?(Input::BACK) && dw.resume && !dw.busy?
        cw.dispose
        @sprites["helpwindow"].visible = false
        return false
      end
      if Input.trigger?(Input::USE) && dw.resume && !dw.busy?
        cw.dispose
        @sprites["helpwindow"].visible = false
        return (cw.index == 0)
      end
    end
  end

  def pbChooseNumber(helptext,item,maximum)
    curnumber = 1
    ret = 0
    helpwindow = @sprites["helpwindow"]
    itemprice = @adapter.getPrice(item, !@buying)
    itemprice /= 2 if !@buying
    pbDisplay(helptext, true)
    using(numwindow = Window_AdvancedTextPokemon.new("")) {   # Showing number of items
      qty = @adapter.getQuantity(item)
      # Use the persistent inbagwindow instead of creating a new one
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
      
      numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
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
          numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
        elsif Input.repeat?(Input::RIGHT)
          pbPlayCursorSE
          curnumber += 10
          curnumber = maximum if curnumber > maximum
          numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
        elsif Input.repeat?(Input::UP)
          pbPlayCursorSE
          curnumber += 1
          curnumber = 1 if curnumber > maximum
          numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
        elsif Input.repeat?(Input::DOWN)
          pbPlayCursorSE
          curnumber -= 1
          curnumber = maximum if curnumber < 1
          numwindow.text = _INTL("x{1}<r>$ {2}", curnumber, (curnumber * itemprice).to_s_formatted)
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

  def pbChooseBuyItem
    itemwindow = @sprites["itemwindow"]
    @sprites["helpwindow"].visible = false
    pbActivateWindow(@sprites, "itemwindow") {
      pbRefresh
      loop do
        Graphics.update
        Input.update
        
        # Category switching with LEFT/RIGHT - CHECK BEFORE self.update consumes input!
        if Input.trigger?(Input::LEFT) && @category_order && @category_order.length > 1 && !$game_temp.fromkurayshop
          pbSEPlay("GUI naming tab swap start")
          switch_category(-1)
          itemwindow = @sprites["itemwindow"]  # Reassign since it's a new window
          pbRefresh
          next
        elsif Input.trigger?(Input::RIGHT) && @category_order && @category_order.length > 1 && !$game_temp.fromkurayshop
          pbSEPlay("GUI naming tab swap start")
          switch_category(1)
          itemwindow = @sprites["itemwindow"]  # Reassign since it's a new window
          pbRefresh
          next
        end
        
        olditem = itemwindow.item
        self.update
        pbRefresh if itemwindow.item != olditem
        
        if Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          return nil
        elsif Input.trigger?(Input::USE)
          if itemwindow.item
            pbRefresh
            return itemwindow.item
          else
            return nil
          end
        end
      end
    }
  end

  def pbChooseSellItem
    if @subscene
      return @subscene.pbChooseItem
    else
      return pbChooseBuyItem
    end
  end
end

#===============================================================================
#
#===============================================================================
class PokemonMartScreen
  def initialize(scene,stock,adapter=PokemonMartAdapter.new)
    @scene=scene
    @stock=stock
    @adapter=adapter
  end

  def pbConfirm(msg)
    return @scene.pbConfirm(msg)
  end

  def pbDisplay(msg)
    return @scene.pbDisplay(msg)
  end

  def pbDisplayPaused(msg,&block)
    return @scene.pbDisplayPaused(msg,&block)
  end

  def pbBuyScreen
    @scene.pbStartBuyScene(@stock,@adapter)
    item=nil
    loop do
      pbWait(4)
      item=@scene.pbChooseBuyItem
      break if !item
      quantity=0
      itemname=@adapter.getDisplayName(item)
      price=@adapter.getPrice(item)
      if @adapter.getMoney<price
        pbDisplayPaused(_INTL("You don't have enough money."))
        next
      end
      if GameData::Item.get(item).is_important?
        if !pbConfirm(_INTL("Certainly. You want {1}. That will be ${2}. OK?",
           itemname,price.to_s_formatted))
          next
        end
        quantity=1
      else
        maxafford = (price <= 0) ? Settings::BAG_MAX_PER_SLOT : @adapter.getMoney / price
        maxafford = Settings::BAG_MAX_PER_SLOT if maxafford > Settings::BAG_MAX_PER_SLOT
        quantity=@scene.pbChooseNumber(
           _INTL("{1}? Certainly. How many would you like?",itemname),item,maxafford)
        next if quantity==0
        price*=quantity
        if !pbConfirm(_INTL("{1}, and you want {2}. That will be ${3}. OK?",
           itemname,quantity,price.to_s_formatted))
          next
        end
      end
      if @adapter.getMoney<price
        pbDisplayPaused(_INTL("You don't have enough money."))
        next
      end
      added=0
      quantity.times do
        break if !@adapter.addItem(item)
        added+=1
      end
      if added!=quantity
        added.times do
          if !@adapter.removeItem(item)
            raise _INTL("Failed to delete stored items")
          end
        end
        pbDisplayPaused(_INTL("You have no more room in the Bag."))
      else
        @adapter.setMoney(@adapter.getMoney-price)
        @scene.pbRefresh  # Trigger animated money display
        @scene.pbWaitForMoneyAnimation  # Wait for animation to complete
        for i in 0...@stock.length
          if GameData::Item.get(@stock[i]).is_important? && $PokemonBag.pbHasItem?(@stock[i])
            @stock[i]=nil
          end
        end
        @stock.compact!
        pbDisplayPaused(_INTL("Here you are! Thank you!")) { pbSEPlay("Mart buy item") }
        if $PokemonBag
          if quantity>=10 && GameData::Item.get(item).is_poke_ball? && GameData::Item.exists?(:PREMIERBALL)
            if @adapter.addItem(GameData::Item.get(:PREMIERBALL))
              pbDisplayPaused(_INTL("I'll throw in a Premier Ball, too."))
            end
          end
        end
      end
    end
    @scene.pbEndBuyScene
  end

  def pbSellScreen
    item=@scene.pbStartSellScene(@adapter.getInventory,@adapter)
    loop do
      item=@scene.pbChooseSellItem
      break if !item
      itemname=@adapter.getDisplayName(item)
      price=@adapter.getPrice(item,true)
      if !@adapter.canSell?(item)
        pbDisplayPaused(_INTL("{1}? Oh, no. I can't buy that.",itemname))
        next
      end
      qty=@adapter.getQuantity(item)
      next if qty==0
      @scene.pbShowMoney
      if qty>1
        qty=@scene.pbChooseNumber(
           _INTL("{1}? How many would you like to sell?",itemname),item,qty)
      end
      if qty==0
        @scene.pbHideMoney
        next
      end
      price/=2
      price*=qty
      if pbConfirm(_INTL("I can pay ${1}. Would that be OK?",price.to_s_formatted))
        @adapter.setMoney(@adapter.getMoney+price)
        @scene.pbRefresh  # Trigger animated money display
        @scene.pbWaitForMoneyAnimation  # Wait for animation to complete
        qty.times do
          @adapter.removeItem(item)
        end
        pbDisplayPaused(_INTL("Turned over the {1} and received ${2}.",itemname,price.to_s_formatted)) { pbSEPlay("Mart buy item") }
      end
      @scene.pbHideMoney
    end
    @scene.pbEndSellScene
  end
end

def replaceShopStockWithRandomized(stock)
  if $PokemonGlobal.randomItemsHash != nil
    newStock = []
    for item in stock
      newItem =$PokemonGlobal.randomItemsHash[item]
        if newItem != nil && GameData::Item.get(newItem).price >0 && !Settings::EXCLUDE_FROM_RANDOM_SHOPS.include?(newItem)
          newStock << newItem
        else
          newStock << item
        end
    end
    return newStock
  end
  return stock
end

#===============================================================================
#
#===============================================================================
def pbPokemonMart(stock,speech=nil,cantsell=false)
  if $game_switches[SWITCH_RANDOM_ITEMS_GENERAL] && $game_switches[SWITCH_RANDOM_SHOP_ITEMS]
    stock = replaceShopStockWithRandomized(stock)
  end

  for i in 0...stock.length
    stock[i] = GameData::Item.get(stock[i]).id
    stock[i] = nil if GameData::Item.get(stock[i]).is_important? && $PokemonBag.pbHasItem?(stock[i])
  end
  stock.compact!
  commands = []
  cmdBuy  = -1
  cmdSell = -1
  cmdQuit = -1
  commands[cmdBuy = commands.length]  = _INTL("Buy")
  commands[cmdSell = commands.length] = _INTL("Sell") if !cantsell
  commands[cmdQuit = commands.length] = _INTL("Quit")
  cmd = pbMessage(
     speech ? speech : _INTL("Welcome! How may I serve you?"),
     commands,cmdQuit+1)
  loop do
    if cmdBuy>=0 && cmd==cmdBuy
      scene = PokemonMart_Scene.new
      screen = PokemonMartScreen.new(scene,stock)
      screen.pbBuyScreen
    elsif cmdSell>=0 && cmd==cmdSell
      scene = PokemonMart_Scene.new
      screen = PokemonMartScreen.new(scene,stock)
      screen.pbSellScreen
    else
      pbMessage(_INTL("Please come again!"))
      break
    end
    cmd = pbMessage(_INTL("Is there anything else I can help you with?"),
       commands,cmdQuit+1)
  end
  $game_temp.clear_mart_prices
end
