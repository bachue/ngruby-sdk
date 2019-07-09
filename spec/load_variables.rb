# frozen_string_literal: true

require 'safe_yaml'

module Variables
  %i[access_key secret_key z2_encrypt_key].each do |variable_name|
    define_method(variable_name) do
      variable_value = ENV[variable_name.to_s]
      variable_value ||= begin
        variable_file_path = File.expand_path('variables.yml', __dir__)
        File.exist?(variable_file_path) && YAML.safe_load_file(variable_file_path)[variable_name.to_s]
      end
      variable_value
    end
  end
end
