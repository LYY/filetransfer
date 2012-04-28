# coding: utf-8
require 'sinatra'
require 'haml'
require 'net/http'
configure do
  set(:app_config) { YAML.load_file( 'app.yml' ) || {} }
  set(:proxy_config) { app_config["proxy"] || {} }
end


class URI::HTTP
  def full_path
    if self.query
      self.path + "?" + self.query
    else
      self.path
    end
  end
end

get '/' do
  haml :index
end

post '/trans' do
  uri = URI.parse(params[:file_url])
  path = uri.path
  file_name = path[path.rindex("/") + 1..-1]
  

  headers \
    "Content-type"   => "application/octet-stream",
    "Content-Disposition" => "attachment; filename=\"#{file_name}\"",
    "Cache-Control" => "no-cache, must-revalidate",
    "Pragma" => "no-cache"
  
  stream do |out|
    Net::HTTP::Proxy(settings.proxy_config['addr'], settings.proxy_config['port'], settings.proxy_config['user'], settings.proxy_config['pass']).start(uri.host, uri.port) do |http|
      http.get(uri.full_path) do |str|
        out << str
      end
    end
  end
  
end
