require 'robot'

class HyperactiveDuck
   include Robot

  def tick events
    turn_radar 1 if time == 0
    accelerate 1
    turn 2
	if !events['robot_scanned'].empty? && gun_heat <= 0
		fire 1
		turn_gun -30		
	end
  end
end