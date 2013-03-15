require 'robot'

class DuckBill04
  include Robot
  # ###########
  # #    Initialize
  # ###########
  def initialize *bf
    super(bf[0]) if bf.size != 0
    super if bf.size == 0
    @ScanRes = [1,2,4,8,16,32,60]
    @mode = 0   # mode of high level logic
    @stage = 0  # sequences within mode
    @dir = 0    # direction we are going
    @walldir = 1    # dirrection we travel around perimeter in, 1 = ccw,-1=cw
    @hit_filter = 0 #low pass filter tells how much damage we are taking
    @sincehit = 100 #how long since we were hit
    @sinceblip = 100  #how long since we saw someone in our radar
    @time_sync = 0 #time since we took evasive action
    @sinceturn = 0
    @closest = 0  #distance to closest robot scanned since last tick
    @range = 10000  #distance of closest robot
    @tangle = 0
    @radar_old = 0
    @mytrack = Tracking.new(battlefield_width,battlefield_height)
    @turns = [0,0,0,0,0,0,0,0,0,0,0,0] # holds data for turn/aim calculations
    @duckdbg = false
  end      
  def debug(a)
    print a if @duckdbg
    STDOUT.flush if @duckdbg
  end
  # ###########
  # #    Controls
  # ###########
  def min(a,b)
    (a < b)? a : b
  end
  def max(a,b)
    (a > b)? a : b
  end
  #dir is 1 for ccw, -1 for cw, and 0 for whichever is quickest
  def aimtank(angle,rate=10,dir=0)
    @turns[0,3] = angle%360,rate,dir
    angle%360 == heading
  end
  def aimgun(angle,rate=30,dir=0)
    @turns[4,3] = angle%360,rate,dir
    angle%360 == gun_heading
  end
  def aimrad(angle,rate=60,dir=0)
    @turns[8,3] = angle%360,rate,dir
    angle%360 == radar_heading
  end
  def doturns
    #this translates directional commands from robot into motor actions
    #turns: 0=desired heading, 1=max speed,2=dir[1=ccw,-1=cw,0=fastest],
    #         3=computed turn, 0-3 for tank, 4-7 for gun, 8-11 for radar
    #compute turns for tank, gun, and radar headings
    #print "computed turns = #{@turns.inspect}\n"
    ccw = (@turns[0] - heading) % 360
    cw = 360 - ccw
    dir = (@turns[2] == 0)? ((ccw<cw)? 1 : -1) : @turns[2]
    @turns[3] = dir * min((dir==1)? ccw : cw,@turns[1])
    ccw = (@turns[4] - @turns[3] - gun_heading) % 360
    cw = 360 - ccw
    dir = (@turns[6] == 0)? ((ccw<cw)? 1 : -1) : @turns[6]
    @turns[7] = dir * min((dir==1)? ccw : cw,@turns[5])
    ccw = (@turns[8] - @turns[7] - @turns[3] - radar_heading) % 360
    cw = 360 - ccw
    dir = (@turns[10] == 0)? ((ccw<cw)? 1 : -1) : @turns[10]
    @turns[11] = dir * min(((dir==1)? ccw : cw),@turns[9])
    #print "computed turns = #{@turns.inspect}\n"
    turn @turns[3]
    turn_gun @turns[7]
    turn_radar @turns[11]
  end
    
  # ###########
  # #    TICK, the Robot code
  # ###########
  def tick events
    @outerlimit = (battlefield_width + battlefield_height)*2
    debug "\nmode=#{@mode},stage=#{@stage},dir=#{@dir},walldir=#{@walldir}\n"
    debug "at (#{x},#{y}) at #{time}, radar=#{radar_heading}, gun=#{gun_heading}\n"
    debug "trk_dir=#{@trk_dir}, trk_res=#{@trk_res},range=#{@range}\n"
    #mode nil is startup and initialize variables
    #STDOUT.flush
    # ###########
    # #    Sensors
    # ###########
    raddif = (radar_heading - @radar_old)%360
    raddif = 360 -raddif if raddif >= 180
    @radave = (radar_heading + raddif/2.0)%360
    @sincehit += 1
    @sinceturn += 1
    @sincehit = 0 if not events['got_hit'].empty?
    events['got_hit'].each{|e| @hit_filter += e.first}
    @hit_filter *= 0.99
    if events['robot_scanned'].empty?
      @sinceblip += 1
      @closest = @outerlimit
      #print"\n"      
    else
      @closest = events['robot_scanned'].collect{|e| e.first}.sort.first
      @sinceblip = 0
      debug ",blip=#{@closest} sweep=(#{@radar_old},#{radar_heading})\n"
    end
    # ###########
    # #    High level logic - state machine
    # ###########
    #print "sincehit=#{@sincehit},closest=#{@closest},range=#{@range}\n"
    #mode 0 is orient tank
    if @mode == 0
      @stage = 0
      @range = @outerlimit
      @mode = 1 if aimrad(@dir*90)
    #mode 1 find range of nearest target
    elsif @mode == 1
      #setup radar for a scan
      if @stage==0
        aimrad(@dir*90 + 180,60,@walldir)
        @range = min(@range,@closest)
        @stage +=1
      #continue around for full circle
      elsif @stage == 1
        @range = min(@range,@closest)
        if aimrad(@dir*90,60,@walldir)
          #did we see a bot?
          if @range == @outerlimit
            @stage = 0 
          else
            @mode = 2
            @stage = 0
          end
        end
      end
    #mode 2: find the nearestbot
    elsif @mode == 2
      #start next circle to re find the closest bot
      if @stage == 0
        #print "range is #{@range}\n"
        aimrad(@dir*90 + 180,60,@walldir)
        @stage +=1
      #continue scan for the closest bot
      elsif @stage == 1
        #print "dir=#{@dir},angle=#{radar_heading}, closest=#{@closest}\n"
        if @closest < @range * 1.25
          @range = @closest
          @mode = 3
          @stage = 1
          @tangle = radar_heading
          @trk_dir,@trk_res = -@walldir,5
          @tangle += @ScanRes[@trk_res] * @trk_dir
          aimrad(@tangle)
          debug "found target at angle #{@tangle}\n"
       #if we finished the scan, and didn't find close target, recompute range
        elsif aimrad(@dir*90,60,@walldir)
          @mode = 0
          @stage =0
        end
      end
    #mode 3 is tracking bot
    elsif @mode == 3
      #entry from previous mode, determine whether to scan ccw or cw
      if @stage == 0
        @trk_dir,@trk_res,@stage = -1,4,2
      #first scan in this direction
      elsif @stage == 1
        if @closest < @range * 1.25
          @range = @closest
          @trk_dir =  -@trk_dir
          @trk_res = max(@trk_res - 1,0)
          @mytrack.add(x,y,@radave, @range , time) if @trk_res < 3
        else
          @stage = 2
        end
      #second scan in this direction
      elsif @stage == 2
        if @closest < @range * 1.25
          @range = @closest
          @trk_dir =  -@trk_dir
          @trk_res = max(@trk_res - 1,0)
          @mytrack.add(x,y,@radave, @range , time) if @trk_res < 3
          @stage = 1
        else
          @trk_dir =  -@trk_dir
          @trk_res = min(@trk_res + 2,4)
          @stage = 3
         end
      #the target bot has moved out of our window, expand the window
      elsif @stage == 3
        if @closest < @range * 1.25
          @range = @closest
          @trk_dir =  - @trk_dir
          @trk_res = max(@trk_res - 2,0)
          @mytrack.add(x,y,@radave, @range , time) if @trk_res < 3
          @stage = 1
        elsif @trk_res < 6
          @trk_dir =  - @trk_dir
          @trk_res = @trk_res +1
        else
          #we lost our target, reaquire from scratch
          @mode = 0
          @stage = 0
        end
      end
      @tangle += @ScanRes[@trk_res] * @trk_dir
      aimrad(@tangle)
      #print"tangle=#{@tangle}, res=#{@ScanRes[@trk_res]}, rot=#{@trk_dir}\n"
    end
    #compute the distances to the four walls
    walls = [battlefield_width - x,y,x,battlefield_height - y]
    toleftwall,torightwall = walls[(@dir+1)%4],walls[(@dir-1)%4]
    #debug "wallroom left=#{toleftwall}, right=#{torightwall}\n"
    if walls.sort.first < 100 and @sinceturn > 30
      if walls.sort[1] < 300
        @dir = walls.index(walls.sort.first)
        aimtank((@dir * 90 + 180)%360)
      else
        aimtank((heading + 180)%360)
      end
      @walldir *= -1
      @sinceturn = 0
    else
      if @range > 800
        aimtank((@tangle + @walldir* 70)%360)
      elsif @range <600
        aimtank((@tangle + @walldir* 110)%360)
      else
        aimtank((@tangle + @walldir* 90)%360)
      end
    end
    debug "time=#{time}, time_sync=#{@time_sync},mod=#{(time+@time_sync)%20}\n"
    if (time+@time_sync) % 20 < 10
      stop
    else
      accelerate 1
    end
    @time_sync = 25 - time%20 if @sincehit == 0
    aim = @mytrack.predict(x,y,time) || (@dir * 90)%360
    aimgun(aim)
    fire 0.1
    doturns  #we already computed our turns, now execute them
    @radar_old = radar_heading
   STDOUT.flush
  end
end
class Tracking
  def debug(a)
    print a if @trkdbg
    STDOUT.flush if @trkdbg
  end
  def initialize(width,height)
    @trkdbg = false
    @tracking = []
     @width = width
    @height = height
  end
  def add(x,y,angle,dist,time)
    @tracking << [x + Math::cos(angle.to_rad)*dist,y - Math::sin(angle.to_rad)*dist,time]
    debug "added track angle=#{angle},dist=#{dist},#{@tracking.last.inspect}\n"
  end
  def trim(time)
    #delete really old samples
    @tracking.delete_if{|e| time - e[2] > 30}
    #limit to 10 samples
    @tracking.shift while @tracking.size>10
    #eliminate samples if they came from a different robot. we can tell this because they have max speed of 8
    gap = 0
    (@tracking.size- 1).times{|i| 
      if (v=velocity(@tracking[i],@tracking[i+1])) > 40
        gap = i+1
        debug "traking gap #{@tracking[i].inspect},#{@tracking[i+1].inspect},v=#{v}\n"
      end
    }
    gap.times{@tracking.shift}
    #normalize the time
    #@tracking.size.times{|i| @tracking[@tracking.size-1-i][2] -=@tracking[0][2]}
  end
  def velocity (e1,e2)
    distance(e1[0],e1[1],e2[0],e2[1])/(e1[2]-e2[2]).abs
  end
  def distance (x1,y1,x2,y2)
    ((x1-x2)**2 + (y1-y2)**2)**(0.5)
  end
  def findline
    sx=sy=st=sxt=syt=stt=0.0
    @tracking.each{|e|
      debug " findline element = #{e.inspect}\n"
      sx += e[0]
      sxt += e[2]*e[0]
      sy += e[1]
      syt += e[2]*e[1]
      st += e[2]
      stt += e[2]*e[2]
    }
    n=@tracking.size
    c2 = (sxt/st-sx/n)/(stt/st-st/n)
    c1 = sx/n-(st/n)*c2
    f2 = (syt/st-sy/n)/(stt/st-st/n)
    f1 = sy/n-(st/n)*f2
    debug "x = #{c2}t + #{c1}\n"
    debug "y = #{f2}t + #{f1}\n"
    [c2,c1,f2,f1]
  end
  def predict(x,y,time)
    trim(time)
    if @tracking.size < 1
      return false 
    elsif @tracking.size == 1
      interceptx,intercepty = @tracking[0][0],@tracking[0][1]
    else
      a,b,c,d = findline
      intercepttime = time + distance(a*time+b,c*time+d,x,y)/30.0
      #interceptx,intercepty = limitcoord(intercepttime*a + b, intercepttime*c+d)
      interceptx,intercepty = intercepttime*a + b, intercepttime*c+d
    end
    debug"intercept at (#{interceptx},#{intercepty},#{intercepttime})\n"
    angle = (Math.atan2(y - intercepty,interceptx - x) * 180 / Math::PI)%360
    debug "firing angle is #{angle}\n"
    angle
  end
  def limitcoord(x,y)
    nx=[x,0.0].max
    nx = [nx,@width.to_f].min
    ny = [ny,@height.to_f].min
    [nx,ny]
  end
end
