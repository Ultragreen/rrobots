class Mine
  attr_accessor :x
  attr_accessor :y
  attr_accessor :t
  attr_accessor :dead
  attr_accessor :energy
  attr_accessor :origin

  def initialize bf, x, y, energy, origin
    @x, @y, @origin = x, y, origin
    @battlefield, @energy, @dead = bf, energy, false
  end
  
  def state
    {:x=>x, :y=>y, :energy=>energy}
  end

  def tick
    @battlefield.robots.each do |robot|
      if (robot != origin) && (Math.hypot(@y - robot.y, robot.x - @x) < 40) && (!robot.dead)
        explosion = Explosion.new(@battlefield, robot.x, robot.y)
        @battlefield << explosion
        damage = robot.hit(self)
        origin.damage_given += damage
        origin.kills += 1 if robot.dead
        robot.trigged_mines += 1
        @dead = true
      end
    end
  end
  
  def destroy
    @dead = true
  end

end