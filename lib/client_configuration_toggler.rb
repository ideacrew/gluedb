# frozen_string_literal: true

# This class is used to swap the application wide configuration between different clients (I.E. DC to Maine)
class ClientConfigurationToggler < MongoidMigrationTask
  def target_config_folder
    "#{Rails.root}/config/client_config/#{@target_client_state_abbreviation}"
  end

  def old_configured_state_abbreviation
    puts "old configuration client was :#{Settings.site.short_name}"
  end

  def target_client_state_abbreviation
    missing_state_abbreviation_message = "Please set your target client as an arguement. " \
    "The rake command should look like:" \
    " RAILS_ENV=production bundle exec rake client_config_toggler:migrate client='me'"
    raise(missing_state_abbreviation_message) if ENV['client'].blank?
    incorrect_state_abbreviation_format_message = "Incorrect state abbreviation length. Set abbreviation to two letters like 'MA' or 'DC'"
    raise(incorrect_state_abbreviation_format_message) if ENV['client'].length > 2
    ENV['client'].downcase
  end

  def copy_target_configuration_to_system_folder
    target_configuration_files = Dir.glob("#{target_config_folder}/*.yml")
    raise("No configuration files present in target directory.") if target_configuration_files.blank?
    yml_files = Dir.glob("#{Rails.root}/config/{[!exchange][!mongoid]}*.yml")
    raise("Settings.yml && IRS yml files are not there on the root.") if yml_files.count != 2
    yml_files.each do |yml_file|
      Dir["*.scss"].reject { |i| i == '_foo.scss' }
      `rm #{yml_file}` if File.exist?(yml_file)
    end
    `cp -r #{target_config_folder}/*.yml #{Rails.root}/config/`
  end

  def migrate
    @old_configured_state_abbreviation = old_configured_state_abbreviation
    @target_client_state_abbreviation = target_client_state_abbreviation
    copy_target_configuration_to_system_folder
    Settings.reload!
    puts("Client configuration toggle complete and new configuration client is :#{Settings.site.short_name}")
  end
end
