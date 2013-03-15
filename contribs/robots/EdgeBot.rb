# EdgeBot.rb
require 'robot'

class EdgeBot
include Robot

@@east = 0
@@north = 90
@@west = 180
@@south = 270
@@none = -1

@@direction = {
:east => {
:angle => @@east,
:inward_angle => @@west,
:next_edge => [:north, :south]
},
:north => {
:angle => @@north,
:inward_angle => @@south,
:next_edge => [:west, :east]
},
:west => {
:angle => @@west,
:inward_angle => @@east,
:next_edge => [:south, :north]
},
:south => {
:angle => @@south,
:inward_angle => @@north,
:next_edge => [:east, :west]
}
}

@@max_robot_turn = 10
@@max_gun_turn = 30
@@max_radar_turn = 60
@@max_speed = 8

@@chicken_energy = 10

def tick( events )
if time == 0
@direction = 0
@target_angle = Hash.new
@next_edge = nearest_edge
@target_angle[:robot] = @@direction[@next_edge][:angle]
@target_angle[:gun] = @@direction[@next_edge][:angle]
@target_angle[:radar] = @@direction[@next_edge][:angle]
@mode = :seek_edge
@prev_radar_heading = radar_heading
@fire_power = 3
end

rotate!
fire( @fire_power )

case @mode
when :seek_edge
# puts "seek_edge"
@fire_power = 0.1
if @turn_complete
@mode = :move_to_edge
end
when :move_to_edge
# puts "move_to_edge"
fire( 3 ) unless events['robot_scanned'].empty?
unless at_edge? @next_edge
accelerate( 1 )
else
@current_edge = @next_edge
@next_edge = @@direction[@current_edge][:next_edge][@direction]
@target_angle[:robot] = @@direction[@next_edge][:angle]
@target_angle[:gun] = @@direction[@current_edge][:inward_angle]
@target_angle[:radar] = @@direction[@next_edge][:angle]
@mode = :edge_align
end
when :edge_align
# puts "edge_align"
@fire_power = 0.1
if speed != 0
stop
end
if @turn_complete && @prev_radar_heading == radar_heading
# Pause for a still radar shot before progressing
@mode = :fire
end
if edge_occupied?( @@direction[@next_edge][:angle], events )
@mode = :clear_edge_align
@target_angle[:gun] = @@direction[@next_edge][:angle]
@target_angle[:radar] = @@direction[@next_edge][:angle]
end
when :fire
# puts "fire"
@fire_power = 0.1
if velocity < @@max_speed
accelerate( 1 )
end
if at_edge?( @next_edge )
@current_edge = @next_edge
@next_edge = @@direction[@current_edge][:next_edge][@direction]
@target_angle[:robot] = @@direction[@next_edge][:angle]
@target_angle[:gun] = @@direction[@current_edge][:inward_angle]
@target_angle[:radar] = @@direction[@next_edge][:angle]
@mode = :edge_align
elsif edge_occupied?( @@direction[@next_edge][:angle], events )
@mode = :clear_edge_align
@target_angle[:gun] = @@direction[@next_edge][:angle]
@target_angle[:radar] = @@direction[@next_edge][:angle]
end
when :clear_edge_align
# puts "clear_edge_align"
@fire_power = 0.1
if speed != 0
stop
end
if @turn_complete
@mode = :clear_edge
end
when :clear_edge
@fire_power = 0.1
if not edge_occupied?( @@direction[@next_edge][:angle], events )
@target_angle[:gun] = @@direction[@current_edge][:inward_angle]
@target_angle[:radar] = @@direction[@next_edge][:angle]
@mode = :edge_align
elsif energy < @@chicken_energy
reverse_course!
end
end

@prev_radar_heading = radar_heading
end

def rotate!
@turn_complete = true
if @target_angle[:robot] != @@none && heading != @target_angle[:robot]
turn( angle_to( @target_angle[:robot], heading, @@max_robot_turn ) )
@turn_complete = false
elsif @target_angle[:gun] != @@none && gun_heading != @target_angle[:gun]
turn_gun( angle_to( @target_angle[:gun], gun_heading, @@max_gun_turn ) )
@turn_complete = false
elsif @target_angle[:radar] != @@none && radar_heading != @target_angle[:radar]
turn_radar( angle_to( @target_angle[:radar], radar_heading, @@max_radar_turn ) )
@turn_complete = false
end
end

def angle_to( target_heading, current_heading, max_turn )
normalised_heading = current_heading - target_heading
dir = (normalised_heading < 180) ? -1 : 1
if normalised_heading < max_turn
return dir * normalised_heading
else
return dir * max_turn
end
end

def at_edge?( edge )
case edge
when :east
return x >= (battlefield_width - size)
when :north
return y <= size
when :west
return x <= size
when :south 
return y >= (battlefield_height - size)
end
end

def edge_occupied?( angle, events )
return (@prev_radar_heading == angle && 
radar_heading == angle &&
!events['robot_scanned'].empty?)
end

def nearest_edge
min = [:west, x]
if y < min[1]
min = [:north, y]
end
if battlefield_width - x < min[1]
min = [:east, battlefield_width - x]
end
if battlefield_height - y < min[1]
min = [:south, battlefield_height - y]
end
return min[0]
end

def reverse_course!
@direction = (@direction + 1) % 2
@next_edge = @@direction[@current_edge][:next_edge][@direction]
@target_angle[:robot] = @@direction[@next_edge][:angle]
@target_angle[:gun] = @@direction[@current_edge][:inward_angle]
@target_angle[:radar] = @@direction[@next_edge][:angle]
@mode = :edge_align
end

end
 

