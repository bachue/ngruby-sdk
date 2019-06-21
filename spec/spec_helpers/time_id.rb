# frozen_string_literal: true

module SpecHelpers
  def time_id
    Time.now.utc.strftime('%Y%m%d%H%M%S%3N')
  end
end
