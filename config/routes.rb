Rails.application.routes.draw do
  resources :hello, only: [:index]
end
