require 'robot'
class ShootingStation
  include Robot
  def tick events
    if rand < 0.2
      turn(10)
      turn_gun(30)
    else
      turn(-4)
      turn_gun(-30)
    end
    fire(0.3)
    accelerate(1)
  end
end