# frozen_string_literal: true

require 'active_record'
require 'carrierwave'
require 'carrierwave/orm/activerecord'

module CarrierWaveTestForQiniuNg
  class TestUploader < ::CarrierWave::Uploader::Base
    def store_dir
      '/tmp/qiniu_ng/uploads'
    end
  end

  class TestActiveRecord < ActiveRecord::Base
    mount_uploader :test, TestUploader
  end

  module_function

  def connect_to_db
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
  end

  def setup_db
    ActiveRecord::Schema.define(version: 1) do
      create_table :test_active_records do |t|
        t.column :test, :string
      end
    end
  end

  def drop_db
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
  end
end
