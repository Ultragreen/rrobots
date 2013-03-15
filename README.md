# UG RRobots Fork

## Copyrights :

UG RRobots
Fork of RRobots project
RRobots Core (c) Simon Kröger
  => Ruby license (http://www.ruby-lang.org/en/LICENSE.txt).
Co-author Fork (c) Romain GEORGES
GOSU Engine (c) Albert Ramstedt

## Version 

- UG RRobots  Fork v1.0
- fork of RRobots v0.2.2

## Presentation

First there was CRobots, followed by PRobots and many others, recently
(well also years ago) Robocode emerged and finally this is RRobots bringing
all the fun to the ruby community.

## What is he talking about?

RRobots is a simulation environment for robots, these robots have a scanner
and a gun, can move forward and backwards and are entirely controlled by
ruby scripts. All robots are equal (well at the moment, maybe this will 
change) except for the ai.

## A simple robot script

```ruby
require 'robot'
class NervousDuck
  include Robot
  def tick events
    turn_radar 1 if time == 0
    turn_gun 30 if time < 3
    accelerate 1
    turn 2
    fire 3 unless events['robot_scanned'].empty? 
  end
end
```


all you need to implement is the tick method which should accept a hash
of events occured turing the last tick.


## API RRobots Fork

By including Robot you get all this methods to controll your bot:

- *battlefield_height*    the height of the battlefield
- *battlefield_width*     the width of the battlefield
- *energy*                your remaining energy (if this drops below 0 you are dead)
- *gun_heading*           the heading of your gun, 0 pointing east, 90 pointing, north, 180 pointing west, 270 pointing south
- *gun_heat*              your gun heat, if this is above 0 you can't shoot
- *heading*               your robots heading, 0 pointing east, 90 pointing north, 180 pointing west, 270 pointing south
- *size*                  your robots radius, if x <= size you hit the left wall
- *radar_heading*         the heading of your radar, 0 pointing east, 90 pointing north, 180 pointing west, 270 pointing south
- *time*                  ticks since match start
- *speed*                 your speed (-8/8)
- *x*                     your x coordinate, 0...battlefield_width
- *y*                     your y coordinate, 0...battlefield_height
- *accelerate*(_param_)   accelerate (max speed is 8, max accelerate is 1/-1, negativ speed means moving backwards)
- *stop*                  accelerates negativ if moving forward (and vice versa), may take 8 ticks to stop (and you have to call it every tick)
- *fire*(_power_)         fires a bullet in the direction of your gun, power is 0.1 - 3, this power will heat your gun
- *turn*(_degrees_)       turns the robot (and the gun and the radar), max 10 degrees per tick
- *turn_gun*(_degrees_)   turns the gun (and the radar), max 30 degrees per tick
- *turn_radar*(_degrees_) turns the radar, max 60 degrees per tick
- *dead*                  true if you are dead
- *say*(_msg_)            shows msg above the robot on screen
- *broadcast*(_msg_)      broadcasts msg to all bots (they recieve 'broadcasts' events with the msg and rough direction)
- *team_broadcast*(_msg_) team_broadcasts msg to all bots in your team (they recieve 'team_broadcasts' events with the msg and rough direction)
- *drop_mine* 			  Drop a mine next to the robot, every robots could drop 3 mines by default

These methods are intentionally of very basic nature, you are free to
unleash the whole power of ruby to create higher level functions.
(e.g. move_to, fire_at and so on)

Some words of explanation: The gun is mounted on the body, if you turn
the body the gun will follow. In a simmilar way the radar is mounted on
the gun. The radar scans everything it sweeps over in a single tick (100 
degrees if you turn your body, gun and radar in the same direction) but
will report only the distance of scanned robots, scanned toolboxes or scanned mines, not the angle. If you 
want more precission you have to turn your radar slower.
UG RRobots Fork introduce toolboxes, toolboxes could spawn during a match and if a robot run over it, the toolbox heal it of a default value of 20 energy point.
Toolboxes could be scan separatly of the robots (events keys toolbox_scanned)
The toolbox mode is optionnal 
Mines could be scan separatly (events keys mine_scanned) 

Mines could be dropped by robots, scan by others robots and kill with Bullets with à default energy > 2 

RRobots is implemented in pure ruby using a tk ui and should run on all
platforms that have ruby and tk. (until now it's tested on windows, OS X
and several linux distributions)

RRobots support an other GUI engine, GOSU
This engine offer best displays, musics and sounds

## Usage

see in doc/usage.rdoc

the names of the rb files have to match the class names of the robots.
Each robot is matched against each other 1on1. The results are available 
as yaml or html files.