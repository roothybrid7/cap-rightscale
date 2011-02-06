# Load recipes
recipes = Dir[File.join(File.dirname(__FILE__), "recipes/**/*.rb")].map {|recipe| File.expand_path(recipe) }
recipes.each do |recipe|
  Capistrano::Configuration.instance.load recipe
end
