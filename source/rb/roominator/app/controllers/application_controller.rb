class ApplicationController < ActionController::Base

  require 'yaml'
  protect_from_forgery

  @service = nil

  def self.authenticate_to_gcal
    if !@service
      auth_data = YAML::load(File.open("config/authentication.yml"))
      @service = GCal4Ruby::Service.new
      @service.authenticate(auth_data['email'], auth_data['password'])
    end
    @service
  end
end
