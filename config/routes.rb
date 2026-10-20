Rails.application.routes.draw do
  root "meetings#index"

  resources :members, except: :show
  resources :meetings do
    member do
      get :reminder_preview
      post :send_reminder
      patch :protocol
      post :process_protocol
      post :send_tasks
      post :send_letter
      post :add_topics_to_agenda
    end
    resources :topic_suggestions, only: %i[create update destroy]
    resources :rsvps, only: :create
    resources :tasks, only: %i[create update destroy]
    resources :recordings, only: %i[create show update destroy] do
      member do
        post :chunk
        post :finish
        post :retry
        post :use_as_protocol
        get :audio
      end
    end
  end
  resource :settings, only: %i[edit update] do
    post :test_email
    post :poll_inbox
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
