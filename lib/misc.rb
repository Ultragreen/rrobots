
def gem_path(path='')
  # TODO : Perhaps a better way to do it ...
  # regarder Rubygems pour avoir le path direct ..
  res = Array::new
  
  table_map = Gem.location_of_caller.first.split('/')
  table_map.each do |item|
    res.push item
    break if item =~ /UG_RRobots/ 
  end
  res.push path unless path.empty? 
  path_prefix = res.join('/')
  return false unless File::exist?(path_prefix)
  return path_prefix
end 

def init_I18n(locales)
  I18n.default_locale = locales
  locales_path = gem_path('config').concat("/locales")
  I18n.load_path << Dir["#{locales_path}/*.yml"]
end

def get_locale_from_env
  if not ENV['LANGUAGE'].empty? then
    locale = ENV['LANGUAGE'].split('_').first
  elsif not ENV['LANG'].empty? then
    locale = ENV['LANG'].split('_').first
  else
    locale = 'en'
  end
end