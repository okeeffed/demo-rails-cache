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
  end
end
```

Update the `config/environments/development.rb` cache config to use the Redis cache instead of the memory store:

```rb
require 'active_support/core_ext/integer/time'

Rails.application.configure do

  # ... omitted

  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    # CHANGE HERE
    # config.cache_store = :memory_store
    config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # ... omitted
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
Server-Timing: start_processing.action_controller;dur=0.125732421875, cache_read.active_support;dur=0.423095703125, cache_generate.active_support;dur=3003.9150390625, cache_write.active_support;dur=0.537841796875, process_action.action_controller;dur=3006.31298828125
Transfer-Encoding: chunked
Vary: Accept
X-Content-Type-Options: nosniff
X-Download-Options: noopen
X-Frame-Options: SAMEORIGIN
X-Permitted-Cross-Domain-Policies: none
X-Request-Id: 19bbeec4-189e-4593-8003-f6c567ce19d8
X-Runtime: 3.012563
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
Started GET "/hello" for ::1 at 2022-03-03 11:43:49 +1000
Processing by HelloController#index as */*
Completed 200 OK in 3006ms (Views: 0.3ms | ActiveRecord: 0.0ms | Allocations: 279)
```

If we run it a second time:

```s
http GET localhost:3000/hello
HTTP/1.1 200 OK
Cache-Control: max-age=0, private, must-revalidate
Content-Type: application/json; charset=utf-8
ETag: W/"d75d122ce074e5382e16eaf331afa72a"
Referrer-Policy: strict-origin-when-cross-origin
Server-Timing: start_processing.action_controller;dur=0.126953125, cache_read.active_support;dur=0.804931640625, cache_fetch_hit.active_support;dur=0.00634765625, process_action.action_controller;dur=2.620849609375
Transfer-Encoding: chunked
Vary: Accept
X-Content-Type-Options: nosniff
X-Download-Options: noopen
X-Frame-Options: SAMEORIGIN
X-Permitted-Cross-Domain-Policies: none
X-Request-Id: 279b4ba3-e72c-4893-ae5f-30a5d884f6a0
X-Runtime: 0.010306
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
Started GET "/hello" for ::1 at 2022-03-03 11:42:35 +1000
Processing by HelloController#index as */*
Completed 200 OK in 2ms (Views: 0.3ms | ActiveRecord: 0.0ms | Allocations: 207)
```

If we were running `redis-cli monitor` that entire time:

```s
$ redis-cli monitor
OK
1646271829.959654 [1 [::1]:56084] "get" "cached_result"
1646271832.964237 [1 [::1]:56084] "set" "cached_result" "\x04\bo: ActiveSupport::Cache::Entry\t:\x0b@value[\aI\"\nHello\x06:\x06ETI\"\nWorld\x06;\aT:\r@version0:\x10@created_atf\x060:\x10@expires_in0"
1646271928.797673 [1 [::1]:56084] "get" "cached_result"
```
