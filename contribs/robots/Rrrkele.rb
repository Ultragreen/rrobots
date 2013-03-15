require 'robot'

class Rrrkele
include Robot

def limit value, m
value -= 360 if value > 180
value += 360 if value < -180
value = -m if value < -m
value = m if value > m
return value
end

def tick events
if time == 0
@acc = 1
@target_distance = 250
@target_heading = rand * 360
@scanning_range = 60
@velocity = 0
end

unless events['robot_scanned'].empty?
@target_distance = events["robot_scanned"].first.first
@target_heading = @radar_heading
@scanning_range *= -0.5 if @scanning_range.abs > 0.5
else
@scanning_range *= -2 if @scanning_range.abs < 60
end

unless events['got_hit'].empty?
@acc *= -1
end

fire 0.1

body_turn_angle = limit(@heading - @target_heading + 90, 10)
gun_turn_angle = limit(@target_heading - @gun_heading - body_turn_angle, 30)
radar_turn_angle = limit(@scanning_range - gun_turn_angle - body_turn_angle, 60)

turn(body_turn_angle)
turn_gun(gun_turn_angle)
turn_radar(radar_turn_angle)

accelerate(@acc)
end
end  

