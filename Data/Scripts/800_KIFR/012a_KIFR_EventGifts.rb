#===============================================================================
# KIF Redux Event Gifts - Scheduled Gift Definitions
# Script Version: 1.0.0
# Author: Stonewall
#===============================================================================
# This file contains all scheduled event gifts that are automatically
# delivered to players based on date and conditions.
#
# HOW TO ADD A GIFT:
# 1. Add a new entry to SCHEDULED_GIFTS hash below
# 2. Each gift needs a unique ID (snake_case recommended)
# 3. Set the date range and rewards
# 4. Optionally add conditions (badges, playtime, flags)
#
# The system automatically checks and delivers gifts on map change.
# Players receive each gift only once per save file.
#===============================================================================

module Gifts
  module Events
    # ==========================================================================
    # SCHEDULED GIFTS - Add your event gifts here!
    # ==========================================================================
    # Format:
    #   unique_id: {
    #     name: "Display Name",        # Shown in red in Gift Inbox
    #     source: "Event",             # Gift type (Event, Holiday, Promo, etc.)
    #     start_date: "MM-DD-YY",      # When gift becomes available
    #     end_date: "MM-DD-YY",        # When gift expires (nil = never expires)
    #     rewards: {                   # What the player receives
    #       items: [[:ITEM, qty], ...],  # Item rewards
    #       pokemon: [{ species: :SPECIES, level: X, shiny: bool }],
    #       eggs: [{ species: :SPECIES }],
    #       money: amount,             # Cash reward
    #       coins: amount              # Game Corner coins
    #     },
    #     conditions: {                # Optional requirements (all optional)
    #       min_badges: 0,             # Minimum badges required
    #       min_playtime: 0,           # Minimum hours played
    #       flag: nil                  # Game switch number that must be ON
    #     }
    #   }
    # ==========================================================================
    
    SCHEDULED_GIFTS = {
      #-------------------------------------------------------------------------
      # EXAMPLE GIFTS (Uncomment to use)
      #-------------------------------------------------------------------------
      
      # Holiday Gift - Available Dec 25 through Jan 1
      # holiday_2026: {
      #   name: "Holiday Gift 2026",
      #   source: "Holiday",
      #   start_date: "12-25-26",
      #   end_date: "01-01-27",
      #   rewards: {
      #     items: [[:RARECANDY, 5], [:MASTERBALL, 1]],
      #     money: 10000
      #   }
      # },
      
      # Launch Day Gift - Never expires
      # launch_day: {
      #   name: "Launch Day Celebration",
      #   source: "Event",
      #   start_date: "01-26-26",
      #   end_date: nil,
      #   rewards: {
      #     items: [[:RARECANDY, 10]]
      #   }
      # },
      
      # Conditional Gift - Requires 4 badges
      # midgame_bonus: {
      #   name: "Trainer Appreciation",
      #   source: "Promo",
      #   start_date: "02-01-26",
      #   end_date: "02-28-26",
      #   rewards: {
      #     items: [[:EXPSHARE, 1]]
      #   },
      #   conditions: {
      #     min_badges: 4
      #   }
      # },
      
      #-------------------------------------------------------------------------
      # YOUR GIFTS BELOW - Add new gifts here!
      #-------------------------------------------------------------------------
    }
    # Don't freeze - we need to be able to add gifts at runtime from the creator
    # SCHEDULED_GIFTS.freeze
  end
end