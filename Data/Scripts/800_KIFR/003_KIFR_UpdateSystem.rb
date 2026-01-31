#===============================================================================
# KIF Redux Update System - Registration, Version Checking, Auto-Updates
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file contains:
# - Registration API (register, register_toggle, register_enum, etc.)
# - On-change callback system
# - ModRegistry (mod self-registration for updates)
# - VersionCheck (collect local mod versions)
# - UpdateCheck (compare with remote versions)
# - ModUpdater (download, backup, install, ZIP handling)
# - ModUpdatesScene, UpdateResultsScene, ChangelogScene
# - Auto-update notification system
#===============================================================================

#===============================================================================
# REGISTRATION API
#===============================================================================
module KIFRSettings
  # Registry for all registered settings
  @registry = []
  @on_change_registry = {}
  @pending_registrations = []
  
  class << self
    # Get the registry array
    def registry
      @registry ||= []
    end
    
    # Get pending registrations
    def pending_registrations
      @pending_registrations ||= []
    end
    
    # Get on_change registry
    def on_change_registry
      @on_change_registry ||= {}
    end
    
    #===========================================================================
    # Simplified Registration API (Hash-based)
    #===========================================================================
    
    # Register a setting using a hash of options
    # @param key [Symbol] Unique identifier for the setting
    # @param options [Hash] Configuration options
    #   :name [String] Display name (required)
    #   :type [Symbol] :toggle, :enum, :number, :slider, :button (required)
    #   :description [String] Help text (default: "")
    #   :default [Object] Default value (default: 0)
    #   :category [String] Category name (default: "Uncategorized")
    #   :values [Array] For :enum - array of option strings
    #   :min/:max [Integer] For :number/:slider - value range
    #   :interval [Integer] For :slider - step size (default: 1)
    #   :on_change [Proc] Callback when value changes
    #   :on_press [Proc] For :button - action when pressed
    #   :searchable_items [Array] Keywords for search
    # @return [Boolean] Success or failure
    def register(key, options = {})
      key = key.to_sym
      
      # Validation
      unless options[:name]
        debug_log("KIFR Update System: WARNING: Registration '#{key}' missing required :name")
        return false
      end
      
      unless [:toggle, :enum, :number, :slider, :button].include?(options[:type])
        debug_log("KIFR Update System: WARNING: Registration '#{key}' has invalid type: #{options[:type]}")
        return false
      end
      
      # Set defaults
      options[:description] ||= ""
      options[:default] ||= 0
      options[:category] ||= "Uncategorized"
      
      # Validate category
      unless valid_category?(options[:category]) || options[:category] == NOCATEGORY
        debug_log("KIFR Update System: WARNING: Registration '#{key}' uses unknown category: #{options[:category]}")
      end
      
      # Build the option object based on type
      opt = case options[:type]
      when :toggle
        ensure_storage(key, options[:default])
        EnumOption.new(
          options[:name],
          [_INTL("Off"), _INTL("On")],
          proc { get(key) || 0 },
          proc { |value| set(key, value) },
          options[:description]
        )
        
      when :enum
        unless options[:values] && options[:values].is_a?(Array)
          debug_log("KIFR Update System: WARNING: Registration '#{key}' is :enum but missing :values array")
          return false
        end
        ensure_storage(key, options[:default])
        EnumOption.new(
          options[:name],
          options[:values],
          proc { get(key) || 0 },
          proc { |value| set(key, value) },
          options[:description]
        )
        
      when :number
        min = options[:min] || 0
        max = options[:max] || 100
        ensure_storage(key, options[:default])
        NumberOption.new(
          options[:name],
          min, max,
          proc { get(key) || min },
          proc { |value| set(key, value) },
          options[:description]
        )
        
      when :slider
        min = options[:min] || 0
        max = options[:max] || 100
        interval = options[:interval] || 1
        ensure_storage(key, options[:default])
        StoneSliderOption.new(
          options[:name],
          min, max, interval,
          proc { get(key) || min },
          proc { |value| set(key, value) },
          options[:description]
        )
        
      when :button
        callback = options[:on_press] || options[:callback] || proc {}
        ButtonOption.new(
          options[:name],
          callback,
          options[:description]
        )
      end
      
      return false unless opt
      
      # Register on_change callback if provided
      if options[:on_change] && options[:on_change].is_a?(Proc)
        register_on_change(key, &options[:on_change])
      end
      
      # Add to registry
      entry = {
        key: key,
        option: opt,
        category: options[:category],
        searchable_items: options[:searchable_items] || []
      }
      
      # Remove existing entry with same key
      registry.reject! { |e| e[:key] == key }
      registry << entry
      
      debug_log("KIFR Update System: Registered setting: #{key} (#{options[:type]}) in category '#{options[:category]}'")
      true
    end
    
    #===========================================================================
    # Traditional Registration Methods
    #===========================================================================
    
    # Register a toggle (On/Off) setting
    def register_toggle(key, name, description = "", default = 0, category = "Uncategorized")
      register(key, {
        name: name,
        type: :toggle,
        description: description,
        default: default,
        category: category
      })
    end
    
    # Register an enum (multiple choice) setting
    def register_enum(key, name, values, default = 0, description = "", category = "Uncategorized")
      register(key, {
        name: name,
        type: :enum,
        values: values,
        description: description,
        default: default,
        category: category
      })
    end
    
    # Register a number setting
    def register_number(key, name, min, max, default = nil, description = "", category = "Uncategorized")
      register(key, {
        name: name,
        type: :number,
        min: min,
        max: max,
        description: description,
        default: default || min,
        category: category
      })
    end
    
    # Register a slider setting
    def register_slider(key, name, min, max, interval = 1, default = nil, description = "", category = "Uncategorized")
      register(key, {
        name: name,
        type: :slider,
        min: min,
        max: max,
        interval: interval,
        description: description,
        default: default || min,
        category: category
      })
    end
    
    # Register a button
    def register_button(key, name, callback, description = "", category = "Uncategorized")
      register(key, {
        name: name,
        type: :button,
        on_press: callback,
        description: description,
        category: category
      })
    end
    
    # Register a custom option object
    def register_option(option, key, category = "Uncategorized", searchable_items = [])
      key = key.to_sym
      
      entry = {
        key: key,
        option: option,
        category: category,
        searchable_items: searchable_items
      }
      
      registry.reject! { |e| e[:key] == key }
      registry << entry
      
      debug_log("KIFR Update System: Registered custom option: #{key} in category '#{category}'")
      true
    end
    
    #===========================================================================
    # On-Change Callbacks
    #===========================================================================
    
    # Register a callback to be invoked when a setting changes
    def register_on_change(key, &block)
      key = key.to_sym
      on_change_registry[key] ||= []
      on_change_registry[key] << block
    end
    
    # Invoke on_change callbacks for a key
    def invoke_on_change(key, new_value, old_value)
      key = key.to_sym
      return unless on_change_registry[key]
      
      on_change_registry[key].each do |callback|
        begin
          callback.call(new_value, old_value)
        rescue => e
          debug_log("KIFR Update System: ERROR: on_change callback for #{key}: #{e.message}")
        end
      end
    end
    
    #===========================================================================
    # Pending Registrations (for mods that load before KIFR)
    #===========================================================================
    
    # Queue a registration for later processing
    def queue_registration(key, options)
      pending_registrations << { key: key, options: options }
    end
    
    # Process all pending registrations
    def process_pending_registrations
      pending_registrations.each do |pending|
        register(pending[:key], pending[:options])
      end
      pending_registrations.clear
    end
    
    #===========================================================================
    # Conflict Detection
    #===========================================================================
    
    # Detect potential conflicts between registered settings
    def detect_conflicts
      conflicts = []
      
      # Check for duplicate keys
      keys = registry.map { |e| e[:key] }
      duplicates = keys.select { |k| keys.count(k) > 1 }.uniq
      duplicates.each do |dup|
        conflicts << { type: :duplicate_key, key: dup }
      end
      
      conflicts
    end
    
    # Generate a conflict report
    def generate_conflict_report
      conflicts = detect_conflicts
      return "No conflicts detected." if conflicts.empty?
      
      report = "KIFR Conflict Report\n"
      report += "=" * 40 + "\n\n"
      
      conflicts.each do |conflict|
        case conflict[:type]
        when :duplicate_key
          report += "Duplicate key: #{conflict[:key]}\n"
        end
      end
      
      report
    end
  end
  
  #=============================================================================
  # MOD REGISTRY - Mod Self-Registration for Updates
  #=============================================================================
  module ModRegistry
    @registered_mods = {}
    
    class << self
      # Get all registered mods
      def all
        @registered_mods ||= {}
      end
      
      # Get all external (non-internal) mods
      def external_mods
        all.reject { |_, info| info[:internal] }
      end
      
      # Register a mod for update checking
      # @param info [Hash] Mod information
      #   :name [String] Display name
      #   :file [String] Filename (e.g., "MyMod.rb")
      #   :version [String] Current version (e.g., "1.0.0")
      #   :download_url [String] URL to download updates
      #   :version_check_url [String] URL to check version (required for ZIP downloads)
      #   :changelog_url [String] URL to view changelog
      #   :graphics [Array] Graphics files to download
      #   :dependencies [Array] Required dependencies
      #   :internal [Boolean] If true, this is an internal KIFR module (not a user mod)
      def register(info)
        return unless info.is_a?(Hash) && info[:file]
        
        existing = @registered_mods[info[:file]]
        is_new = existing.nil?
        version_changed = existing && existing[:version] != info[:version]
        
        @registered_mods[info[:file]] = {
          name: info[:name] || info[:file],
          file: info[:file],
          version: info[:version] || "0.0.0",
          download_url: info[:download_url],
          version_check_url: info[:version_check_url],
          changelog_url: info[:changelog_url],
          graphics: info[:graphics] || [],
          dependencies: info[:dependencies] || [],
          internal: info[:internal] || false
        }
        
        if is_new || version_changed
          KIFRSettings.debug_log("KIFR Update System: ModRegistry registered #{info[:file]} v#{info[:version]}#{info[:internal] ? ' (internal)' : ''}")
        end
      end
      
      # Get a specific mod by filename
      def get(filename)
        all[filename]
      end
      
      # Check if a mod is registered
      def registered?(filename)
        all.key?(filename)
      end
      
      # Clear all registered mods
      def clear
        @registered_mods = {}
      end
    end
  end
  
  #=============================================================================
  # VERSION CHECK - Collect Local Mod Versions
  #=============================================================================
  module VersionCheck
    SEARCH_DIRS = ["Mods", "Mods/Stone's Mods"]
    MAX_HEADER_LINES = 40
    
    class << self
      # Collect all local mods with version info
      # @param include_internal [Boolean] Whether to include internal KIFR modules
      def collect(include_internal = true)
        KIFRSettings.debug_log("KIFR Update System: Collecting local mod versions...")
        mods = []
        registered = include_internal ? ModRegistry.all : ModRegistry.external_mods
        scanned_filenames = []
        
        # Add registered mods first
        registered.each do |filename, info|
          path = find_mod_path(filename)
          scanned_filenames << filename.downcase
          
          mod_name = File.basename(filename, ".rb")
          mods << {
            name: mod_name,
            version: info[:version],
            path: path,
            display_name: info[:name] || mod_name,
            registered: true,
            internal: info[:internal] || false
          }
        end
        
        KIFRSettings.debug_log("KIFR Update System: Found #{registered.length} registered mods")
        
        # Scan directories for unregistered mods
        unregistered_count = 0
        SEARCH_DIRS.each do |dir|
          next unless Dir.exist?(dir)
          
          Dir.glob(File.join(dir, "*.rb")).each do |file_path|
            filename = File.basename(file_path)
            next if scanned_filenames.include?(filename.downcase)
            
            mod_name = File.basename(filename, ".rb")
            version = extract_version_from_header(file_path)
            
            mods << {
              name: mod_name,
              version: version || "",
              path: File.expand_path(file_path),
              display_name: mod_name,
              registered: false,
              internal: false
            }
            unregistered_count += 1
          end
        end
        
        KIFRSettings.debug_log("KIFR Update System: Found #{unregistered_count} unregistered mods in search directories")
        KIFRSettings.debug_log("KIFR Update System: Total mods collected: #{mods.length}")
        
        mods.sort_by! { |m| m[:display_name].downcase }
        mods
      end
      
      # Extract version from file header
      def extract_version_from_header(file_path)
        return nil unless File.exist?(file_path)
        
        line_count = 0
        File.open(file_path, "r") do |file|
          file.each_line do |line|
            line_count += 1
            break if line_count > MAX_HEADER_LINES
            
            if line =~ /^#\s*Script Version:\s*(\d+\.\d+(?:\.\d+)?)/i
              return $1
            end
          end
        end
        nil
      rescue
        nil
      end
      
      # Find the path to a mod file
      def find_mod_path(filename)
        SEARCH_DIRS.each do |dir|
          path = File.join(dir, filename)
          return File.expand_path(path) if File.exist?(path)
        end
        File.expand_path(File.join("Mods", filename))
      end
    end
  end
  
  #=============================================================================
  # UPDATE CHECK - Compare Local with Remote Versions
  #=============================================================================
  module UpdateCheck
    class << self
      # Check for updates on all registered mods (excludes internal KIFR modules)
      def check_updates
        KIFRSettings.debug_log("KIFR Update System: Starting update check...")
        
        # Exclude internal mods from update checks
        local_mods = VersionCheck.collect(false)
        if local_mods.nil? || local_mods.empty?
          KIFRSettings.debug_log("KIFR Update System: ERROR: No local mods found")
          return { error: "No local mods found." }
        end
        
        KIFRSettings.debug_log("KIFR Update System: Found #{local_mods.length} local mods to check")
        
        registered_mods = ModRegistry.external_mods
        KIFRSettings.debug_log("KIFR Update System: Found #{registered_mods.length} registered mods")
        
        results = {
          up_to_date: [],
          hotfixes: [],
          minor_updates: [],
          major_updates: [],
          developer_version: [],
          not_tracked: [],
          check_failed: []
        }
        
        # Check KIF Redux first (always at top of mod list)
        KIFRSettings.debug_log("KIFR Update System: Checking KIF Redux...")
        check_kifr_update(results)
        
        # Check Multiplayer mod second (right after KIF Redux in display order)
        KIFRSettings.debug_log("KIFR Update System: Checking Multiplayer mod...")
        check_multiplayer_update(results)
        
        local_mods.each do |mod|
          mod_name = mod[:name]
          mod_file = "#{mod_name}.rb"
          
          # Skip KIF Redux since we already checked it above
          if mod_name == "KIF Redux" || mod[:display_name] == "KIF Redux"
            next
          end
          
          if mod[:registered] && registered_mods.key?(mod_file)
            reg = registered_mods[mod_file]
            
            download_url = reg[:download_url]
            version_check_url = reg[:version_check_url]
            changelog_url = reg[:changelog_url]
            graphics = reg[:graphics]
            dependencies = reg[:dependencies]
            
            KIFRSettings.debug_log("KIFR Update System: Checking #{mod[:display_name]} (local: #{mod[:version]})...")
            
            # Fetch remote version
            online_version = fetch_remote_version(download_url, version_check_url)
            
            unless online_version
              KIFRSettings.debug_log("KIFR Update System: ERROR: Failed to fetch remote version for #{mod[:display_name]}")
              results[:check_failed] << {
                name: mod[:display_name],
                version: mod[:version],
                url: download_url
              }
              next
            end
            
            KIFRSettings.debug_log("KIFR Update System: #{mod[:display_name]} - Local: #{mod[:version]}, Online: #{online_version}")
            
            local_parsed = parse_version(mod[:version])
            online_parsed = parse_version(online_version)
            
            local_ver, local_has_patch = local_parsed
            online_ver, online_has_patch = online_parsed
            
            local_major, local_minor, local_patch = local_ver
            online_major, online_minor, online_patch = online_ver
            
            update_info = {
              name: mod[:display_name],
              mod_name: mod_name,
              local: mod[:version],
              online: online_version,
              path: mod[:path],
              download_url: download_url,
              changelog_url: changelog_url,
              graphics: graphics,
              dependencies: dependencies
            }
            
            # Categorize by version comparison
            if local_major > online_major ||
               (local_major == online_major && local_minor > online_minor) ||
               (local_major == online_major && local_minor == online_minor && local_patch > online_patch)
              results[:developer_version] << update_info
              KIFRSettings.debug_log("KIFR Update System: #{mod[:display_name]} - Developer version (ahead of release)")
            elsif local_major < online_major
              results[:major_updates] << update_info
              KIFRSettings.debug_log("KIFR Update System: #{mod[:display_name]} - MAJOR update available!")
            elsif local_minor < online_minor
              results[:minor_updates] << update_info
              KIFRSettings.debug_log("KIFR Update System: #{mod[:display_name]} - Minor update available")
            elsif (local_has_patch && local_patch < online_patch) || (!local_has_patch && online_patch > 0)
              results[:hotfixes] << update_info
              KIFRSettings.debug_log("KIFR Update System: #{mod[:display_name]} - Hotfix available")
            else
              results[:up_to_date] << update_info
              KIFRSettings.debug_log("KIFR Update System: #{mod[:display_name]} - Up to date")
            end
          else
            results[:not_tracked] << { name: mod[:display_name], version: mod[:version] }
            KIFRSettings.debug_log("KIFR Update System: #{mod[:display_name]} - Not tracked (no registration)")
          end
        end
        
        # Log summary
        total_updates = results[:major_updates].length + results[:minor_updates].length + results[:hotfixes].length
        KIFRSettings.debug_log("KIFR Update System: Update check complete!")
        KIFRSettings.debug_log("KIFR Update System: Summary - Updates: #{total_updates}, Up-to-date: #{results[:up_to_date].length}, Failed: #{results[:check_failed].length}, Not tracked: #{results[:not_tracked].length}")
        
        results
      end
      
      # Fetch the remote version from URL
      def fetch_remote_version(url, version_check_url = nil)
        check_url = version_check_url || url
        if check_url.nil? || check_url.empty?
          KIFRSettings.debug_log("KIFR Update System: No URL provided for version check")
          return nil
        end
        
        begin
          KIFRSettings.debug_log("KIFR Update System: Fetching version from: #{check_url}")
          
          unless defined?(HTTPLite)
            KIFRSettings.debug_log("KIFR Update System: ERROR: HTTPLite not available")
            return nil
          end
          
          response = HTTPLite.get(check_url)
          
          unless response.is_a?(Hash)
            KIFRSettings.debug_log("KIFR Update System: ERROR: Invalid response type: #{response.class}")
            return nil
          end
          
          unless response[:status] == 200
            KIFRSettings.debug_log("KIFR Update System: ERROR: HTTP #{response[:status]} from #{check_url}")
            return nil
          end
          
          content = response[:body]
          
          # Try multiple version patterns
          
          # Pattern 1: VERSION = "x.x.x" (used by KIFR)
          if content =~ /VERSION\s*=\s*["']([\d.]+)["']/
            KIFRSettings.debug_log("KIFR Update System: Found version: #{$1}")
            return $1
          end
          
          # Pattern 2: ModRegistry.register with version:
          reg_pos = content.index(/(?:KIFRSettings|ModSettingsMenu)::ModRegistry\.register\s*\(/) ||
                    content.index(/ModRegistry\.register\s*\(/)
          
          if reg_pos
            chunk = content[reg_pos, 2000]
            if chunk =~ /version:\s*["']([^"']+)["']/
              KIFRSettings.debug_log("KIFR Update System: Found version: #{$1}")
              return $1
            end
          end
          
          # Pattern 3: Script Version: x.x.x in header comments
          if content =~ /Script Version:\s*([\d.]+)/i
            KIFRSettings.debug_log("KIFR Update System: Found version: #{$1}")
            return $1
          end
          
          KIFRSettings.debug_log("KIFR Update System: ERROR: Could not parse version from response")
          nil
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: Fetching remote version failed: #{e.class} - #{e.message}")
          nil
        end
      end
      
      # Check Multiplayer mod for updates (special handling - not in ModRegistry)
      def check_multiplayer_update(results)
        begin
          # Check local version from 002_Version.rb
          local_version = nil
          version_file = File.join(Dir.pwd, "Data", "Scripts", "659_Multiplayer", "002_Version.rb")
          
          unless File.exist?(version_file)
            KIFRSettings.debug_log("KIFR Update System: Multiplayer version file not found at #{version_file}")
            return
          end
          
          content = File.read(version_file)
          if content =~ /CURRENT_VERSION\s*=\s*["']([^"']+)["']/
            local_version = $1
          end
          
          unless local_version
            KIFRSettings.debug_log("KIFR Update System: Multiplayer could not parse version from file")
            return
          end
          
          # Fetch online version
          online_version = nil
          if defined?(HTTPLite)
            response = HTTPLite.get("https://raw.githubusercontent.com/skarreku/KIF-Multiplayer/main/version.txt")
            if response.is_a?(Hash) && response[:status] == 200
              online_version = response[:body].to_s.strip
            end
          end
          
          update_info = {
            name: "Multiplayer",
            mod_name: "Multiplayer",
            local: local_version,
            online: online_version || "?",
            path: version_file,
            download_url: "autoupdate_multiplayer.bat", # Special flag for batch file updater
            changelog_url: nil,
            graphics: nil,
            dependencies: nil,
            is_multiplayer: true # Flag for special handling
          }
          
          unless online_version
            results[:check_failed] << {
              name: "Multiplayer",
              version: local_version,
              url: "https://raw.githubusercontent.com/skarreku/KIF-Multiplayer/main/version.txt"
            }
            return
          end
          
          # Compare versions
          local_parsed = parse_version(local_version)
          online_parsed = parse_version(online_version)
          
          local_ver, local_has_patch = local_parsed
          online_ver, online_has_patch = online_parsed
          
          local_major, local_minor, local_patch = local_ver
          online_major, online_minor, online_patch = online_ver
          
          # Categorize by version comparison - insert at index 1 (after KIF Redux)
          if local_major > online_major ||
             (local_major == online_major && local_minor > online_minor) ||
             (local_major == online_major && local_minor == online_minor && local_patch > online_patch)
            results[:developer_version].insert([1, results[:developer_version].length].min, update_info)
          elsif local_major < online_major
            results[:major_updates].insert([1, results[:major_updates].length].min, update_info)
          elsif local_minor < online_minor
            results[:minor_updates].insert([1, results[:minor_updates].length].min, update_info)
          elsif (local_has_patch && local_patch < online_patch) || (!local_has_patch && online_patch > 0)
            results[:hotfixes].insert([1, results[:hotfixes].length].min, update_info)
          else
            results[:up_to_date].insert([1, results[:up_to_date].length].min, update_info)
          end
          
          KIFRSettings.debug_log("KIFR Update System: Multiplayer version check - Local: #{local_version}, Online: #{online_version}")
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: Multiplayer update check failed: #{e.class} - #{e.message}")
        end
      end
      
      # Check KIF Redux update (appears at top of mod list)
      def check_kifr_update(results)
        begin
          local_version = KIFRSettings::VERSION
          
          unless local_version
            KIFRSettings.debug_log("KIFR Update System: ERROR: KIF Redux version not defined")
            return
          end
          
          # Fetch online version from GitHub
          online_version = nil
          version_check_url = "https://raw.githubusercontent.com/Stonewallx/KIF-Redux/refs/heads/main/Data/Scripts/800_KIFR/000_KIFR_Version.rb"
          
          if defined?(HTTPLite)
            response = HTTPLite.get(version_check_url)
            if response.is_a?(Hash) && response[:status] == 200
              content = response[:body].to_s
              # Parse VERSION constant from the file
              if content =~ /VERSION\s*=\s*["']([^"']+)["']/
                online_version = $1
              end
            end
          end
          
          update_info = {
            name: "KIF Redux",
            mod_name: "KIF Redux",
            local: local_version,
            online: online_version || "?",
            path: File.join(Dir.pwd, "Data", "Scripts", "800_KIFR", "000_KIFR_Version.rb"),
            download_url: nil,
            changelog_url: nil,
            graphics: nil,
            dependencies: nil,
            is_kifr: true # Flag for special handling
          }
          
          unless online_version
            results[:check_failed].unshift({
              name: "KIF Redux",
              version: local_version,
              url: version_check_url
            })
            KIFRSettings.debug_log("KIFR Update System: ERROR: Could not fetch KIF Redux online version")
            return
          end
          
          # Compare versions
          local_parsed = parse_version(local_version)
          online_parsed = parse_version(online_version)
          
          local_ver, local_has_patch = local_parsed
          online_ver, online_has_patch = online_parsed
          
          local_major, local_minor, local_patch = local_ver
          online_major, online_minor, online_patch = online_ver
          
          # Categorize by version comparison - use unshift to insert at beginning
          if local_major > online_major ||
             (local_major == online_major && local_minor > online_minor) ||
             (local_major == online_major && local_minor == online_minor && local_patch > online_patch)
            results[:developer_version].unshift(update_info)
            KIFRSettings.debug_log("KIFR Update System: KIF Redux - Developer version (ahead of release)")
          elsif local_major < online_major
            results[:major_updates].unshift(update_info)
            KIFRSettings.debug_log("KIFR Update System: KIF Redux - MAJOR update available!")
          elsif local_minor < online_minor
            results[:minor_updates].unshift(update_info)
            KIFRSettings.debug_log("KIFR Update System: KIF Redux - Minor update available")
          elsif (local_has_patch && local_patch < online_patch) || (!local_has_patch && online_patch > 0)
            results[:hotfixes].unshift(update_info)
            KIFRSettings.debug_log("KIFR Update System: KIF Redux - Hotfix available")
          else
            results[:up_to_date].unshift(update_info)
            KIFRSettings.debug_log("KIFR Update System: KIF Redux - Up to date")
          end
          
          KIFRSettings.debug_log("KIFR Update System: KIF Redux version check - Local: #{local_version}, Online: #{online_version}")
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: KIF Redux update check failed: #{e.class} - #{e.message}")
        end
      end
      
      # Parse version string to components
      def parse_version(version_str)
        return [[0, 0, 0], false] if version_str.nil? || version_str.empty?
        
        parts = version_str.split('.')
        major = parts[0].to_i
        minor = parts[1].to_i if parts.length > 1
        minor ||= 0
        patch = parts[2].to_i if parts.length > 2
        patch ||= 0
        has_patch = parts.length > 2
        
        [[major, minor, patch], has_patch]
      end
      
      # Compare two version strings
      def compare_versions(v1, v2)
        v1_parts = v1.split('.').map(&:to_i)
        v2_parts = v2.split('.').map(&:to_i)
        
        [v1_parts.length, v2_parts.length].max.times do |i|
          v1_num = v1_parts[i] || 0
          v2_num = v2_parts[i] || 0
          
          return -1 if v1_num < v2_num
          return 1 if v1_num > v2_num
        end
        
        0
      end
      
      # Determine update type
      def determine_update_type(current, latest)
        current_parts = current.split('.').map(&:to_i)
        latest_parts = latest.split('.').map(&:to_i)
        
        if latest_parts[0] > (current_parts[0] || 0)
          return "Major"
        elsif latest_parts[1] > (current_parts[1] || 0)
          return "Minor"
        elsif latest_parts[2] > (current_parts[2] || 0)
          return "Hotfix"
        end
        
        "Update"
      end
    end
  end
  
  #=============================================================================
  # MOD UPDATER - Download, Backup, Install, ZIP Handling
  #=============================================================================
  module ModUpdater
    class << self
      # Get base game directory
      def get_base_dir
        File.expand_path(Dir.pwd)
      end
      
      # Run a system command silently (no visible window)
      # Returns true if command succeeded, false otherwise
      def run_silent(command)
        begin
          # Use IO.popen to run command without opening a visible window
          # Redirect stderr to stdout and capture output
          output = IO.popen(command + " 2>&1", "r") { |io| io.read }
          $?.success?
        rescue => e
          KIFRSettings.debug_log("KIFR run_silent error: #{e.message}")
          false
        end
      end
      
      # Run silent and return exit status for robocopy (which uses non-zero for success)
      def run_silent_robocopy(command)
        begin
          output = IO.popen(command + " 2>&1", "r") { |io| io.read }
          # Robocopy: 0-7 = success, 8+ = failure
          $?.exitstatus.nil? ? false : $?.exitstatus < 8
        rescue => e
          KIFRSettings.debug_log("KIFR run_silent_robocopy error: #{e.message}")
          false
        end
      end
      
      # Ensure ModsBackup directory exists
      def ensure_backup_dir
        backup_dir = File.join(get_base_dir, "ModsBackup")
        Dir.mkdir(backup_dir) unless Dir.exist?(backup_dir)
        backup_dir
      end
      
      # Download a file from URL
      def download_file(url, progress_callback = nil)
        return nil unless defined?(HTTPLite)
        
        begin
          progress_callback&.call(0)
          
          max_redirects = 5
          redirect_count = 0
          current_url = url
          
          loop do
            response = HTTPLite.get(current_url)
            
            if response.is_a?(Hash) && response[:status] == 200
              progress_callback&.call(100)
              return response[:body]
            elsif response.is_a?(Hash) && [301, 302, 303, 307, 308].include?(response[:status])
              redirect_count += 1
              return nil if redirect_count > max_redirects
              
              location = response[:headers]["location"] || response[:headers]["Location"]
              return nil if location.nil? || location.empty?
              
              current_url = location
            else
              return nil
            end
          end
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: Download failed: #{e.message}")
          nil
        end
      end
      
      # Backup a mod file before updating
      def backup_mod(mod_path, version)
        begin
          return false unless File.exist?(mod_path)
          
          backup_dir = ensure_backup_dir
          filename = File.basename(mod_path)
          date_str = Time.now.strftime("%Y-%m-%d")
          backup_name = filename.sub(/\.rb$/, "_v#{version}_#{date_str}.rb")
          backup_path = File.join(backup_dir, backup_name)
          
          content = File.read(mod_path)
          File.open(backup_path, 'wb') { |f| f.write(content) }
          
          File.exist?(backup_path)
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: Backup failed: #{e.message}")
          false
        end
      end
      
      # Check if URL is a ZIP file
      def is_zip_url?(url)
        url && url.downcase.end_with?(".zip")
      end
      
      # Validate file extension against whitelist
      def is_safe_extension?(filename)
        allowed_extensions = [
          ".rb", ".png", ".gif", ".jpg", ".jpeg", ".bmp",
          ".wav", ".ogg", ".mp3", ".mid", ".midi",
          ".txt", ".md", ".json", ".yml", ".yaml",
          ".rxdata", ".rvdata", ".rvdata2"
        ]
        ext = File.extname(filename).downcase
        allowed_extensions.include?(ext)
      end
      
      # Validate and sanitize file path to prevent traversal attacks
      def sanitize_zip_path(path, base_dir)
        # Normalize path separators
        normalized = path.gsub("\\", "/")
        
        # Reject absolute paths
        if normalized.start_with?("/") || normalized.match?(/^[A-Za-z]:/)
          KIFRSettings.debug_log("KIFR Update System: Security: Rejected absolute path: #{path}")
          return nil
        end
        
        # Reject path traversal attempts
        if normalized.include?("../") || normalized.include?("..\\")
          KIFRSettings.debug_log("KIFR Update System: Security: Rejected path traversal attempt: #{path}")
          return nil
        end
        
        # Check file extension whitelist
        unless is_safe_extension?(normalized)
          KIFRSettings.debug_log("KIFR Update System: Security: Rejected unsafe extension: #{path}")
          return nil
        end
        
        # Build full path and verify it's within base directory
        full_path = File.expand_path(File.join(base_dir, normalized))
        base_expanded = File.expand_path(base_dir)
        
        unless full_path.start_with?(base_expanded)
          KIFRSettings.debug_log("KIFR Update System: Security: Path escapes base directory: #{path}")
          return nil
        end
        
        normalized
      end
      
      # List contents of ZIP file using 7z
      def list_zip_contents(zip_path)
        begin
          sevenz_path = File.join(get_base_dir, "REQUIRED_BY_INSTALLER_UPDATER", "7z.exe")
          unless File.exist?(sevenz_path)
            KIFRSettings.debug_log("KIFR Update System: ERROR: 7z.exe not found at #{sevenz_path}")
            return nil
          end
          
          # Create temp file for output
          base_dir = get_base_dir
          temp_output = File.join(base_dir, "temp_7z_list.txt")
          
          # Use 7z list command, redirect output to file (run silently)
          command = "\"#{sevenz_path}\" l -slt \"#{zip_path}\" > \"#{temp_output}\""
          run_silent(command)
          
          unless File.exist?(temp_output)
            KIFRSettings.debug_log("KIFR Update System: ERROR: 7z output file not created")
            return nil
          end
          
          # Read the output file
          output = File.read(temp_output)
          File.delete(temp_output) if File.exist?(temp_output)
          
          files = []
          current_path = nil
          is_directory = false
          
          output.each_line do |line|
            line = line.strip
            
            if line =~ /^Path = (.+)$/
              current_path = $1.strip
            elsif line =~ /^Folder = (.+)$/
              is_directory = ($1.strip == "+")
            elsif line.empty? && current_path
              # Skip directories and the archive itself
              is_zip_file = current_path == zip_path || 
                            current_path.end_with?('.zip') && (current_path.include?(':\\') || current_path.start_with?('/'))
              unless is_directory || is_zip_file || current_path.empty?
                files << current_path
              end
              current_path = nil
              is_directory = false
            end
          end
          
          KIFRSettings.debug_log("KIFR Update System: Found #{files.length} files in ZIP archive")
          files
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: Listing ZIP contents failed: #{e.message}")
          nil
        end
      end
      
      # Detect if ZIP has a single wrapper folder (like GitHub archives)
      def detect_wrapper_folder(contents)
        return nil if contents.nil? || contents.empty?
        
        # Filter out any non-relative paths
        relative_files = contents.select { |path| !path.include?(":\\") && !path.start_with?("/") }
        return nil if relative_files.empty?
        
        # Get first-level folder from each path (skip files in root)
        first_folders = relative_files.map do |path|
          parts = path.split(/[\/\\]/)
          parts.length > 1 ? parts[0] : nil
        end.compact.uniq
        
        # If all files are in a single top-level folder, that's likely a wrapper
        if first_folders.length == 1
          wrapper = first_folders[0]
          
          # Check if it matches GitHub archive pattern or all files are inside
          if wrapper =~ /^.+-(main|master|dev|development|\d+\.\d+)$/i ||
             relative_files.all? { |path| path.start_with?("#{wrapper}/") || path.start_with?("#{wrapper}\\") }
            KIFRSettings.debug_log("KIFR Update System: Detected wrapper folder in ZIP: #{wrapper}")
            return wrapper
          end
        end
        
        nil
      end
      
      # Extract ZIP file using 7z.exe with security validation
      # Falls back to pure Ruby extraction if 7z not available (cross-platform)
      # @param zip_path [String] Path to the ZIP file
      # @param destination [String] Destination folder
      # @param skip_validation [Boolean] Skip file validation for trusted sources (faster)
      def extract_zip(zip_path, destination = nil, skip_validation = false, skip_existing = false)
        begin
          destination ||= get_base_dir
          
          sevenz_path = File.join(get_base_dir, "REQUIRED_BY_INSTALLER_UPDATER", "7z.exe")
          
          # -aos flag tells 7z to skip extracting files that already exist
          skip_flag = skip_existing ? "-aos" : ""
          
          # Check if 7z exists, otherwise use Ruby fallback
          unless File.exist?(sevenz_path)
            KIFRSettings.debug_log("KIFR Update System: 7z.exe not found, using Ruby ZIP extraction...")
            return extract_zip_ruby(zip_path, destination, skip_validation, skip_existing)
          end
          
          # List ZIP contents to detect wrapper folder
          contents = list_zip_contents(zip_path)
          if contents.nil?
            KIFRSettings.debug_log("KIFR Update System: ERROR: Failed to read ZIP contents")
            return false
          end
          
          # Detect wrapper folder
          wrapper_folder = detect_wrapper_folder(contents)
          
          # Validate files only if not skipping (for untrusted sources)
          unless skip_validation
            valid_files = []
            rejected_files = []
            
            contents.each do |file_path|
              sanitized = sanitize_zip_path(file_path, destination)
              if sanitized
                valid_files << file_path
              else
                rejected_files << file_path
              end
            end
            
            KIFRSettings.debug_log("KIFR Update System: ZIP validation - Valid: #{valid_files.length}, Rejected: #{rejected_files.length}")
            
            if valid_files.empty?
              KIFRSettings.debug_log("KIFR Update System: ERROR: No valid files to extract from ZIP")
              return false
            end
          else
            KIFRSettings.debug_log("KIFR Update System: Skipping validation (trusted source) - #{contents.length} files")
            rejected_files = []
          end
          
          Dir.mkdir(destination) unless Dir.exist?(destination)
          
          if wrapper_folder
            # OPTIMIZED: Extract to temp, then use system move/copy for speed
            temp_extract = File.join(get_base_dir, "temp_extract_#{Time.now.to_i}")
            Dir.mkdir(temp_extract) unless Dir.exist?(temp_extract)
            
            # Extract with 7z (fast, silent, multi-threaded)
            # -aos = skip existing files (when skip_existing is true)
            command = "\"#{sevenz_path}\" x \"#{zip_path}\" -o\"#{temp_extract}\" -y -mmt=on #{skip_flag} -bso0 -bsp0".strip
            KIFRSettings.debug_log("KIFR Update System: Extracting ZIP to temp folder#{skip_existing ? ' (skip existing)' : ''}...")
            result = run_silent(command)
            
            if result
              wrapper_path = File.join(temp_extract, wrapper_folder)
              
              if Dir.exist?(wrapper_path)
                KIFRSettings.debug_log("KIFR Update System: Moving files from wrapper folder (optimized)...")
                
                # OPTIMIZED: Use robocopy on Windows for much faster bulk copy
                # /E = copy subdirs including empty, /MOVE = move instead of copy
                # /NFL /NDL /NJH /NJS = quiet mode
                # /XC /XN /XO = skip existing files (when skip_existing is true)
                skip_copy_flags = skip_existing ? "/XC /XN /XO" : ""
                robocopy_cmd = "robocopy \"#{wrapper_path}\" \"#{destination}\" /E /MOVE #{skip_copy_flags} /NFL /NDL /NJH /NJS /R:1 /W:1".gsub(/\s+/, ' ')
                copy_result = run_silent_robocopy(robocopy_cmd)
                
                # Robocopy returns 0-7 for success (various levels of success/info)
                # 8+ indicates errors
                # We'll also fall back to Ruby copy if robocopy fails
                unless copy_result
                  KIFRSettings.debug_log("KIFR Update System: Robocopy not available or failed, using fallback...")
                  
                  # Fallback: Use xcopy (faster than Ruby, available on all Windows)
                  xcopy_cmd = "xcopy \"#{wrapper_path}\\*\" \"#{destination}\" /E /Y /Q /I"
                  xcopy_result = run_silent(xcopy_cmd)
                  
                  unless xcopy_result
                    KIFRSettings.debug_log("KIFR Update System: xcopy failed, using Ruby fallback...")
                    # Final fallback: Ruby copy (slowest but most compatible)
                    copy_count = fast_copy_directory(wrapper_path, destination)
                    KIFRSettings.debug_log("KIFR Update System: Ruby copied #{copy_count} files")
                  end
                end
                
                # Clean up temp folder
                cleanup_temp_folder(temp_extract)
                
                KIFRSettings.debug_log("KIFR Update System: ZIP extraction successful (wrapper folder stripped)")
                return true
              else
                cleanup_temp_folder(temp_extract)
                return false
              end
            else
              cleanup_temp_folder(temp_extract)
              return false
            end
          else
            # No wrapper folder - extract directly to destination (fastest path, multi-threaded)
            # -aos = skip existing files (when skip_existing is true)
            command = "\"#{sevenz_path}\" x \"#{zip_path}\" -o\"#{destination}\" -y -mmt=on #{skip_flag} -bso0 -bsp0".strip
            KIFRSettings.debug_log("KIFR Update System: Direct extraction#{skip_existing ? ' (skip existing)' : ''}...")
            result = run_silent(command)
            
            if result
              # Remove any rejected files that may have been extracted
              unless skip_validation
                rejected_files.each do |rejected|
                  full_path = File.join(destination, rejected)
                  if File.exist?(full_path)
                    begin
                      File.delete(full_path)
                      KIFRSettings.debug_log("KIFR Update System: Security: Removed rejected file: #{rejected}")
                    rescue
                    end
                  end
                end
              end
              
              KIFRSettings.debug_log("KIFR Update System: ZIP extraction successful")
              return true
            else
              KIFRSettings.debug_log("KIFR Update System: ERROR: ZIP extraction failed")
              return false
            end
          end
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: ZIP extraction error: #{e.message}")
          false
        end
      end
      
      # Fast directory copy using buffered IO
      def fast_copy_directory(source_dir, dest_dir)
        copy_count = 0
        buffer_size = 1024 * 1024 # 1MB buffer for faster large file copies
        
        Dir.glob("#{source_dir}/**/*").each do |source_path|
          next if File.directory?(source_path)
          
          relative_path = source_path.sub("#{source_dir}#{File::SEPARATOR}", "").sub("#{source_dir}/", "")
          dest_path = File.join(dest_dir, relative_path)
          
          # Create parent directory if needed
          dest_parent = File.dirname(dest_path)
          FileUtils.mkdir_p(dest_parent) unless Dir.exist?(dest_parent)
          
          # Copy with buffer
          begin
            File.open(source_path, 'rb') do |src|
              File.open(dest_path, 'wb') do |dst|
                while (chunk = src.read(buffer_size))
                  dst.write(chunk)
                end
              end
            end
            copy_count += 1
          rescue => e
            KIFRSettings.debug_log("KIFR Update System: Copy error for #{relative_path}: #{e.message}")
          end
        end
        
        copy_count
      end
      
      # Helper to clean up temp extraction folder
      def cleanup_temp_folder(temp_folder)
        return unless Dir.exist?(temp_folder)
        begin
          Dir.glob("#{temp_folder}/**/*").reverse_each do |path|
            begin
              if File.directory?(path)
                Dir.rmdir(path) rescue nil
              else
                File.delete(path) rescue nil
              end
            rescue
            end
          end
          Dir.rmdir(temp_folder) rescue nil
        rescue
        end
      end
      
      # Extract ZIP with progress callback
      # Uses 7z if available (fast), falls back to Ruby extraction
      # @param zip_path [String] Path to ZIP file
      # @param destination [String] Destination folder
      # @param progress_callback [Proc] Called with (percent, status_text) for progress updates
      # @return [Boolean] Success
      def extract_zip_with_progress(zip_path, destination, skip_existing = false, &progress_callback)
        sevenz_path = File.join(get_base_dir, "REQUIRED_BY_INSTALLER_UPDATER", "7z.exe")
        
        if File.exist?(sevenz_path)
          # Use 7z with progress (much faster)
          return extract_zip_7z_progress(zip_path, destination, sevenz_path, skip_existing, &progress_callback)
        else
          # Fall back to Ruby extraction
          return extract_zip_ruby_progress(zip_path, destination, skip_existing, &progress_callback)
        end
      end
      
      # Extract using 7z with progress parsing
      def extract_zip_7z_progress(zip_path, destination, sevenz_path, skip_existing = false, &progress_callback)
        begin
          KIFRSettings.debug_log("KIFR Update System: Starting 7z extraction with progress#{skip_existing ? ' (skip existing)' : ''}...")
          
          # -aos flag tells 7z to skip extracting files that already exist
          skip_flag = skip_existing ? "-aos" : ""
          
          # First, detect wrapper folder
          contents = list_zip_contents(zip_path)
          wrapper_folder = contents ? detect_wrapper_folder(contents) : nil
          file_count = contents ? contents.length : 0
          
          if wrapper_folder
            KIFRSettings.debug_log("KIFR Update System: Detected wrapper folder: #{wrapper_folder}")
            # Extract to temp, then move
            temp_extract = File.join(get_base_dir, "temp_extract_#{Time.now.to_i}")
            Dir.mkdir(temp_extract) unless Dir.exist?(temp_extract)
            extract_dest = temp_extract
          else
            extract_dest = destination
          end
          
          Dir.mkdir(destination) unless Dir.exist?(destination)
          
          # Run 7z with multi-threading and progress output
          # -mmt=on enables multi-threaded decompression (faster on multi-core)
          # -bsp1 shows progress percentage
          # -aos skips existing files (when skip_existing is true)
          command = "\"#{sevenz_path}\" x \"#{zip_path}\" -o\"#{extract_dest}\" -y -mmt=on #{skip_flag} -bsp1 -bso0".gsub(/\s+/, ' ')
          
          last_percent = -1
          last_update = Time.now
          success = false
          
          # Show initial progress with file count
          if progress_callback
            status_msg = skip_existing ? "Extracting #{file_count} files (skipping existing)..." : "Extracting #{file_count} files..."
            progress_callback.call(0, status_msg)
            Graphics.update
          end
          
          # Use IO.popen to read progress in real-time
          IO.popen(command + " 2>&1", "r") do |io|
            while line = io.gets
              # 7z progress lines look like: " 45% - filename" or just " 45%"
              if line =~ /^\s*(\d+)%/
                percent = $1.to_i
                # Only update every 2% change AND every 0.15 seconds (reduces overhead)
                if percent != last_percent && (percent - last_percent >= 2 || Time.now - last_update >= 0.15)
                  last_percent = percent
                  last_update = Time.now
                  progress_callback.call(percent, "Extracting... #{percent}%") if progress_callback
                  Graphics.update
                end
              end
            end
          end
          
          success = $?.success?
          
          # Handle wrapper folder stripping
          if success && wrapper_folder
            wrapper_path = File.join(temp_extract, wrapper_folder)
            
            if Dir.exist?(wrapper_path)
              progress_callback.call(100, "Installing files...") if progress_callback
              Graphics.update
              
              # Move files from wrapper to destination
              # /XC /XN /XO = skip existing files (when skip_existing is true)
              skip_copy_flags = skip_existing ? "/XC /XN /XO" : ""
              run_silent_robocopy("robocopy \"#{wrapper_path}\" \"#{destination}\" /E /MOVE #{skip_copy_flags} /NFL /NDL /NJH /NJS /R:1 /W:1".gsub(/\s+/, ' '))
            end
            
            cleanup_temp_folder(temp_extract)
          end
          
          KIFRSettings.debug_log("KIFR Update System: 7z extraction #{success ? 'successful' : 'failed'}")
          return success
          
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: 7z progress extraction error: #{e.message}")
          return false
        end
      end
      
      # Extract using pure Ruby with progress (fallback when 7z not available)
      def extract_zip_ruby_progress(zip_path, destination, skip_existing = false, &progress_callback)
        begin
          require 'zlib'
          
          KIFRSettings.debug_log("KIFR Update System: Starting Ruby extraction with progress#{skip_existing ? ' (skip existing)' : ''}...")
          
          # Read ZIP file
          zip_data = File.binread(zip_path)
          
          # Parse ZIP structure
          entries = parse_zip_entries(zip_data)
          
          if entries.empty?
            KIFRSettings.debug_log("KIFR Update System: ERROR: No entries found in ZIP")
            return false
          end
          
          total_files = entries.count { |e| !e[:directory] }
          KIFRSettings.debug_log("KIFR Update System: Found #{total_files} files to extract")
          
          # Detect wrapper folder
          entry_names = entries.map { |e| e[:name] }
          wrapper_folder = detect_wrapper_folder(entry_names)
          
          if wrapper_folder
            KIFRSettings.debug_log("KIFR Update System: Detected wrapper folder: #{wrapper_folder}")
          end
          
          Dir.mkdir(destination) unless Dir.exist?(destination)
          
          extracted_count = 0
          skipped_count = 0
          file_index = 0
          
          entries.each do |entry|
            begin
              # Strip wrapper folder from path if present
              entry_path = entry[:name]
              if wrapper_folder && entry_path.start_with?("#{wrapper_folder}/")
                entry_path = entry_path[(wrapper_folder.length + 1)..-1]
              elsif wrapper_folder && entry_path.start_with?("#{wrapper_folder}\\")
                entry_path = entry_path[(wrapper_folder.length + 1)..-1]
              end
              
              # Skip if path is empty after stripping
              next if entry_path.nil? || entry_path.empty?
              
              full_path = File.join(destination, entry_path)
              
              if entry[:directory]
                FileUtils.mkdir_p(full_path) unless Dir.exist?(full_path)
              else
                file_index += 1
                
                # Call progress callback with percent and status
                if progress_callback
                  percent = (file_index * 100 / total_files).to_i
                  progress_callback.call(percent, "Extracting... #{percent}% (#{file_index}/#{total_files})")
                end
                
                # Skip existing files if requested
                if skip_existing && File.exist?(full_path)
                  skipped_count += 1
                  Graphics.update if file_index % 50 == 0
                  next
                end
                
                # Extract file
                dir = File.dirname(full_path)
                FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
                
                content = decompress_zip_entry(zip_data, entry)
                
                if content
                  File.open(full_path, 'wb') { |f| f.write(content) }
                  extracted_count += 1
                end
                
                # Update graphics periodically to prevent freeze
                Graphics.update if file_index % 50 == 0
              end
            rescue => e
              KIFRSettings.debug_log("KIFR Update System: Error extracting #{entry[:name]}: #{e.message}")
            end
          end
          
          if skip_existing && skipped_count > 0
            KIFRSettings.debug_log("KIFR Update System: Extraction complete - #{extracted_count} extracted, #{skipped_count} skipped")
          else
            KIFRSettings.debug_log("KIFR Update System: Extraction complete - #{extracted_count} files")
          end
          return extracted_count > 0 || skipped_count > 0
          
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: Extraction with progress error: #{e.message}")
          return false
        end
      end
      
      # Pure Ruby ZIP extraction (cross-platform fallback when 7z not available)
      # Supports wrapper folder stripping and security validation
      # @param zip_path [String] Path to ZIP file
      # @param destination [String] Destination folder
      # @param skip_validation [Boolean] Skip security validation
      # @return [Boolean] Success
      def extract_zip_ruby(zip_path, destination, skip_validation = false, skip_existing = false)
        begin
          require 'zlib'
          
          KIFRSettings.debug_log("KIFR Update System: Starting Ruby ZIP extraction#{skip_existing ? ' (skip existing)' : ''}...")
          
          # Read ZIP file
          zip_data = File.binread(zip_path)
          
          # Parse ZIP structure (simplified ZIP parser)
          entries = parse_zip_entries(zip_data)
          
          if entries.empty?
            KIFRSettings.debug_log("KIFR Update System: ERROR: No entries found in ZIP")
            return false
          end
          
          KIFRSettings.debug_log("KIFR Update System: Found #{entries.length} entries in ZIP")
          
          # Detect wrapper folder
          entry_names = entries.map { |e| e[:name] }
          wrapper_folder = detect_wrapper_folder(entry_names)
          
          if wrapper_folder
            KIFRSettings.debug_log("KIFR Update System: Detected wrapper folder: #{wrapper_folder}")
          end
          
          # Validate entries if needed
          unless skip_validation
            entries.reject! do |entry|
              sanitized = sanitize_zip_path(entry[:name], destination)
              if sanitized.nil?
                KIFRSettings.debug_log("KIFR Update System: Rejected: #{entry[:name]}")
                true
              else
                false
              end
            end
          end
          
          Dir.mkdir(destination) unless Dir.exist?(destination)
          
          extracted_count = 0
          skipped_count = 0

          entries.each do |entry|
            begin
              # Strip wrapper folder from path if present
              entry_path = entry[:name]
              if wrapper_folder && entry_path.start_with?("#{wrapper_folder}/")
                entry_path = entry_path[(wrapper_folder.length + 1)..-1]
              elsif wrapper_folder && entry_path.start_with?("#{wrapper_folder}\\")
                entry_path = entry_path[(wrapper_folder.length + 1)..-1]
              end
              
              # Skip if path is empty after stripping (the wrapper folder itself)
              next if entry_path.nil? || entry_path.empty?
              
              full_path = File.join(destination, entry_path)
              
              if entry[:directory]
                # Create directory
                FileUtils.mkdir_p(full_path) unless Dir.exist?(full_path)
              else
                # Skip existing files if requested
                if skip_existing && File.exist?(full_path)
                  skipped_count += 1
                  next
                end
                
                # Extract file
                dir = File.dirname(full_path)
                FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
                
                # Decompress data
                content = decompress_zip_entry(zip_data, entry)
                
                if content
                  File.open(full_path, 'wb') { |f| f.write(content) }
                  extracted_count += 1
                end
              end
            rescue => e
              KIFRSettings.debug_log("KIFR Update System: Error extracting #{entry[:name]}: #{e.message}")
            end
          end
          
          if skip_existing && skipped_count > 0
            KIFRSettings.debug_log("KIFR Update System: Ruby extraction complete - #{extracted_count} extracted, #{skipped_count} skipped (already exist)")
          else
            KIFRSettings.debug_log("KIFR Update System: Ruby extraction complete - #{extracted_count} files")
          end
          return extracted_count > 0 || skipped_count > 0
          
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: Ruby ZIP extraction error: #{e.message}")
          return false
        end
      end
      
      # Parse ZIP file entries (simplified ZIP parser)
      # @param zip_data [String] Raw ZIP file data
      # @return [Array<Hash>] Array of entry hashes with :name, :offset, :compressed_size, :size, :method, :directory
      def parse_zip_entries(zip_data)
        entries = []
        offset = 0
        
        # Local file header signature: 0x04034b50 (PK\003\004)
        local_sig = [0x50, 0x4b, 0x03, 0x04].pack('C*')
        
        while (pos = zip_data.index(local_sig, offset))
          break if pos + 30 > zip_data.length
          
          # Parse local file header
          header = zip_data[pos, 30]
          
          # version_needed = header[4, 2].unpack('v')[0]
          # flags = header[6, 2].unpack('v')[0]
          method = header[8, 2].unpack('v')[0]
          # mod_time = header[10, 2].unpack('v')[0]
          # mod_date = header[12, 2].unpack('v')[0]
          # crc32 = header[14, 4].unpack('V')[0]
          compressed_size = header[18, 4].unpack('V')[0]
          uncompressed_size = header[22, 4].unpack('V')[0]
          name_length = header[26, 2].unpack('v')[0]
          extra_length = header[28, 2].unpack('v')[0]
          
          # Get filename
          name_start = pos + 30
          break if name_start + name_length > zip_data.length
          
          name = zip_data[name_start, name_length]
          name = name.force_encoding('UTF-8') rescue name
          
          # Data starts after header + name + extra
          data_offset = name_start + name_length + extra_length
          
          entries << {
            name: name,
            offset: data_offset,
            compressed_size: compressed_size,
            size: uncompressed_size,
            method: method,
            directory: name.end_with?('/') || name.end_with?('\\')
          }
          
          # Move to next entry
          offset = data_offset + compressed_size
        end
        
        entries
      end
      
      # Decompress a ZIP entry
      # @param zip_data [String] Raw ZIP file data
      # @param entry [Hash] Entry hash from parse_zip_entries
      # @return [String, nil] Decompressed data or nil on error
      def decompress_zip_entry(zip_data, entry)
        return nil if entry[:directory]
        return nil if entry[:offset] + entry[:compressed_size] > zip_data.length
        
        compressed = zip_data[entry[:offset], entry[:compressed_size]]
        
        case entry[:method]
        when 0  # Stored (no compression)
          return compressed
        when 8  # Deflate
          begin
            # Use raw deflate (negative window bits)
            zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
            result = zstream.inflate(compressed)
            zstream.close
            return result
          rescue Zlib::Error => e
            KIFRSettings.debug_log("KIFR Update System: Zlib error: #{e.message}")
            return nil
          end
        else
          KIFRSettings.debug_log("KIFR Update System: Unsupported compression method: #{entry[:method]}")
          return nil
        end
      end
      
      # Install/update a mod (basic version without terminal UI)
      def install_mod(mod_path, download_url, current_version, progress_callback = nil)
        begin
          # Skip if this is the Multiplayer special case (should be handled by pbUpdateMod)
          if download_url == "autoupdate_multiplayer.bat"
            KIFRSettings.debug_log("KIFR Update System: Skipping install_mod for Multiplayer (use pbUpdateMod)")
            return false
          end
          
          # Validate URL
          unless download_url && download_url.start_with?("http://", "https://")
            KIFRSettings.debug_log("KIFR Update System: Invalid download URL: #{download_url}")
            return false
          end
          
          if is_zip_url?(download_url)
            KIFRSettings.debug_log("KIFR Update System: Detected ZIP download URL")
            
            # Download ZIP
            content = download_file(download_url, progress_callback)
            return false if content.nil?
            
            # Save to temp location
            base_dir = get_base_dir
            temp_zip = File.join(base_dir, "temp_mod.zip")
            File.open(temp_zip, 'wb') { |f| f.write(content) }
            
            # Extract to base game folder (security validated in extract_zip)
            success = extract_zip(temp_zip)
            
            # Clean up temp file
            File.delete(temp_zip) if File.exist?(temp_zip)
            
            if success
              KIFRSettings.debug_log("KIFR Update System: Successfully installed mod from ZIP")
              return true
            else
              KIFRSettings.debug_log("KIFR Update System: ERROR: ZIP mod installation failed")
              return false
            end
          else
            # Regular .rb file download
            # Backup current version
            backup_mod(mod_path, current_version)
            
            # Download new version
            content = download_file(download_url, progress_callback)
            return false if content.nil?
            
            # Write new version
            File.open(mod_path, 'wb') { |f| f.write(content) }
            
            KIFRSettings.debug_log("KIFR Update System: Updated mod file: #{File.basename(mod_path)}")
            true
          end
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: Install failed: #{e.message}")
          false
        end
      end
      
      # Install/update a mod with terminal UI (visual progress bar)
      # @param mod_info [Hash] Mod info hash with :path, :name, :download_url, :local (version)
      # @return [Boolean] Success
      # Note: This method is kept for compatibility but now just calls install_mod
      def install_mod_with_terminal(mod_info)
        mod_path = mod_info[:path]
        download_url = mod_info[:download_url]
        current_version = mod_info[:local] || mod_info[:version]
        install_mod(mod_path, download_url, current_version)
      end
      
      # List all backup files
      def list_backups
        begin
          backup_dir = File.join(get_base_dir, "ModsBackup")
          return [] unless Dir.exist?(backup_dir)
          
          backups = []
          Dir.entries(backup_dir).each do |filename|
            next if filename == "." || filename == ".."
            next unless filename.end_with?(".rb")
            
            backups << {
              path: File.join(backup_dir, filename),
              filename: filename,
              display_name: filename
            }
          end
          
          backups.sort_by { |b| b[:filename] }
        rescue
          []
        end
      end
      
      # List backups for a specific mod
      def list_backups_for_mod(mod_path)
        mod_name = File.basename(mod_path, ".rb")
        list_backups.select { |b| b[:filename].start_with?(mod_name) }
      end
      
      # Rollback a mod to a backup version
      def rollback_mod(mod_path, backup_path)
        begin
          return false unless File.exist?(backup_path)
          
          content = File.read(backup_path)
          File.open(mod_path, 'wb') { |f| f.write(content) }
          
          KIFRSettings.debug_log("KIFR Update System: Rolled back mod: #{File.basename(mod_path)}")
          true
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: Rollback failed: #{e.message}")
          false
        end
      end
      
      # Delete a backup file
      def delete_backup(backup_path)
        begin
          return false unless File.exist?(backup_path)
          File.delete(backup_path)
          true
        rescue
          false
        end
      end
      
      # Install graphics files for a mod
      def install_graphics(graphics_list)
        return [0, 0] if graphics_list.nil? || graphics_list.empty?
        
        base_dir = "."
        success = 0
        failure = 0
        
        graphics_list.each do |graphic|
          begin
            url = graphic[:url] || graphic["url"]
            rel_path = graphic[:path] || graphic["path"]
            
            content = download_file(url)
            if content.nil?
              failure += 1
              next
            end
            
            full_path = File.join(base_dir, rel_path)
            
            # Ensure directory exists
            dir = File.dirname(full_path)
            unless Dir.exist?(dir)
              parts = []
              temp = dir
              while temp != base_dir && !Dir.exist?(temp)
                parts.unshift(File.basename(temp))
                temp = File.dirname(temp)
              end
              parts.each do |part|
                temp = File.join(temp, part)
                Dir.mkdir(temp) unless Dir.exist?(temp)
              end
            end
            
            File.open(full_path, 'wb') { |f| f.write(content) }
            KIFRSettings.debug_log("KIFR Update System: Installed graphic: #{rel_path}")
            success += 1
          rescue => e
            KIFRSettings.debug_log("KIFR Update System: ERROR: Graphics install failed: #{e.class} - #{e.message}")
            failure += 1
          end
        end
        
        [success, failure]
      end
    end
  end
end

#===============================================================================
# COLORED CATEGORY HEADER - For update results
#===============================================================================
class ColoredCategoryHeaderOption < Option
  include PropertyMixin if defined?(PropertyMixin)
  attr_accessor :color_theme_key
  attr_reader :name
  
  def initialize(name, description, color_theme_key)
    @name = name
    @description = description
    @color_theme_key = color_theme_key
  end
  
  def get; 0; end
  def set(value); end
  def prev(current); current; end
  def next(current); current; end
  def values; [""]; end
  
  def format(value)
    return @name
  end
end

#===============================================================================
# COLUMN HEADER - For version displays
#===============================================================================
class ColumnHeaderOption < Option
  include PropertyMixin if defined?(PropertyMixin)
  attr_reader :name
  
  def initialize
    @name = "Mod Name                                                     Local              Online"
    @description = " "
  end
  
  def get; 0; end
  def set(value); end
  def prev(current); current; end
  def next(current); current; end
  
  def format(value)
    return @name
  end
end

#===============================================================================
# WINDOW FOR UPDATE RESULTS - Custom drawing with colors
#===============================================================================
class Window_UpdateResults < Window_PokemonOption
  attr_accessor :nameBaseColor, :nameShadowColor, :use_color_theme
  
  def initialize(options, x, y, width, height)
    super(options, x, y, width, height)
    @use_color_theme = false
  end
  
  # Apply the selected color theme
  def apply_color_theme(theme_index)
    return unless defined?(::COLOR_THEMES)
    
    theme_key = ::COLOR_THEMES.keys[theme_index]
    return unless theme_key
    
    theme = ::COLOR_THEMES[theme_key]
    if theme && theme[:base] && theme[:shadow]
      @nameBaseColor = theme[:base]
      @nameShadowColor = theme[:shadow]
      @selBaseColor = theme[:base]
      @selShadowColor = theme[:shadow]
    end
    refresh
  end
  
  def drawItem(index, _count, rect)
    # Column header
    if index < @options.length && @options[index].is_a?(ColumnHeaderOption)
      rect = drawCursor(index, rect)
      pbSetSystemFont(self.contents)
      
      optionwidth = rect.width * 12 / 20
      colwidth = (rect.width - optionwidth) / 2
      
      baseColor = Color.new(240, 120, 120)
      shadowColor = Color.new(92, 44, 44)
      
      pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height, "Mod Name",
                       baseColor, shadowColor)
      
      xpos = optionwidth + rect.x
      pbDrawShadowText(self.contents, xpos, rect.y, colwidth, rect.height, "Local",
                       baseColor, shadowColor)
      
      xpos += colwidth
      pbDrawShadowText(self.contents, xpos, rect.y, colwidth, rect.height, "Online",
                       baseColor, shadowColor)
      return
    end
    
    # ConflictCategoryOption - matching KIFRCategoryHeaderOption style
    if index < @options.length && defined?(ConflictCategoryOption) && @options[index].is_a?(ConflictCategoryOption)
      theme_key = @options[index].color
      theme = nil
      
      # Try to get the color theme
      if theme_key
        if defined?(::COLOR_THEMES) && ::COLOR_THEMES.is_a?(Hash)
          theme = ::COLOR_THEMES[theme_key]
        elsif defined?(COLOR_THEMES) && COLOR_THEMES.is_a?(Hash)
          theme = COLOR_THEMES[theme_key]
        end
      end
      
      if theme && theme[:base] && theme[:shadow]
        old_name_base = @nameBaseColor
        old_name_shadow = @nameShadowColor
        
        @nameBaseColor = theme[:base]
        @nameShadowColor = theme[:shadow]
        
        # Draw cursor using parent's method
        rect = drawCursor(index, rect)
        
        # Get formatted text (with +/- indicator)
        text = @options[index].format(@options[index].get)
        text_width = 200
        begin
          text_size_result = self.contents.text_size(text)
          text_width = text_size_result.width if text_size_result && text_size_result.respond_to?(:width)
        rescue
          text_width = 200
        end
        x_pos = (rect.width - text_width) / 2
        
        pbDrawShadowText(self.contents, x_pos, rect.y, text_width, rect.height, text,
                       @nameBaseColor, @nameShadowColor)
        
        @nameBaseColor = old_name_base
        @nameShadowColor = old_name_shadow
      else
        super(index, _count, rect)
      end
      return
    end
    
    # Colored category header
    if index < @options.length && @options[index].is_a?(ColoredCategoryHeaderOption)
      theme_key = @options[index].color_theme_key
      theme = COLOR_THEMES[theme_key] if theme_key && defined?(COLOR_THEMES)
      
      if theme && theme[:base] && theme[:shadow]
        old_name_base = @nameBaseColor
        old_name_shadow = @nameShadowColor
        
        @nameBaseColor = theme[:base]
        @nameShadowColor = theme[:shadow]
        
        # Draw cursor using parent's method
        rect = drawCursor(index, rect)
        
        text = @options[index].format(0)
        text_width = 200
        begin
          text_size_result = self.contents.text_size(text)
          text_width = text_size_result.width if text_size_result && text_size_result.respond_to?(:width)
        rescue
          text_width = 200
        end
        x_pos = (rect.width - text_width) / 2
        
        pbDrawShadowText(self.contents, x_pos, rect.y, text_width, rect.height, text,
                       @nameBaseColor, @nameShadowColor)
        
        @nameBaseColor = old_name_base
        @nameShadowColor = old_name_shadow
      else
        super(index, _count, rect)
      end
    elsif index < @options.length && @options[index].is_a?(ButtonOption)
      # Custom drawing for mod version entries
      return if respond_to?(:dont_draw_item) && dont_draw_item(index)
      rect = drawCursor(index, rect)
      
      optionname = @options[index].name
      
      # Handle pipe-delimited format: "Mod Name|1.0.0|2.0.0"
      if optionname =~ /^(.+?)\|(.+?)\|(.+)$/
        mod_name = $1
        local_version = $2
        online_version = $3
        
        optionwidth = rect.width * 12 / 20
        pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height, mod_name,
                         @nameBaseColor, @nameShadowColor)
        
        colwidth = (rect.width - optionwidth) / 2
        xpos = optionwidth + rect.x
        
        # Check if update needed
        show_arrow = false
        begin
          local_parts = local_version.split('.').map(&:to_i)
          online_parts = online_version.split('.').map(&:to_i)
          max_len = [local_parts.length, online_parts.length].max
          local_parts += [0] * (max_len - local_parts.length)
          online_parts += [0] * (max_len - online_parts.length)
          comparison = 0
          local_parts.each_with_index do |local_num, i|
            if local_num < online_parts[i]
              comparison = -1
              break
            elsif local_num > online_parts[i]
              comparison = 1
              break
            end
          end
          show_arrow = (comparison == -1)
        rescue
          show_arrow = true
        end
        
        version_text = show_arrow ? "#{local_version} =>" : local_version
        pbDrawShadowText(self.contents, xpos, rect.y, colwidth, rect.height, version_text,
                         @selBaseColor, @selShadowColor)
        
        xpos += colwidth
        pbDrawShadowText(self.contents, xpos, rect.y, colwidth, rect.height, online_version,
                         @selBaseColor, @selShadowColor)
      elsif optionname =~ /^(.+?)\|(.*)\|$/
        # Format: "Mod Name|1.0.0|" - Up to date or not tracked
        mod_name = $1
        version = $2
        
        optionwidth = rect.width * 12 / 20
        pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height, mod_name,
                         @nameBaseColor, @nameShadowColor)
        
        colwidth = (rect.width - optionwidth) / 2
        xpos = optionwidth + rect.x
        pbDrawShadowText(self.contents, xpos, rect.y, colwidth, rect.height, version,
                         @selBaseColor, @selShadowColor)
      else
        super(index, _count, rect)
      end
    else
      super(index, _count, rect)
    end
  end
end

#===============================================================================
# UPDATE RESULTS SCENE - Full update display
#===============================================================================
class UpdateResultsScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def initialize(results)
    super()
    @results = results
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
    optionsWindow.visible = true
    return optionsWindow
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    options << ColumnHeaderOption.new
    
    # Major Updates (RED)
    if @results[:major_updates].any?
      options << ColoredCategoryHeaderOption.new("Major Updates Available", "Major version behind - significant changes available.", :red)
      @results[:major_updates].each do |mod|
        text = sprintf("%s|%s|%s", mod[:name], mod[:local], mod[:online])
        callback = proc { pbModUpdateActions(mod) }
        desc = _INTL("Press ENTER for update options. {1} -> {2}", mod[:local], mod[:online])
        options << ButtonOption.new(text, callback, desc)
      end
    end
    
    # Minor Updates (ORANGE)
    if @results[:minor_updates].any?
      options << ColoredCategoryHeaderOption.new("Minor Updates Available", "Minor version behind - new features available.", :orange)
      @results[:minor_updates].each do |mod|
        text = sprintf("%s|%s|%s", mod[:name], mod[:local], mod[:online])
        callback = proc { pbModUpdateActions(mod) }
        desc = _INTL("Press ENTER for update options. {1} -> {2}", mod[:local], mod[:online])
        options << ButtonOption.new(text, callback, desc)
      end
    end
    
    # Hotfixes (YELLOW)
    if @results[:hotfixes].any?
      options << ColoredCategoryHeaderOption.new("Hotfixes Available", "Hotfix version behind - bug fixes available.", :yellow)
      @results[:hotfixes].each do |mod|
        text = sprintf("%s|%s|%s", mod[:name], mod[:local], mod[:online])
        callback = proc { pbModUpdateActions(mod) }
        desc = _INTL("Press ENTER for update options. {1} -> {2}", mod[:local], mod[:online])
        options << ButtonOption.new(text, callback, desc)
      end
    end
    
    # Up to Date (GREEN)
    if @results[:up_to_date].any?
      options << ColoredCategoryHeaderOption.new("Up to Date", "These mods are running the latest version.", :green)
      @results[:up_to_date].each do |mod|
        text = sprintf("%s|%s|", mod[:name], mod[:local])
        callback = proc { pbModUpdateActions(mod) }
        desc = _INTL("Version {1} - Up to date!", mod[:local])
        options << ButtonOption.new(text, callback, desc)
      end
    end
    
    # Developer Version (RED)
    if @results[:developer_version].any?
      options << ColoredCategoryHeaderOption.new("Developer Version", "Version is newer than the latest release.", :red)
      @results[:developer_version].each do |mod|
        text = sprintf("%s|%s|%s", mod[:name], mod[:local], mod[:online])
        callback = proc { pbModUpdateActions(mod) }
        desc = _INTL("Dev build {1} (latest release: {2})", mod[:local], mod[:online])
        options << ButtonOption.new(text, callback, desc)
      end
    end
    
    # Not Tracked (BLUE)
    if @results[:not_tracked].any?
      options << ColoredCategoryHeaderOption.new("Not Tracked", "These mods are not registered for auto-updates.", :blue)
      @results[:not_tracked].each do |mod|
        version_display = mod[:version].to_s.empty? ? "N/A" : mod[:version]
        text = sprintf("%s|%s|", mod[:name], version_display)
        desc = _INTL("This mod is not tracked for updates.")
        options << ButtonOption.new(text, proc {}, desc)
      end
    end
    
    # Check Failed (PINK/WHITE)
    if @results[:check_failed].any?
      options << ColoredCategoryHeaderOption.new("Update Check Failed", "Could not fetch version info for these mods.", :pink)
      @results[:check_failed].each do |mod|
        text = sprintf("%s|%s|Error", mod[:name], mod[:version])
        desc = _INTL("Failed to check for updates. Check logs.")
        options << ButtonOption.new(text, proc {}, desc)
      end
    end
    
    return options
  end
  
  def pbModUpdateActions(mod)
    commands = []
    descriptions = []
    
    update_needed = false
    if mod[:local] && mod[:online]
      begin
        local_parts = mod[:local].split('.').map(&:to_i)
        online_parts = mod[:online].split('.').map(&:to_i)
        update_needed = (local_parts <=> online_parts) < 0
      rescue
        update_needed = false
      end
    end
    
    has_download_url = mod[:download_url] && !mod[:download_url].empty?
    is_multiplayer = mod[:is_multiplayer] || mod[:download_url] == "autoupdate_multiplayer.bat"
    is_kifr = mod[:is_kifr] || mod[:name] == "KIF Redux"
    
    commands << _INTL("Update Mod")
    descriptions << _INTL("Download and install the latest version of this mod.")
    
    if mod[:changelog_url] && !mod[:changelog_url].empty?
      commands << _INTL("View Changelog")
      descriptions << _INTL("View the changelog for this mod.")
    end
    
    unless is_multiplayer || is_kifr
      commands << _INTL("Rollback")
      descriptions << _INTL("Restore a previous version from backup.")
    end
    
    commands << _INTL("Cancel")
    descriptions << _INTL("Return without making changes.")
    
    cmd = show_mod_list_commands(commands, descriptions, -1)
    
    index = 0
    
    if cmd == index  # Update
      if update_needed && has_download_url
        pbUpdateMod(mod)
      elsif update_needed && !has_download_url
        pbMessage(_INTL("Auto-update for this mod is not supported yet."))
      else
        pbMessage(_INTL("Your mod is already up to date!"))
      end
      return
    end
    index += 1
    
    if mod[:changelog_url] && !mod[:changelog_url].empty? && cmd == index
      pbViewChangelog(mod)
      return
    end
    index += 1 if mod[:changelog_url] && !mod[:changelog_url].empty?
    
    if cmd == index && !is_multiplayer && !is_kifr  # Rollback (not for Multiplayer or KIF Redux)
      pbRollbackMod(mod)
      return
    end
  end
  
  def pbUpdateMod(mod)
    # Debug log what we received
    KIFRSettings.debug_log("KIFR Update System: pbUpdateMod called for: #{mod[:name]}")
    KIFRSettings.debug_log("KIFR Update System:   is_multiplayer: #{mod[:is_multiplayer]}")
    KIFRSettings.debug_log("KIFR Update System:   download_url: #{mod[:download_url]}")
    
    # Special handling for Multiplayer - uses batch file updater
    if mod[:is_multiplayer] || mod[:download_url] == "autoupdate_multiplayer.bat"
      KIFRSettings.debug_log("KIFR Update System: Using Multiplayer special path")
      updater_path = File.join(Dir.pwd, "autoupdate_multiplayer.bat")
      KIFRSettings.debug_log("KIFR Update System: Updater path: #{updater_path}")
      if File.exist?(updater_path)
        if pbConfirmMessage(_INTL("Update Multiplayer from {1} to {2}?\n\nThis will run the auto-updater.", mod[:local], mod[:online]))
          KIFRSettings.debug_log("KIFR Update System: User confirmed, running batch file...")
          system("start \"\" \"#{updater_path}\"")
          pbMessage(_INTL("Auto-updater started. Please restart the game after the update completes."))
        end
      else
        KIFRSettings.debug_log("KIFR Update System: ERROR: Batch file not found!")
        pbMessage(_INTL("Could not find autoupdate_multiplayer.bat in the game folder."))
      end
      return
    end
    
    # Check dependencies
    if mod[:dependencies] && mod[:dependencies].any?
      missing_deps = []
      local_mods = KIFRSettings::VersionCheck.collect
      
      mod[:dependencies].each do |dep|
        dep_name = dep.is_a?(Hash) ? (dep[:name] || dep["name"]) : dep
        dep_version = dep.is_a?(Hash) ? (dep[:version] || dep["version"]) : nil
        
        installed = local_mods.find { |m| m[:name] == dep_name }
        
        if installed.nil?
          display_name = dep_name
          if KIFRSettings::ModRegistry.registered?("#{dep_name}.rb")
            reg = KIFRSettings::ModRegistry.get("#{dep_name}.rb")
            display_name = reg[:name] if reg
          end
          
          if dep_version
            missing_deps << "#{display_name}: #{dep_version}"
          else
            missing_deps << display_name
          end
        elsif dep_version
          begin
            inst_parts = installed[:version].split('.').map(&:to_i)
            req_parts = dep_version.split('.').map(&:to_i)
            if (inst_parts <=> req_parts) < 0
              display = installed[:display_name] || installed[:name]
              missing_deps << "#{display}: #{dep_version} (have #{installed[:version]})"
            end
          rescue
          end
        end
      end
      
      unless missing_deps.empty?
        warning = "This mod requires:\n"
        missing_deps.each { |dep| warning += "  - #{dep}\n" }
        warning += "\nContinue anyway?"
        return unless pbConfirmMessage(warning)
      end
    end
    
    message = sprintf("Update %s from %s to %s?", mod[:name], mod[:local], mod[:online])
    if mod[:graphics] && mod[:graphics].any?
      message += sprintf("\n\nThis will also download %d graphics file(s).", mod[:graphics].length)
    end
    
    return unless pbConfirmMessage(message)
    
    # Show brief status then do the work
    msgwindow = pbCreateMessageWindow
    pbMessageDisplay(msgwindow, _INTL("Updating {1}...", mod[:name]), false)
    Graphics.update
    
    success = KIFRSettings::ModUpdater.install_mod(mod[:path], mod[:download_url], mod[:local])
    pbDisposeMessageWindow(msgwindow)
    
    unless success
      pbMessage(_INTL("Failed to update mod. Check KIFRDebug.txt for details."))
      return
    end
    
    if mod[:graphics] && mod[:graphics].any?
      pbMessage(_INTL("Installing graphics files..."))
      success_count, failure_count = KIFRSettings::ModUpdater.install_graphics(mod[:graphics])
      
      if failure_count > 0
        pbMessage(sprintf("Mod updated! Graphics: %d succeeded, %d failed. Restart the game.", success_count, failure_count))
      else
        pbMessage(sprintf("Mod updated! Installed %d graphics file(s). Restart the game.", success_count))
      end
    else
      pbMessage(_INTL("Mod updated! Please restart the game for changes to take effect."))
    end
  end
  
  def pbRollbackMod(mod)
    backups = KIFRSettings::ModUpdater.list_backups_for_mod(mod[:path])
    
    if backups.empty?
      pbMessage(_INTL("No backups found for this mod."))
      return
    end
    
    commands = backups.map { |b| b[:display_name] } + [_INTL("Cancel")]
    choice = pbShowCommandsOpaque(commands, -1)
    
    if choice >= 0 && choice < backups.length
      selected_backup = backups[choice]
      
      message = sprintf("Rollback %s to %s?", mod[:name], selected_backup[:version])
      return unless pbConfirmMessage(message)
      
      if KIFRSettings::ModUpdater.rollback_mod(mod[:path], selected_backup[:path])
        pbMessage(_INTL("Mod rolled back successfully! Please restart the game."))
      else
        pbMessage(_INTL("Failed to rollback mod. Check KIFRDebug.txt for details."))
      end
    end
  end
  
  def show_mod_list_commands(commands, descriptions, cmdIfCancel = 0, defaultIndex = 0)
    # Store the current textbox content to restore later
    prev_text = @sprites["textbox"].text if @sprites["textbox"]
    
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
    @sprites["textbox"].text = descriptions[cmdwindow.index] if descriptions && descriptions[cmdwindow.index]
    
    command = 0
    loop do
      Graphics.update
      Input.update
      cmdwindow.update
      
      # Update description when selection changes
      if descriptions && descriptions[cmdwindow.index]
        @sprites["textbox"].text = descriptions[cmdwindow.index]
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
    
    # Restore the previous textbox content
    @sprites["textbox"].text = prev_text if @sprites["textbox"] && prev_text
    
    # Clear input to prevent the back button from propagating to the parent menu
    Input.update
    
    return command
  end
  
  def pbViewChangelog(mod)
    content = KIFRSettings::ModUpdater.download_file(mod[:changelog_url])
    
    if content.nil?
      pbMessage(_INTL("Failed to fetch changelog. Check KIFRDebug.txt for details."))
      return
    end
    
    ChangelogScene.show(mod[:name], content)
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create title (invisible initially)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Mod List"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    
    # Create description textbox (invisible initially)
    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].visible = false
    
    # Build options and window
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = false
    
    if @sprites["option"] && @sprites["option"].respond_to?(:use_color_theme=)
      @sprites["option"].use_color_theme = true
    end
    
    # Apply color theme BEFORE showing anything
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
  
  def pbOptions
    pbActivateWindow(@sprites, "option") {
      loop do
        Graphics.update
        Input.update
        pbUpdate
        
        # Handle back button
        if Input.trigger?(Input::BACK)
          break
        end
        
        # Handle selection
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
          option = @PokemonOptions[current]
          desc = option.description rescue ""
          # For ColoredCategoryHeaderOption, show the description
          if option.is_a?(ColoredCategoryHeaderOption)
            desc = option.instance_variable_get(:@description) || ""
          end
          @sprites["textbox"].text = desc if @sprites["textbox"]
        elsif current == @PokemonOptions.length
          @sprites["textbox"].text = _INTL("Return to Mod Manager.") if @sprites["textbox"]
        end
      end
    }
  end
end

#===============================================================================
# CHANGELOG VIEWER SCENE
#===============================================================================
class ChangelogScene
  def initialize(mod_name, changelog_text)
    @mod_name = mod_name
    @changelog_text = changelog_text || ""
    
    lines = @changelog_text.split("\n")
    @header = (lines.first && !lines.first.empty?) ? lines.first : mod_name
    @content = lines.length > 1 ? lines[1..-1].join("\n") : @changelog_text
    
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
  end
  
  def pbStartScene
    # Create black background for fade
    @sprites["background"] = Sprite.new(@viewport)
    @sprites["background"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @sprites["background"].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    @sprites["background"].z = -1
    
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      @header, 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    @sprites["textbox"] = Window_AdvancedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].text = _INTL("B: Back")
    
    content_y = @sprites["title"].height
    content_height = Graphics.height - @sprites["title"].height - @sprites["textbox"].height
    
    wrapped_lines = []
    content_to_wrap = @content || ""
    content_to_wrap.split("\n").each do |line|
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
    
    # Ensure we have at least one line
    wrapped_lines << _INTL("No changelog content available.") if wrapped_lines.empty?
    
    @sprites["content"] = Window_CommandPokemon.newWithSize(
      wrapped_lines, 0, content_y, Graphics.width, content_height, @viewport)
    @sprites["content"].baseColor = Color.new(248, 248, 248)
    @sprites["content"].shadowColor = Color.new(0, 0, 0)
    @sprites["content"].index = 0
    
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
      
      max_index = @sprites["content"].commands.length - 1
      
      # Scrolling: UP/DOWN = 1 line, LEFT/RIGHT = 2 lines
      if Input.trigger?(Input::UP)
        @sprites["content"].index -= 1 if @sprites["content"].index > 0
      elsif Input.trigger?(Input::DOWN)
        @sprites["content"].index += 1 if @sprites["content"].index < max_index
      elsif Input.trigger?(Input::LEFT)
        @sprites["content"].index = [@sprites["content"].index - 2, 0].max
      elsif Input.trigger?(Input::RIGHT)
        @sprites["content"].index = [@sprites["content"].index + 2, max_index].min
      elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
        break
      end
    end
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  def self.show(mod_name, changelog_text)
    scene = ChangelogScene.new(mod_name, changelog_text)
    scene.pbStartScene
    scene.pbScene
    scene.pbEndScene
  end
end

#===============================================================================
# AUTO-UPDATE NOTIFICATION SCENE
#===============================================================================
class AutoUpdateNotificationScene < PokemonOption_Scene
  attr_accessor :confirmed
  
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def initialize(updates_available, skip_confirm)
    super()
    @updates_available = updates_available
    @skip_confirm = skip_confirm
    @confirmed = false
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
    optionsWindow.visible = true
    return optionsWindow
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    options << ColumnHeaderOption.new
    
    major_updates = []
    minor_updates = []
    hotfixes = []
    
    @updates_available.each do |mod|
      if mod[:local] && mod[:online]
        begin
          local_parts = mod[:local].split('.').map(&:to_i)
          online_parts = mod[:online].split('.').map(&:to_i)
          
          if local_parts[0] < online_parts[0]
            major_updates << mod
          elsif local_parts[1] < online_parts[1]
            minor_updates << mod
          else
            hotfixes << mod
          end
        rescue
          hotfixes << mod
        end
      end
    end
    
    if major_updates.any?
      options << ColoredCategoryHeaderOption.new("Major Updates Available", "Major version behind", :red)
      major_updates.each do |mod|
        text = sprintf("%s|%s|%s", mod[:name], mod[:local], mod[:online])
        options << ButtonOption.new(text, proc {}, " ")
      end
    end
    
    if minor_updates.any?
      options << ColoredCategoryHeaderOption.new("Minor Updates Available", "Minor version behind", :orange)
      minor_updates.each do |mod|
        text = sprintf("%s|%s|%s", mod[:name], mod[:local], mod[:online])
        options << ButtonOption.new(text, proc {}, " ")
      end
    end
    
    if hotfixes.any?
      options << ColoredCategoryHeaderOption.new("Hotfixes Available", "Hotfix version behind", :yellow)
      hotfixes.each do |mod|
        text = sprintf("%s|%s|%s", mod[:name], mod[:local], mod[:online])
        options << ButtonOption.new(text, proc {}, " ")
      end
    end
    
    return options
  end
  
  def pbStartScene(inloadscreen = false)
    super
    
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Auto-Update"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    
    if @sprites["option"] && @sprites["option"].respond_to?(:use_color_theme=)
      @sprites["option"].use_color_theme = true
    end
    
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0)
    end
    @sprites["option"].refresh
    
    pbFadeInAndShow(@sprites) { pbUpdate }
  end
  
  def pbEndScene
    if @skip_confirm
      @confirmed = true
    else
      count = @updates_available.length
      @confirmed = pbConfirmMessage(_INTL("Would you like to update all {1} mod(s)?", count))
    end
    
    super
  end
  
  def self.show_and_confirm(updates_available, skip_confirm = false)
    scene = nil
    pbFadeOutIn {
      scene = AutoUpdateNotificationScene.new(updates_available, skip_confirm)
      screen = PokemonOptionScreen.new(scene)
      screen.pbStartScreen
    }
    
    return scene.confirmed
  end
end

#===============================================================================
# MOD MANAGER MENU SCENE - Proper scene-based menu (KIFR style)
#===============================================================================
class ModManagerMenuScene < PokemonOption_Scene
  # Skip fade-in - we handle it manually after applying theme
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
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
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create UI elements first (invisible)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Mod Manager"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    
    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].visible = false
    
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = false
    
    # Apply color theme BEFORE showing anything
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    # Initialize option values
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0) rescue 0
    end
    @sprites["option"].refresh
    
    # Now show everything
    @sprites.each { |k, s| s.visible = true if s }
    pbFadeInAndShow(@sprites)
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    options << ButtonOption.new(_INTL("Manage Mods"),
      proc { do_manage_mods },
      _INTL("Enable or disable installed mods."))
    
    options << ButtonOption.new(_INTL("Mod List"),
      proc { do_check_updates },
      _INTL("View installed mods and check for updates."))
    
    options << ButtonOption.new(_INTL("Update All"),
      proc { do_update_all },
      _INTL("Update all mods that have available updates."))
    
    options << ButtonOption.new(_INTL("Manage Backups"),
      proc { do_manage_backups },
      _INTL("Manage mod backup files."))
    
    options << EnumOption.new(_INTL("Auto-Update Check"), [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:mod_auto_update, 1) },  # Default: On
      proc { |value| KIFRSettings.set(:mod_auto_update, value) },
      _INTL("Automatically check for mod updates when the game starts."))
    
    options << EnumOption.new(_INTL("Auto-Update Confirm"), [_INTL("Off"), _INTL("On")],
      proc { KIFRSettings.get(:mod_auto_update_confirm) || 1 },
      proc { |value| KIFRSettings.set(:mod_auto_update_confirm, value) },
      _INTL("Require confirmation before applying auto-updates."))
    
    options
  end
  
  def pbOptions
    pbActivateWindow(@sprites, "option") {
      loop do
        Graphics.update
        Input.update
        pbUpdate
        
        # Handle back button (B/X)
        if Input.trigger?(Input::BACK)
          break
        end
        
        # Handle selection
        if Input.trigger?(Input::USE)
          # Check if Confirm button selected
          break if isConfirmedOnKeyPress
          
          current = @sprites["option"].index
          option = @PokemonOptions[current]
          
          if option.is_a?(ButtonOption) && option.respond_to?(:callback) && option.callback
            option.callback.call
          end
        end
        
        # Update description
        current = @sprites["option"].index
        if current >= 0 && current < @PokemonOptions.length
          desc = @PokemonOptions[current].description rescue ""
          @sprites["textbox"].text = desc if @sprites["textbox"]
        elsif current == @PokemonOptions.length
          # Confirm button
          @sprites["textbox"].text = _INTL("Return to KIFR Settings.") if @sprites["textbox"]
        end
      end
    }
  end
  
  def do_manage_mods
    pbFadeOutIn {
      scene = ModManagerScene.new
      screen = PokemonOptionScreen.new(scene)
      screen.pbStartScreen
    }
  end
  
  def do_check_updates
    results = KIFRSettings::UpdateCheck.check_updates
    
    if results[:error]
      pbMessage(_INTL(results[:error]))
      return
    end
    
    pbFadeOutIn {
      scene = UpdateResultsScene.new(results)
      screen = PokemonOptionScreen.new(scene)
      screen.pbStartScreen
    }
  end
  
  def do_update_all
    # Check for updates first
    pbMessage(_INTL("Checking for updates..."))
    results = KIFRSettings::UpdateCheck.check_updates
    
    if results[:error]
      pbMessage(_INTL(results[:error]))
      return
    end
    
    # Find mods with updates available
    mods_list = results[:mods] || []
    updatable_mods = mods_list.select { |m| m[:has_update] && m[:download_url] }
    
    if updatable_mods.empty?
      pbMessage(_INTL("All mods are up to date!"))
      return
    end
    
    # Show list and confirm
    mod_names = updatable_mods.map { |m| m[:name] || File.basename(m[:path], ".rb") }
    
    if !pbConfirmMessage(_INTL("Update {1} mod(s)?\n{2}", updatable_mods.length, mod_names.join(", ")))
      return
    end
    
    # Update each mod
    success_count = 0
    fail_count = 0
    skipped_special = []
    
    msgwindow = pbCreateMessageWindow
    
    updatable_mods.each do |mod|
      mod_name = mod[:name] || File.basename(mod[:path])
      
      # Skip Multiplayer and KIF Redux - they need special handling
      is_multiplayer = mod[:is_multiplayer] || mod[:download_url] == "autoupdate_multiplayer.bat"
      is_kifr = mod[:is_kifr] || mod[:name] == "KIF Redux"
      
      if is_multiplayer || is_kifr
        skipped_special << mod_name
        next
      end
      
      pbMessageDisplay(msgwindow, _INTL("Updating {1}...", mod_name), false)
      Graphics.update
      
      begin
        result = KIFRSettings::ModUpdater.install_mod(
          mod[:path],
          mod[:download_url],
          mod[:current_version]
        )
        
        if result
          success_count += 1
        else
          fail_count += 1
        end
      rescue => e
        KIFRSettings.debug_log("KIFR Update System: ERROR: Update failed for #{mod[:path]}: #{e.message}")
        fail_count += 1
      end
    end
    
    pbDisposeMessageWindow(msgwindow)
    
    # Report results
    if fail_count == 0 && success_count > 0
      pbMessage(_INTL("Successfully updated {1} mod(s)!", success_count))
      pbMessage(_INTL("Please restart the game for changes to take effect."))
    elsif fail_count > 0
      pbMessage(_INTL("Updated {1} mod(s), {2} failed.", success_count, fail_count))
      if success_count > 0
        pbMessage(_INTL("Please restart the game for changes to take effect."))
      end
    end
    
    # Notify about skipped special mods that need manual update
    if skipped_special.any?
      pbMessage(_INTL("KIF Redux and Multiplayer must be updated in the Mod Manager."))
    end
  end
  
  def do_manage_backups
    backups = KIFRSettings::ModUpdater.list_backups
    
    if backups.empty?
      pbMessage(_INTL("No backups found."))
      return
    end
    
    commands = backups.map { |b| b[:display_name] }
    commands << _INTL("Delete All")
    commands << _INTL("Back")
    
    loop do
      choice = pbMessage(_INTL("Mod Backups ({1})", backups.length), commands, -1)
      
      break if choice < 0 || choice == commands.length - 1
      
      if choice == commands.length - 2  # Delete All
        if pbConfirmMessage(_INTL("Delete all {1} backup(s)?", backups.length))
          count = 0
          backups.each do |backup|
            count += 1 if KIFRSettings::ModUpdater.delete_backup(backup[:path])
          end
          pbMessage(_INTL("Deleted {1} backup(s).", count))
          break
        end
      else
        backup = backups[choice]
        if pbConfirmMessage(_INTL("Delete {1}?", backup[:display_name]))
          if KIFRSettings::ModUpdater.delete_backup(backup[:path])
            pbMessage(_INTL("Backup deleted."))
            backups = KIFRSettings::ModUpdater.list_backups
            commands = backups.map { |b| b[:display_name] } + [_INTL("Delete All"), _INTL("Back")]
          else
            pbMessage(_INTL("Failed to delete backup."))
          end
        end
      end
    end
  end
  
  def do_spritepacks
    pbFadeOutIn {
      scene = SpritepacksScene.new
      screen = PokemonOptionScreen.new(scene)
      screen.pbStartScreen
    }
  end
end

#===============================================================================
# SPRITEPACKS SCENE - Download sprite packs
#===============================================================================
class SpritepacksScene < PokemonOption_Scene
  # Spritepack definitions
  SPRITEPACKS = {
    kif: {
      name: "KIF Spritepack", 
      download_url: "https://github.com/Stonewallx/KIF-Spritepack/archive/refs/heads/main.zip"
    },
    pif: {
      name: "PIF Spritepack",
      download_url: "https://github.com/Stonewallx/PIF-Spritepack/archive/refs/heads/main.zip"
    },
    kifr: {
      name: "KIFR Spritepack",
      download_url: nil  # TODO: Add URL
    }
  }
  
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  def initialize
    super
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
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Spritepacks"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    
    # Use description box instead of message window
    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].visible = false
    
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = false
    
    # Apply color theme
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    @sprites.each { |k, s| s.visible = true if s }
    pbFadeInAndShow(@sprites)
  end
  
  def pbGetOptions(inloadscreen = false)
    options = []
    
    options << ButtonOption.new(_INTL("KIF Spritepack"),
      proc { run_spritepack_installer("KIFR-KIF Spritepack Install.bat", "KIF Spritepack") },
      _INTL("KIF (Feb 2025)"))
    
    options << ButtonOption.new(_INTL("PIF Spritepack"),
      proc { run_spritepack_installer("KIFR-PIF Spritepack Install.bat", "PIF Spritepack") },
      _INTL("PIF Full 1-120 (Nov 2025)"))
    
    options
  end
  
  def run_spritepack_installer(bat_file, name)
    bat_path = File.join(Dir.pwd, bat_file)
    
    if !File.exist?(bat_path)
      pbMessage(_INTL("Could not find {1} in the game folder.", bat_file))
      return
    end
    
    return unless pbConfirmMessage(_INTL("Run the {1} installer?\\nThis will download/update the spritepack from GitHub.", name))
    
    begin
      # Store game window handle to refocus later
      game_hwnd = nil
      set_foreground = nil
      begin
        if defined?(Win32API)
          get_foreground = Win32API.new('user32', 'GetForegroundWindow', '', 'L')
          set_foreground = Win32API.new('user32', 'SetForegroundWindow', 'L', 'I')
          game_hwnd = get_foreground.call
        end
      rescue
      end
      
      # Run the batch file
      system("start \"\" \"#{bat_path}\"")
      
      pbMessage(_INTL("{1} installer launched!\\nCheck the command prompt window for progress.", name))
      
      # Try to refocus on game
      begin
        if game_hwnd && game_hwnd != 0 && set_foreground
          set_foreground.call(game_hwnd)
        end
      rescue
      end
    rescue => e
      pbMessage(_INTL("Error launching installer: {1}", e.message))
    end
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
        
        # Update description
        current = @sprites["option"].index
        if current >= 0 && current < @PokemonOptions.length
          desc = @PokemonOptions[current].description rescue ""
          @sprites["textbox"].text = desc if @sprites["textbox"]
        elsif current == @PokemonOptions.length
          @sprites["textbox"].text = _INTL("Return to Mod Manager.") if @sprites["textbox"]
        end
      end
    }
  end
  
  def show_spritepack_options(pack_key)
    pack = SPRITEPACKS[pack_key]
    return unless pack
    
    download_spritepack(pack)
  end
  
  def download_spritepack(pack)
    if pack[:download_url].nil? || pack[:download_url].empty?
      pbMessage(_INTL("Download URL not configured for {1}.", pack[:name]))
      return
    end
    
    # Simple confirmation - always shows progress and skips existing
    return unless pbConfirmMessage(_INTL("Download and install {1}?\\nExisting files will be skipped for faster install.", pack[:name]))
    
    begin
      KIFRSettings.debug_log("KIFR Spritepacks: Starting download of #{pack[:name]}")
      
      base_folder = Dir.pwd
      
      # Show downloading message
      msgwindow = pbCreateMessageWindow
      pbMessageDisplay(msgwindow, _INTL("Downloading {1}...\\nPlease wait, this may take a while.", pack[:name]), false)
      Graphics.update
      
      content = KIFRSettings::ModUpdater.download_file(pack[:download_url])
      
      unless content && content.length > 0
        pbDisposeMessageWindow(msgwindow)
        pbMessage(_INTL("Download failed - no data received."))
        return
      end
      
      # Save ZIP file
      temp_zip = File.join(base_folder, pack[:name].gsub(" ", "_") + ".zip")
      File.open(temp_zip, 'wb') { |f| f.write(content) }
      
      # Extract with progress, skipping existing files
      last_update = Time.now
      success = KIFRSettings::ModUpdater.extract_zip_with_progress(temp_zip, base_folder, true) do |percent, status_text|
        if Time.now - last_update >= 0.1
          pbMessageDisplay(msgwindow, status_text, false)
          Graphics.update
          last_update = Time.now
        end
      end
      
      File.delete(temp_zip) if File.exist?(temp_zip)
      
      pbDisposeMessageWindow(msgwindow)
      
      if success
        pbMessage(_INTL("Successfully installed {1}!\\nPlease restart the game.", pack[:name]))
      else
        pbMessage(_INTL("Download completed but extraction failed."))
      end
      
    rescue => e
      KIFRSettings.debug_log("KIFR Spritepacks: ERROR: #{e.class} - #{e.message}")
      pbDisposeMessageWindow(msgwindow) if msgwindow
      pbMessage(_INTL("Installation failed: {1}", e.message))
    end
  end
end

#===============================================================================
# OVERRIDE MOD UPDATES MENU
#===============================================================================
class KIFRSettingsScene
  # Full Mod Manager menu - now uses proper scene
  def show_mod_updates_menu
    scene = ModManagerMenuScene.new
    screen = PokemonOptionScreen.new(scene)
    screen.pbStartScreen
  end
  
  # Spritepacks menu - now uses proper scene
  def show_spritepacks_menu
    scene = SpritepacksScene.new
    screen = PokemonOptionScreen.new(scene)
    screen.pbStartScreen
  end
end

#===============================================================================
# MOD MANAGER MODULE
#===============================================================================
# Handles enabling/disabling mods by renaming file extensions
# .rb = enabled, .disabled = disabled
#===============================================================================
module KIFRSettings
  module ModManager
    # Directories to scan for mods
    SCAN_DIRS = [
      "Mods",
      "Data/Scripts/998_Mods"
    ]
    
    # Files that should never be disabled (system files)
    PROTECTED_FILES = [
      "002_KIF_Recursive_Mod.rb",
      "001_Utils.rb",
      "002_KIF_Recursive_Mod.disabled",
      "001_Utils.disabled"
    ]
    
    # Track if any changes were made this session (for restart warning)
    @changes_made = false
    
    class << self
      attr_accessor :changes_made
      
      # Collect all manageable mods (both .rb and .disabled)
      # Returns array of hashes with mod info
      def collect_mods
        mods = []
        
        SCAN_DIRS.each do |base_dir|
          next unless Dir.exist?(base_dir)
          scan_directory(base_dir, mods)
        end
        
        # Sort with KIF Redux first, then Multiplayer, then KIFR Dev Tools, then alphabetically
        mods.sort_by! do |m|
          name_lower = m[:display_name].downcase
          # KIF Redux gets priority 0, Multiplayer gets priority 1, KIFR Dev Tools gets 1.5, others get 2
          is_kifr = name_lower.include?("kif redux") || name_lower.include?("kifr redux")
          is_multiplayer = name_lower == "multiplayer"
          is_kifrdev = name_lower.include?("kifr dev") || name_lower.include?("kifrdev")
          priority = if is_kifr then 0
                     elsif is_multiplayer then 1
                     elsif is_kifrdev then 1.5
                     else 2
                     end
          [priority, name_lower]
        end
        mods
      end
      
      # Recursively scan a directory for mods
      def scan_directory(dir, mods)
        return unless Dir.exist?(dir)
        
        # Find all .rb and .disabled files
        Dir.glob(File.join(dir, "*.rb")) do |file_path|
          add_mod_entry(file_path, true, mods)
        end
        
        Dir.glob(File.join(dir, "*.disabled")) do |file_path|
          add_mod_entry(file_path, false, mods)
        end
        
        # Recursively scan subdirectories
        Dir.foreach(dir) do |entry|
          next if entry == "." || entry == ".."
          subdir = File.join(dir, entry)
          scan_directory(subdir, mods) if File.directory?(subdir)
        end
      end
      
      # Add a mod entry to the collection
      def add_mod_entry(file_path, enabled, mods)
        filename = File.basename(file_path)
        
        # Skip protected files
        return if protected?(filename)
        
        # Get display name (without extension) - fallback
        fallback_name = filename.sub(/\.(rb|disabled)$/, '')
        
        # Extract version from header
        version = extract_version(file_path)
        
        # Get folder for display
        folder = File.dirname(file_path)
        folder = "Root" if folder == "Mods"
        folder = folder.sub("Mods/", "") if folder.start_with?("Mods/")
        folder = folder.sub("Data/Scripts/998_Mods/", "") if folder.start_with?("Data/Scripts/998_Mods/")
        folder = "998_Mods" if folder == "Data/Scripts/998_Mods"
        
        # Check if registered with ModRegistry (only works for enabled mods)
        rb_filename = fallback_name + ".rb"
        registered = ModRegistry.registered?(rb_filename)
        reg_info = registered ? ModRegistry.get(rb_filename) : nil
        
        # Check if this is an integrated mod
        is_integrated = KIFRSettings.is_integrated_file?(filename)
        
        # Get display name - try multiple sources
        display_name = nil
        
        # 1. Try registry name (if found by exact filename match)
        if reg_info && reg_info[:name]
          display_name = reg_info[:name]
        end
        
        # 2. If no registry match, try to extract name from file content
        #    (works for both enabled and disabled mods, handles filename mismatches)
        if display_name.nil?
          display_name = extract_registration_name(file_path)
        end
        
        # 3. Fallback to filename
        display_name ||= fallback_name
        
        mods << {
          path: File.expand_path(file_path),
          filename: filename,
          display_name: display_name,
          version: version || (reg_info ? reg_info[:version] : nil),
          folder: folder,
          enabled: enabled,
          protected: false,
          registered: registered,
          integrated: is_integrated,
          dependencies: reg_info ? (reg_info[:dependencies] || []) : []
        }
      end
      
      # Extract the display name from a mod file's registration block
      # Looks for: name: "Display Name" in ModRegistry.register calls
      def extract_registration_name(file_path)
        return nil unless File.exist?(file_path)
        
        begin
          content = File.read(file_path, encoding: 'utf-8')
          
          # Find ModRegistry.register block and extract name from within it
          # Match the register call and its argument block (handles multi-line)
          # Look for patterns like:
          #   ModRegistry.register(
          #     name: "Display Name",
          #   or
          #   ModRegistry.register({
          #     name: "Display Name",
          
          # Find position of ModRegistry.register
          if content =~ /ModSettingsMenu::ModRegistry\.register\s*\(\s*\{?/m ||
             content =~ /KIFRSettings::ModRegistry\.register\s*\(\s*\{?/m ||
             content =~ /ModRegistry\.register\s*\(\s*\{?/m
            
            register_pos = $~.end(0)
            
            # Get the text after the register call (up to 500 chars should be enough for the block)
            block_text = content[register_pos, 500]
            
            # Now look for name: within this block, but NOT in comments
            # Split by lines and find the first non-commented name:
            block_text.each_line do |line|
              # Skip comment lines
              next if line.strip.start_with?('#')
              
              # Look for name: "value" or name: 'value'
              if line =~ /^\s*name:\s*["']([^"']+)["']/
                return $1
              end
            end
          end
        rescue => e
          # Silently fail
        end
        
        nil
      end
      
      # Check if a file is protected
      def protected?(filename)
        PROTECTED_FILES.any? { |pf| filename.downcase == pf.downcase }
      end
      
      # Extract version from file header
      def extract_version(file_path)
        return nil unless File.exist?(file_path)
        
        line_count = 0
        File.open(file_path, "r") do |file|
          file.each_line do |line|
            line_count += 1
            break if line_count > 40
            
            if line =~ /^#\s*Script Version:\s*(\d+\.\d+(?:\.\d+)?)/i
              return $1
            end
          end
        end
        nil
      rescue
        nil
      end
      
      # Enable a mod (rename .disabled to .rb)
      def enable_mod(path)
        return false unless File.exist?(path)
        return false unless path.end_with?(".disabled")
        
        # Block enabling integrated files
        base_name = File.basename(path).sub(/\.disabled$/, '.rb')
        if KIFRSettings.is_integrated_file?(base_name)
          return :integrated  # Return special symbol to indicate integrated file
        end
        
        new_path = path.sub(/\.disabled$/, ".rb")
        
        begin
          File.rename(path, new_path)
          @changes_made = true
          KIFRSettings.debug_log("KIFR Update System: Enabled mod: #{File.basename(path)}")
          true
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: Failed to enable mod: #{e.message}")
          false
        end
      end
      
      # Disable a mod (rename .rb to .disabled)
      def disable_mod(path)
        return false unless File.exist?(path)
        return false unless path.end_with?(".rb")
        return false if protected?(File.basename(path))
        
        new_path = path.sub(/\.rb$/, ".disabled")
        
        begin
          File.rename(path, new_path)
          @changes_made = true
          KIFRSettings.debug_log("KIFR Update System: Disabled mod: #{File.basename(path)}")
          true
        rescue => e
          KIFRSettings.debug_log("KIFR Update System: ERROR: Failed to disable mod: #{e.message}")
          false
        end
      end
      
      # Toggle a mod's enabled state
      def toggle_mod(path)
        if path.end_with?(".disabled")
          enable_mod(path)
        elsif path.end_with?(".rb")
          disable_mod(path)
        else
          false
        end
      end
      
      # Enable all mods
      def enable_all
        count = 0
        collect_mods.each do |mod|
          next if mod[:enabled]
          count += 1 if enable_mod(mod[:path])
        end
        count
      end
      
      # Disable all mods
      def disable_all
        count = 0
        collect_mods.each do |mod|
          next unless mod[:enabled]
          next if mod[:protected]
          count += 1 if disable_mod(mod[:path])
        end
        count
      end
      
      # Check for mods that depend on a given mod
      # Returns array of mod names that depend on the target
      def find_dependents(mod_display_name)
        dependents = []
        
        collect_mods.each do |mod|
          next unless mod[:enabled]
          next if mod[:dependencies].nil? || mod[:dependencies].empty?
          
          mod[:dependencies].each do |dep|
            dep_name = dep.is_a?(Hash) ? dep[:file] : dep.to_s
            next if dep_name.nil? || dep_name.empty?
            dep_name = dep_name.sub(/\.rb$/, '')
            
            if dep_name.downcase == mod_display_name.downcase
              dependents << mod[:display_name]
            end
          end
        end
        
        dependents
      end
      
      # Scan a file for require/load statements to detect dependencies
      def scan_for_dependencies(file_path)
        deps = []
        return deps unless File.exist?(file_path)
        
        File.open(file_path, "r") do |file|
          file.each_line do |line|
            # Look for require_relative or load statements
            if line =~ /require_relative\s+['"]([^'"]+)['"]/
              deps << $1
            elsif line =~ /load\s+['"]([^'"]+\.rb)['"]/
              deps << $1
            end
          end
        end
        
        deps
      rescue
        []
      end
      
      # Reset changes flag
      def reset_changes
        @changes_made = false
      end
      
      # Check if changes were made
      def changes_made?
        @changes_made
      end
    end
  end
end

#===============================================================================
# MOD MANAGER OPTION TYPES
#===============================================================================

# Option type for mod entries with colored status
class ModEntryOption < Option
  attr_reader :name, :mod_data
  
  def initialize(mod_data)
    @mod_data = mod_data
    @name = mod_data[:display_name]
    @description = build_description
  end
  
  def build_description
    status = @mod_data[:enabled] ? "Enabled" : "Disabled"
    version = @mod_data[:version] ? " v#{@mod_data[:version]}" : ""
    folder = @mod_data[:folder] != "Root" ? " [#{@mod_data[:folder]}]" : ""
    "#{status}#{version}#{folder}"
  end
  
  def get
    @mod_data[:enabled] ? 1 : 0
  end
  
  def set(value)
    # Not used directly - toggle is handled by scene
  end
  
  def prev(current)
    current  # No change - not a selectable enum
  end
  
  def next(current)
    current  # No change - not a selectable enum
  end
  
  def values
    ["Disabled", "Enabled"]
  end
  
  def description
    @description
  end
end

# Status header option for Mod Manager (uses ColoredCategoryHeaderOption pattern)
class ModStatusHeaderOption < Option
  attr_reader :name, :color_key
  
  def initialize(text, count, color_key)
    @text = text
    @count = count
    @name = "#{text} (#{count})"
    @color_key = color_key
    @description = ""
  end
  
  def get
    0
  end
  
  def set(value)
  end
  
  def prev(current)
    current  # No change - headers are not selectable
  end
  
  def next(current)
    current  # No change - headers are not selectable
  end
  
  def values
    [""]
  end
  
  def format(value)
    return @name
  end
  
  def non_interactive?
    true
  end
  
  def description
    @description
  end
end

#===============================================================================
# WINDOW FOR MOD MANAGER - Styled like Window_UpdateResults
#===============================================================================
class Window_ModManager < Window_PokemonOption
  attr_reader :mustUpdateDescription
  
  def initialize(options, x, y, width, height)
    @options = options
    @mustUpdateDescription = false
    super(options, x, y, width, height)
  end
  
  def descriptionUpdated
    @mustUpdateDescription = false
  end
  
  # itemCount inherited from parent: returns @options.length + 1 (includes Confirm)
  
  def drawItem(index, _count, rect)
    # Confirm button at index == @options.length - let parent draw it
    if index == @options.length
      super(index, _count, rect)
      return
    end
    
    return if index >= @options.length
    option = @options[index]
    
    # Spacer - draw nothing
    if option.is_a?(SpacerOption)
      return
    end
    
    # Category header (Enabled Mods / Disabled Mods) - use red theme, centered
    if option.is_a?(ModStatusHeaderOption)
      draw_category_header(option, index, rect)
      return
    end
    
    # Mod entry - show name + colored status
    if option.is_a?(ModEntryOption)
      draw_mod_entry(option, index, rect)
      return
    end
    
    # Button (Enable All, Disable All, Back)
    if option.is_a?(ButtonOption)
      draw_button(option, index, rect)
      return
    end
    
    # Fallback
    super(index, _count, rect)
  end
  
  def draw_category_header(option, index, rect)
    # Use the correct color theme based on the header's color_key
    theme = nil
    if defined?(COLOR_THEMES) && option.respond_to?(:color_key)
      theme = COLOR_THEMES[option.color_key]
    end
    theme ||= COLOR_THEMES[:red] if defined?(COLOR_THEMES)
    
    # Draw cursor using parent's method
    rect = drawCursor(index, rect)
    
    text = option.format(0)
    text_width = 200
    begin
      text_size_result = self.contents.text_size(text)
      text_width = text_size_result.width if text_size_result && text_size_result.respond_to?(:width)
    rescue
      text_width = 200
    end
    x_pos = (rect.width - text_width) / 2
    
    if theme && theme[:base] && theme[:shadow]
      pbDrawShadowText(self.contents, x_pos, rect.y, text_width + 20, rect.height, text,
                     theme[:base], theme[:shadow])
    else
      pbDrawShadowText(self.contents, x_pos, rect.y, text_width + 20, rect.height, text,
                     Color.new(178, 34, 34), Color.new(60, 20, 20))
    end
  end
  
  def draw_mod_entry(option, index, rect)
    rect = drawCursor(index, rect)
    mod = option.mod_data
    name = mod[:display_name] || "Unknown"
    
    # Layout: Mod Name (left) | Status (right)
    optionwidth = rect.width * 14 / 20
    status_width = rect.width - optionwidth
    
    # Truncate name if too long (with safety limit to prevent infinite loop)
    max_name_width = optionwidth - 10
    max_iterations = 50
    iterations = 0
    while self.contents.text_size(name).width > max_name_width && name.length > 6 && iterations < max_iterations
      name = name[0..-5] + "..."
      iterations += 1
    end
    
    # Draw mod name
    pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height,
                     name, @nameBaseColor, @nameShadowColor)
    
    # Draw status - Green for Enabled, Red for Disabled, Blue for Integrated
    status_x = rect.x + optionwidth
    if mod[:integrated]
      status_color = Color.new(100, 149, 237)  # Cornflower blue
      status_shadow = Color.new(35, 55, 100)
      status_text = "Integrated"
    elsif mod[:enabled]
      status_color = Color.new(34, 139, 34)  # Forest green
      status_shadow = Color.new(15, 60, 15)
      status_text = "Enabled"
    else
      status_color = Color.new(178, 34, 34)  # Firebrick red
      status_shadow = Color.new(60, 20, 20)
      status_text = "Disabled"
    end
    
    pbDrawShadowText(self.contents, status_x, rect.y, status_width, rect.height,
                     status_text, status_color, status_shadow)
  end
  
  def draw_button(option, index, rect)
    rect = drawCursor(index, rect)
    
    # Use theme color for buttons
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    theme_key = COLOR_THEMES.keys[theme_index] if defined?(COLOR_THEMES)
    theme = COLOR_THEMES[theme_key] if theme_key && defined?(COLOR_THEMES)
    
    if theme && theme[:base] && theme[:shadow]
      pbDrawShadowText(self.contents, rect.x, rect.y, rect.width, rect.height,
                       option.name, theme[:base], theme[:shadow])
    else
      pbDrawShadowText(self.contents, rect.x, rect.y, rect.width, rect.height,
                       option.name, @nameBaseColor, @nameShadowColor)
    end
  end
end

#===============================================================================
# MOD MANAGER SCENE
#===============================================================================
class ModManagerScene < PokemonOption_Scene
  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if visiblesprites
      visiblesprites.each { |s| sprites[s].visible = true }
    else
      sprites.each { |key, sprite| sprite.visible = true if sprite }
    end
  end
  
  # Override pbUpdate to handle description properly (including Confirm button)
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
    
    if @sprites["option"] && @sprites["option"].mustUpdateDescription
      current = @sprites["option"].index
      
      if current >= 0 && current < @PokemonOptions.length
        desc = @PokemonOptions[current].description rescue ""
        @sprites["textbox"].text = desc if @sprites["textbox"]
      elsif current == @PokemonOptions.length
        # Confirm button
        @sprites["textbox"].text = _INTL("Save changes and return.") if @sprites["textbox"]
      else
        @sprites["textbox"].text = "" if @sprites["textbox"]
      end
      
      @sprites["option"].descriptionUpdated
    end
  end
  
  def initialize
    super()
    @restart_warning_shown = false
    KIFRSettings::ModManager.reset_changes
  end
  
  def pbStartScene(inloadscreen = false)
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    # Create title (invisible initially)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Manage Mods"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["title"].visible = false
    
    # Create textbox (invisible initially)
    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      "", 0, Graphics.height - 64, Graphics.width, 64, @viewport)
    @sprites["textbox"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["textbox"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["textbox"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
    @sprites["textbox"].visible = false
    
    # Build options and window
    @PokemonOptions = pbGetOptions(inloadscreen)
    @sprites["option"] = initOptionsWindow
    @sprites["option"].visible = false
    
    # Apply color theme BEFORE showing anything
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
    
    # Refresh display
    @sprites["option"].refresh if @sprites["option"].respond_to?(:refresh)
    
    # Now show everything
    @sprites.each { |k, s| s.visible = true if s }
    pbFadeInAndShow(@sprites)
  end
  
  def initOptionsWindow
    optionsWindow = Window_ModManager.new(@PokemonOptions, 0,
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
  
  def pbGetOptions(inloadscreen = false)
    build_options_list
  end
  
  def build_options_list
    options = []
    mods = KIFRSettings::ModManager.collect_mods
    
    # Separate integrated mods from regular mods
    integrated_mods = mods.select { |m| m[:integrated] }
    regular_mods = mods.reject { |m| m[:integrated] }
    
    # Count enabled and disabled (only regular mods)
    enabled_count = regular_mods.count { |m| m[:enabled] }
    disabled_count = regular_mods.count { |m| !m[:enabled] }
    
    # Action buttons at top (only affects non-integrated mods)
    options << ButtonOption.new(_INTL("Enable All ({1} disabled)", disabled_count),
      proc { do_enable_all },
      _INTL("Enable all disabled mods (excludes integrated mods)."))
    
    options << ButtonOption.new(_INTL("Disable All ({1} enabled)", enabled_count),
      proc { do_disable_all },
      _INTL("Disable all enabled mods (excludes integrated mods)."))
    
    # Enabled mods section (only non-integrated)
    enabled_regular = regular_mods.select { |m| m[:enabled] }
    if enabled_regular.any?
      options << ModStatusHeaderOption.new("Enabled Mods", enabled_regular.count, :green)
      enabled_regular.each do |mod|
        options << ModEntryOption.new(mod)
      end
    end
    
    # Disabled mods section (only non-integrated)
    disabled_regular = regular_mods.select { |m| !m[:enabled] }
    if disabled_regular.any?
      options << ModStatusHeaderOption.new("Disabled Mods", disabled_regular.count, :red)
      disabled_regular.each do |mod|
        options << ModEntryOption.new(mod)
      end
    end
    
    # Integrated mods section
    if integrated_mods.any?
      options << ModStatusHeaderOption.new("Integrated Mods", integrated_mods.count, :blue)
      integrated_mods.each do |mod|
        options << ModEntryOption.new(mod)
      end
    end
    
    if mods.empty?
      options << ButtonOption.new(_INTL("No mods found"), proc {}, _INTL("No manageable mods found in Mods folder."))
    end
    
    # No Back button - let Confirm button work naturally from parent class
    options
  end
  
  def do_enable_all
    if pbConfirmMessage(_INTL("Enable all disabled mods?"))
      count = KIFRSettings::ModManager.enable_all
      pbMessage(_INTL("Enabled {1} mod(s).", count))
      show_restart_warning if count > 0
      refresh_list
    end
  end
  
  def do_disable_all
    if pbConfirmMessage(_INTL("Disable all enabled mods? This will not affect protected system files."))
      count = KIFRSettings::ModManager.disable_all
      pbMessage(_INTL("Disabled {1} mod(s).", count))
      show_restart_warning if count > 0
      refresh_list
    end
  end
  
  def refresh_list
    @PokemonOptions = build_options_list
    @sprites["option"].dispose if @sprites["option"]
    @sprites["option"] = initOptionsWindow
    @sprites["option"].index = 0
    
    # Re-apply color theme
    theme_index = ($PokemonSystem.kifr_color_theme rescue 0) || 0
    apply_kifr_color_theme(@sprites["option"], theme_index)
  end
  
  def show_restart_warning
    return if @restart_warning_shown
    pbMessage(_INTL("\\se[]Changes will take effect after restarting the game."))
    @restart_warning_shown = true
  end
  
  def pbUpdateOptions(optindex)
    option = @PokemonOptions[optindex]
    
    # Handle mod entry selection
    if option.is_a?(ModEntryOption)
      handle_mod_actions(option.mod_data)
    # Handle button callbacks
    elsif option.is_a?(ButtonOption) && option.respond_to?(:callback) && option.callback
      option.callback.call
    end
  end
  
  def pbOptions
    pbActivateWindow(@sprites, "option") {
      loop do
        Graphics.update
        Input.update
        pbUpdate
        
        # Handle back button (B/X)
        if Input.trigger?(Input::BACK)
          break
        end
        
        # Handle selection
        if Input.trigger?(Input::USE)
          # Check if Confirm button selected (index == options.length)
          break if isConfirmedOnKeyPress
          
          current = @sprites["option"].index
          if current >= 0 && current < @PokemonOptions.length
            pbUpdateOptions(current)
          end
        end
        
        # Update description
        current = @sprites["option"].index
        if current >= 0 && current < @PokemonOptions.length
          desc = @PokemonOptions[current].description rescue ""
          @sprites["textbox"].text = desc if @sprites["textbox"]
        elsif current == @PokemonOptions.length
          # Confirm button
          @sprites["textbox"].text = _INTL("Save changes and return.") if @sprites["textbox"]
        end
      end
    }
  end
  
  def handle_mod_actions(mod)
    commands = []
    descriptions = []
    
    # Different options for integrated vs regular mods
    if mod[:integrated]
      commands << _INTL("Delete File")
      descriptions << _INTL("Permanently delete this mod file (already integrated into KIFR).")
      commands << _INTL("View Info")
      descriptions << _INTL("View detailed information about this mod.")
      commands << _INTL("Cancel")
      descriptions << _INTL("Return without making changes.")
      
      choice = show_mod_commands(commands, descriptions, -1)
      
      case choice
      when 0  # Delete
        delete_mod_file(mod)
      when 1  # View Info
        show_mod_info(mod)
      end
    else
      if mod[:enabled]
        commands << _INTL("Disable Mod")
        descriptions << _INTL("Disable this mod. Changes take effect after restart.")
      else
        commands << _INTL("Enable Mod")
        descriptions << _INTL("Enable this mod. Changes take effect after restart.")
      end
      
      commands << _INTL("Delete File")
      descriptions << _INTL("Permanently delete this mod file. This cannot be undone!")
      commands << _INTL("View Info")
      descriptions << _INTL("View detailed information about this mod.")
      commands << _INTL("Cancel")
      descriptions << _INTL("Return without making changes.")
      
      choice = show_mod_commands(commands, descriptions, -1)
      
      case choice
      when 0  # Toggle
        toggle_mod(mod)
      when 1  # Delete
        delete_mod_file(mod)
      when 2  # View Info
        show_mod_info(mod)
      end
    end
  end
  
  def delete_mod_file(mod)
    # Warning message
    if mod[:integrated]
      msg = _INTL("Delete {1}?\n\nThis mod's functionality is already integrated into KIFR.\nThe file is no longer needed.", mod[:display_name])
    else
      msg = _INTL("Permanently delete {1}?\n\nThis cannot be undone!", mod[:display_name])
    end
    
    unless pbConfirmMessage(msg)
      return
    end
    
    begin
      if File.exist?(mod[:path])
        File.delete(mod[:path])
        pbMessage(_INTL("{1} has been deleted.", mod[:display_name]))
        refresh_list
      else
        pbMessage(_INTL("File not found: {1}", mod[:path]))
      end
    rescue => e
      pbMessage(_INTL("Failed to delete {1}: {2}", mod[:display_name], e.message))
      KIFRSettings.debug_log("Mod Manager: Failed to delete #{mod[:path]}: #{e.message}")
    end
  end
  
  def toggle_mod(mod)
    if mod[:enabled]
      # Check for dependents before disabling
      dependents = KIFRSettings::ModManager.find_dependents(mod[:display_name])
      
      if dependents.any?
        dep_list = dependents.join(", ")
        unless pbConfirmMessage(_INTL("Warning: The following mods may depend on this mod:\n{1}\n\nDisable anyway?", dep_list))
          return
        end
      end
      
      if KIFRSettings::ModManager.disable_mod(mod[:path])
        pbMessage(_INTL("{1} has been disabled.", mod[:display_name]))
        show_restart_warning
        refresh_list
      else
        pbMessage(_INTL("Failed to disable {1}.", mod[:display_name]))
      end
    else
      # Check if this is an integrated file
      result = KIFRSettings::ModManager.enable_mod(mod[:path])
      
      if result == :integrated
        pbMessage(_INTL("{1} is already integrated into KIFR and cannot be enabled.\n\nThe functionality of this mod is now built into KIF Redux.", mod[:display_name]))
      elsif result
        pbMessage(_INTL("{1} has been enabled.", mod[:display_name]))
        show_restart_warning
        refresh_list
      else
        pbMessage(_INTL("Failed to enable {1}.", mod[:display_name]))
      end
    end
  end
  
  def show_mod_info(mod)
    info_lines = []
    info_lines << _INTL("Name: {1}", mod[:display_name])
    
    # Status - show Integrated if applicable
    if mod[:integrated]
      info_lines << _INTL("Status: Integrated (built into KIFR)")
    else
      info_lines << _INTL("Status: {1}", mod[:enabled] ? "Enabled" : "Disabled")
    end
    
    info_lines << _INTL("Version: {1}", mod[:version] || "Unknown")
    info_lines << _INTL("Location: {1}", mod[:folder])
    info_lines << _INTL("Registered: {1}", mod[:registered] ? "Yes" : "No")
    
    if mod[:dependencies] && mod[:dependencies].any?
      deps = mod[:dependencies].map { |d| d.is_a?(Hash) ? d[:file] : d.to_s }.join(", ")
      info_lines << _INTL("Dependencies: {1}", deps)
    end
    
    # Check for mods that depend on this one
    dependents = KIFRSettings::ModManager.find_dependents(mod[:display_name])
    if dependents.any?
      info_lines << _INTL("Required by: {1}", dependents.join(", "))
    end
    
    pbMessage(info_lines.join("\n"))
  end
  
  def show_mod_commands(commands, descriptions, cmdIfCancel = 0, defaultIndex = 0)
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
    @sprites["textbox"].text = descriptions[cmdwindow.index] if descriptions[cmdwindow.index]
    
    command = 0
    loop do
      Graphics.update
      Input.update
      cmdwindow.update
      
      # Update description when selection changes
      if descriptions[cmdwindow.index]
        @sprites["textbox"].text = descriptions[cmdwindow.index]
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
    # Show final restart warning if changes were made
    if KIFRSettings::ModManager.changes_made? && !@restart_warning_shown
      pbMessage(_INTL("\\se[]Remember to restart the game for changes to take effect."))
    end
    super
  end
end

#===============================================================================
# AUTO-UPDATE CHECK SYSTEM
#===============================================================================
# Performs automatic update check when game starts (if enabled)
#===============================================================================
module KIFRSettings
  # Perform auto-update check if enabled
  # Called from PokemonLoadScreen hook on game start
  def self.perform_auto_update_check
    begin
      debug_log("KIFR Update System: Auto-update check starting...")
      
      # Check if auto-update is enabled
      setting = get(:mod_auto_update)
      debug_log("KIFR Update System: Auto-update setting value: #{setting.inspect}")
      
      unless setting == 1 || setting == true
        debug_log("KIFR Update System: Auto-update disabled, skipping")
        return
      end
      
      debug_log("KIFR Update System: Auto-update enabled, checking for updates...")
      
      # Perform update check
      results = UpdateCheck.check_updates
      
      if results[:error]
        debug_log("KIFR Update System: ERROR: Auto-update check failed: #{results[:error]}")
        return
      end
      
      # Collect all mods with updates available
      updates_available = results[:major_updates] + results[:minor_updates] + results[:hotfixes]
      
      if updates_available.any?
        count = updates_available.length
        debug_log("KIFR Update System: Auto-update found #{count} updates available")
        
        # Filter to only mods with download URLs
        updatable = updates_available.select { |mod| mod[:download_url] && !mod[:download_url].empty? }
        
        if updatable.empty?
          debug_log("KIFR Update System: No mods support auto-update yet")
          pbMessage(_INTL("{1} mod update(s) available, but auto-update not supported yet.\n\nCheck 'Mod Manager' in KIFR Settings.", count)) if defined?(pbMessage)
          return
        end
        
        # Check if confirmation is required
        confirm_setting = get(:mod_auto_update_confirm)
        skip_confirm = (confirm_setting == 0 || confirm_setting == false)
        
        # Show notification scene and get confirmation
        if defined?(AutoUpdateNotificationScene)
          confirmed = AutoUpdateNotificationScene.show_and_confirm(updatable, skip_confirm)
          
          if confirmed
            debug_log("KIFR Update System: User confirmed, updating #{updatable.length} mods")
            
            # Perform updates
            success_count = 0
            failure_count = 0
            skipped_special = []
            
            pbFadeOutIn {
              updatable.each do |mod|
                # Skip Multiplayer and KIF Redux - they need special handling
                is_multiplayer = mod[:is_multiplayer] || mod[:download_url] == "autoupdate_multiplayer.bat"
                is_kifr = mod[:is_kifr] || mod[:name] == "KIF Redux"
                
                if is_multiplayer || is_kifr
                  skipped_special << mod[:name]
                  debug_log("KIFR Update System: Auto-update skipped #{mod[:name]} (requires special handling)")
                  next
                end
                
                success = ModUpdater.install_mod(
                  mod[:path],
                  mod[:download_url],
                  mod[:local]
                )
                
                if success
                  success_count += 1
                  debug_log("KIFR Update System: Auto-update updated #{mod[:name]}")
                else
                  failure_count += 1
                  debug_log("KIFR Update System: ERROR: Auto-update failed to update #{mod[:name]}")
                end
              end
            }
            
            # Show results
            if success_count > 0
              if failure_count > 0
                pbMessage(_INTL("Updated {1} mod(s). {2} failed.\n\nRestart required for changes to take effect.", success_count, failure_count))
              else
                pbMessage(_INTL("Successfully updated {1} mod(s)!\n\nRestart required for changes to take effect.", success_count))
              end
            elsif failure_count > 0
              pbMessage(_INTL("Failed to update {1} mod(s).", failure_count))
            end
            
            # Notify about skipped special mods
            if skipped_special.any?
              pbMessage(_INTL("KIF Redux and Multiplayer must be updated in the Mod Manager."))
            end
          else
            debug_log("KIFR Update System: Auto-update cancelled by user")
          end
        end
      else
        debug_log("KIFR Update System: Auto-update check complete - all mods up to date")
      end
    rescue => e
      debug_log("KIFR Update System: ERROR: Auto-update check error: #{e.class} - #{e.message}")
      debug_log("KIFR Update System: Backtrace: #{e.backtrace.first(3).join('\n')}")
    end
  end
end

#===============================================================================
# Initialize Auto-Update Settings with Defaults
#===============================================================================
begin
  if defined?(KIFRSettings)
    # Check for migration flag - if users have old defaults, offer to enable auto-update
    if KIFRSettings.get(:mod_auto_update).nil?
      # New user - default to On
      KIFRSettings.set(:mod_auto_update, 1)
      KIFRSettings.debug_log("KIFR Update System: Initialized mod_auto_update setting to 1 (On)")
    elsif KIFRSettings.get(:mod_auto_update_v2_migrated).nil?
      # Existing user who hasn't been asked yet - mark as migrated
      # Don't change their setting, but mark that we've upgraded
      KIFRSettings.set(:mod_auto_update_v2_migrated, 1)
      KIFRSettings.debug_log("KIFR Update System: Marked auto-update settings as migrated")
    end
    
    if KIFRSettings.get(:mod_auto_update_confirm).nil?
      KIFRSettings.set(:mod_auto_update_confirm, 1)  # Default: On (ask for confirmation)
      KIFRSettings.debug_log("KIFR Update System: Initialized mod_auto_update_confirm setting to 1 (On)")
    end
  end
rescue
  # Silently fail during initialization
end

# Register KIFR now that ModRegistry is loaded
KIFRSettings.register_kifr

# Log startup summary with mod counts
KIFRSettings.log_startup_summary

KIFRSettings.debug_log("KIFR Update System: Loaded successfully")
