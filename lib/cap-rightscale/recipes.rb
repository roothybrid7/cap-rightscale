# Load recipes
recipes = Dir['cap-rightscale/recipes/*.rb'].map {|recipe| File.expand_path(recipe)}
recipes.each do |recipe|
  Capistrano::Configuration.instance.load recipe
end
