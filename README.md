# README

This is the repo to go along with a blog post.

## Steps

In `config/application/rb`:

```rb
require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DemoRailsCache
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.action_controller.default_protect_from_forgery = false if ENV['RAILS_ENV'] == 'development'
    config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
  end
end
```

Setup:

```s
# Generate a test controller
$ bin/rails g controller hello index

# Toggle on cache in dev mode
$ bin/rails dev:cache

$ bin/rails s
```

For `config/routes.rb`:

```rb
Rails.application.routes.draw do
  resources :hello, only: [:index]
end
```

Inside of `app/controllers/hello_controller.rb` add the following:

```rb
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
```

## Testing our endpoint

First run:

```s
$ http GET localhost:3000/hello
HTTP/1.1 200 OK
Cache-Control: max-age=0, private, must-revalidate
Content-Type: application/json; charset=utf-8
ETag: W/"d75d122ce074e5382e16eaf331afa72a"
Referrer-Policy: strict-origin-when-cross-origin
Server-Timing: start_processing.action_controller;dur=0.09619140625, cache_read.active_support;dur=0.010986328125, !compile_template.action_view;dur=54.86083984375, !render_template.action_view;dur=184.389892578125, render_partial.action_view;dur=11.81005859375, render_collection.action_view;dur=15.66064453125, render_template.action_view;dur=149.24560546875, render_layout.action_view;dur=96.518798828125, request.action_dispatch;dur=243.8232421875, cache_generate.active_support;dur=3004.27197265625, cache_write.active_support;dur=0.087890625, process_action.action_controller;dur=3017.899169921875
Transfer-Encoding: chunked
Vary: Accept
X-Content-Type-Options: nosniff
X-Download-Options: noopen
X-Frame-Options: SAMEORIGIN
X-Permitted-Cross-Domain-Policies: none
X-Request-Id: 5f2c4516-a870-418c-8eb9-4d4c4f17e4ea
X-Runtime: 3.032582
X-XSS-Protection: 0

{
    "message": [
        "Hello",
        "World"
    ]
}
```

Our server console tells us the following:

```s
Started GET "/hello" for ::1 at 2022-03-02 15:28:09 +1000
Processing by HelloController#index as */*
Completed 200 OK in 3018ms (Views: 0.2ms | Allocations: 76268)
```

If we run it a second time:

```s
http GET localhost:3000/hello
HTTP/1.1 200 OK
Cache-Control: max-age=0, private, must-revalidate
Content-Type: application/json; charset=utf-8
ETag: W/"d75d122ce074e5382e16eaf331afa72a"
Referrer-Policy: strict-origin-when-cross-origin
Server-Timing: start_processing.action_controller;dur=0.218994140625, cache_read.active_support;dur=0.065185546875, cache_fetch_hit.active_support;dur=0.002685546875, process_action.action_controller;dur=1.281005859375
Transfer-Encoding: chunked
Vary: Accept
X-Content-Type-Options: nosniff
X-Download-Options: noopen
X-Frame-Options: SAMEORIGIN
X-Permitted-Cross-Domain-Policies: none
X-Request-Id: b97f2b96-5947-4156-b171-e3c8bc9b195d
X-Runtime: 0.010434
X-XSS-Protection: 0

{
    "message": [
        "Hello",
        "World"
    ]
}
```

The Rails server logs tell us the following:

```s
Started GET "/hello" for ::1 at 2022-03-02 15:29:14 +1000
Processing by HelloController#index as */*
Completed 200 OK in 1ms (Views: 0.2ms | Allocations: 167)
```
