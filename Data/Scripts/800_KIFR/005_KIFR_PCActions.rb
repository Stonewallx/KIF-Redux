#===============================================================================
# KIF Redux PC Actions - PC Mod Actions Menu System
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file contains:
# - PCModActions registry module
# - PC menu integration hooks
#===============================================================================

#===============================================================================
# PC MOD ACTIONS - REGISTRY MODULE
#===============================================================================
# Mods can register custom actions for the PC Pokemon menu
# (alongside Move, Summary, etc.)
#===============================================================================

module KIFRSettings
  module PCModActions
    @handlers = []
    
    class << self
      def handlers
        @handlers ||= []
      end
      
      # Simplified registration with hash parameters
      # @param options [Hash] Configuration
      #   :name [String, Proc] Display name (can be dynamic)
      #   :on_select [Proc] Action when selected (receives pokemon, selected, heldpoke, scene)
      #   :condition [Proc] Condition check (receives pokemon, selected, heldpoke) - return true to show
      #   :supports_batch [Boolean] Whether action can be applied to multiple Pokemon (default: true)
      def register(options = {})
        handler = {
          name: options[:name] || "Unnamed Action",
          effect: options[:on_select] || options[:effect],
          condition: options[:condition],
          supports_batch: options.key?(:supports_batch) ? options[:supports_batch] : true
        }
        handlers << handler unless handlers.include?(handler)
      end
      
      # Traditional registration
      def register_handler(handler)
        handler[:supports_batch] = true unless handler.key?(:supports_batch)
        handlers << handler unless handlers.include?(handler)
      end
      
      def clear
        @handlers = []
      end
      
      def has_actions?
        handlers.any?
      end
      
      def has_batch_actions?
        handlers.any? { |h| h[:supports_batch] }
      end
      
      # Get available actions for a Pokemon
      def get_available_actions(pokemon, selected, heldpoke)
        available = []
        
        handlers.each do |handler|
          if handler[:condition]
            begin
              next unless handler[:condition].call(pokemon, selected, heldpoke)
            rescue
              next
            end
          end
          available << handler
        end
        
        available
      end
      
      # Get name for a handler (handles both String and Proc)
      def get_handler_name(handler, pokemon = nil)
        name = handler[:name]
        
        if name.is_a?(Proc)
          begin
            return name.call(pokemon)
          rescue
            return "Action"
          end
        end
        
        name.to_s
      end
      
      # Execute a handler's effect
      def execute_handler(handler, pokemon, selected, heldpoke, scene)
        return false unless handler[:effect]
        
        begin
          handler[:effect].call(pokemon, selected, heldpoke, scene)
          return true
        rescue => e
          KIFRSettings.debug_log("PCModActions error: #{e.message}")
          return false
        end
      end
    end
  end
end

#===============================================================================
# PC MENU INTEGRATION
#===============================================================================
# This hooks into the PC Storage scene to add "Mod Actions" option
# Note: The actual hook depends on the game's PC implementation
#===============================================================================

# Placeholder for PC menu hook - game-specific implementation needed
# The hook should:
# 1. Add "Mod Actions" to the Pokemon context menu
# 2. When selected, show available actions from PCModActions.handlers
# 3. Execute the selected action

# Example registration for other mods:
#
# KIFRSettings::PCModActions.register(
#   name: "Change Ability",
#   on_select: proc { |pokemon, selected, heldpoke, scene|
#     # Show ability selection menu
#     # Change pokemon's ability
#   },
#   condition: proc { |pokemon, selected, heldpoke|
#     # Only show if Pokemon has multiple possible abilities
#     pokemon.numAbilities > 1
#   },
#   supports_batch: false  # Can't batch-change abilities
# )
#
# KIFRSettings::PCModActions.register(
#   name: proc { |pokemon| "Heal #{pokemon.name}" },  # Dynamic name
#   on_select: proc { |pokemon, selected, heldpoke, scene|
#     pokemon.heal
#     scene.pbDisplay(_INTL("{1} was healed!", pokemon.name))
#   },
#   condition: proc { |pokemon, selected, heldpoke|
#     pokemon.hp < pokemon.totalhp || pokemon.status != :NONE
#   },
#   supports_batch: true  # Can heal multiple Pokemon at once
# )

KIFRSettings.debug_log("KIFR PC Actions loaded") if defined?(KIFRSettings)
