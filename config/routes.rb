Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :users, only: %i[new create]
  resource :session, only: %i[new create destroy]
  
  get "signup" => "users#new"
  get "login" => "sessions#new"
  delete "logout" => "sessions#destroy"

  resources :dns_watches, only: %i[index show create update destroy]

  # RSS Feeds
  get "feeds/public", to: "feeds#public", as: :public_feed, defaults: { format: :rss }
  get "feeds/user", to: "feeds#user", as: :user_feed, defaults: { format: :rss }
  get "feeds/watch/:id", to: "feeds#watch", as: :watch_feed, defaults: { format: :rss }

  # Defines the root path route ("/")
  root "dns_watches#index"
end
