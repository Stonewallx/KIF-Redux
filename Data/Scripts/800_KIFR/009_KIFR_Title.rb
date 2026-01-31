#===============================================================================
# KIF Redux Title Screen & Load Screen - Custom Overrides
# Script Version: 2.0.0
# Author: Stonewall
#===============================================================================
# This file handles:
# - Title screen logo replacement (kifreduxlogo.png)
# - Load screen overrides with save delete functionality
# - Game version update checks
# - Mod auto-update integration
#===============================================================================

#===============================================================================
# TITLE SCREEN LOGO OVERRIDE
#===============================================================================
# Replaces the default "pokelogo" with the KIF Redux logo on the title screen
# The logo file should be at: Graphics/800_KIFR/kifreduxlogo.png
#===============================================================================

if defined?(GenOneStyle)
  class GenOneStyle
    # Store the original initialize method
    alias kifr_original_initialize initialize
    
    def initialize
      # Call the original initialize first
      kifr_original_initialize
      
      # Now replace the logo sprite with our custom KIFR logo
      replace_logo_with_kifr
    end
    
    # Replace the title screen logo with KIF Redux logo
    def replace_logo_with_kifr
      kifr_logo_path = "Graphics/800_KIFR/kifreduxlogo"
      
      # Check if our custom logo exists
      if pbResolveBitmap(kifr_logo_path)
        begin
          # Dispose the old logo bitmap if it exists
          if @sprites["logo"] && @sprites["logo"].bitmap
            @sprites["logo"].bitmap.dispose
          end
          
          # Load the new KIF Redux logo
          kifr_bitmap = pbBitmap(kifr_logo_path)
          
          # Create a new bitmap and copy the KIFR logo
          @sprites["logo"].bitmap = Bitmap.new(kifr_bitmap.width, kifr_bitmap.height)
          @sprites["logo"].bitmap.blt(0, 0, kifr_bitmap, Rect.new(0, 0, kifr_bitmap.width, kifr_bitmap.height))
          
          # Reset tone to ensure logo displays properly (original sets it to white)
          @sprites["logo"].tone = Tone.new(255, 255, 255, 255)
          
          # Make the logo 20% bigger
          @sprites["logo"].zoom_x = 1
          @sprites["logo"].zoom_y = 1
          
          # Move 30 pixels to the right (original x is 50)
          @sprites["logo"].x = 130
          
          # Move up 30 pixels (original y is -20)
          @sprites["logo"].y = -40
          
          KIFRSettings.debug_log("Title screen logo replaced with KIF Redux logo") if defined?(KIFRSettings)
        rescue => e
          # If anything goes wrong, log it but don't crash
          KIFRSettings.debug_log("Error replacing title logo: #{e.message}") if defined?(KIFRSettings)
        end
      else
        KIFRSettings.debug_log("KIF Redux logo not found at #{kifr_logo_path}") if defined?(KIFRSettings)
      end
    end
  end
  
  KIFRSettings.debug_log("KIFR Title: Title screen logo override loaded") if defined?(KIFRSettings)
end

#===============================================================================
# LOAD SCREEN SCENE OVERRIDE - Save Delete Functionality
#===============================================================================
# Adds left/right navigation between saves and SPECIAL (D/RS) to delete
#===============================================================================

class PokemonLoad_Scene
  # Override pbChoose to add save navigation and delete functionality
  def pbChoose(commands, continue_idx)
    @sprites["cmdwindow"].commands = commands
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::USE)
        return @sprites["cmdwindow"].index
      elsif @sprites["cmdwindow"].index == continue_idx
        # Show arrows if they exist (may not in all scene variants)
        @sprites["leftarrow"].visible = true if @sprites["leftarrow"]
        @sprites["rightarrow"].visible = true if @sprites["rightarrow"]
        if Input.trigger?(Input::LEFT)
          return -3
        elsif Input.trigger?(Input::RIGHT)
          return -2
        elsif Input.trigger?(Input::SPECIAL)
          return -4
        end
      else
        # Hide arrows if they exist
        @sprites["leftarrow"].visible = false if @sprites["leftarrow"]
        @sprites["rightarrow"].visible = false if @sprites["rightarrow"]
      end
    end
  end
end

#===============================================================================
# LOAD SCREEN OVERRIDE - Main Load Screen with Updates & Delete
#===============================================================================

class PokemonLoadScreen
  # Override the load screen to add version checks and save delete
  unless method_defined?(:kifr_orig_pbStartLoadScreen)
    alias kifr_orig_pbStartLoadScreen pbStartLoadScreen
  end
  
  def pbStartLoadScreen
    KIFRSettings.debug_log("KIFR Load Screen: pbStartLoadScreen called") if defined?(KIFRSettings)
    
    # Run pre-checks and updates
    perform_startup_checks
    
    # Check for game version updates
    check_game_version_update
    
    # Check for mod auto-updates (KIFR system)
    perform_kifr_auto_update_check
    
    # Handle shiny cache clearing
    clear_shiny_cache_if_needed
    
    # Handle imported sprites
    handle_imported_sprites
    
    # Copy keybindings
    copyKeybindings()
    
    # Reset options name flag
    $KURAY_OPTIONSNAME_LOADED = false
    
    # Run kuray eggs if enabled
    kurayeggs_main() if $KURAYEGGS_WRITEDATA
    
    # Now run the main load screen with delete functionality
    pbStartLoadScreen_WithDelete
  end
  
  # Perform startup file checks/updates
  def perform_startup_checks
    begin
      updateHttpSettingsFile if respond_to?(:updateHttpSettingsFile)
      updateCreditsFile if respond_to?(:updateCreditsFile)
      updateCustomDexFile if respond_to?(:updateCustomDexFile)
      updateOnlineCustomSpritesFile if respond_to?(:updateOnlineCustomSpritesFile)
    rescue => e
      KIFRSettings.debug_log("KIFR Load Screen: Startup check error: #{e.message}") if defined?(KIFRSettings)
    end
  end
  
  # Check for game version updates
  def check_game_version_update
    begin
      newer_version = find_newer_available_version
      if newer_version
        if File.file?('.\INSTALL_OR_UPDATE.bat')
          update_answer = pbMessage(_INTL("Version {1} is now available! Update now?", newer_version), ["Yes","No"], 1)
          if update_answer == 0
            Process.spawn('.\INSTALL_OR_UPDATE.bat', "auto")
            exit
          end
        else
          pbMessage(_INTL("Version {1} is now available! Please check the game's official page to download the newest version.", newer_version))
        end
      end
    rescue => e
      KIFRSettings.debug_log("KIFR Load Screen: Version check error: #{e.message}") if defined?(KIFRSettings)
    end
  end
  
  # Perform KIFR mod auto-update check
  def perform_kifr_auto_update_check
    begin
      if defined?(KIFRSettings) && KIFRSettings.respond_to?(:perform_auto_update_check)
        KIFRSettings.perform_auto_update_check
      end
    rescue => e
      KIFRSettings.debug_log("KIFR Load Screen: Auto-update check error: #{e.message}") if defined?(KIFRSettings)
    end
  end
  
  # Clear shiny cache if setting is enabled
  def clear_shiny_cache_if_needed
    begin
      if $PokemonSystem && $PokemonSystem.shiny_cache == 1
        checkDirectory("Cache")
        checkDirectory("Cache/Shiny")
        Dir.glob("Cache/Shiny/*").each do |file|
          File.delete(file) if File.file?(file)
        end
        checkDirectory("Cache/Shiny/vanilla")
        Dir.glob("Cache/Shiny/vanilla/*").each do |file|
          File.delete(file) if File.file?(file)
        end
      end
    rescue => e
      KIFRSettings.debug_log("KIFR Load Screen: Shiny cache clear error: #{e.message}") if defined?(KIFRSettings)
    end
  end
  
  # Handle any imported sprites
  def handle_imported_sprites
    begin
      if ($game_temp.unimportedSprites && $game_temp.unimportedSprites.size > 0)
        handleReplaceExistingSprites() if respond_to?(:handleReplaceExistingSprites)
      end
      if ($game_temp.nb_imported_sprites && $game_temp.nb_imported_sprites > 0)
        pbMessage(_INTL("{1} new custom sprites were imported into the game", $game_temp.nb_imported_sprites.to_s))
      end
      checkEnableSpritesDownload if respond_to?(:checkEnableSpritesDownload)
      $game_temp.nb_imported_sprites = nil
    rescue => e
      KIFRSettings.debug_log("KIFR Load Screen: Sprite import error: #{e.message}") if defined?(KIFRSettings)
    end
  end
  
  # Main load screen loop with save delete functionality
  def pbStartLoadScreen_WithDelete
    save_file_list = SaveData::AUTO_SLOTS + SaveData::MANUAL_SLOTS
    first_time = true
    
    loop do
      if @selected_file
        @save_data = load_save_file(SaveData.get_full_path(@selected_file))
      else
        @save_data = {}
      end
      
      commands = []
      cmd_continue = -1
      cmd_new_game = -1
      cmd_new_game_plus = -1
      cmd_options = -1
      cmd_mystery_gift = -1
      cmd_debug = -1
      cmd_quit = -1
      cmd_discord = -1
      
      show_continue = !@save_data.empty?
      new_game_plus = show_continue && (@save_data[:player].new_game_plus_unlocked || $DEBUG)

      if show_continue
        commands[cmd_continue = commands.length] = "#{@selected_file}"
        commands[cmd_mystery_gift = commands.length] = _INTL('Mystery Gift')
      end

      commands[cmd_new_game = commands.length] = _INTL('New Game')
      if new_game_plus
        commands[cmd_new_game_plus = commands.length] = _INTL('New Game +')
      end
      commands[cmd_options = commands.length] = _INTL('Options')
      commands[cmd_discord = commands.length] = _INTL('KIF Discord')
      commands[cmd_debug = commands.length] = _INTL('Debug') if $DEBUG
      commands[cmd_quit = commands.length] = _INTL('Quit Game')
      
      cmd_left = -3
      cmd_right = -2
      cmd_delete = -4

      map_id = show_continue ? @save_data[:map_factory].map.map_id : 0
      save_tag = show_continue ? @save_data[:kifr_save_tag] : nil
      @scene.pbStartScene(commands, show_continue, @save_data[:player],
                          @save_data[:frame_count] || 0, map_id, save_tag)
      @scene.pbSetParty(@save_data[:player]) if show_continue
      
      if first_time
        @scene.pbStartScene2
        first_time = false
      else
        @scene.pbUpdate
      end

      loop do
        command = @scene.pbChoose(commands, cmd_continue)
        pbPlayDecisionSE if command != cmd_quit

        case command
        when cmd_continue
          @scene.pbEndScene
          Game.load(@save_data)
          $game_switches[SWITCH_V5_1] = true if defined?(SWITCH_V5_1)
          ensureCorrectDifficulty() if respond_to?(:ensureCorrectDifficulty)
          setGameMode() if respond_to?(:setGameMode)
          $PokemonGlobal.alt_sprite_substitutions = {} if !$PokemonGlobal.alt_sprite_substitutions
          $PokemonGlobal.autogen_sprites_cache = {}
          return
          
        when cmd_new_game
          @scene.pbEndScene
          Game.start_new
          $PokemonGlobal.alt_sprite_substitutions = {} if !$PokemonGlobal.alt_sprite_substitutions
          return
          
        when cmd_new_game_plus
          @scene.pbEndScene
          Game.start_new(@save_data[:bag], @save_data[:storage_system], @save_data[:player])
          @save_data[:player].new_game_plus_unlocked = true
          return
          
        when cmd_discord
          openUrlInBrowser(Settings::DISCORD_URL) if defined?(Settings::DISCORD_URL)
          return
          
        when cmd_mystery_gift
          pbFadeOutIn { pbDownloadMysteryGift(@save_data[:player]) }
          
        when cmd_options
          pbFadeOutIn do
            scene = PokemonOption_Scene.new
            screen = PokemonOptionScreen.new(scene)
            screen.pbStartScreen(true)
          end
          
        when cmd_debug
          pbFadeOutIn { pbDebugMenu(false) }
          
        when cmd_quit
          pbPlayCloseMenuSE
          @scene.pbEndScene
          $scene = nil
          return
          
        when cmd_left
          @scene.pbCloseScene
          @selected_file = SaveData.get_prev_slot(save_file_list, @selected_file)
          break
          
        when cmd_right
          @scene.pbCloseScene
          @selected_file = SaveData.get_next_slot(save_file_list, @selected_file)
          break
          
        when cmd_delete
          if show_continue && @selected_file
            handle_save_delete(save_file_list)
          end
          
        else
          pbPlayBuzzerSE
        end
      end
    end
  end
  
  # Handle save file deletion
  def handle_save_delete(save_file_list)
    pbPlayDecisionSE
    file_count = count_related_save_files(@selected_file)
    autosave_count = file_count - 2
    
    if autosave_count > 0
      delete_msg = _INTL("Delete '{1}' and {2} autosave(s)?", @selected_file, autosave_count)
    else
      delete_msg = _INTL("Delete the save file '{1}'?", @selected_file)
    end
    
    if pbConfirmMessageSerious(delete_msg)
      pbMessage(_INTL("Total files to be moved: {1}\\nThey will be moved to DELETED SAVES folder.\\wtnp[30]", file_count))
      if pbConfirmMessageSerious(_INTL("Are you absolutely sure?"))
        delete_current_save_and_related_files
        @scene.pbCloseScene
        temp_file = @selected_file
        @selected_file = nil
        save_file_list.each do |slot|
          next if slot == temp_file
          if File.file?(SaveData.get_full_path(slot))
            @selected_file = slot
            break
          end
        end
        @selected_file = SaveData.get_newest_save_slot if @selected_file.nil?
        pbMessage(_INTL("Moved {1} files to DELETED SAVES.", file_count))
      end
    end
  end
  
  # Count files related to a save (including autosaves)
  def count_related_save_files(selected_file)
    return 0 if !selected_file
    
    save_dir = SaveData::SAVE_DIR
    count = 0
    
    file_path = SaveData.get_full_path(selected_file)
    count += 1 if File.file?(file_path)
    count += 1 if File.file?(file_path + '.bak')
    
    Dir.foreach(save_dir) do |filename|
      next if filename == '.' || filename == '..'
      next if filename == 'DELETED SAVES'
      
      full_path = File.join(save_dir, filename)
      next unless File.file?(full_path)
      
      if filename.start_with?(selected_file + " ") || 
         (filename.start_with?(selected_file + ".") && filename != selected_file + ".rxdata" && filename != selected_file + ".rxdata.bak")
        count += 1
      end
    end
    
    return count
  end
  
  # Move save files to DELETED SAVES folder
  def delete_current_save_and_related_files
    return if !@selected_file
    
    save_dir = SaveData::SAVE_DIR
    deleted_folder = File.join(save_dir, "DELETED SAVES")
    
    Dir.mkdir(deleted_folder) unless Dir.exist?(deleted_folder)
    
    files_to_move = []
    
    file_path = SaveData.get_full_path(@selected_file)
    files_to_move << file_path if File.file?(file_path)
    files_to_move << (file_path + '.bak') if File.file?(file_path + '.bak')
    
    Dir.foreach(save_dir) do |filename|
      next if filename == '.' || filename == '..'
      next if filename == 'DELETED SAVES'
      
      full_path = File.join(save_dir, filename)
      next unless File.file?(full_path)
      
      if filename.start_with?(@selected_file + " ") || 
         filename.start_with?(@selected_file + ".") ||
         filename == @selected_file + ".rxdata"
        files_to_move << full_path unless files_to_move.include?(full_path)
      end
    end
    
    count = 0
    files_to_move.each do |file|
      begin
        if File.file?(file)
          dest_path = File.join(deleted_folder, File.basename(file))
          File.rename(file, dest_path)
          count += 1
        end
      rescue SystemCallError => e
        KIFRSettings.debug_log("KIFR Load Screen: Error moving file: #{e.message}") if defined?(KIFRSettings)
      end
    end
  end
end

#===============================================================================
# SAVE DELETE SETTINGS SCENE
#===============================================================================
# Manage deleted saves - restore or permanently delete
#===============================================================================

class SaveDeleteSettings_Scene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    options << ButtonOption.new(_INTL("Restore Deleted Saves"),
      proc {
        pbRestoreDeletedSaves
        @sprites["option"].refresh if @sprites["option"]
      },
      _INTL("Restore a previously deleted save file"))
    
    options << ButtonOption.new(_INTL("Clean Up Deleted Saves"),
      proc {
        pbCleanUpDeletedSaves
        @sprites["option"].refresh if @sprites["option"]
      },
      _INTL("Permanently delete all files in DELETED SAVES folder"))
    
    options << ButtonOption.new(_INTL("View Deleted Saves Folder"),
      proc {
        pbOpenDeletedSavesFolder
      },
      _INTL("Open the DELETED SAVES folder in Explorer"))
    
    return options
  end
  
  def pbStartScene(inloadscreen = false)
    super(inloadscreen)
    
    disk_info = get_deleted_saves_disk_info
    title_text = _INTL("Save Delete Settings ({1} files, {2})", disk_info[:count], disk_info[:size_text])
    
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      title_text, 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    if @sprites["option"]
      # Apply KIFR color theme
      if defined?(KIFRSettings)
        theme_index = KIFRSettings.get(:kifr_color_theme) || 0
        apply_kifr_color_theme(@sprites["option"], theme_index) if respond_to?(:apply_kifr_color_theme)
      end
      @sprites["option"].refresh
    end
  end
  
  def get_deleted_saves_disk_info
    save_dir = SaveData::SAVE_DIR
    deleted_folder = File.join(save_dir, "DELETED SAVES")
    
    count = 0
    total_bytes = 0
    
    if Dir.exist?(deleted_folder)
      Dir.foreach(deleted_folder) do |filename|
        next if filename == '.' || filename == '..'
        full_path = File.join(deleted_folder, filename)
        if File.file?(full_path)
          count += 1
          total_bytes += File.size(full_path)
        end
      end
    end
    
    size_text = format_file_size(total_bytes)
    
    return { count: count, total_bytes: total_bytes, size_text: size_text }
  end
  
  def format_file_size(bytes)
    return "0 bytes" if bytes == 0
    return "#{bytes} bytes" if bytes < 1024
    
    kb = bytes / 1024.0
    return "#{kb.round(1)} KB" if kb < 1024
    
    mb = kb / 1024.0
    return "#{mb.round(2)} MB" if mb < 1024
    
    gb = mb / 1024.0
    return "#{gb.round(2)} GB"
  end
  
  def pbRestoreDeletedSaves
    save_dir = SaveData::SAVE_DIR
    deleted_folder = File.join(save_dir, "DELETED SAVES")
    
    if !Dir.exist?(deleted_folder)
      pbMessage(_INTL("No deleted saves folder found."))
      return
    end
    
    save_files = []
    Dir.foreach(deleted_folder) do |filename|
      next if filename == '.' || filename == '..'
      next unless filename.end_with?(".rxdata")
      next if filename.end_with?(".rxdata.bak")
      save_files.push(filename)
    end
    
    if save_files.empty?
      pbMessage(_INTL("No deleted save files found to restore."))
      return
    end
    
    save_files.sort!
    
    # Show opaque command window with cleaned up names
    commands = save_files.map { |f| f.gsub(".rxdata", "") } + [_INTL("Cancel")]
    choice = pbShowCommandsOpaque(commands, -1)
    
    return if choice < 0 || choice >= save_files.length
    
    selected_file = save_files[choice]
    base_name = selected_file.gsub(".rxdata", "")
    
    if pbConfirmMessage(_INTL("Restore '{1}'?", base_name))
      restored_count = 0
      
      Dir.foreach(deleted_folder) do |filename|
        next if filename == '.' || filename == '..'
        
        if filename.start_with?(base_name + " ") || 
           filename.start_with?(base_name + ".") ||
           filename == selected_file
          
          source_path = File.join(deleted_folder, filename)
          dest_path = File.join(save_dir, filename)
          
          begin
            if File.file?(source_path)
              File.rename(source_path, dest_path)
              restored_count += 1
            end
          rescue SystemCallError => e
            KIFRSettings.debug_log("KIFR Save Delete: Error restoring file: #{e.message}") if defined?(KIFRSettings)
          end
        end
      end
      
      pbMessage(_INTL("Restored {1} files for '{2}'.", restored_count, base_name))
    end
  end
  
  def pbCleanUpDeletedSaves
    save_dir = SaveData::SAVE_DIR
    deleted_folder = File.join(save_dir, "DELETED SAVES")
    
    if !Dir.exist?(deleted_folder)
      pbMessage(_INTL("No deleted saves folder found."))
      return
    end
    
    file_count = 0
    total_bytes = 0
    Dir.foreach(deleted_folder) do |filename|
      next if filename == '.' || filename == '..'
      full_path = File.join(deleted_folder, filename)
      if File.file?(full_path)
        file_count += 1
        total_bytes += File.size(full_path)
      end
    end
    
    if file_count == 0
      pbMessage(_INTL("The deleted saves folder is already empty."))
      return
    end
    
    size_text = format_file_size(total_bytes)
    
    if pbConfirmMessageSerious(_INTL("Permanently delete all {1} files ({2})?", file_count, size_text))
      pbMessage(_INTL("This will free up {1} of disk space.\nThis cannot be undone!\\wtnp[30]", size_text))
      if pbConfirmMessageSerious(_INTL("Are you absolutely sure?"))
        deleted_count = 0
        Dir.foreach(deleted_folder) do |filename|
          next if filename == '.' || filename == '..'
          full_path = File.join(deleted_folder, filename)
          begin
            if File.file?(full_path)
              File.delete(full_path)
              deleted_count += 1
            end
          rescue SystemCallError
          end
        end
        pbMessage(_INTL("Permanently deleted {1} files.", deleted_count))
      end
    end
  end
  
  def pbOpenDeletedSavesFolder
    save_dir = SaveData::SAVE_DIR
    deleted_folder = File.join(save_dir, "DELETED SAVES")
    
    if !Dir.exist?(deleted_folder)
      pbMessage(_INTL("No deleted saves folder found."))
      Dir.mkdir(deleted_folder)
      pbMessage(_INTL("Created DELETED SAVES folder."))
    end
    
    begin
      system("start \"\" \"#{deleted_folder}\"")
      pbMessage(_INTL("Opening DELETED SAVES folder..."))
    rescue
      pbMessage(_INTL("Could not open folder. Path:\n{1}", deleted_folder))
    end
  end
end

# Entry point for Save Delete Settings menu
def save_delete_settings_menu
  scene = SaveDeleteSettings_Scene.new
  screen = PokemonOptionScreen.new(scene)
  screen.pbStartScreen
end

KIFRSettings.debug_log("KIFR Title: Load screen and save delete functionality loaded") if defined?(KIFRSettings)

#===============================================================================
# KIFR SAVE TAGS SYSTEM
#===============================================================================
# Allows players to add custom labels to save files (e.g., "Nuzlocke", "Main")
# Tags appear on the load screen next to the save file name
#===============================================================================

module KIFR
  module SaveTags
    MAX_LENGTH = 20
    
    # Predefined tags for quick selection
    PREDEFINED_TAGS = [
      "Main",
      "Nuzlocke",
      "Hardcore",
      "Randomizer",
      "Challenge",
      "Coop",
      "Testing"
    ]
    
    # Get the current save tag
    def self.current
      $kifr_save_tag || ""
    end
    
    # Set a new save tag via selection menu
    def self.set_tag
      # Build command list: Custom first, then predefined tags, then Clear/Cancel
      commands = [_INTL("Custom...")]
      commands.concat(PREDEFINED_TAGS)
      commands.push(_INTL("Clear Tag"))
      commands.push(_INTL("Cancel"))
      
      choice = pbMessage(_INTL("Select a save tag:"), commands, commands.length)
      
      if choice == 0
        # Custom - show text input
        new_tag = pbEnterText(_INTL("Enter save tag:"), 1, MAX_LENGTH)
        $kifr_save_tag = new_tag.strip.empty? ? nil : new_tag.strip
        pbMessage(_INTL("Tag was changed to {1}.", $kifr_save_tag || "None"))
      elsif choice > 0 && choice <= PREDEFINED_TAGS.length
        # Selected a predefined tag (offset by 1 due to Custom being first)
        $kifr_save_tag = PREDEFINED_TAGS[choice - 1]
        pbMessage(_INTL("Tag was changed to {1}.", $kifr_save_tag))
      elsif choice == PREDEFINED_TAGS.length + 1
        # Clear tag
        $kifr_save_tag = nil
        pbMessage(_INTL("Tag was changed to {1}.", "None"))
      end
      # Cancel does nothing
    end
    
    # Clear the save tag
    def self.clear_tag
      $kifr_save_tag = nil
    end
    
    # Check if a tag is set
    def self.has_tag?
      !$kifr_save_tag.nil? && !$kifr_save_tag.empty?
    end
    
    # Format title with tag (e.g., "File A - Nuzlocke")
    def self.format_title(title, tag)
      return title if tag.nil? || tag.empty?
      "#{title} - #{tag}"
    end
  end
end

#===============================================================================
# SaveData Registration - Persist save tag with save file
#===============================================================================
SaveData.register(:kifr_save_tag) do
  optional
  ensure_class :String
  save_value { $kifr_save_tag }
  load_value { |value| $kifr_save_tag = value }
  new_game_value { "" }
end

# Note: Save Tag option is added to KIFR Settings in 002_KIFR_Options.rb

#===============================================================================
# PokemonLoadPanel - Add save tag support
# Note: Must alias since base class is defined in core game scripts
#===============================================================================
class PokemonLoadPanel < SpriteWrapper
  attr_accessor :kifr_save_tag
  
  alias kifr_savetag_orig_initialize initialize unless method_defined?(:kifr_savetag_orig_initialize)
  
  def initialize(index, title, isContinue, trainer, framecount, mapid, viewport = nil, tag = nil)
    @kifr_save_tag = tag
    kifr_savetag_orig_initialize(index, title, isContinue, trainer, framecount, mapid, viewport)
  end
  
  alias kifr_savetag_orig_refresh refresh unless method_defined?(:kifr_savetag_orig_refresh)
  
  def refresh
    return if @refreshing
    return if disposed?
    @refreshing = true
    
    if !self.bitmap || self.bitmap.disposed?
      self.bitmap = BitmapWrapper.new(@bgbitmap.width, 111 * 2)
      pbSetSystemFont(self.bitmap)
    end
    
    if @refreshBitmap
      @refreshBitmap = false
      self.bitmap.clear if self.bitmap
      
      if @isContinue
        self.bitmap.blt(0, 0, @bgbitmap.bitmap, Rect.new(0, (@selected) ? 111 * 2 : 0, @bgbitmap.width, 111 * 2))
      else
        self.bitmap.blt(0, 0, @bgbitmap.bitmap, Rect.new(0, 111 * 2 * 2 + ((@selected) ? 23 * 2 : 0), @bgbitmap.width, 23 * 2))
      end
      
      textpos = []
      if @isContinue
        # Format title with save tag if present
        display_title = KIFR::SaveTags.format_title(@title, @kifr_save_tag)
        textpos.push([display_title, 16 * 2, 2 * 2, 0, TEXTCOLOR, TEXTSHADOWCOLOR])
        
        textpos.push([_INTL("Badges:"), 16 * 2, 53 * 2, 0, TEXTCOLOR, TEXTSHADOWCOLOR])
        textpos.push([@trainer.badge_count.to_s, 103 * 2, 53 * 2, 1, TEXTCOLOR, TEXTSHADOWCOLOR])
        textpos.push([_INTL("Pokédex:"), 16 * 2, 69 * 2, 0, TEXTCOLOR, TEXTSHADOWCOLOR])
        textpos.push([@trainer.pokedex.seen_count.to_s, 103 * 2, 69 * 2, 1, TEXTCOLOR, TEXTSHADOWCOLOR])
        textpos.push([_INTL("Time:"), 16 * 2, 85 * 2, 0, TEXTCOLOR, TEXTSHADOWCOLOR])
        
        hour = @totalsec / 60 / 60
        min = @totalsec / 60 % 60
        if hour > 0
          textpos.push([_INTL("{1}h {2}m", hour, min), 103 * 2, 85 * 2, 1, TEXTCOLOR, TEXTSHADOWCOLOR])
        else
          textpos.push([_INTL("{1}m", min), 103 * 2, 85 * 2, 1, TEXTCOLOR, TEXTSHADOWCOLOR])
        end
        
        if @trainer.male?
          textpos.push([@trainer.name, 56 * 2, 29 * 2, 0, MALETEXTCOLOR, MALETEXTSHADOWCOLOR])
        elsif @trainer.female?
          textpos.push([@trainer.name, 56 * 2, 29 * 2, 0, FEMALETEXTCOLOR, FEMALETEXTSHADOWCOLOR])
        else
          textpos.push([@trainer.name, 56 * 2, 29 * 2, 0, TEXTCOLOR, TEXTSHADOWCOLOR])
        end
        
        mapname = pbGetMapNameFromId(@mapid)
        mapname.gsub!(/\\PN/, @trainer.name)
        textpos.push([mapname, 193 * 2, 2 * 2, 1, TEXTCOLOR, TEXTSHADOWCOLOR])
      else
        textpos.push([@title, 16 * 2, 1 * 2, 0, TEXTCOLOR, TEXTSHADOWCOLOR])
      end
      
      pbDrawTextPositions(self.bitmap, textpos)
    end
    @refreshing = false
  end
end

#===============================================================================
# PokemonLoad_Scene - Add save tag parameter support
# Note: Must alias since base class is defined in core game scripts
#===============================================================================
class PokemonLoad_Scene
  alias kifr_savetag_orig_pbStartScene pbStartScene unless method_defined?(:kifr_savetag_orig_pbStartScene)
  
  def pbStartScene(commands, show_continue, trainer, frame_count, map_id, tag = nil)
    @kifr_save_tag = tag
    kifr_savetag_orig_pbStartScene(commands, show_continue, trainer, frame_count, map_id)
    
    # Update continue panel with the tag
    if show_continue && @sprites["panel0"] && @kifr_save_tag
      @sprites["panel0"].kifr_save_tag = @kifr_save_tag
      @sprites["panel0"].pbRefresh
    end
  end
end

#===============================================================================
# PokemonSave_Scene - Show tag in save confirmation window
# Note: Must alias since base class is defined in core game scripts
#===============================================================================
class PokemonSave_Scene
  alias kifr_savetag_orig_pbStartScreen pbStartScreen unless method_defined?(:kifr_savetag_orig_pbStartScreen)
  
  def pbStartScreen
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    
    totalsec = Graphics.frame_count / Graphics.frame_rate
    hour = totalsec / 60 / 60
    min = totalsec / 60 % 60
    mapname = $game_map.name
    
    textColor = ["0070F8,78B8E8", "E82010,F8A8B8", "0070F8,78B8E8"][$Trainer.gender]
    locationColor = "209808,90F090"
    
    loctext = _INTL("<ac><c3={1}>{2}</c3></ac>", locationColor, mapname)
    loctext += _INTL("Player<r><c3={1}>{2}</c3><br>", textColor, $Trainer.name)
    
    if hour > 0
      loctext += _INTL("Time<r><c3={1}>{2}h {3}m</c3><br>", textColor, hour, min)
    else
      loctext += _INTL("Time<r><c3={1}>{2}m</c3><br>", textColor, min)
    end
    
    loctext += _INTL("Badges<r><c3={1}>{2}</c3><br>", textColor, $Trainer.badge_count)
    
    if $Trainer.has_pokedex
      loctext += _INTL("Pokédex<r><c3={1}>{2}/{3}</c3><br>", textColor, 
                       $Trainer.pokedex.owned_count, $Trainer.pokedex.seen_count)
    end
    
    # Show save tag if set
    if KIFR::SaveTags.has_tag?
      loctext += _INTL("Tag<r><c3={1}>{2}</c3><br>", textColor, KIFR::SaveTags.current)
    end
    
    @sprites["locwindow"] = Window_AdvancedTextPokemon.new(loctext)
    @sprites["locwindow"].viewport = @viewport
    @sprites["locwindow"].x = 0
    @sprites["locwindow"].y = 0
    @sprites["locwindow"].width = 228 if @sprites["locwindow"].width < 228
    @sprites["locwindow"].visible = true
  end
end

KIFRSettings.debug_log("KIFR Title: Save Tags system loaded") if defined?(KIFRSettings)