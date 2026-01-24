#===============================================================================
# KIF Redux Version
# This file defines the KIFR version and handles self-registration
# Edit the VERSION constant here to update the displayed version
#===============================================================================

module KIFRSettings
  VERSION = "1.0.0"
  
  # Version components for comparison
  def self.version_parts
    VERSION.split('.').map(&:to_i)
  end
  
  # Compare version with another version string
  # Returns -1 if older, 0 if same, 1 if newer
  def self.compare_version(other_version)
    other_parts = other_version.split('.').map(&:to_i)
    version_parts <=> other_parts
  end
end

#===============================================================================
# KIFR Self-Registration (deferred until ModRegistry is loaded)
#===============================================================================
# This will be called after 003_KIFR_UpdateSystem.rb loads ModRegistry
module KIFRSettings
  def self.register_kifr
    return unless defined?(KIFRSettings::ModRegistry)
    
    KIFRSettings::ModRegistry.register({
      name: "KIF Redux",
      file: "000_KIFR_Version.rb",
      version: KIFRSettings::VERSION,
      download_url: nil,
      version_check_url: "https://raw.githubusercontent.com/Stonewallx/KIF-Redux/refs/heads/main/Data/Scripts/800_KIFR/000_KIFR_Version.rb",
      changelog_url: nil
    })
  end
end
