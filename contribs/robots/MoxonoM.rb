require 'robot'
class MoxonoM
  include Robot
  def initialize *bf
    if bf.size != 0
      super(bf[0])
      @tourney = false
    else
      super
      @tourney = true
    end
    @adjust_radar = true
    @turn_gun_range = (-5..5).to_a
    @turn_range     = (-10..10).to_a
    @lastchange = time
  end
 
  def rel_direction(from, to)
    rel = to -from
    if rel > 180 
      rel = -360 + rel
    end
    if rel < -180
      rel = 360 + rel
    end 
    return rel
  end 
 
  def a_rand(*args)
    args.flatten!
    return args[rand(args.size)]
  end
 
  def tick events
    @enemy = 0 unless @enemy
    @dist = 400 unless @dist
    @gun_head = nil unless @gun_head
    @adjust = nil unless @adjust
    if !@adjust
      turn_radar(-5)
      @adjust = true
    end
    @head = (@head||=90)
    @gun_head_to  = (@gun_head_to||=90)
    top    = y-size
    left   = x-size
    bottom = battlefield_height-size
    right  = battlefield_width-size
    istop = (top <= size)
    isleft = (left <= size)
    isbottom = (bottom <= (y+size))
    isright = (right <= (x+size))
    if (time-@lastchange >= 15 || !events['got_hit'].empty?)
      (isleft)   ? (@head = a_rand([270,90,0])) : nil
      (isbottom) ? (@head = a_rand([180,90,0])) : nil
      (isright)  ? (@head = a_rand([270,90,180]))  : nil
      (istop)    ? (@head = a_rand([270,180,0])) : nil
      (isleft && istop)     ? (@head = a_rand([315,270,0])) : nil
      (isleft && isbottom)  ? (@head = a_rand([45,90,0])) : nil
      (isright && istop)    ? (@head = a_rand([270,180,225])) : nil
      (isright && isbottom) ? (@head = a_rand([135,90,180])) : nil
      @lastchange = time
    end
    if !events['robot_scanned'].empty?
      @enemy = 5
      @dist = events['robot_scanned'].first.first
      @gun_head = gun_heading
      fire(3)
    end
    rel = rel_direction(heading, @head)
    (rel >= 5) ? (turn(rel*10);turn_gun(-(rel*10))) : turn(0)
    if gun_heat <= 0
      if @enemy >= 1
        (@dist <= 300) ? fire(3) : fire(3)
        gun_rel = rel_direction(gun_heading, @gun_head-5)
        (gun_rel >= 10) ? turn(gun_rel*rand(15)) : turn(0)
      else
        fire(0.5)
      end
    end
    turn_gun(-15) if @gun_head.nil?
    accelerate(1)
    @enemy = ((@enemy <= 0) ? (@ememy; @gun_head = nil) : (@enemy-1))
  end
end