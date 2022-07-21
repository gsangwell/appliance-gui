Rails.application.routes.draw do
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

  constraints Clearance::Constraints::SignedIn.new do
    get  '/logout',  to: 'sessions#destroy'

    get '/setup',  to: 'setup#start'

    get '/setup/user',  to: 'setup#user'
    post '/setup/user',  to: 'setup#user_settings'

    get '/setup/network',  to: 'setup#network'
    post '/setup/network',    to: 'setup#network_settings'

    get '/setup/confirm',  to: 'setup#confirm'
    post '/setup/confirm',  to: 'setup#reconfigure'

    get '/setup/complete',  to: 'setup#complete'

    get '/system',  to: 'system#index'

    get '/support/enable', to: 'support#enable'
    get '/support/disable', to: 'support#disable'

    get '/power/shutdown', to: 'power#shutdown'
    get '/power/restart', to: 'power#restart'

    match '*path', to: 'system#index', via: :get
    root 'system#index'
  end

  constraints Clearance::Constraints::SignedOut.new do
    get     '/login',   to: 'sessions#new'
    post    '/login',   to: 'sessions#create'

    match '*path', to: 'sessions#new', via: :get
    root 'sessions#new', as: :unauthed_root_path
  end

end
