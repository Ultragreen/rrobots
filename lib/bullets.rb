class Bullet
  attr_accessor :x
  attr_accessor :y
  attr_accessor :heading
  attr_accessor :speed
  attr_accessor :energy
  attr_accessor :dead
  attr_accessor :origin

  def initialize bf, x, y, heading, speed, energy, origin
    @x, @y, @heading, @origin = x, y, heading, origin
    @speed, @energy = speed, energy
    @battlefield, dead = bf, false
  end

  def state
    {:x=>x, :y=>y, :energy=>energy}
  end

  def tick
    return if @dead
    @x += Math::cos(@heading.to_rad) * @speed
    @y -= Math::sin(@heading.to_rad) * @speed

    @dead ||= (@x < 0) || (@x >= @battlefield.width)
    @dead ||= (@y < 0) || (@y >= @battlefield.height)

    @battlefield.robots.each do |other|
      if (other != origin) && (Math.hypot(@y - other.y, other.x - @x) < 40) && (!other.dead)
        explosion = Explosion.new(@battlefield, other.x, other.y)
        @battlefield << explosion
        damage = other.hit(self)
        origin.damage_given += damage
        origin.kills += 1 if other.dead
        @dead = true
      end
    end
    
    @battlefield.mines.each do |mine|
      if (Math.hypot(@y - mine.y, mine.x - @x) < 10) && (!mine.dead) && (mine.origin != origin) then
        explosion = Explosion.new(@battlefield, mine.x, mine.y)
        @battlefield << explosion
        mine.destroy if self.energy > @battlefield.config.mines[:bullet_energy_resistance]
        origin.destroyed_mines += 1
        @dead = true
      end
    end
    
  end
end
