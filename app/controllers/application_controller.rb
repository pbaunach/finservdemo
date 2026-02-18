class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token, if: -> { ENV['STATIC_EXPORT'] == '1' }

  #http_basic_authenticate_with name: "FinServ", password: "123salesforce"
end
