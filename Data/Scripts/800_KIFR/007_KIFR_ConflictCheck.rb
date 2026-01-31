#===============================================================================
# KIF Redux Conflict Check - Mod Conflict Detection System
# Script Version: 1.1.0
# Author: Stonewall
#===============================================================================
# This file provides robust conflict detection for mods:
# - Detects method alias chains (multiple mods hooking same method)
# - Finds duplicate setting keys across mods
# - Identifies potential overwrites of methods/constants
# - Generates detailed conflict reports
# - Provides UI to view and manage conflicts
# - Supports dismissing/restoring conflicts with persistence
#===============================================================================

module KIFRConflictCheck
  # Conflict severity levels
  SEVERITY_INFO = 0      # Informational - may not be a problem
  SEVERITY_WARNING = 1   # Warning - could cause issues
  SEVERITY_ERROR = 2     # Error - likely to cause problems
  SEVERITY_CRITICAL = 3  # Critical - will break things
  
  SEVERITY_NAMES = {
    SEVERITY_INFO => "Info",
    SEVERITY_WARNING => "Warning",
    SEVERITY_ERROR => "Error",
    SEVERITY_CRITICAL => "Critical"
  }
  
  SEVERITY_COLORS = {
    SEVERITY_INFO => Color.new(128, 200, 255),      # Light blue
    SEVERITY_WARNING => Color.new(255, 200, 80),    # Yellow/orange
    SEVERITY_ERROR => Color.new(255, 120, 120),     # Light red
    SEVERITY_CRITICAL => Color.new(255, 60, 60)     # Bright red
  }
  
  # File for dismissed conflicts
  DISMISSED_FILE = "KIFR_Dismissed_Conflicts.kro"
  
  # Cache for dismissed conflicts
  @dismissed_conflicts = nil
  
  class << self
    #=========================================================================
    # MAIN CONFLICT DETECTION
    #=========================================================================
    
    # Run all conflict checks and return combined results
    # @param include_dismissed [Boolean] Include previously dismissed conflicts
    def detect_all_conflicts(include_dismissed = false)
      conflicts = []
      
      # 1. Check for method alias conflicts in mod files
      conflicts.concat(detect_alias_conflicts)
      
      # 2. Check for setting key duplicates
      conflicts.concat(detect_setting_conflicts)
      
      # 3. Check for constant redefinitions
      conflicts.concat(detect_constant_conflicts)
      
      # 4. Check for known problematic mod combinations
      conflicts.concat(detect_known_conflicts)
      
      # Filter out dismissed conflicts unless requested
      unless include_dismissed
        dismissed = load_dismissed_conflicts
        conflicts.reject! { |c| dismissed.include?(conflict_id(c)) }
      end
      
      # Sort by severity (highest first), then by mod name
      conflicts.sort_by { |c| [-c[:severity], c[:mod] || ""] }
    end
    
    # Generate unique ID for a conflict (for dismissal tracking)
    def conflict_id(conflict)
      id_parts = [conflict[:type].to_s]
      id_parts << conflict[:method].to_s if conflict[:method]
      id_parts << conflict[:key].to_s if conflict[:key]
      id_parts << conflict[:constant].to_s if conflict[:constant]
      id_parts << conflict[:mods].sort.join("_") if conflict[:mods]
      id_parts.join("_").gsub(/\s+/, "_").downcase[0..100]
    end
    
    #=========================================================================
    # DISMISSAL PERSISTENCE
    #=========================================================================
    
    # Get path to dismissed conflicts file
    def dismissed_file_path
      folder = KIFRSettings.kifr_folder rescue nil
      return nil unless folder
      File.join(folder, DISMISSED_FILE)
    end
    
    # Load dismissed conflicts from file
    def load_dismissed_conflicts
      return @dismissed_conflicts if @dismissed_conflicts
      
      @dismissed_conflicts = []
      file_path = dismissed_file_path
      return @dismissed_conflicts unless file_path && File.exist?(file_path)
      
      begin
        if defined?(kurayjson_load)
          data = kurayjson_load(file_path)
        else
          content = File.read(file_path)
          data = eval(content) rescue nil
        end
        
        @dismissed_conflicts = data if data.is_a?(Array)
      rescue => e
        KIFRSettings.debug_log("ConflictCheck: Error loading dismissed conflicts: #{e.message}")
      end
      
      @dismissed_conflicts
    end
    
    # Save dismissed conflicts to file
    def save_dismissed_conflicts
      file_path = dismissed_file_path
      return false unless file_path
      
      begin
        if defined?(kurayjson_save)
          kurayjson_save(file_path, @dismissed_conflicts || [])
        else
          File.open(file_path, 'w') { |f| f.write((@dismissed_conflicts || []).inspect) }
        end
        true
      rescue => e
        KIFRSettings.debug_log("ConflictCheck: Error saving dismissed conflicts: #{e.message}")
        false
      end
    end
    
    # Dismiss a conflict (won't show again)
    def dismiss_conflict(conflict)
      @dismissed_conflicts ||= []
      id = conflict_id(conflict)
      unless @dismissed_conflicts.include?(id)
        @dismissed_conflicts << id
        save_dismissed_conflicts
        KIFRSettings.debug_log("ConflictCheck: Dismissed conflict: #{id}")
      end
    end
    
    # Restore a dismissed conflict by ID
    def restore_conflict(conflict_id_str)
      @dismissed_conflicts ||= []
      if @dismissed_conflicts.delete(conflict_id_str)
        save_dismissed_conflicts
        KIFRSettings.debug_log("ConflictCheck: Restored conflict: #{conflict_id_str}")
        return true
      end
      false
    end
    
    # Clear all dismissed conflicts
    def clear_dismissed
      @dismissed_conflicts = []
      save_dismissed_conflicts
      KIFRSettings.debug_log("ConflictCheck: Cleared all dismissed conflicts")
    end
    
    # Get count of dismissed conflicts
    def dismissed_count
      load_dismissed_conflicts.length
    end
    
    # Get all dismissed conflict IDs
    def dismissed_ids
      load_dismissed_conflicts.dup
    end
    
    # Check if a conflict is dismissed
    def is_dismissed?(conflict)
      load_dismissed_conflicts.include?(conflict_id(conflict))
    end
    
    #=========================================================================
    # ALIAS CONFLICT DETECTION
    #=========================================================================
    
    # Scan mod files for alias_method calls and detect conflicts
    def detect_alias_conflicts
      conflicts = []
      alias_registry = {}  # { "Class#method" => [mod1, mod2, ...] }
      
      # Scan all mod files
      mod_files = collect_mod_files
      
      mod_files.each do |file_path|
        begin
          content = File.read(file_path)
          mod_name = File.basename(file_path)
          
          # Find all alias_method calls
          # Patterns: alias_method :new_name, :old_name
          #           alias_method(:new_name, :old_name)
          content.scan(/alias_method\s*[:(]\s*:?(\w+)\s*,\s*:?(\w+)/) do |new_name, old_name|
            # Try to determine the class context
            class_context = extract_class_context(content, $~.begin(0))
            key = "#{class_context}##{old_name}"
            
            alias_registry[key] ||= []
            alias_registry[key] << {
              mod: mod_name,
              file: file_path,
              alias_name: new_name,
              original_method: old_name,
              class_context: class_context
            }
          end
        rescue => e
          KIFRSettings.debug_log("ConflictCheck: Error reading #{file_path}: #{e.message}")
        end
      end
      
      # Check for conflicts (multiple mods aliasing same method)
      alias_registry.each do |method_key, aliases|
        next if aliases.length <= 1
        
        # Multiple mods hooking the same method
        mod_names = aliases.map { |a| a[:mod] }.uniq
        next if mod_names.length <= 1  # Same mod, different aliases - OK
        
        conflicts << {
          type: :alias_conflict,
          severity: SEVERITY_WARNING,
          method: method_key,
          mods: mod_names,
          details: aliases,
          description: "Multiple mods hook #{method_key}: #{mod_names.join(', ')}",
          suggestion: "These mods may conflict. Check if they work together correctly."
        }
      end
      
      conflicts
    end
    
    # Extract the class/module context for a position in code
    def extract_class_context(content, position)
      # Get content before the position
      before = content[0...position]
      
      # Find the most recent class/module definition
      # Look for patterns like "class Foo" or "module Bar" or "class Foo < Bar"
      classes = before.scan(/(?:class|module)\s+([A-Z][\w:]*)/i).flatten
      
      # Track nesting by counting class/module opens vs ends
      nesting = []
      before.scan(/(class|module)\s+([A-Z][\w:]*)|(\bend\b)/i) do |type, name, end_keyword|
        if end_keyword
          nesting.pop
        elsif name
          nesting.push(name)
        end
      end
      
      nesting.join("::").presence || "Unknown"
    end
    
    #=========================================================================
    # SETTING KEY CONFLICT DETECTION
    #=========================================================================
    
    # Check for duplicate setting keys across different mods
    def detect_setting_conflicts
      conflicts = []
      
      # Check KIFRSettings registry
      if defined?(KIFRSettings) && KIFRSettings.respond_to?(:registry)
        key_sources = {}
        
        KIFRSettings.registry.each do |entry|
          key = entry[:key]
          source = entry[:source] || entry[:category] || "Unknown"
          
          key_sources[key] ||= []
          key_sources[key] << source
        end
        
        key_sources.each do |key, sources|
          unique_sources = sources.uniq
          next if unique_sources.length <= 1
          
          conflicts << {
            type: :setting_duplicate,
            severity: SEVERITY_ERROR,
            key: key,
            sources: unique_sources,
            mod: unique_sources.first,
            description: "Setting key '#{key}' registered by multiple sources: #{unique_sources.join(', ')}",
            suggestion: "Rename one of the setting keys to avoid conflicts."
          }
        end
      end
      
      # Check ModSettingsMenu registry
      if defined?(ModSettingsMenu) && ModSettingsMenu.respond_to?(:registry)
        key_sources = {}
        
        ModSettingsMenu.registry.each do |entry|
          key = entry[:key]
          source = entry[:source] || entry[:category] || "Unknown"
          
          key_sources[key] ||= []
          key_sources[key] << source
        end
        
        key_sources.each do |key, sources|
          unique_sources = sources.uniq
          next if unique_sources.length <= 1
          
          conflicts << {
            type: :setting_duplicate,
            severity: SEVERITY_ERROR,
            key: key,
            sources: unique_sources,
            mod: unique_sources.first,
            description: "ModSettings key '#{key}' registered by multiple sources: #{unique_sources.join(', ')}",
            suggestion: "Rename one of the setting keys to avoid conflicts."
          }
        end
      end
      
      conflicts
    end
    
    #=========================================================================
    # CONSTANT CONFLICT DETECTION
    #=========================================================================
    
    # Scan mod files for constant definitions that might conflict
    def detect_constant_conflicts
      conflicts = []
      constant_registry = {}  # { "CONSTANT_NAME" => [mod1, mod2, ...] }
      
      # Important constants that shouldn't be redefined
      protected_constants = %w[
        POKEMON_COUNT TYPE_COUNT MOVE_COUNT ABILITY_COUNT
        SCREEN_WIDTH SCREEN_HEIGHT
      ]
      
      mod_files = collect_mod_files
      
      mod_files.each do |file_path|
        begin
          content = File.read(file_path)
          mod_name = File.basename(file_path)
          
          # Find top-level constant definitions (ALL_CAPS names)
          content.scan(/^\s*([A-Z][A-Z0-9_]+)\s*=/) do |const_name|
            const_name = const_name[0]
            
            constant_registry[const_name] ||= []
            constant_registry[const_name] << {
              mod: mod_name,
              file: file_path
            }
          end
        rescue => e
          # Skip unreadable files
        end
      end
      
      # Check for conflicts
      constant_registry.each do |const_name, definitions|
        mod_names = definitions.map { |d| d[:mod] }.uniq
        next if mod_names.length <= 1
        
        severity = protected_constants.include?(const_name) ? SEVERITY_ERROR : SEVERITY_WARNING
        
        conflicts << {
          type: :constant_conflict,
          severity: severity,
          constant: const_name,
          mods: mod_names,
          mod: mod_names.first,
          description: "Constant '#{const_name}' defined in multiple mods: #{mod_names.join(', ')}",
          suggestion: "Only the last-loaded definition will be used. This may cause unexpected behavior."
        }
      end
      
      conflicts
    end
    
    #=========================================================================
    # KNOWN CONFLICT DETECTION
    #=========================================================================
    
    # Check for known problematic mod combinations
    def detect_known_conflicts
      conflicts = []
      
      # Define known conflicts between specific mods
      known_conflicts = [
        {
          mods: ["Nuzlocke Plus", "Random Trades"],
          severity: SEVERITY_INFO,
          description: "Random Trades may give Pokemon that bypass Nuzlocke rules.",
          suggestion: "Consider disabling Random Trades during Nuzlocke runs."
        },
        {
          mods: ["Dynamic Randomiser", "evolution randomizer"],
          severity: SEVERITY_WARNING,
          description: "Both mods modify Pokemon/evolution data and may conflict.",
          suggestion: "Use only one randomizer at a time for best results."
        }
      ]
      
      # Get list of enabled mods
      enabled_mods = collect_enabled_mod_names
      
      known_conflicts.each do |kc|
        # Check if all mods in the conflict set are enabled
        matching = kc[:mods].select { |m| enabled_mods.any? { |em| em.downcase.include?(m.downcase) } }
        
        if matching.length >= 2
          conflicts << {
            type: :known_conflict,
            severity: kc[:severity],
            mods: matching,
            mod: matching.first,
            description: kc[:description],
            suggestion: kc[:suggestion]
          }
        end
      end
      
      conflicts
    end
    
    #=========================================================================
    # HELPER METHODS
    #=========================================================================
    
    # Collect all mod .rb files from Mods, Multiplayer, and KIFR directories
    def collect_mod_files
      files = []
      
      # Directories to scan for potential conflicts
      scan_dirs = [
        "Mods",
        "Data/Scripts/659_Multiplayer",
        "Data/Scripts/800_KIFR",
        "Data/Scripts/998_Mods"
      ]
      
      scan_dirs.each do |dir|
        next unless Dir.exist?(dir)
        
        # Recursively find all .rb files
        Dir.glob("#{dir}/**/*.rb").each do |file|
          # Skip disabled mods
          next if file.end_with?(".disabled")
          next if File.basename(file).start_with?("_")
          files << file
        end
      end
      
      files
    end
    
    # Get names of enabled mods
    def collect_enabled_mod_names
      names = []
      
      collect_mod_files.each do |file|
        names << File.basename(file, ".rb")
      end
      
      # Also check ModRegistry if available
      if defined?(KIFRSettings::ModRegistry)
        KIFRSettings::ModRegistry.all.each do |filename, info|
          names << (info[:name] || filename)
        end
      end
      
      names.uniq
    end
    
    #=========================================================================
    # REPORT GENERATION
    #=========================================================================
    
    # Generate a text report of all conflicts
    def generate_report
      conflicts = detect_all_conflicts
      
      if conflicts.empty?
        return "[OK] No conflicts detected!\n\nAll mods appear to be compatible."
      end
      
      report = "KIFR Conflict Report\n"
      report += "=" * 50 + "\n"
      report += "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n"
      report += "Total issues: #{conflicts.length}\n\n"
      
      # Group by severity
      by_severity = conflicts.group_by { |c| c[:severity] }
      
      [SEVERITY_CRITICAL, SEVERITY_ERROR, SEVERITY_WARNING, SEVERITY_INFO].each do |sev|
        items = by_severity[sev]
        next unless items && items.any?
        
        report += "#{SEVERITY_NAMES[sev].upcase} (#{items.length})\n"
        report += "-" * 40 + "\n"
        
        items.each do |conflict|
          report += "- #{conflict[:description]}\n"
          report += "  -> #{conflict[:suggestion]}\n" if conflict[:suggestion]
          report += "\n"
        end
        
        report += "\n"
      end
      
      report
    end
    
    # Save report to file
    def save_report(filename = "ConflictReport.txt")
      report = generate_report
      File.open(filename, 'w') { |f| f.write(report) }
      KIFRSettings.debug_log("Conflict report saved to #{filename}")
      filename
    end
    
    # Get conflict summary counts
    def get_summary
      conflicts = detect_all_conflicts
      
      {
        total: conflicts.length,
        critical: conflicts.count { |c| c[:severity] == SEVERITY_CRITICAL },
        errors: conflicts.count { |c| c[:severity] == SEVERITY_ERROR },
        warnings: conflicts.count { |c| c[:severity] == SEVERITY_WARNING },
        info: conflicts.count { |c| c[:severity] == SEVERITY_INFO }
      }
    end
    
    # Check if there are any serious conflicts
    def has_serious_conflicts?
      conflicts = detect_all_conflicts
      conflicts.any? { |c| c[:severity] >= SEVERITY_ERROR }
    end
  end
end

#===============================================================================
# CONFLICT RESULTS SCENE - Full conflict viewer with collapsible categories
#===============================================================================
class ConflictResultsScene < PokemonOption_Scene
  FADE_DURATION = 8 # Frames for fade in/out
  
  # Custom fade in with proper timing
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    # First make sprites visible but transparent
    sprites.each do |key, sprite|
      next unless sprite
      sprite.visible = true
      sprite.opacity = 0 if sprite.respond_to?(:opacity=)
    end
    
    # Gradually increase opacity
    FADE_DURATION.times do
      sprites.each do |key, sprite|
        next unless sprite && sprite.respond_to?(:opacity=)
        sprite.opacity += (255 / FADE_DURATION)
      end
      Graphics.update
      Input.update
    end
    
    # Ensure full opacity
    sprites.each do |key, sprite|
      next unless sprite && sprite.respond_to?(:opacity=)
      sprite.opacity = 255
    end
  end
  
  # Custom fade out with proper timing
  def pbFadeOutAndHide(sprites)
    # Gradually decrease opacity
    FADE_DURATION.times do
      sprites.each do |key, sprite|
        next unless sprite && sprite.respond_to?(:opacity=)
        sprite.opacity -= (255 / FADE_DURATION)
      end
      Graphics.update
      Input.update
    end
    
    # Hide all sprites
    sprites.each do |key, sprite|
      next unless sprite
      sprite.visible = false
      sprite.opacity = 0 if sprite.respond_to?(:opacity=)
    end
  end
  
  def initialize
    super()
    @conflicts = KIFRConflictCheck.detect_all_conflicts
    @conflicts_by_severity = @conflicts.group_by { |c| c[:severity] }
    
    # Track collapsed categories
    @collapsed = {
      critical: false,
      error: false,
      warning: false,
      info: false
    }
  end
  
  def initOptionsWindow
    optionsWindow = Window_UpdateResults.new(@PokemonOptions, 0,
                                             @sprites["title"].height, Graphics.width,
                                             Graphics.height - @sprites["title"].height - @sprites["textbox"].height)
    optionsWindow.setSkin(PokemonOption_Scene.get_kifr_windowskin)
    optionsWindow.nameBaseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    optionsWindow.nameShadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    optionsWindow.selBaseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    optionsWindow.selShadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    optionsWindow.viewport = @viewport
    optionsWindow.visible = false
    optionsWindow.opacity = 0
    return optionsWindow
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    # Save Report at top
    options << ButtonOption.new(_INTL("Save Report to File||"),
      proc { pbSaveReport },
      _INTL("Save the full conflict report to ConflictReport.txt"))
    
    # Restore Conflicts button (if any dismissed)
    dismissed_count = KIFRConflictCheck.dismissed_count
    if dismissed_count > 0
      options << ButtonOption.new(_INTL("Restore Conflicts ({1})||", dismissed_count),
        proc { pbRestoreConflicts },
        _INTL("Restore previously dismissed conflicts."))
    end
    
    # Critical (RED) - Collapsible
    critical = @conflicts_by_severity[KIFRConflictCheck::SEVERITY_CRITICAL] || []
    if critical.any?
      options << ConflictCategoryOption.new(
        :critical,
        "Critical (#{critical.length})", 
        "Will definitely cause problems - Click to expand/collapse", 
        :red,
        @collapsed[:critical],
        proc { toggle_category(:critical) }
      )
      
      unless @collapsed[:critical]
        critical.each do |conflict|
          text = format_conflict_name(conflict)
          callback = proc { pbConflictActions(conflict) }
          options << ButtonOption.new(text, callback, conflict[:description] || " ")
        end
      end
    end
    
    # Errors (ORANGE) - Collapsible
    errors = @conflicts_by_severity[KIFRConflictCheck::SEVERITY_ERROR] || []
    if errors.any?
      options << ConflictCategoryOption.new(
        :error,
        "Errors (#{errors.length})", 
        "Likely to cause problems - Click to expand/collapse", 
        :orange,
        @collapsed[:error],
        proc { toggle_category(:error) }
      )
      
      unless @collapsed[:error]
        errors.each do |conflict|
          text = format_conflict_name(conflict)
          callback = proc { pbConflictActions(conflict) }
          options << ButtonOption.new(text, callback, conflict[:description] || " ")
        end
      end
    end
    
    # Warnings (ORANGE) - Collapsible
    warnings = @conflicts_by_severity[KIFRConflictCheck::SEVERITY_WARNING] || []
    if warnings.any?
      options << ConflictCategoryOption.new(
        :warning,
        "Warnings (#{warnings.length})", 
        "Could cause issues - Click to expand/collapse", 
        :orange,
        @collapsed[:warning],
        proc { toggle_category(:warning) }
      )
      
      unless @collapsed[:warning]
        warnings.each do |conflict|
          text = format_conflict_name(conflict)
          callback = proc { pbConflictActions(conflict) }
          options << ButtonOption.new(text, callback, conflict[:description] || " ")
        end
      end
    end
    
    # Info (GREEN) - Collapsible
    info = @conflicts_by_severity[KIFRConflictCheck::SEVERITY_INFO] || []
    if info.any?
      options << ConflictCategoryOption.new(
        :info,
        "Info (#{info.length})", 
        "Informational - Click to expand/collapse", 
        :green,
        @collapsed[:info],
        proc { toggle_category(:info) }
      )
      
      unless @collapsed[:info]
        info.each do |conflict|
          text = format_conflict_name(conflict)
          callback = proc { pbConflictActions(conflict) }
          options << ButtonOption.new(text, callback, conflict[:description] || " ")
        end
      end
    end
    
    # No conflicts - show green message
    if @conflicts.empty?
      options << ColoredCategoryHeaderOption.new("No Conflicts Detected", "All mods appear compatible", :green)
    end
    
    return options
  end
  
  def toggle_category(category)
    @collapsed[category] = !@collapsed[category]
    refresh_options
  end
  
  def refresh_options
    # Rebuild options list
    @PokemonOptions = pbGetOptions
    
    # Recreate window
    old_index = @sprites["option"].index rescue 0
    @sprites["option"].dispose if @sprites["option"]
    
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = true
    @sprites["option"].opacity = 255
    
    # Apply theme directly to window
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    if @sprites["option"].respond_to?(:apply_color_theme)
      @sprites["option"].apply_color_theme(theme_index)
    elsif respond_to?(:apply_kifr_color_theme)
      apply_kifr_color_theme(@sprites["option"], theme_index)
    end
    
    if @sprites["option"] && @sprites["option"].respond_to?(:use_color_theme=)
      @sprites["option"].use_color_theme = true
    end
    
    # Restore index (clamped to valid range)
    max_index = @PokemonOptions.length - 1
    @sprites["option"].index = [old_index, max_index].min
    
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0) rescue 0
    end
    @sprites["option"].refresh
  end
  
  def format_conflict_name(conflict)
    # Use trailing || format so Window_UpdateResults draws it left-aligned
    case conflict[:type]
    when :alias_conflict
      method_name = conflict[:method].to_s.split('#').last rescue "method"
      "  Method Hook: #{method_name}||"
    when :setting_duplicate
      "  Duplicate Key: #{conflict[:key]}||"
    when :constant_conflict
      "  Constant: #{conflict[:constant]}||"
    when :known_conflict
      mods = conflict[:mods] || []
      "  Known Issue: #{mods.first || 'Mods'}||"
    else
      "  " + (conflict[:description] || "Unknown").to_s[0, 40] + "||"
    end
  end
  
  def pbConflictActions(conflict)
    commands = []
    commands << _INTL("View Details")
    commands << _INTL("Dismiss")
    commands << _INTL("Cancel")
    
    cmd = pbMessage(_INTL("What would you like to do?"), commands, commands.length)
    
    case cmd
    when 0  # View Details
      pbViewConflictDetails(conflict)
    when 1  # Dismiss
      KIFRConflictCheck.dismiss_conflict(conflict)
      pbMessage(_INTL("Conflict dismissed. It won't appear in future scans."))
      # Refresh the conflict list
      @conflicts = KIFRConflictCheck.detect_all_conflicts
      @conflicts_by_severity = @conflicts.group_by { |c| c[:severity] }
      refresh_options
    end
  end
  
  def pbViewConflictDetails(conflict)
    # Build content text like a changelog
    content = build_conflict_details_text(conflict)
    # Use pbFadeOutIn to properly transition
    pbFadeOutIn {
      ConflictDetailsScene.show(format_conflict_name(conflict).gsub("||", "").strip, content)
    }
  end
  
  def pbRestoreConflicts
    # Get all dismissed IDs and corresponding conflicts
    dismissed_ids = KIFRConflictCheck.dismissed_ids
    
    if dismissed_ids.empty?
      pbMessage(_INTL("No dismissed conflicts to restore."))
      return
    end
    
    # Get all conflicts including dismissed ones to show names
    all_conflicts = KIFRConflictCheck.detect_all_conflicts(true)
    
    # Build a list of dismissed conflicts with their display names
    dismissed_list = []
    dismissed_ids.each do |id|
      # Try to find the conflict with this ID
      conflict = all_conflicts.find { |c| KIFRConflictCheck.conflict_id(c) == id }
      if conflict
        name = format_conflict_name(conflict).gsub("||", "").strip
        dismissed_list << { id: id, name: name, conflict: conflict }
      else
        # Conflict no longer exists (mod removed?), show raw ID
        dismissed_list << { id: id, name: id, conflict: nil }
      end
    end
    
    # Build command list
    commands = dismissed_list.map { |d| d[:name] }
    commands << _INTL("Restore All")
    commands << _INTL("Cancel")
    
    cmd = pbMessage(_INTL("Select a conflict to restore:"), commands, commands.length)
    
    if cmd == commands.length - 2  # Restore All
      KIFRConflictCheck.clear_dismissed
      pbMessage(_INTL("All {1} conflicts restored.", dismissed_list.length))
      # Refresh
      @conflicts = KIFRConflictCheck.detect_all_conflicts
      @conflicts_by_severity = @conflicts.group_by { |c| c[:severity] }
      refresh_options
    elsif cmd < dismissed_list.length
      # Restore specific conflict
      item = dismissed_list[cmd]
      KIFRConflictCheck.restore_conflict(item[:id])
      pbMessage(_INTL("Conflict restored."))
      # Refresh
      @conflicts = KIFRConflictCheck.detect_all_conflicts
      @conflicts_by_severity = @conflicts.group_by { |c| c[:severity] }
      refresh_options
    end
  end
  
  def build_conflict_details_text(conflict)
    sev_name = KIFRConflictCheck::SEVERITY_NAMES[conflict[:severity]] || "Unknown"
    type_name = conflict[:type].to_s.gsub('_', ' ').capitalize
    
    lines = []
    lines << "Severity: #{sev_name}"
    lines << "Type: #{type_name}"
    lines << ""
    lines << "Description:"
    lines << (conflict[:description] || "No description available")
    lines << ""
    
    if conflict[:suggestion]
      lines << "Suggestion:"
      lines << conflict[:suggestion]
      lines << ""
    end
    
    if conflict[:mods] && conflict[:mods].any?
      lines << "Affected Mods:"
      conflict[:mods].each { |m| lines << "  - #{m}" }
      lines << ""
    end
    
    if conflict[:details] && conflict[:details].is_a?(Array)
      lines << "Details:"
      conflict[:details].each do |detail|
        if detail.is_a?(Hash)
          lines << "  - #{detail[:mod]}"
          lines << "    Alias: #{detail[:alias_name]} -> #{detail[:original_method]}"
        end
      end
    end
    
    lines.join("\n")
  end
  
  def pbSaveReport
    filename = KIFRConflictCheck.save_report
    pbMessage(_INTL("Report saved to {1}", filename))
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Build title with summary
    summary = KIFRConflictCheck.get_summary
    title_text = _INTL("Conflict Report")
    if summary[:total] > 0
      title_text += " (#{summary[:critical]}C/#{summary[:errors]}E/#{summary[:warnings]}W/#{summary[:info]}I)"
    end
    
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      title_text, 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    @sprites["title"].opacity = 0
    
    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].visible = false
    @sprites["textbox"].opacity = 0
    
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    
    # Apply color theme directly to the window
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    if @sprites["option"].respond_to?(:apply_color_theme)
      @sprites["option"].apply_color_theme(theme_index)
    elsif respond_to?(:apply_kifr_color_theme)
      apply_kifr_color_theme(@sprites["option"], theme_index)
    end
    
    if @sprites["option"] && @sprites["option"].respond_to?(:use_color_theme=)
      @sprites["option"].use_color_theme = true
    end
    
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0) rescue 0
    end
    @sprites["option"].refresh
    
    # Fade in
    pbFadeInAndShow(@sprites)
  end
  
  # Custom pbOptions to handle category clicking properly
  def pbOptions
    pbActivateWindow(@sprites, "option") {
      loop do
        Graphics.update
        Input.update
        pbUpdate
        
        # Handle mustUpdateOptions - but safely check for nil
        if @sprites["option"].mustUpdateOptions
          for i in 0...@PokemonOptions.length
            opt = @PokemonOptions[i]
            next if opt.nil?
            opt.set(@sprites["option"][i]) if opt.respond_to?(:set)
          end
        end
        
        # Handle back button
        if Input.trigger?(Input::BACK)
          break
        end
        
        # Handle USE button - for clicking categories and buttons
        if Input.trigger?(Input::USE)
          break if isConfirmedOnKeyPress
          
          current = @sprites["option"].index
          option = @PokemonOptions[current]
          
          if option
            # Handle ConflictCategoryOption clicks
            if option.is_a?(ConflictCategoryOption) && option.callback
              option.callback.call
            # Handle ButtonOption clicks  
            elsif option.is_a?(ButtonOption) && option.respond_to?(:activate)
              option.activate
            end
          end
        end
        
        # Update description
        current = @sprites["option"].index
        if current >= 0 && current < @PokemonOptions.length
          opt = @PokemonOptions[current]
          desc = opt.respond_to?(:description) ? (opt.description rescue "") : ""
          @sprites["textbox"].text = desc if @sprites["textbox"]
        elsif current == @PokemonOptions.length
          @sprites["textbox"].text = _INTL("Return to KIFR Settings.") if @sprites["textbox"]
        end
      end
    }
  end
  
  def pbEndScene
    # Fade out before disposing
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose if @viewport
  end
end

#===============================================================================
# CONFLICT CATEGORY OPTION - Category header matching KIFRCategoryHeaderOption style
#===============================================================================
class ConflictCategoryOption
  attr_reader :name, :color, :callback
  attr_accessor :category_key
  
  def initialize(category_key, display_name, description, color, collapsed, callback)
    @category_key = category_key
    @display_name = display_name
    @description = description
    @color = color
    @collapsed = collapsed
    @callback = callback
  end
  
  def non_interactive?
    true  # Can still be clicked, but doesn't scroll left/right
  end
  
  def get
    @collapsed ? 1 : 0
  end
  
  def set(value)
    @callback.call if @callback
  end
  
  # Format display text with collapse indicator (matching KIFR settings style)
  def format(value)
    indicator = value == 1 ? "+" : "-"
    "#{indicator} #{@display_name} #{indicator}"
  end
  
  def name
    indicator = @collapsed ? "+" : "-"
    "#{indicator} #{@display_name} #{indicator}"
  end
  
  def values
    [""]
  end
  
  def next(current)
    current  # No change on right arrow
  end
  
  def prev(current)
    current  # No change on left arrow
  end
  
  def description
    @description || ""
  end
end

#===============================================================================
# CONFLICT DETAILS SCENE - Shows detailed info about a specific conflict
#===============================================================================
class ConflictDetailsScene
  FADE_DURATION = 8 # Frames for fade in/out
  
  def initialize(title, details_text)
    @title = title
    @details_text = details_text
    
    lines = details_text.split("\n")
    @header = title
    @content = details_text
    
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
  end
  
  # Custom fade in with proper timing
  def pbFadeInAndShow(sprites)
    # First make sprites visible but transparent
    sprites.each do |key, sprite|
      next unless sprite
      sprite.visible = true
      sprite.opacity = 0 if sprite.respond_to?(:opacity=)
    end
    
    # Gradually increase opacity
    FADE_DURATION.times do
      sprites.each do |key, sprite|
        next unless sprite && sprite.respond_to?(:opacity=)
        sprite.opacity += (255 / FADE_DURATION)
      end
      Graphics.update
      Input.update
    end
    
    # Ensure full opacity
    sprites.each do |key, sprite|
      next unless sprite && sprite.respond_to?(:opacity=)
      sprite.opacity = 255
    end
  end
  
  # Custom fade out with proper timing
  def pbFadeOutAndHide(sprites)
    # Gradually decrease opacity
    FADE_DURATION.times do
      sprites.each do |key, sprite|
        next unless sprite && sprite.respond_to?(:opacity=)
        sprite.opacity -= (255 / FADE_DURATION)
      end
      Graphics.update
      Input.update
    end
    
    # Hide all sprites
    sprites.each do |key, sprite|
      next unless sprite
      sprite.visible = false
      sprite.opacity = 0 if sprite.respond_to?(:opacity=)
    end
  end
  
  def pbStartScene
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      @header, 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    @sprites["title"].opacity = 0
    
    @sprites["textbox"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].text = _INTL("B: Back")
    @sprites["textbox"].visible = false
    @sprites["textbox"].opacity = 0
    
    content_y = 64  # title height
    content_height = Graphics.height - 64 - 64  # title - textbox
    
    wrapped_lines = []
    @content.split("\n").each do |line|
      if line.strip.empty?
        wrapped_lines << ""
      else
        words = line.split(" ")
        current_line = ""
        words.each do |word|
          test_line = current_line.empty? ? word : "#{current_line} #{word}"
          if test_line.length > 50
            wrapped_lines << current_line unless current_line.empty?
            current_line = word
          else
            current_line = test_line
          end
        end
        wrapped_lines << current_line unless current_line.empty?
      end
    end
    
    @sprites["content"] = Window_CommandPokemon.newWithSize(
      wrapped_lines, 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["content"].baseColor = Color.new(248, 248, 248)
    @sprites["content"].shadowColor = Color.new(0, 0, 0)
    @sprites["content"].index = 0
    @sprites["content"].visible = false
    @sprites["content"].opacity = 0
    
    # Fade in
    pbFadeInAndShow(@sprites)
  end
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
  
  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdate
      
      # Scrolling (UP/DOWN and LEFT/RIGHT)
      if Input.repeat?(Input::UP) || Input.repeat?(Input::LEFT)
        @sprites["content"].index -= 1 if @sprites["content"].index > 0
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::RIGHT)
        max_index = @sprites["content"].commands.length - 1
        @sprites["content"].index += 1 if @sprites["content"].index < max_index
      elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
        break  # Only exits this scene, not the parent
      end
    end
  end
  
  def pbEndScene
    # Fade out before disposing
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  def self.show(title, details_text)
    scene = ConflictDetailsScene.new(title, details_text)
    scene.pbStartScene
    scene.pbScene
    scene.pbEndScene
  end
end

#===============================================================================
# INTEGRATION WITH KIFR SETTINGS
#===============================================================================
class KIFRSettingsScene
  def show_conflict_viewer
    scene = ConflictResultsScene.new
    screen = PokemonOptionScreen.new(scene)
    screen.pbStartScreen
  end
end
