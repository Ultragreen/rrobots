require 'robot'

class BillDuck
  include Robot
  def min(a,b)
    (a < b)? a : b
  end
  def aimtank(angle,rate)
    error = (360 + angle - heading) % 360
    if error > 180
      turn -min(360-error,rate) 
    else
      turn min(error,rate)
    end
    error == 0
  end
  def aimgun(angle,rate)
    error = (360 + angle - gun_heading) % 360
    if error > 180
      turn_gun -min(360-error,rate) 
    else
      turn_gun min(error,rate)
    end
    error == 0
  end
  def aimrad(angle,rate)
    error = (360 + angle - radar_heading) % 360
    if error > 180
      turn_radar -min(360-error,rate) 
    else
      turn_radar min(error,rate)
    end
    error == 0
  end
  def tick events
    #mode nil is startup and initialize variables
    if @mode == nil
      @mode = 0
      @stage = 0
      @dir = 0
      @firecnt = 0
      @timer = 0
      @sincehit = 100
      @sinceblip = 100
    #mode 0 is turn to new heading
    elsif @mode == 0
      a,b,c = aimtank(@dir*90,10),aimgun(@dir*90,30),aimrad(@dir*90,60)
      @stage = 0
      @mode = 1 if a and b and c
    #mode 1 is look forward down the wall
    elsif @mode == 1
      (@stage%2==0)? aimrad(@dir*90 + 5,60) : aimrad(@dir*90-5,60)
      if @stage > 2 and @sinceblip > 2
        @mode,@stage = 2,0
      else
        @stage += 1
      end
    #mode 2 is look backward down the wall
    elsif @mode == 2
      if @stage == 0
        a,b = aimgun(@dir*90 + 180,30), aimrad(@dir*90 + 180,60)
        @stage += 1 if a and b
      else
        (@stage%2==0)? aimrad(@dir*90 + 185,10) : aimrad(@dir*90 +175,10)
        @stage += 1
      end
      if @stage > 2 and @sinceblip > 2
        @mode,@stage = 3,0
      end
    #mode 3 is scan towards the center of the arena and run down the wall
    elsif @mode == 3
      if @stage == 0
        a,b = aimgun(@dir*90 + 90,30), aimrad(@dir*90 + 80,60)
        @stage += 1 if a and b
      else
        @stage += 1
        (@stage%2 == 0)? aimrad(@dir*90 + 90,10) : aimrad(@dir*90 + 80,10)
      end
    end
    walls = [battlefield_width - x,y,x,battlefield_height - y]
    if walls[@dir] < 100
      @mode,@stage,@dir = 0,0,(@dir+1)%4      
    end
    accelerate 1
    @sincehit += 1
    @sincehit = 0 if not events['got_hit'].empty?
    @sinceblip += 1
    @sinceblip = 0 if not events['robot_scanned'].empty?
    fire 0.1
    STDOUT.flush
  end
end