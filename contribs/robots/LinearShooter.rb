require 'robot'
require 'matrix'


class Numeric

  def deg2rad
    self * 0.0174532925199433
  end

  def rad2deg
    self * 57.2957795130823
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

class Vector
include Enumerable

  def each &block
    @elements.each(&block)
  end

end


class LinearShooter
include Robot

  def initialize *args, &block
    super
    @rt = @radar_scan = 15
    @min_radar_scan = 1.5
    @max_radar_scan = 60.0
    @radar_turned = false
    @lock = false
    @lock_threshold = 15.0
    @firing_threshold = 20.0
    @wanted_turn = @wanted_gun_turn = @wanted_radar_turn = 0
    @rturn_dir = 1
    @racc_dir = 1
    @serial_hit_limit = 10
    @serial_hit_counter = 0
    @target_positions = []
    @min_distance = 1500 
    @sd_limit = 30
  end

  def tick events
    @prev_health = energy if time == 0
    scan events
    firing_solution events
    navigate events
    turn_hull
    turn_turret
    turn_radar_dish
    @prev_health = energy
  end

  def scan events
    if events['robot_scanned'].empty?
      increase_radar_scan
      @lock = false
    else
      decrease_radar_scan
      @lock = @radar_scan.abs < @lock_threshold
    end
    @rt = (time/2 % 2 < 1 ? -@radar_scan/2.0 : @radar_scan/2.0) if @radar_scan.abs < @max_radar_scan - 0.1
    @wanted_radar_turn += @rt
  end

  def firing_solution events
    add_target_position(events['robot_scanned'])
    th = target_heading
    gtd = heading_distance(gun_heading, th) if th
    @firepower = [1.5e5 / (@min_distance)**2, 3*25 / (@vsd||1500)].max / 2.0
    msg = "Hope this hits.."
    msg = "On target." if @firepower > 1.5
    msg = "Takedown!" if @firepower > 2.25
    msg = "SURE HIT!" if @firepower > 3.0
    say msg if @on_target and gun_heat == 0
    fire @firepower if @on_target
    if @lock and gtd and gtd.abs < @firing_threshold
      @wanted_gun_turn = gtd
      @on_target = true
    else
      #fire @firepower*0.3
      @wanted_gun_turn = gtd || (gun_radar_distance/3.0) + Math.sin(time*0.2)*(1000.0/@min_distance)
      @on_target = false
    end
  end

  def add_target_position(distances)
    unless distances.empty?
      positions = distances.map{|d|
        tx = x + Math.cos((radar_heading - @radar_scan.abs / 2.0).deg2rad) * d[0]
        ty = y - Math.sin((radar_heading - @radar_scan.abs / 2.0).deg2rad) * d[0]
        [d, Vector[tx,ty]]
      }
      last = @target_positions.last
      position = if last
        positions.min{|a,b| (a[1] - last).r <=> (b[1] - last).r }[1]
      else
        positions.min{|a,b| a[0] <=> b[0]}[1]
      end
      @min_distance = distances.min{|a,b| a[0]<=>b[0]}[0]
      @target_positions.push position if position
    end
    @target_positions.shift if @target_positions.size > 200
  end

  def average_last_positions(c=4)
    tps = @target_positions[-10,10]
    d = tps.size/c
    ptas = (0...c).map{|i| tps[i*d,d] }
    ptas.map{|pta| average(pta) }
  end

  def average arr
    arr.inject{|s,i| s+i} * (1.0/arr.size)
  end

  def sd arr
    Math.sqrt(arr.map{|v| v[0]}.sd**2 + arr.map{|v| v[1]}.sd**2)
  end

  def deltas arr
    arr[0..-2].zip(arr[1..-1]).map{|a,b| b - a}
  end

  def target_heading
    return nil if @target_positions.size < 10
    return radar_heading if @min_distance < 200
    lps = average_last_positions(5)
    p4 = lps.last
    vs = deltas(lps).map{|v| v * 0.5 }
    @vsd = sd vs
    return nil if @vsd > @sd_limit
    v = average(vs)
    if v.r < 4.0
      #say 'Stationary targeting'
      return heading_for(average(lps))
    end
    p4 = p4 + (v*0.5)
    distance = p4 - Vector[x,y]
    shot_speed = (30/8.0)*v.r
    a = distance[0]**2 + distance[1]**2
    b = 2*distance[0]*v[0] + 2*distance[1]*v[1]
    c = v[0]**2 + v[1]**2 - shot_speed**2
    t = 2*a / (-b + Math.sqrt(b**2-4*a*c))
    ep = p4 + v*t
    estimated_position = Vector[[size, [battlefield_width-size, ep[0]].min].max, [size, [battlefield_height-size, ep[1]].min].max]
    est_head = heading_for(estimated_position)
    #say 'Linear targeting'
    est_head + (rand-0.5)*@vsd*0.2
  end
  
  def format(arr, precision = 1)
    case arr
    when Float
      (arr * 10**precision).round * 10**-precision
    when Array
      arr.map{|i| format i, precision}
    else
      arr
    end
  end

  def gun_vector
    Vector[Math.cos(gun_heading.deg2rad), -Math.sin(gun_heading.deg2rad)]
  end

  def heading_for(position)
    distance = position - Vector[x,y]
    heading = (Math.atan2(-distance[1], distance[0])).rad2deg
    heading += 360 if heading < 0
    heading
  end

  def navigate events
    if events['got_hit'].empty?
      @serial_hit_counter -= 0.05 if @serial_hit_counter > 0
      accelerate(@racc_dir) if velocity.abs < 7.9
    else
      @serial_hit_counter += @prev_health - events['got_hit'].last.last
      @serial_hit_counter = [@serial_hit_counter, @serial_hit_limit + 0.04].max
      if @serial_hit_counter > @serial_hit_limit
        acc = velocity > 0 ? 1 : -1
        accelerate(acc) if velocity.abs < 7.9
      end
    end
    if @serial_hit_counter > @serial_hit_limit and not events['got_hit'].empty? and @wanted_turn <= 1
      @wanted_turn = @rturn_dir * 30
      @rturn_dir *= -1 if rand < 0.05
    elsif approaching_wall? and @wanted_turn <= 1
      @wanted_turn = 60 * @rturn_dir
      @rturn_dir *= -1 if rand < 0.5
    elsif rand < 0.15
      @wanted_turn += rand * 10 * @rturn_dir
    elsif rand < 0.01
      @rturn_dir *= -1
    elsif rand < 0.01
      @racc_dir *= -1
    end
  end

  def increase_radar_scan
    @radar_scan *= 1.5
    @radar_scan = [@radar_scan, @max_radar_scan].min
  end

  def decrease_radar_scan
    @radar_scan *= 0.6
    @radar_scan = [@radar_scan, @min_radar_scan].max
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
    #puts "Turning hull by: #{turn_amt}" if turn_amt.abs > 1
    turn turn_amt
    @wanted_turn -= turn_amt
    @wanted_gun_turn -= turn_amt
    @wanted_radar_turn -= turn_amt
  end

  def turn_turret
    turn_amt = [-30.0, [@wanted_gun_turn, 30.0].min].max
    #puts "Turning gun by: #{turn_amt}" if turn_amt.abs > 1
    turn_gun turn_amt
    @wanted_gun_turn -= turn_amt
    @wanted_radar_turn -= turn_amt
  end

  def turn_radar_dish
    turn_amt = [-60.0, [@wanted_radar_turn, 60.0].min].max
    #puts "Turning radar by: #{turn_amt}" if turn_amt.abs > 1
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
