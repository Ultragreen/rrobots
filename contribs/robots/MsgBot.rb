require 'robot'

class MsgBot
include Robot

  def tick events
    priv = true
    unless priv then 
      events['broadcasts'].each{|msg,dir|
        say "Got message #{msg.inspect} from #{dir}!"
      }
      broadcast "Hello! Team #{team}!" if rand < 0.01
    else
      events['team_broadcasts'].each{|msg,dir|
        say "Got priv message #{msg.inspect} from #{dir}!"
      }
      team_broadcast "Hello! Team #{team}!" if rand < 0.01
    end
  end

end
