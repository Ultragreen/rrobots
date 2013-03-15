module Configuration_accessors  
  attr_accessor :game
  attr_accessor :toolboxes
  attr_accessor :robots
  attr_accessor :bullets
  attr_accessor :battlefield
  attr_accessor :mines
end

class Configuration
  
  include Configuration_accessors
  
  def write_config(path='.')
    filepath = "#{path}/#{@filename}"
    File.unlink(filepath) if File::exist?(filepath)
    File.open(filepath, 'w') { |f| f.puts self.to_yaml }
  end

  def initialize(filename="rrobots.yml")
    @filename = filename
    @game = { :timeout => 50000 }
    @toolboxes = { :with_toolboxes => false, :life_time => 200, :spawning_chances => 100, :energy_heal_points => 20 }
    @robots = { :energy_max => 100, :nb_mines => 3, :radar_mine_scanning_performance => 500 }
    @bullets = { :speed => 30 } 
    @battlefield = { :height => 800, :width => 800 }
    @mines = { :with_mines => false, :energy_hit_points => 20, :bullet_energy_resistance => 2 }
  end
  
end
