#!/usr/bin/env rake

chef_version = '12.19.36'
namespace :style do
  require 'rubocop/rake_task'
  desc 'Style check with rubocop'

  require 'foodcritic'
  desc 'Style check with foodcritic for root'
  orig_dir = Dir.pwd
  FoodCritic::Rake::LintTask.new('chef./'.to_sym) do |t|
    t.options = {
      progress: true,
      chef_version: chef_version,
      fail_tags: %w(none),
      role_path: ['./stub-environment/roles/'],
      environment_path: ['./stub-environments/environments/Test-Laptop.json']
    }
  end

  Dir.glob('./cookbooks/*').each do |c|
    Dir.chdir(File.join(orig_dir, c))
    desc 'Style check with foodcritic for #{c}'
    FoodCritic::Rake::LintTask.new(('chef' + c).to_sym) do |t|
      t.options = {
        fail_tags: %w(none),
        progress: true,
        chef_version: chef_version,
        role_path: ['./stub-environment/roles/*'],
        cookbook_path: c,
        environment_path: ['./stub-environments/environments/Test-Laptop.json']
      }
    end
    Dir.chdir(orig_dir)
  end

  RuboCop::RakeTask.new(:ruby) do |t|
    t.options = ['-d']
    t.fail_on_error = false
  end

  desc 'Check style violation difference'
  task('diff'.to_sym) do
    sh './compare_style.sh'
  end

  desc 'Run foodcritic checks'
  task chef: %w(style:chef./) + \
              Dir.glob('./cookbooks/*').map { |c| 'style:chef' + c }
end

desc 'Run style checks'
task style: %w(style:ruby style:chef)

desc 'Clean some generated files'
task :clean do
  %w(
    **/Berksfile.lock
    .bundle
    .cache
    **/Gemfile.lock
    .kitchen
    vendor
    ../cluster
    vbox
  ).each { |f| FileUtils.rm_rf(Dir.glob(f)) }
  # XXX should remove VBox VM's
end

task :default => 'style'
