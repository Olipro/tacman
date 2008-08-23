ActionController::Routing::Routes.draw do |map|
  map.resources :departments

  map.resources :avpairs

  map.resources :author_avpair_entries

  map.resources :author_avpairs,
                :member => {:create_entry => :post, :resequence => :put,
                            :changelog => :get}

  map.resources :acl_entries

  map.resources :shell_command_object_group_entries

  map.resources :network_object_group_entries

  map.resources :acls,
                :member => {:create_entry => :post, :resequence => :put,
                            :changelog => :get}

  map.resources :user_groups,
                :member => {:changelog => :get, :members => :get}

  map.resources :shell_command_object_groups,
                :member => {:create_entry => :post, :resequence => :put,
                            :changelog => :get}

  map.resources :network_object_groups,
                :member => {:create_entry => :post, :optimize => :put, :resequence => :put,
                            :changelog => :get}

  map.resources :command_authorization_profile_entries

  map.resources :command_authorization_profiles,
                :member => {:create_entry => :post, :resequence => :put,
                            :changelog => :get}

  map.resources :command_authorization_whitelist_entries

  map.resources :configured_users,
                :member => {:activate => :put, :suspend => :put}

  map.resources :tacacs_daemons,
                :member => {:aaa_log => :get, :changelog => :get, :error_log => :get,
                            :clear_error_log => :put, :migrate => :get, :do_migrate => :post},
                :collection => {:start_stop_selected => :put, :bulk_create => :get, :import => :post}

  map.resources :configurations,
                :member => {:aaa_log_archives => :get, :aaa_log_file => :get, :aaa_logs => :get, :aaa_log_details => :get,
                            :add => :post, :download_archived_log => :post,
                            :acls => :get, :new_acl => :get, :create_acl => :post,
                            :author_avpairs => :get, :new_author_avpair => :get, :create_author_avpair => :post,
                            :command_authorization_profiles => :get, :new_command_authorization_profile => :get, :create_command_authorization_profile => :post,
                            :command_authorization_whitelist => :get, :new_command_authorization_whitelist_entry => :get, :create_command_authorization_whitelist_entry => :post,
                            :network_object_groups => :get, :new_network_object_group => :get, :create_network_object_group => :post,
                            :shell_command_object_groups => :get, :new_shell_command_object_group => :get, :create_shell_command_object_group => :post,
                            :tacacs_daemons => :get, :tacacs_daemon_changelog => :get, :tacacs_daemon_control => :put, :tacacs_daemon_logs => :get,
                            :user_groups => :get, :new_user_group => :get, :create_user_group => :post,
                            :add_remove_users => :get, :settings => :get,
                            :resequence_whitelist => :put, :search_aaa_logs => :get, :log_search_form => :get,
                            :changelog => :get, :publish => :put}

  map.resources :users,
                :collection => {:authenticate => :put, :home => :get, :help => :get,
                                :change_password => :get, :change_enable => :get,
                                :login => :get, :logout => :get,
                                :update_change_password => :put, :update_change_enable => :put,
                                :bulk_create => :get, :import => :post},
                :member => {:aaa_logs => :get, :system_logs => :get, :add_to_configuration => :post, :remove_from_configuration => :post,
                            :reset_password => :get, :reset_enable => :get,
                            :set_role_admin => :put, :set_role_user => :put, :set_role_user_admin => :put,
                            :toggle_allow_web_login => :put, :toggle_allow_web_services => :put, :toggle_disabled => :put,
                            :toggle_enable_expiry => :put, :toggle_password_expiry => :put,
                            :extend_enable_expiry => :put, :extend_password_expiry => :put,
                            :toggle_disable_aaa_log_import => :put, :toggle_disable_aaa_log_import => :put,
                            :update_reset_password => :put, :update_reset_enable => :put,
                            :changelog => :get, :publish => :put}

  map.resources :system_messages

  map.resources :managers,
                :collection => {:local => :get, :local_logs => :get, :register => :post,
                                :master => :post, :slave => :post, :stand_alone => :post,
                                :request_registration => :post, :resync => :post,
                                :show_master => :get, :backgroundrb => :post,
                                :system_export => :get, :tacacs_daemon_control => :post,
                                :read_log_file => :post, :write_to_inbox => :post,
                                :system_log_archives => :get, :download_archived_log => :post,
                                :toggle_maintenance_mode => :post},
                :member => {:approve => :put, :disable => :put, :enable => :put, :inbox => :get, :outbox => :get, :system_sync => :post,
                            :system_logs => :get, :unprocessable_messages => :get,
                            :changelog => :get, :search_logs => :get, :log_search_form => :get,
                            :write_outbox => :post, :process_inbox => :post}


  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  map.connect '', :controller => "users", :action => 'login'

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
