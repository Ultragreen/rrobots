require 'robot'
class Polisher
include Robot
  def tick events
    @min_distance = (events['robot_scanned'].min || [0]).first
    @radar_scan ||= 20.0
    @mid ||= (((x - battlefield_width / 2).abs < 400) and ((y - battlefield_height / 2).abs < 400))
    accelerate(@mid ? (Math.sin(time*0.1)*2)+0.8 : 1.0)
    turn(@mid ? 10 : 2)
    @radar_scan = events['robot_scanned'].empty? ? [40.0,@radar_scan*1.5].min : [15.0,@radar_scan*0.5].max
    @rt = (@radar_scan > 39.0) ? @radar_scan : @radar_scan*((time % 2)-0.5)
    turn_gun @rt - (@mid ? 10 : 2)
    fire 3
  end
end