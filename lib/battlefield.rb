require 'toolboxes'
require 'explosions'
require 'bullets'
require 'mines'

class Battlefield
  
  
   attr_reader :width
   attr_reader :height
   attr_reader :robots
   attr_reader :teams
   attr_reader :bullets
   attr_reader :explosions
   attr_reader :toolboxes
   attr_reader :mines
   attr_reader :time
   attr_reader :seed
   attr_reader :timeout  # how many ticks the match can go before ending.
   attr_reader :game_over
   attr_reader :with_toolboxes
   attr_reader :with_mines
   attr_reader :config

  def initialize width, height, timeout, seed, with_toolboxes, with_mines, merge, write_config
    filename = "rrobots.yml"
    @config = Configuration::new
    @path_prefix = gem_path('config')
    config_sources  = [@path_prefix]
    config_sources.push "." if merge and File::exist?('./rrobots.yml') 
    config_sources.each do |filepath|
      file = YAML::load(File.open("#{filepath}/#{filename}")) 
      file.extend(Configuration_accessors)
      [:game, :toolboxes, :robots, :bullets, :battlefield].each do |accessor|
        @config.send(accessor).merge(file.send(accessor))
      end
    end
    
    @config.write_config if write_config
    @width = (width != self.config.battlefield[:width]) ? width : self.config.battlefield[:width]
    @height = (height != self.config.battlefield[:height]) ? height : self.config.battlefield[:height]
    @seed = seed
    @time = 0
    @robots = []
    @toolboxes = []
    @mines = []
    @with_mines = (self.config.mines[:with_mines] != with_mines)? with_mines : self.config.mines[:with_mines]
    @with_toolboxes = (self.config.toolboxes[:with_toolboxes] != with_toolboxes)? with_toolboxes : self.config.toolboxes[:with_toolboxes]
    @teams = Hash.new{|h,k| h[k] = [] }
    @bullets = []
    @explosions = []
    @timeout = timeout
    @game_over = false
    srand @seed
  end

  def << object
    case object
    when RobotRunner
      @robots << object
      @teams[object.team] << object
    when Bullet
      @bullets << object
    when Explosion
      @explosions << object
    when Toolbox
      @toolboxes << object 
    when Mine
      @mines << object
    end
  end

  def tick
    explosions.delete_if{|explosion| explosion.dead}
    explosions.each{|explosion| explosion.tick}

    toolboxes.delete_if{|toolbox| toolbox.dead}
    toolboxes.each{|toolbox| toolbox.tick}

    mines.delete_if{|mine| mine.dead}
    mines.each{|mine| mine.tick}

    bullets.delete_if{|bullet| bullet.dead}
    bullets.each{|bullet| bullet.tick}
    
    spawning_toolboxes if with_toolboxes

    robots.each do |robot|
      begin
        robot.send :internal_tick unless robot.dead
      rescue Exception => bang
        puts I18n.t('battlefield.robot_made_an_exception', :robot => robot)
        puts "#{bang.class}: #{bang}", bang.backtrace
        robot.instance_eval{@energy = -1}
      end
    end

    @time += 1
    live_robots = robots.find_all{|robot| !robot.dead}
    @game_over = (  (@time >= timeout) or # timeout reached
                    (live_robots.length == 0) or # no robots alive, draw game
                    (live_robots.all?{|r| r.team == live_robots.first.team})) # all other teams are dead
    not @game_over
  end

  def state
    {:explosions => explosions.map{|e| e.state},
     :bullets => bullets.map{|b| b.state},
     :toolboxes => toolboxes.map{|t| t.state},
     :mines => mines.map{|m| m.state},
     :robots => robots.map{|r| r.state}}
  end
  
  def spawning_toolboxes
      if rand(self.config.toolboxes[:spawning_chances]) == 10 and !self.game_over then 
        x = rand(self.width).to_i
        y = rand(self.height).to_i
        toolbox = Toolbox.new(self, x, y, 0, self.config.toolboxes[:energy_heal_points]) 
        self << toolbox
      end
  end

end
