#===============================================================================
# KIF Redux Developer Tools - Milestones Manager
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# In-game tool for managing milestone rewards.
# Access via Debug & Developer > KIFR Dev Tools > Milestones
#===============================================================================

class KIFRDEV_Milestones < PokemonOption_Scene
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
    
    options << ClickOnlyButtonOption.new(
      _INTL("Reset Milestones"),
      proc { reset_milestones },
      _INTL("Reset all claimed milestones so they can be claimed again")
    )
    
    return options
  end
  
  def reset_milestones
    if pbConfirmMessage(_INTL("Reset all Milestones?"))
      $game_system.claimed_rewards = []
      Kernel.pbMessage(_INTL("All milestones have been reset."))
    end
  end
  
  def pbStartScene(inloadscreen = false)
    super(inloadscreen)
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Milestones"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["title"].setSkin(PokemonOption_Scene.get_kifr_windowskin)
    @sprites["title"].baseColor = PokemonOption_Scene.OPTIONS_TEXT_BASE
    @sprites["title"].shadowColor = PokemonOption_Scene.OPTIONS_TEXT_SHADOW
  end
end

KIFRDEV.debug_log("Milestones Manager module loaded") if defined?(KIFRDEV)