#===============================================================================
# KIF Redux Developer Tools - Core Module
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This folder (801_KIFRDEV) contains developer and server-side tools:
#
# FEATURES:
# - Gift Creator - Create scheduled event gifts in-game
# - Pokemon File Editor - Create custom Pokemon for gifts/events (Coming Soon)
# - Item Bundle Editor - Create item bundles for distribution (Coming Soon)
# - Event Gift Manager - Manage event-based gifts (Coming Soon)
#
# FILES:
# - 000_KIFRDEV_Core.rb - Core utilities and Dev Tools menu
# - 001_KIFRDEV_GiftCreator.rb - In-game gift creation tool
# - 002_KIFRDEV_Milestones.rb - Milestone management tools
#
# NOTE: These tools are for development use only. They should not
# be distributed to regular players in production builds.
#===============================================================================

module KIFRDEV
  VERSION = "1.0.0"
  NAME = "KIFR Dev Tools"
  
  def self.debug_log(message)
    if defined?(KIFRSettings) && KIFRSettings.respond_to?(:debug_log)
      KIFRSettings.debug_log("KIFRDEV: #{message}")
    end
  end
  
  # Dev tools are always enabled (internal use only)
  def self.enabled?
    true
  end
end

module KIFRDEV
  # Define options to be included in KIFR Settings
  # Called by pbGetOptions in 002_KIFR_Options.rb
  def self.settings_options
    {
      "Debug & Developer" => [
        ButtonOption.new(
          _INTL("KIFR Dev Tools"),
          proc {
            if KIFRDEV.enabled?
              pbFadeOutIn {
                scene = KIFR_DevToolsScene.new
                screen = PokemonOptionScreen.new(scene)
                screen.pbStartScreen
              }
            else
              Kernel.pbMessage(_INTL("Developer tools are disabled. Enable Debug Mode or run with $DEBUG."))
            end
          },
          _INTL("Developer tools for KIF Redux."))
      ]
    }
  end
end

#===============================================================================
# DEV TOOLS SCENE - Uses PokemonOption_Scene pattern
#===============================================================================
class KIFR_DevToolsScene < PokemonOption_Scene
  # Skip fade-in (outer pbFadeOutIn handles transition)
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
    # GIFT TOOLS
    #---------------------------------------------------------------------------
    options << ButtonOption.new(
      _INTL("Gift Creator"),
      proc { 
        if defined?(KIFRDEV_GiftCreator)
          pbFadeOutIn { KIFRDEV_GiftCreator.show }
        else
          Kernel.pbMessage(_INTL("Gift Creator not loaded!"))
        end
      },
      _INTL("Create new scheduled event gifts")
    )
    
    options << ButtonOption.new(
      _INTL("Gift List"),
      proc { 
        if defined?(KIFRDEV_GiftList)
          pbFadeOutIn { KIFRDEV_GiftList.show }
        else
          Kernel.pbMessage(_INTL("Gift List not loaded!"))
        end
      },
      _INTL("View and manage existing scheduled gifts")
    )
    
    #---------------------------------------------------------------------------
    # MILESTONE TOOLS
    #---------------------------------------------------------------------------
    options << ButtonOption.new(
      _INTL("Milestones"),
      proc { 
        if defined?(KIFRDEV_Milestones)
          pbFadeOutIn {
            scene = KIFRDEV_Milestones.new
            screen = PokemonOptionScreen.new(scene)
            screen.pbStartScreen
          }
        else
          Kernel.pbMessage(_INTL("Milestones not loaded!"))
        end
      },
      _INTL("Milestone management tools")
    )
    
    #---------------------------------------------------------------------------
    # COMING SOON
    #---------------------------------------------------------------------------
    options << ButtonOption.new(
      _INTL("Pokemon File Editor"),
      proc { Kernel.pbMessage(_INTL("Pokemon File Editor coming in a future update!")) },
      _INTL("Create custom Pokemon for gifts/events (Coming Soon)")
    )
    
    options << ButtonOption.new(
      _INTL("Item Bundle Editor"),
      proc { Kernel.pbMessage(_INTL("Item Bundle Editor coming in a future update!")) },
      _INTL("Create item bundles for distribution (Coming Soon)")
    )
    
    return options
  end
  
  def pbStartScene(inloadscreen = false)
    super(inloadscreen)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("KIFR Developer Tools"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
  end
end

KIFRDEV.debug_log("Developer tools module loaded") if defined?(KIFRDEV)
