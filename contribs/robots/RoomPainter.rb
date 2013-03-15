# RoomPainter
# written by Jannis Harder (jix) in 2005

require 'robot'

# avoid clashes with other state robots

module RoomPainterTools

  # a state based robot
  class StateRobot
    include Robot
    
    def initialize(*)
      super
      @mode = :idle
      @sec_modes = []
      init
    end
    
    # set mode for next tick
    def next_mode new_mode
      if has_mode? new_mode
        @mode = new_mode
      else
        warn "Robot #{self.class} switched to unknown mode :#{new_mode}!"
        @mode = :idle
      end
    end
    
    # activate a secondary mode
    def add_sec_mode new_mode
      if has_mode? new_mode
        @sec_modes << new_mode
      else
        warn "Robot #{self.class} switched to unknown secondary mode :#{new_mode}!"
      end
    end
    
    # activate some secondary modes
    def add_sec_modes *modes
      modes.flatten.each do |new_mode|
        add_sec_mode new_mode
      end
    end
    
    # deactivate a secondary mode
    def del_sec_mode old_mode
      @sec_modes.delete old_mode
    end
    
    # deactivate some secondary modes
    def del_sec_modes *modes
      modes.flatten.each do |old_mode|
        del_sec_mode old_mode
      end
    end
    
    # test for a mode
    def has_mode? new_mode
      respond_to? new_mode.to_s<<'_tick'
    end
    
    # set new mode and tick it once
    def mode new_mode
      next_mode new_mode
      tick @events
    end
    
    # tick a mode
    def tick_mode temp_mode
      send temp_mode.to_s<<'_tick'
    end
    
    # default tick
    def idle_tick 
    end
    
    # processing
    def tick events
      @events = events
      tick_mode @mode
      @sec_modes.each do |smode|
        tick_mode smode
      end
    end
    
    
    attr_reader :events
    
  end
  
end

class RoomPainter < RoomPainterTools::StateRobot

  def init
    next_mode :move
    add_sec_modes :aim, :scan, :fire
    @scan_range = 2
    @tracking = 0
    @fire = [nil]*2
    @turning = 0
    @deg = 0
    @acc = 1
  end
  

  #helpers
  
  def offset(heading_a,heading_b)
    my_offset = heading_a-heading_b % 360
    my_offset = my_offset -360 if my_offset > 180
    my_offset
  end
  
  def on_wall
    x <= size or \
    y <= size or \
    x >= battlefield_width-size or \
    y >= battlefield_height-size
  end
  
  def nth?(n)
    time % n == 0
  end
  
  #ticks 
  
  def turn_upwards_tick
    stop
    if heading == 90
      mode :paint
      
    else
      turn 90-heading
    end
  end
  
  def scan_tick
    @scan_range = [@scan_range,10].min

    radar_offset = offset(radar_heading,gun_heading)
    if nth? 2
      turn_radar -@scan_range-radar_offset
    else
      turn_radar +@scan_range-radar_offset
    end
  end
  
  def fire_tick
    if x = @fire.pop
      fire x
    end
    if scanned = events['robot_scanned'].first
      away = scanned.first
      str = [0.1,800.0/away].max
      @fire << str
    else
      @fire << nil
    end

  end
  
  def aim_tick
    
    if scanned = events['robot_scanned'].first
      away = scanned.first
      @scan_range = 1.2
      
      @last_offset = offset(radar_heading,gun_heading)/2.0
      turn_gun(@last_offset)
      @tracking = 10
    elsif @tracking <= 0
      @scan_range += 0.1
      if @deg > 0
        turn_gun(-30)
      else
        turn_gun(30)
      end
    else
      @tracking-=1
      @last_offset*=-2
      turn_gun(@last_offset)
    end
    
  end
  
  def move_tick
    accelerate(@acc)
    if @turning <= 0
      @turning = rand(30)
      @deg = (rand*4)*(1-rand(2)*2)
    end
    @turning-=1
    if on_wall and (velocity < 0) == (@acc < 0) and velocity.abs > 4
      @acc *= -1
    else
      turn(@deg)
    end
  end
  

  
end