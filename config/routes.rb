Rails.application.routes.draw do
  #get 'pnr_data/get_pnr_info_form_gds'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'
  namespace :api do
    namespace :v1 do
      get 'pnr/:code/gds/:name' => 'pnr_data#get_pnr_info'
      get 'pnr_tickets/:code/gds/:name' => 'pnr_data#get_tickets_from_pnr'
      post 'pnr/write_remarks' => 'pnr_data#write_remarks'
      post 'pnr/send_itinerary' => 'pnr_data#send_itinerary'
    end
  end

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  mount MongodbLogger::Server.new, :at => "/mongodb"
  mount MongodbLogger::Assets.instance, :at => "/mongodb/assets", :as => :mongodb_assets # assets
end
