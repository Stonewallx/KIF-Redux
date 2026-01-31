#===============================================================================
# KIF Redux Battle Menu - Battle Command Menu System
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file contains:
# - BattleCommandMenu registry module
# - BattleCommandMenuPatch (prepend to PokeBattle_Scene)
# - Battle menu toggle setting
#===============================================================================

#===============================================================================
# BATTLE COMMAND MENU - REGISTRY MODULE
#===============================================================================
# Mods can register commands to appear in the battle menu (R button / AUX2)
#===============================================================================

module BattleCommandMenu
  @registry = []
  
  class << self
    def registry
      @registry ||= []
    end
    
    # Simplified registration with hash parameters
    # @param options [Hash] Configuration
    #   :name [String] Display name
    #   :on_press [Proc] Action when selected (receives battle, idxBattler, scene)
    #   :description [String] Help text
    #   :condition [Proc] Condition check (receives battle, idxBattler) - return true to show
    #   :priority [Integer] Sort order (lower = first, default 100)
    def register(options = {})
      registry << {
        name: options[:name] || "Unnamed Command",
        proc: options[:on_press] || options[:proc],
        description: options[:description] || "",
        condition: options[:condition],
        priority: options[:priority] || 100
      }
    end
    
    # Traditional registration
    def register_command(name, proc, description = "", condition = nil, priority = 100)
      registry << {
        name: name,
        proc: proc,
        description: description,
        condition: condition,
        priority: priority
      }
    end
    
    # Get available commands for current battle state
    def get_available_commands(battle, idxBattler)
      available = []
      
      registry.each do |cmd|
        if cmd[:condition]
          begin
            next unless cmd[:condition].call(battle, idxBattler)
          rescue
            next
          end
        end
        available << cmd
      end
      
      available.sort_by { |cmd| cmd[:priority] || 100 }
    end
    
    def clear_registry
      @registry = []
    end
  end
end

#===============================================================================
# BATTLE COMMAND MENU - UI PATCH
#===============================================================================
# Patches PokeBattle_Scene to intercept AUX2 (R button) during battle
#===============================================================================

module BattleCommandMenuPatch
  # Override the battle command menu to add AUX2 handling
  def pbCommandMenuEx(idxBattler, texts, mode = 0)
    # Check if battle menu is enabled
    enabled = false
    begin
      if defined?(KIFRSettings)
        setting = KIFRSettings.get(:battle_command_menu)
        enabled = (setting == 1 || setting == true)
      end
    rescue
      enabled = false
    end
    
    # If disabled, use original behavior
    return super unless enabled
    
    # Show command window
    pbShowWindow(PokeBattle_Scene::COMMAND_BOX)
    cw = @sprites["commandWindow"]
    cw.setTexts(texts)
    cw.setIndexAndMode(@lastCmd[idxBattler], mode)
    pbSelectBattler(idxBattler)
    ret = -1
    
    loop do
      oldIndex = cw.index
      pbUpdate(cw)
      
      # Directional input
      if Input.trigger?(Input::LEFT)
        cw.index -= 1 if (cw.index & 1) == 1
      elsif Input.trigger?(Input::RIGHT)
        cw.index += 1 if (cw.index & 1) == 0
      elsif Input.trigger?(Input::UP)
        cw.index -= 2 if (cw.index & 2) == 2
      elsif Input.trigger?(Input::DOWN)
        cw.index += 2 if (cw.index & 2) == 0
      end
      pbPlayCursorSE if cw.index != oldIndex
      
      # AUX2 (R button) - Open battle command menu
      if Input.trigger?(Input::AUX2)
        pbPlayDecisionSE
        begin
          menu_result = pbOpenBattleCommandMenu(idxBattler)
          if menu_result == :quick_throw_used
            ret = -100
            break
          end
          next
        rescue => e
          pbPrintException(e) if $DEBUG
          next
        end
      end
      
      # Confirm
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = cw.index
        @lastCmd[idxBattler] = ret
        break
      # Cancel (if allowed)
      elsif Input.trigger?(Input::BACK) && mode == 1
        pbPlayCancelSE
        break
      # Debug
      elsif Input.trigger?(Input::F9) && $DEBUG
        pbPlayDecisionSE
        ret = -2
        break
      end
    end
    
    ret
  end
  
  # Open the battle command menu
  def pbOpenBattleCommandMenu(idxBattler)
    available_commands = BattleCommandMenu.get_available_commands(@battle, idxBattler)
    
    if available_commands.empty?
      pbDisplay(_INTL("No battle commands available."))
      return false
    end
    
    command_names = available_commands.map { |cmd| cmd[:name] }
    command_names << _INTL("Cancel")
    
    choice = pbShowCommands_BattleMenu(_INTL("Battle Commands"), command_names, -1)
    
    return false if choice < 0 || choice >= available_commands.length
    
    begin
      selected = available_commands[choice]
      result = selected[:proc].call(@battle, idxBattler, self)
      return result if result == :quick_throw_used
      return true
    rescue => e
      pbPrintException(e) if $DEBUG
      return false
    end
  end
  
  # Helper: Show command menu
  def pbShowCommands_BattleMenu(message, commands, default = 0)
    msgwindow = pbDisplayMessage_BattleMenu(message, false)
    choice = msgwindow ? pbShowMessageChoices_BattleMenu(msgwindow, commands, default) : -1
    pbDisposeMessageWindow_BattleMenu(msgwindow) if msgwindow
    choice
  end
  
  def pbShowMessageChoices_BattleMenu(msgwindow, commands, default = 0)
    cmdwindow = Window_CommandPokemon.new(commands)
    cmdwindow.z = 99999
    cmdwindow.index = default if default >= 0 && default < commands.length
    cmdwindow.visible = true
    cmdwindow.x = Graphics.width - cmdwindow.width
    cmdwindow.y = Graphics.height - cmdwindow.height - (msgwindow ? msgwindow.height : 0)
    
    ret = -1
    loop do
      Graphics.update
      Input.update
      cmdwindow.update
      msgwindow.update if msgwindow
      
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = cmdwindow.index
        break
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        ret = -1
        break
      end
    end
    
    cmdwindow.dispose
    ret
  end
  
  def pbDisplayMessage_BattleMenu(message, waitForInput = true)
    msgwindow = pbDisplayMessageWindow_BattleMenu(message)
    if waitForInput
      pbWaitMessage_BattleMenu
      pbDisposeMessageWindow_BattleMenu(msgwindow)
      return nil
    end
    msgwindow
  end
  
  def pbDisplayMessageWindow_BattleMenu(message)
    if @sprites && @sprites["messageWindow"]
      @sprites["messageWindow"].text = message
      @sprites["messageWindow"].visible = true
      return @sprites["messageWindow"]
    end
    
    msgwindow = Window_AdvancedTextPokemon.newWithSize("", 0, Graphics.height - 96, Graphics.width, 96)
    msgwindow.z = 99999
    msgwindow.text = message
    msgwindow.visible = true
    msgwindow
  end
  
  def pbDisposeMessageWindow_BattleMenu(msgwindow)
    return unless msgwindow
    return if @sprites && @sprites["messageWindow"] == msgwindow
    msgwindow.dispose
  end
  
  def pbWaitMessage_BattleMenu
    loop do
      Graphics.update
      Input.update
      break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
    end
  end
end

#===============================================================================
# APPLY PATCH
#===============================================================================
if defined?(PokeBattle_Scene)
  class PokeBattle_Scene
    prepend BattleCommandMenuPatch
  end
end

#===============================================================================
# REGISTER BATTLE MENU TOGGLE SETTING
#===============================================================================
if defined?(KIFRSettings)
  KIFRSettings.register(:battle_command_menu, {
    name: _INTL("Battle Menu"),
    type: :toggle,
    description: _INTL("Press AUX2 (R) during battle to open a command menu"),
    default: 0,
    category: "Battle Mechanics"
  })
  
  KIFRSettings.register(:overworld_menu, {
    name: _INTL("Overworld Menu"),
    type: :toggle,
    description: _INTL("Press ACTION in the overworld to open the quick menu"),
    default: 1,
    category: "Interface"
  })
end

KIFRSettings.debug_log("KIFR Battle Menu loaded") if defined?(KIFRSettings)
