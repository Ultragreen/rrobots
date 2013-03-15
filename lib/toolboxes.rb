class Toolbox
  attr_accessor :x
  attr_accessor :y
  attr_accessor :t
  attr_accessor :dead
  attr_accessor :energy

  def initialize bf, x, y, t, energy
    @x, @y, @t = x, y, t
    @battlefield, @energy, @dead = bf, energy, false
  end
  
  def state
    {:x=>x, :y=>y, :energy=>energy}
  end

  def tick
    @t += 1
    @dead ||= t > @battlefield.config.toolboxes[:life_time]
    @battlefield.robots.each do |robot|
      if Math.hypot(@y - robot.y, robot.x - @x) < 20 && (!robot.dead)
        healing = robot.heal(self)
        @dead = true
      end
    end
  end

end