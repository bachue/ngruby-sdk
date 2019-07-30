# frozen_string_literal: true

unless defined?(::CarrierWave)
  begin
    require 'carrierwave'
  rescue LoadError
    # do nothing
    nil
  end
end

if defined?(::CarrierWave)
  # If CarrierWave matches `>=1.0.0`
  require 'qiniu_ng/storage/thirdparty/carrierwave' if ::CarrierWave::VERSION.split('.').map(&:to_i).first.positive?
end

unless defined?(::ActiveStorage)
  begin
    require 'active_storage'
  rescue LoadError
    # do nothing
    nil
  end
end

require 'qiniu_ng/storage/thirdparty/active_storage' if defined?(::ActiveStorage::Service)
