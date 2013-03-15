require 'robot'

class KoDuck
include Robot

def initialize *bd
super
end

def near_wall?
if x+10 <= size || y+10 < size || (x+size+10 >= battlefield_width) || 
(y+size+10 >= battlefield_height)
return true
else
return false
end
end

def tick events
@out_of_wall = 0
if time == 0 && near_wall?
turn -10
accelerate 1
return
end
n = (rand + 0.5) * -1
if near_wall? && @out_of_wall.zero?
n *= 10
@out_of_wall += 1
turn n 
else
@out_of_wall += 1 unless @out_of_wall.zero?
turn n
accelerate 1
if @out_of_wall > 100
@out_of_wall = 0
if n.abs > 5
n /=5.0
end
end
end
if !events['robot_scanned'].empty?
fire 3
if (n * 5).abs > 30
n = (n > 0) ? 3: -3
end
turn_gun(-n * 10)
else
turn_gun -6
fire 0.1
end

end

end
 

