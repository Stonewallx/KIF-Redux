#===============================================================================
# KIF Redux Compatibility - ModSettingsMenu Alias Layer
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file creates the ModSettingsMenu module for external mods to register
# their settings. Options registered here appear in the "Mod Settings" menu.
#
# ModSettingsMenu uses KIFRSettings for STORAGE (get/set values) but has its
# own REGISTRY for options. This keeps external mod registrations separate
# from KIFR's internal settings.
#===============================================================================

# Only create compatibility layer if KIFRSettings exists
if defined?(KIFRSettings)
  
  #=============================================================================
  # ModSettingsSpacing - LEGACY MODULE (no longer needed with cycling arrows)
  # Kept for backward compatibility with mods that include it
  #=============================================================================
  module ModSettingsSpacing
    # LEGACY: Was for inserting spacers after multi-row dropdowns
    # With cycling arrow display, multi-row layouts no longer exist
    # Simply returns options unchanged for backward compatibility
    def auto_insert_spacers(options)
      options
    end
  end
  
  #=============================================================================
  # ModSettingsMenu - Public API for external mods
  # Mods register their options here to appear in "Mod Settings" menu
  #=============================================================================
  module ModSettingsMenu
    # Special category constant
    NOCATEGORY = "__nocategory__"
    
    # Own registry for mod options (separate from KIFRSettings)
    @option_registry = []
    @on_change_registry = {}
    
    class << self
      #=========================================================================
      # Storage Methods (forwarded to KIFRSettings - shared storage)
      #=========================================================================
      
      def storage
        KIFRSettings.storage
      end
      
      def set_storage(hash)
        KIFRSettings.set_storage(hash)
      end
      
      def get(key, default = nil)
        KIFRSettings.get(key, default)
      end
      
      def set(key, value)
        KIFRSettings.set(key, value)
      end
      
      def has_key?(key)
        KIFRSettings.has_key?(key)
      end
      
      # Set a default value for a key ONLY if the key doesn't already exist
      # This is the recommended way for mods to initialize defaults
      # @param key [Symbol, String] The setting key
      # @param default [Object] Default value to set if key doesn't exist
      # @return [Boolean] True if default was set, false if key already existed
      def set_default(key, default)
        key = key.to_sym if key.is_a?(String)
        if KIFRSettings.has_key?(key)
          return false
        else
          KIFRSettings.set(key, default)
          return true
        end
      end
      
      # Support both signatures:
      # ensure_storage() - initialize storage system (old API)
      # ensure_storage(key, default) - ensure key has default value (new API)
      def ensure_storage(key = nil, default = nil)
        if key.nil?
          KIFRSettings.storage
          return
        end
        KIFRSettings.ensure_storage(key, default)
      end
      
      #=========================================================================
      # Category Methods (forwarded to KIFRSettings)
      #=========================================================================
      
      def categories
        KIFRSettings.categories
      end
      
      def valid_category?(name)
        KIFRSettings.valid_category?(name)
      end
      
      def category_collapsed?(name)
        KIFRSettings.category_collapsed?(name)
      end
      
      def toggle_category(name)
        KIFRSettings.toggle_category(name)
      end
      
      def initialize_category(name, collapsed = true)
        KIFRSettings.initialize_category(name, collapsed)
      end
      
      def save_category_states
        KIFRSettings.save_category_states
      end
      
      def restore_category_states
        KIFRSettings.restore_category_states
      end
      
      def reset_all_categories
        KIFRSettings.reset_all_categories
      end
      
      #=========================================================================
      # Text Utilities (forwarded to KIFRSettings)
      #=========================================================================
      
      def sanitize_text(text)
        KIFRSettings.sanitize_text(text)
      end
      
      #=========================================================================
      # Debug & Persistence (forwarded to KIFRSettings)
      #=========================================================================
      
      def debug_log(message)
        KIFRSettings.debug_log("[ModSettingsMenu] #{message}")
      end
      
      def version
        KIFRSettings.version
      end
      
      def save_to_file
        KIFRSettings.save_to_file
      end
      
      def load_from_file
        KIFRSettings.load_from_file
      end
      
      #=========================================================================
      # Option Registration (OWN registry - NOT forwarded to KIFRSettings)
      # These options appear in the "Mod Settings" menu
      #=========================================================================
      
      # Get all registered mod options
      def registry
        @option_registry ||= []
      end
      
      # Register an option to appear in Mod Settings menu
      # @param key [Symbol] Unique key for the option
      # @param options [Hash] Option configuration
      def register(key, options = {})
        key = key.to_sym if key.is_a?(String)
        
        # Remove existing registration if present
        @option_registry ||= []
        @option_registry.reject! { |r| r[:key] == key }
        
        # Add new registration
        registration = options.merge(key: key)
        registration[:category] ||= "Uncategorized"
        registration[:type] ||= :button
        
        # Set default value in storage if provided
        if options.key?(:default) && !KIFRSettings.has_key?(key)
          KIFRSettings.set(key, options[:default])
        end
        
        @option_registry << registration
        debug_log("Registered option: #{key} (#{options[:name] || key})")
      end
      
      # Convenience method to register a toggle option
      def register_toggle(key, name, description = "", default = 0, category = "Uncategorized")
        register(key, {
          name: name,
          type: :toggle,
          description: description,
          default: default,
          category: category,
          values: [_INTL("Off"), _INTL("On")]
        })
      end
      
      # Convenience method to register an enum option
      def register_enum(key, name, values, default = 0, description = "", category = "Uncategorized")
        register(key, {
          name: name,
          type: :enum,
          values: values,
          default: default,
          description: description,
          category: category
        })
      end
      
      # Convenience method to register a number option
      def register_number(key, name, min, max, default = nil, description = "", category = "Uncategorized")
        register(key, {
          name: name,
          type: :number,
          min: min,
          max: max,
          default: default || min,
          description: description,
          category: category
        })
      end
      
      # Convenience method to register a slider option
      def register_slider(key, name, min, max, interval = 1, default = nil, description = "", category = "Uncategorized")
        register(key, {
          name: name,
          type: :slider,
          min: min,
          max: max,
          interval: interval,
          default: default || min,
          description: description,
          category: category
        })
      end
      
      # Register a custom option object
      def register_option(option, key, category = "Uncategorized", searchable_items = [])
        register(key, {
          name: option.respond_to?(:name) ? option.name : key.to_s,
          type: :custom,
          option_object: option,
          category: category,
          searchable: searchable_items
        })
      end
      
      # Check if an option is registered
      def registered?(key)
        key = key.to_sym if key.is_a?(String)
        registry.any? { |r| r[:key] == key }
      end
      
      # Get registrations grouped by category
      def registry_by_category
        result = {}
        registry.each do |reg|
          cat = reg[:category] || "Uncategorized"
          result[cat] ||= []
          result[cat] << reg
        end
        result
      end
      
      #=========================================================================
      # On-Change Callbacks (OWN registry)
      #=========================================================================
      
      def on_change_registry
        @on_change_registry ||= {}
      end
      
      def register_on_change(key, &block)
        key = key.to_sym if key.is_a?(String)
        @on_change_registry ||= {}
        @on_change_registry[key] ||= []
        @on_change_registry[key] << block
      end
      
      def invoke_on_change(key, new_value, old_value)
        key = key.to_sym if key.is_a?(String)
        return unless @on_change_registry && @on_change_registry[key]
        @on_change_registry[key].each { |cb| cb.call(new_value, old_value) rescue nil }
      end
      
      #=========================================================================
      # Preset Management (forwarded to KIFRSettings)
      #=========================================================================
      
      def list_presets
        KIFRSettings.list_presets
      end
      
      def save_preset(name)
        KIFRSettings.save_preset(name)
      end
      
      def load_preset(name)
        KIFRSettings.load_preset(name)
      end
      
      def delete_preset(name)
        KIFRSettings.delete_preset(name)
      end
      
      def export_to_file(name)
        KIFRSettings.export_to_file(name)
      end
      
      def import_from_file(name)
        KIFRSettings.import_from_file(name)
      end
      
      def list_exports
        KIFRSettings.list_exports
      end
      
      def delete_export(name)
        KIFRSettings.delete_export(name)
      end
    end
    
    #===========================================================================
    # Sub-Module Aliases (ModRegistry for update system)
    #===========================================================================
    
    # ModRegistry alias - for mod update tracking
    module ModRegistry
      class << self
        def all
          KIFRSettings::ModRegistry.all
        end
        
        def external_mods
          KIFRSettings::ModRegistry.external_mods
        end
        
        def register(info)
          KIFRSettings::ModRegistry.register(info)
        end
        
        def get(filename)
          KIFRSettings::ModRegistry.get(filename)
        end
        
        def registered?(filename)
          KIFRSettings::ModRegistry.registered?(filename)
        end
        
        def clear
          KIFRSettings::ModRegistry.clear
        end
      end
    end
  end
  
  #=============================================================================
  # ModManager alias (for backward compatibility)
  #=============================================================================
  module ModManager
    class << self
      def method_missing(method, *args, &block)
        if KIFRSettings::ModManager.respond_to?(method)
          KIFRSettings::ModManager.send(method, *args, &block)
        else
          super
        end
      end
      
      def respond_to_missing?(method, include_private = false)
        KIFRSettings::ModManager.respond_to?(method) || super
      end
    end
  end
  
  KIFRSettings.debug_log("KIFR Compatibility layer loaded - ModSettingsMenu ready for external mods")
end
