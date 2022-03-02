class HelloController < ApplicationController
  def index
    res = Rails.cache.fetch(:cached_result) do
      # Only executed if the cache does not already have a value for this key

      # We will sleep for 3 seconds to simulate an expensive operation
      sleep 3

      # Return the array ["Hello", "World"]
      messages = %w[Hello World]
    end

    render json: { message: res }
  end
end
