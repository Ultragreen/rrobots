require 'robot'
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
      @tracking << [x + Math::cos(angle.to_rad)*dist,y + Math::sin(angle.to_rad)*dist,time]
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
        if v=velocity(@tracking[i],@tracking[i+1]) > 25
          gap = i+1
          debug "traking gap #{@tracking[i].inspect},#{@tracking[i+1].inspect},v\n"
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
        intercepttime = time + distance(a*time+b,c*time+d,x,y)/60.0
        #interceptx,intercepty = limitcoord(intercepttime*a + b, intercepttime*c+d)
        interceptx,intercepty = intercepttime*a + b, intercepttime*c+d
      end
      debug"intercept at (#{interceptx},#{intercepty},#{intercepttime})\n"
      angle = (Math.atan2(intercepty - y,interceptx - x) * 180 / Math::PI)%360
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

class DuckBill
  include Robot
  @@ScanRes = [1,2,4,8,16,32,60]
  # ###########
  # #    Initialize
  # ###########
  def initialize *bf
    if bf.size != 0
      super(bf[0])
      @tourney = false
    else
      super
      @tourney = true
    end
    @mode = 0   # mode of high level logic
    @stage = 0  # sequences within mode
    @dir = 0    # direction we are going
    @walldir = 1    # dirrection we travel around perimeter in, 1 = ccw,-1=cw
    @hit_filter = 0 #low pass filter tells how much damage we are taking
    @sincehit = 100 #how long since we were hit
    @sinceblip = 100  #how long since we saw someone in our radar
    @since_evade = 0 #time since we took evasive action
    @closest = 0  #distance to closest robot scanned since last tick
    @range = 10000  #distance of closest robot
    @mytrack = Tracking.new(battlefield_width,battlefield_height)
    @turns = [0,0,0,0,0,0,0,0,0,0,0,0] # holds data for turn/aim calculations
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
    @outerlimit = (battlefield_width + battlefield_height) * 3
    #print "mode=#{@mode},stage=#{@stage},dir=#{@dir},walldir=#{@walldir}\n"
    #print "at (#{x},#{y}) at time #{time},res=#{@trk_res}\n"
    #mode nil is startup and initialize variables
    #STDOUT.flush
    # ###########
    # #    Sensors
    # ###########
    @since_evade += 1
    @sincehit += 1
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
      #print ",blip=#{@closest}\n"
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
        aimrad(@dir*90 + 180,60,1)
        @range = min(@range,@closest)
        @stage +=1
      #continue around for full circle
      elsif @stage == 1
        @range = min(@range,@closest)
        if aimrad(@dir*90,60,1)
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
        aimrad(@dir*90 + 180,60,1)
        @stage +=1
      #continue scan for the closest bot
      elsif @stage == 1
        #print "dir=#{@dir},angle=#{radar_heading}, closest=#{@closest}\n"
        if @closest < @range * 1.25
          @range = @closest
          @mode = 3
          @stage = 0
          @tangle = radar_heading
          #print "found target at angle #{@tangle}\n"
       #if we finished the scan, and didn't find close target, recompute range
        elsif aimrad(@dir*90,60,1)
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
          @mytrack.add(x,y,@radar_heading, @range , time) if @trk_res < 3
        else
          @stage = 2
        end
      #second scan in this direction
      elsif @stage == 2
        if @closest < @range * 1.25
          @range = @closest
          @trk_dir =  -@trk_dir
          @trk_res = max(@trk_res - 1,0)
          @mytrack.add(x,y,@radar_heading, @range , time) if @trk_res < 3
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
          @mytrack.add(x,y,@radar_heading, @range , time) if @trk_res < 3
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
      @tangle += @@ScanRes[@trk_res] * @trk_dir
      aimrad(@tangle)
      #print"tangle=#{@tangle}, res=#{@@ScanRes[@trk_res]}, rot=#{@trk_dir}\n"
    elsif @mode == 4
      #determine which corner to go to from a corner
      if @stage == 0
        @stage += 1 if aimrad(@dir*90 + 95*@walldir)
      #first scan in direction of prev corner
      elsif @stage == 1
        aimrad(@dir*90 + 60*@walldir)
        @stage += 1
      #save count of robots in next corner, and swing radar to previous corner
      elsif @stage == 2
        @prevCorner = events['robot_scanned'].size
        aimrad(@dir*90 + 30*@walldir)
        @stage += 1
      elsif @stage == 3
        aimrad(@dir*90 -5*@walldir)
        @stage += 1
      elsif @stage == 4
        @nextCorner = events['robot_scanned'].size
        #print "next corner=#{@nextCorner}, prev corner=#{@prevCorner}\n"
        if @nextCorner > @prevCorner
          @dir = (@dir + @walldir)%4
          @walldir *= -1
        end
        @stage = 0
        @mode = 0
      end
    elsif @mode == 5
      #determine which corner to go to from middle of wall
      if @stage == 0
        @stage += 1 if aimrad(@dir*90 - 5*@walldir)
      #first scan in direction of prev corner
      elsif @stage == 1
        aimrad(@dir*90 + 30*@walldir)
        @stage += 1
      #save count of robots in next corner, and swing radar to previous corner
      elsif @stage == 2
        @nextCorner = events['robot_scanned'].size
        aimrad(@dir*90 + 150*@walldir)
        @stage += 1
      elsif @stage == 3
        @stage += 1 
        aimrad(@dir*90 -150*@walldir)
      elsif @stage == 4
        aimrad(@dir*90 -185*@walldir)
        @stage += 1
      elsif @stage == 5        
        @prevCorner = events['robot_scanned'].size
        #print "next corner=#{@nextCorner}, prev corner=#{@prevCorner}\n"
        if @nextCorner > @prevCorner
          @dir = (@dir + 2)%4
          @walldir *= -1
        end
        @stage = 0
        @mode = 0
      end
    end
    #compute the distances to the four walls
    walls = [battlefield_width - x,y,x,battlefield_height - y]
    #hug the wall, if we are slightly off the wall, than move back to the wall
    toleftwall,torightwall = walls[(@dir+1)%4],walls[(@dir-1)%4]
    #print "wallroom left=#{toleftwall}, right=#{torightwall}\n"
    if toleftwall > 80 and toleftwall < 200
      aimtank(@dir * 90 + 20)
    elsif torightwall > 80 and torightwall < 200
      aimtank(@dir * 90 - 20)
    else
      aimtank(@dir * 90)
    end
    #If we reach a corner or wall, turn towards farthest corner on this wall
    if walls[@dir] < 100
      if toleftwall > torightwall
        @walldir = 1 #we are now going ccw
        @dir = (@dir+1)%4 # turn ccw
        #print "turn left\n"        
      else
        @walldir = -1 #we are now going cw
        @dir = (@dir-1)%4 #turn cw
        #print "turn right\n"        
      end
      #don't check corners at T junction
      if  toleftwall > 100 and torightwall > 100
        @mode = 5 # determin weather it is safer ahead or behind
        @stage = 0
      else
        @mode = 4 # determin if previous corner was safer
        @stage = 0
      end
    #If we are getting hammered, turn now to evade damage
    # once we evade, avoid making another evasive manuver or we will turn in circles
    elsif @hit_filter > 400 and @since_evade > 100
      @dir = (@dir+@walldir)%4
      @hit_filter = 0
      @since_evade = 0
    end
    accelerate 1
    aim = @mytrack.predict(x,y,time) || (@dir * 90)%360
    aimgun(aim)
    fire 0.1
    doturns  #we already computed our turns, now execute them
   STDOUT.flush
  end
end