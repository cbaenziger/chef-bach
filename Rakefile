require 'rubocop/rake_task'
require 'foodcritic'
require 'kitchen'

# Style tests. Rubocop and Foodcritic
namespace :style do
  desc 'Run Ruby style checks'
  RuboCop::RakeTask.new(:ruby) do |task|
    task.patterns = ['cookbooks/*bcpc*/**/*.rb',
                     'cookbooks/*bach*/**/*.rb',
                     'cookbooks/hannibal/**/*.rb']
    # don't abort rake on failure
    task.fail_on_error = false
  end

  desc 'Run Chef style checks'
  FoodCritic::Rake::LintTask.new(:chef) do |task|
    task.options = {
      cookbook_paths: Dir.glob('cookbooks/*bcpc*/') +
                      Dir.glob('cookbooks/*bach*/') +
                      Dir.glob('cookbooks/hannibal/'),
      fail_tags: ['any']
    }
  end
end

namespace :spec do
  begin
    require 'rspec/core/rake_task'
    # Rspec and ChefSpec
    desc 'Run ChefSpec examples'
    RSpec::Core::RakeTask.new(:spec)
  rescue LoadError
  end
end

# Integration tests. Kitchen.ci
namespace :integration do
  desc 'Run Test Kitchen with Vagrant'
  task :vagrant do
    Kitchen.logger = Kitchen.default_file_logger
    Kitchen::Config.new.instances.each do |instance|
      instance.test(:always)
    end
  end
end
