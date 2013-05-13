# encoding: utf-8

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
    do_transfer(out, uri)
  end
end

def do_transfer(out, uri, limit = 10)
  location = nil
  error = nil
  if limit == 0
    error = 'too many HTTP redirects'
  else
    begin
      Net::HTTP::Proxy(settings.proxy_config['addr'], settings.proxy_config['port'], settings.proxy_config['user'], settings.proxy_config['pass']).start(uri.host, uri.port) do |http|
        http.request_get(uri.full_path) do |resp|
          case resp
          when Net::HTTPSuccess then
            resp.read_body { |segment| out << segment }
          when Net::HTTPRedirection then
            location = resp['location']
          else
            error = resp.value
          end
        end
      end
    rescue => exception
      error = exception.to_s
    end
  end
  
  unless location.nil?
    do_transfer(out, URI.parse(location), limit - 1)
  end
  if error
    out << error
  end
end
