require 'tk'
require 'base64'

def load_gui(battlefield, xres, yres, speed_multiplier)
  arena = GUI::TkArena.new(battlefield, xres, yres, speed_multiplier)
  game_over_counter = battlefield.teams.all?{|k,t| t.size < 2} ? 250 : 500
  outcome_printed = false
  arena.on_game_over{|battlefield|
    unless outcome_printed
      print_outcome(battlefield)
      outcome_printed = true
    end
    exit 0 if game_over_counter < 0
    game_over_counter -= 1
  }
  arena.run
end

module GUI
  

  
  TkRobot = Struct.new(:body, :gun, :radar, :speech, :info, :status)

  class TkArena
    

    attr_reader :engine
    attr_reader :battlefield, :xres, :yres
    attr_accessor :speed_multiplier, :on_game_over_handlers
    attr_accessor :canvas, :boom, :robots, :bullets, :explosions, :colors, :toolboxes, :toolbox_img, :mines, :mine_img
    attr_accessor :default_skin_prefix, :path_prefix

    def initialize battlefield, xres, yres, speed_multiplier
      @engine = 'tk'
      @battlefield = battlefield
      @xres, @yres = xres, yres
      @speed_multiplier = speed_multiplier
      @text_colors = ['#ff0000', '#00ff00', '#0000ff', '#ffff00', '#00ffff', '#ff00ff', '#ffffff', '#777777']
      @path_prefix = "#{gem_path}/medias/#{@engine}"
      @default_skin_prefix = "images/red_"
      @on_game_over_handlers = []
      init_canvas
      init_simulation
    end

    def on_game_over(&block)
      @on_game_over_handlers << block
    end

    def read_gif name, c1, c2, c3
      data = nil
      open(name, 'rb') do |f|
        data = f.read()
        ncolors = 2**(1 + data[10][0] + data[10][1] * 2 + data[10][2] * 4)
        ncolors.times do |j|
          data[13 + j * 3 + 0], data[13 + j * 3 + 1], data[13 + j * 3 + 2] =
          data[13 + j * 3 + c1], data[13 + j * 3 + c2], data[13 + j * 3 + c3]
        end
      end
      TkPhotoImage.new(:data => Base64.encode64(data))
    end

    def init_canvas
      @canvas = TkCanvas.new(:height=>yres, :width=>xres, :scrollregion=>[0, 0, xres, yres], :background => '#000000').pack
      @colors = []
      [[0,1,1],[1,0,1],[1,1,0],[0,0,1],[1,0,0],[0,1,0],[0,0,0],[1,1,1]][0...@battlefield.robots.length].zip(@battlefield.robots) do |color, robot|
        bodies, guns, radars = [], [], []
        image_path = robot.skin_prefix || @default_skin_prefix
        image_path = "#{@path_prefix}/#{image_path}"
        reader = robot.skin_prefix ? lambda{|fn| TkPhotoImage.new(:file => fn) } : lambda{|fn| read_gif(fn, *color)}
        36.times do |i|
          bodies << reader["#{image_path}body#{(i*10).to_s.rjust(3, '0')}.gif"]
          guns << reader["#{image_path}turret#{(i*10).to_s.rjust(3, '0')}.gif"]
          radars << reader["#{image_path}radar#{(i*10).to_s.rjust(3, '0')}.gif"]
        end
        @colors << GUI::TkRobot.new(bodies << bodies[0], guns << guns[0], radars << radars[0])
      end

      @boom = (0..14).map do |i|
        TkPhotoImage.new(:file => "#{path_prefix}/images/explosion#{i.to_s.rjust(2, '0')}.gif")
      end
      @toolbox_img = TkPhotoImage.new(:file => "#{path_prefix}/images/toolbox.gif")
      @mine_img = TkPhotoImage.new(:file => "#{path_prefix}/images/mine.gif")
    end

    def init_simulation
      @robots, @bullets, @explosions, @toolboxes, @mines = {}, {}, {}, {}, {}
      TkTimer.new(20, -1, Proc.new{
        begin
          draw_frame
        rescue => err
          puts err.class, err, err.backtrace
          raise
        end
        }).start
      end

      def draw_frame
        simulate(@speed_multiplier)
        draw_battlefield
      end

      def simulate(ticks=1)
        @explosions.reject!{|e,tko| @canvas.delete(tko) if e.dead; e.dead }
        @bullets.reject!{|b,tko| @canvas.delete(tko) if b.dead; b.dead }
        @toolboxes.reject!{|t,tko| @canvas.delete(tko) if t.dead; t.dead }
        @mines.reject!{|m,tko| @canvas.delete(tko) if m.dead; m.dead }
        @robots.reject! do |ai,tko|
          if ai.dead
            tko.status.configure(:text => I18n.t('gui.ai_name_dead', :ai_name => ai.name.ljust(20)))
            tko.each{|part| @canvas.delete(part) if part != tko.status}
            true
          end
        end
        ticks.times do
          if @battlefield.game_over
            @on_game_over_handlers.each{|h| h.call(@battlefield) }
            unless @game_over
              winner = @robots.keys.first
              whohaswon = if winner.nil?
                I18n.t('gui.draw')
              elsif @battlefield.teams.all?{|k,t|t.size<2}
                I18n.t('gui.no_team_won', :winner_name => winner.name)
              else
                I18n.t('gui.team_won', :winner_team => winner.team)
              end
              text_color = winner ? winner.team : 7
              @game_over = TkcText.new(canvas,
              :fill => @text_colors[text_color],
              :anchor => 'c', :coords => [400,400], :font=>'courier 36', :justify => 'center',
              :text => I18n.t('gui.game_over').concat("\n#{whohaswon}"))
            end
          end
          @battlefield.tick
        end
      end

      def draw_battlefield
        draw_toolboxes
        draw_mines
        draw_robots
        draw_bullets
        draw_explosions
      end

      def draw_robots
        @battlefield.robots.each_with_index do |ai, i|
          next if ai.dead
          @robots[ai] ||= GUI::TkRobot.new(
          TkcImage.new(@canvas, 0, 0),
          TkcImage.new(@canvas, 0, 0),
          TkcImage.new(@canvas, 0, 0),
          TkcText.new(@canvas,
          :fill => @text_colors[ai.team],
          :anchor => 's', :justify => 'center', :coords => [ai.x / 2, ai.y / 2 - ai.size / 2]),
          TkcText.new(@canvas,
          :fill => @text_colors[ai.team],
          :anchor => 'n', :justify => 'center', :coords => [ai.x / 2, ai.y / 2 + ai.size / 2]),
          TkcText.new(@canvas,
          :fill => @text_colors[ai.team],
          :anchor => 'nw', :coords => [10, 15 * i + 10], :font => TkFont.new("courier 9")))
          @robots[ai].body.configure( :image => @colors[ai.team].body[(ai.heading+5) / 10],
          :coords => [ai.x / 2, ai.y / 2])
          @robots[ai].gun.configure(  :image => @colors[ai.team].gun[(ai.gun_heading+5) / 10],
          :coords => [ai.x / 2, ai.y / 2])
          @robots[ai].radar.configure(:image => @colors[ai.team].radar[(ai.radar_heading+5) / 10],
          :coords => [ai.x / 2, ai.y / 2])
          @robots[ai].speech.configure(:text => "#{ai.speech}",
          :coords => [ai.x / 2, ai.y / 2 - ai.size / 2])
          @robots[ai].info.configure(:text => "#{ai.name}\n#{'|' * (ai.energy / 5)}",
          :coords => [ai.x / 2, ai.y / 2 + ai.size / 2])
          @robots[ai].status.configure(:text => "#{ai.name.ljust(20)} #{'%.1f' % ai.energy}")
        end
      end

      def draw_bullets
        @battlefield.bullets.each do |bullet|
          @bullets[bullet] ||= TkcOval.new(
          @canvas, [-2, -2], [3, 3],
          :fill=>'#'+("%02x" % (128+bullet.energy*14).to_i)*3)
          @bullets[bullet].coords(
          bullet.x / 2 - 2, bullet.y / 2 - 2,
          bullet.x / 2 + 3, bullet.y / 2 + 3)
        end
      end

      def draw_mines
        @battlefield.mines.each do |mine|
          @mines[mine] ||= TkcImage.new(@canvas, mine.x / 2, mine.y / 2)
          @mines[mine].image(mine_img)
        end
      end

      def draw_explosions
        @battlefield.explosions.each do |explosion|
          @explosions[explosion] ||= TkcImage.new(@canvas, explosion.x / 2, explosion.y / 2)
          @explosions[explosion].image(boom[explosion.t])
        end
      end

      def draw_toolboxes
        @battlefield.toolboxes.each do |toolbox|
          @toolboxes[toolbox] ||= TkcImage.new(@canvas, toolbox.x / 2, toolbox.y / 2)
          @toolboxes[toolbox].image(toolbox_img)
        end
      end

      def run
        Tk.mainloop
      end

    end

  end