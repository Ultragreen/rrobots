# Uses linear targetting and
# moves in a way that dodges linear targetting.
# Not very good for melee.
#
require 'robot'
require 'matrix'

class Numeric
  def deg2rad
    self * 0.0174532925199433
  end
  def rad2deg
    self * 57.2957795130823
  end
  def sign
    self / abs
  end
end
class Array
  def average
    inject{|s,i|s+i} / size.to_f
  end
  def sd
    avg = average
    Math.sqrt( inject(0){|s,i| s+(i-avg)**2} / (size-1.0) )
  end
end

class Kite
include Robot

  def initialize *args, &block
    super
    @rt = @radar_scan = 15
    @min_radar_scan = 1.5
    @max_radar_scan = 60.0
    @lock = false
    @firing_threshold = 20.0
    @wanted_turn = @wanted_gun_turn = @wanted_radar_turn = 0
    @rturn_dir = 1
    @racc_dir = 1
    @target_positions = []
    @sd_limit = 30
  end

  def tick events
    @prev_health = energy if time == 0
    if events['robot_scanned'].empty?
      @radar_scan = [@radar_scan * 1.5, @max_radar_scan].min
    else
      @radar_scan = [@radar_scan * 0.5, @min_radar_scan].max
    end
    @rt = (time/2 % 2 < 1 ? -@radar_scan/2.0 : @radar_scan/2.0) if @radar_scan.abs < @max_radar_scan - 0.1
    @wanted_radar_turn += @rt
    firing_solution events
    @hit = unless events['got_hit'].empty?
      @racc_dir = @racc_dir / @racc_dir.abs 
      20
    else
      (@hit||0) - 1
    end
    if @hit < 0
      @racc_dir = (@min_distance and @min_distance < 450) ? @racc_dir.sign : Math.sin(time*0.1+rand*0.2)
    end
    accelerate(@racc_dir)
    if approaching_wall?
      @wanted_turn = 60 * @rturn_dir
    elsif @target_heading and @wanted_turn <= 1
      @wanted_turn = heading_distance(((@min_distance and @min_distance < 450) ? (90-@rturn_dir.sign*30)*-@racc_dir.sign : 0)+heading, 90+@target_heading)
    elsif rand < 0.3
      @wanted_turn += rand * 10 * @racc_dir.sign * @rturn_dir
    elsif rand < 0.01
      @rturn_dir *= -1
    elsif rand < 0.01
      @racc_dir *= -1
    end
    turn_hull
    turn_turret
    turn_radar_dish
    @prev_health = energy
  end

  def firing_solution events
    unless events['robot_scanned'].empty?
      last = @target_positions.last || Vector[0,0]
      position = events['robot_scanned'].map{|d|
        tx = x + Math.cos((radar_heading - @radar_scan.abs / 2.0).deg2rad) * d[0]
        ty = y - Math.sin((radar_heading - @radar_scan.abs / 2.0).deg2rad) * d[0]
        Vector[tx,ty]
      }.min{|a,b| (a - last).r <=> (b - last).r }
      @target_positions.push position
      @min_distance = events['robot_scanned'].flatten.min
    end
    @target_positions.shift if @target_positions.size > 10
    @min_distance = nil if @target_positions.empty?
    @target_heading = target_heading
    gtd = heading_distance(gun_heading, @target_heading) if @target_heading
    @firepower = [3*25 / (@vsd||1500)].max / 2.0
    fire @firepower if @on_target
    if gtd and gtd.abs < @firing_threshold
      @wanted_gun_turn = gtd
      @on_target = true
    else
      @wanted_gun_turn = gtd || (gun_radar_distance/3.0)
      @on_target = false
    end
  end
  
  def average arr
    arr.inject{|s,i| s+i} * (1.0/arr.size)
  end

  def target_heading
    return nil if @target_positions.size < 10
    return radar_heading if @min_distance and @min_distance < 200
    lps = (0...5).map{|i| @target_positions[i*2,2] }.map{|pta| average(pta) }
    p4 = lps.last
    vs = lps[0..-2].zip(lps[1..-1]).map{|a,b| (b-a) * 0.5 }
    @vsd = Math.sqrt(vs.map{|v| v[0]}.sd**2 + vs.map{|v| v[1]}.sd**2)
    return nil if @vsd > @sd_limit
    v = average(vs)
    return heading_for(average(lps)) if v.r < 4.0
    p4 = p4 + (v*0.5)
    distance = p4 - Vector[x,y]
    shot_speed = (30/8.0)*v.r
    a = distance[0]**2 + distance[1]**2
    b = 2*distance[0]*v[0] + 2*distance[1]*v[1]
    c = v[0]**2 + v[1]**2 - shot_speed**2
    t = 2*a / (-b + Math.sqrt(b**2-4*a*c))
    ep = p4 + v*t
    estimated_position = Vector[
      [size, [battlefield_width-size, ep[0]].min].max, 
      [size, [battlefield_height-size, ep[1]].min].max]
    heading_for(estimated_position) + (rand-0.5)*@vsd*0.2
  end
  
  def heading_for(position)
    distance = position - Vector[x,y]
    heading = (Math.atan2(-distance[1], distance[0])).rad2deg
    heading += 360 if heading < 0
    heading
  end

  def heading_distance h1, h2
    limit h2 - h1, 180
  end

  def limit value, m
    value -= 360 if value > 180
    value += 360 if value < -180
    value = -m if value < -m
    value = m if value > m
    return value
  end

  def gun_radar_distance
    heading_distance gun_heading, radar_heading
  end

  def turn_hull
    turn_amt = [-10.0, [@wanted_turn, 10.0].min].max
    turn turn_amt
    @wanted_turn -= turn_amt
    @wanted_gun_turn -= turn_amt
    @wanted_radar_turn -= turn_amt
  end

  def turn_turret
    turn_amt = [-30.0, [@wanted_gun_turn, 30.0].min].max
    turn_gun turn_amt
    @wanted_gun_turn -= turn_amt
    @wanted_radar_turn -= turn_amt
  end

  def turn_radar_dish
    turn_amt = [-60.0, [@wanted_radar_turn, 60.0].min].max
    turn_radar turn_amt
    @wanted_radar_turn -= turn_amt
  end

  def approaching_wall?
    if not ( (velocity > 0) ^ heading.between?(0.0, 180.0) )
      y < 100
    else
      y > battlefield_height - 100
    end or if not ( (velocity > 0) ^ heading.between?(90.0, 270.0) )
      x < 100
    else
      x > battlefield_width - 100
    end
  end

end
