# frozen_string_literal: true

module SpecHelpers
  def print_progress
    lambda do |downloaded, total|
      defined = defined?(@__last_time_to_print_progress)
      return if defined && Time.now - @__last_time_to_print_progress < 300

      @__last_time_to_print_progress = Time.now
      puts "#{downloaded} / #{total}" if defined
    end
  end
end
