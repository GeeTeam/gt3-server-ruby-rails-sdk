Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root 'geetest#index'
  get 'register', to: 'geetest#first_register'
  post 'validate', to: 'geetest#second_validate'
end

