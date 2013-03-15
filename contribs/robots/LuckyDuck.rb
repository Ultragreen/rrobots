require 'robot'
class LuckyDuck
	include Robot
	def initialize *bf
    if bf.size != 0
      super(bf[0])
      @tourney = false
    else
      super
      @tourney = true
    end
		@lastchange = time
		@dc = []
		@dc[300] = 3
		@dc[300] = 3
		@dc[300] = 3
		@dc[300] = 3
		@dc[300] = 3
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
		@head = (@head||=90)
		@gun_head_to  = (@gun_head_to||=90)
		istop = (y-size <= size*2)
		isleft = (x-size <= size*2)
		isbottom = (battlefield_height-size <= (y+size))
		isright = (battlefield_width-size <= (x+size))
		if (time-@lastchange >= 5 || !events['got_hit'].empty?)
			(isleft)   ? (@head = a_rand([270,90])) : nil
			(isbottom) ? (@head = a_rand([180,0])) : nil
			(isright)  ? (@head = a_rand([270,90]))  : nil
			(istop)    ? (@head = a_rand([180,0])) : nil
			(isleft && istop)     ? (@head = a_rand([270,0])) : nil
			(isleft && isbottom)  ? (@head = a_rand([90,0])) : nil
			(isright && istop)    ? (@head = a_rand([270,180])) : nil
			(isright && isbottom) ? (@head = a_rand([90,180])) : nil
			@lastchange = time
		end
		if !events['robot_scanned'].empty?
			@enemy = 10
			@dist = events['robot_scanned'].first.first
			@gun_head = gun_heading
		end
		rel = rel_direction(heading, @head)
		(rel >= 5) ? (turn(rel*10);turn_gun(-(rel*10))) : turn(0)
		if gun_heat <= 0
			if @enemy >= 1
				offset = (gun_heading+(@dist/200).to_i).abs
				gun_rel = rel_direction(gun_heading, @gun_head)
				puts "[#{gun_rel} | #{@gun_head} ~~ #{gun_heading} (#{offset})"
				#(gun_rel != 0) ? turn_gun(gun_rel) : turn_gun(+2)
				turn_gun(gun_rel/2)
				
				(@dist <= 600) ? fire(3) : fire(0.1)*30
			end
		end
		turn_gun(-10) if @gun_head.nil?
		accelerate(1)
		@enemy = ((@enemy <= 0) ? (@ememy; @gun_head = nil) : (@enemy-1))
		if @enemy == 1
			turn_gun(15)
		end
	end
end