# frozen_string_literal: true

require 'faraday'
require 'fileutils'
require 'pathname'

module SpecHelpers
  def create_temp_file(kilo_size:, thread_id: nil)
    fake_data = ('A' + 'b' * 4093 + "\r\n").freeze
    filename = "qiniu_#{kilo_size}k"
    filename += "_t#{thread_id}" if thread_id
    temp_file = File.open(Pathname.new('/tmp').join(filename), 'wb+')
    size = kilo_size * 1024
    rest = size
    while rest > 0
      to_write = [rest, fake_data.size].min
      temp_file.write fake_data[0...to_write]
      rest -= to_write
    end
    if block_given?
      yield temp_file
      FileUtils.rm_f(temp_file.path)
    else
      temp_file.path
    end
  ensure
    temp_file&.close
  end

  def temp_file_from_url(url)
    temp_file = File.open(Pathname.new('/tmp').join(File.basename(url)), 'w')
    temp_file.close
    QiniuNg::Storage::URL.new(url).download_to(temp_file.path, progress: print_progress)
    temp_file.path
  end
end
