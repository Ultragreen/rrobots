require 'rubygems'

require 'rake'
require "rake/clean"
require 'rubygems/package_task'
require "rdoc/task"




spec = Gem::Specification.new do |s| 
  s.name = "UG_RRobots"
  s.version = "2.2"
  s.author = "Simon Kröger, Romain GEORGES"
  s.email = "dev@ultragreen.net"
  s.homepage = "http://www.ultragreen.net/projects/rrobots"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ultragreen RRobots Fork with new features like toolboxes, config file, gemified"
  s.files = FileList["{bin,lib,medias,config,doc,contribs,tools}/**/*"].to_a.concat(['COPYRIGHT.txt','Rakefile'])
  s.require_path = "lib"
  #  s.autorequire = "name"
  #  s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.has_rdoc = true
  s.extra_rdoc_files = FileList["doc/*"].to_a.concat(FileList["bin/*"].to_a)
  s.add_dependency("i18n", ">= 0.2.1")
  s.bindir = 'bin'
  s.executables = ['rrobots','tournament']
  s.description = "Ultragreen RRobots Fork"
  s.rdoc_options << '--title' << 'UG RRobots a RRobots project Fork ' << '--main' << 'doc/manual.rdoc' << '--line-numbers' << '--exclude' << 'contribs robots medias' << '--diagram' 
end



Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
end
 
Rake::RDocTask.new('rdoc') do |d|
  d.rdoc_files.include('doc/**/*','lib/**/*.rb','bin/*')
  d.main = 'doc/manual.rdoc'
  d.title = 'UG RRobots a RRobots project Fork '
  d.options << '--line-numbers' << '--exclude' << 'contribs robots medias' << '--diagram' << '-SHN'
end

task :default => [:gem]

task 'stats' do
  require './tools/scriptlines'

  files = FileList['lib/**/*.rb'].concat(FileList["bin/*"].to_a)
  

  puts ScriptLines.headline
  sum = ScriptLines.new("TOTAL (#{files.size} file(s))")

  # Print stats for each file.
  files.each do |fn|
    File.open(fn) do |file|
      script_lines = ScriptLines.new(fn)
      script_lines.read(file)
      sum += script_lines
      puts script_lines
    end
  end

  # Print total stats.
  puts sum
end



