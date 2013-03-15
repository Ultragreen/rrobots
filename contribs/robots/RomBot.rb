require 'robot'

# utilisation des matrices
require 'matrix'


module MathRobot

 def coef_dir(point_1,point_2)
   x1,y1 = point_1
   x2,y2 = point_2
   return (y2-y1)/(x2-x1)
 end

 def ordonne_origine(a,point)
   x,y = point
   return y - a*x
 end


 # calcule vectoriel pour déterminer l'angle de tir pour le prédicat fait avec la regression lineaire
 # en utilisant le coeficient directeur a de ma f(x) = ax + b trouvé

 # dfférence de deux vecteur
  def diff_vecteur(a,b)
    return a.zip(b).map{|a,b| a - b}
  end

  # Produit scalaire carré du vecteur
  def carre_scalaire_du_vecteur(a)
    return produit_scalaire(a,a)
  end

  # produit_scalaire
  def produit_scalaire(a,b)
    return a.zip(b).map{|a,b| a*b}.inject(0){|a,b| a+b}
  end


  # On Utilise un régression linéaire pour déterminer le coef dir à suivre f(x) = ax + b
  def reg_linaire(liste_x,liste_y)
    somme_des_produits = 0.0
    somme_des_x_au_carre = 0.0
    somme_des_x = 0.0
    somme_des_y = 0.0
    taille = liste_x.size
    # ma surcharge de Array va pas suffire
    somme_des_x = liste_x.sum
    somme_des_y = liste_y.sum
    taille.times {|i|
      somme_des_produits += liste_x[i]*liste_y[i]
      somme_des_x_au_carre += liste_x[i]*liste_x[i]
    }
    # calcule de a et b selon une regression linaire
    b = (taille*somme_des_produits - somme_des_x*somme_des_y) / (taille*somme_des_x_au_carre - somme_des_x*somme_des_x)
    a = (somme_des_y - b*somme_des_x) / taille

    raise ListeCoordTropPetite if a.nan? or b.nan? # on leve si a ou b tend vers - l'infini

    return [a,b]
  end

end



# Surcharge de Array pour calcule de Reg Lin
class Array
def sum
 sumit = 0
 self.each do |item|
   sumit += item
 end
 return sumit
end
def mean
 return self.sum / self.size
end
def max
 self.sort.last
end
def min
 self.sort.first
end
end


# surcharge de Float pour le round

class Float
 def round2(precision=2)
   return ("%01.#{precision}f" %self).to_f
 end
end


class RobotConfig



 # configuration du RomBot
 attr_reader :vitesse_max_robot
 attr_reader :calcul_taux_obux
 attr_reader :range_correcteur_linaire
 attr_reader :taux_de_tir_haut
 attr_reader :taux_de_tir_bas
 attr_reader :debug
 attr_reader :critere_crise
 attr_reader :mode_esquive
 attr_reader :mode_say
 attr_reader :critere_crise_vie_perte
 attr_reader :critere_crise_vie_duree
 attr_reader :cible_proche
 attr_reader :cible_loin

 def initialize
   @vitesse_max_robot = 7 # max 8 min 1
   @calcul_taux_obux = 30
   @range_correcteur_linaire = 2  # taille de la range de mon predicteur
   @taux_de_tir_haut = 0.1
   @taux_de_tir_bas = 2
   @debug = true
   @critere_crise = 10
   @mode_esquive = false
   @mode_say = true
   @critere_crise_vie_perte = 10
   @critere_crise_vie_duree = 10
   @cible_proche = 200
   @cible_loin = 1000
 end
end




class RomBot

include MathRobot
include Robot

def tick events
 config_initiale if time == 0
 maj_donnees_radar(events)
 maj_donnees_canon
 maj_context
 reglage_taux_de_tir
 detection_toolboxes(events)
 if situation_crise?(events) then
   @botlog.write "Situation de crise : #{@cumul_crise}\n" if @config.debug
   speed = 0 if @config.mode_esquive
   @taux_de_tir = @config.taux_de_tir_bas # Forçage de tir de puissance
 end
 accelerate 1
 @botlog.write "vitesse = #{speed}\n" if @config.debug
 say_msg if @config.mode_say
 turn_radar(decalage_radar - @vitesse_arme_relative - @vitesse_agulaire)
 turn_gun(@vitesse_arme_relative - @vitesse_agulaire)
 turn(@vitesse_agulaire )
 maj_vie_time
end


def detection_toolboxes(events)
  unless events['toolbox_scanned'].empty? then
    @botlog.write "scan toolbox #{events} pour time = #{time}\n" 

  end
end


def reglage_taux_de_tir
 unless @distance_cible_plus_proche.nil?
    dist = @distance_cible_plus_proche.to_i
 
    if dist > @config.cible_proche and dist < @config.cible_loin then
          @taux_de_tir = dist * @coef_dir_taux_de_tir + @ordonne_origine_taux_de_tir
          @taux_de_tir = @taux_de_tir.round2(1)
        elsif dist <= @config.cible_proche then
          @taux_de_tir = @config.taux_de_tir_haut
       elsif dist >= @config.cible_loin then
          @taux_de_tir = @config.taux_de_tir_bas
        end
 end
end


def maj_vie_time
  @botlog.write "energie = #{energy.to_i}\n" if @config.debug
  if time == @time_derniere + @config.critere_crise_vie_duree then
    if @check_vie_derniere - energy.to_i >=  @config.critere_crise_vie_perte then
      @cumul_crise += @config.critere_crise  unless (@cumul_crise > @config.critere_crise)
      @botlog.write "energie crise\n" if @config.debug
    end
    @check_vie_derniere = energy.to_i
    @time_derniere = time
  end
end


def situation_crise?(events)
 res = false
 # @botlog.write("scan cible x : #{@pos_cible_ennemi_x}\t y : #{@pos_cible_ennemi_y}\t pour time = #{time}\n")  if @config.debug
 unless events['got_hit'].empty? then
  @cumul_crise += events['got_hit'].size
 else
  @cumul_crise -= 1 if @cumul_crise > 0
 end
 res = true if @cumul_crise > @config.critere_crise
 return res
end


def say_msg
 chaine = String::new
 chaine << "X: #{x.to_i} "
 chaine << "Y: #{y.to_i}\n"
 chaine <<"DEBUG\n" if @config.debug
 chaine << "ESQUIVE\n" if @config.mode_esquive
 chaine << "Energy : #{energy.to_i}\n"
 chaine << "Critic #{@cumul_crise}"
 chaine << " !!" if @cumul_crise >  @config.critere_crise
 chaine << "\n"
 chaine << "Speed : #{speed}\n"
 chaine << "Fire rate : #{@taux_de_tir}\n"
 chaine << "Proxy : #{@distance_cible_plus_proche.to_i}" unless @distance_cible_plus_proche.nil?
 chaine << @msg
 say chaine
end



def mode_recherche
 @vitesse_base_radar = limiteur(@vitesse_base_radar + amplitude_angle_vers_cible_ennemi, 0, 60)

 if @cumul_ticks > 0
   @cumul_ticks -= 1
   if @cumul_ticks == 0
     @radar_direction *= -1
   end
 end
end

def debut_detection(dist)
 @contexte_prevision_time = beam_center
 @uptick_dist = dist
end

def cible_verrouille(dist)
 @uptick_dist = dist
end

def perte_cible
 @radar_direction *= -1
 @vitesse_base_radar = limiteur(@vitesse_base_radar * 0.5, amplitude_angle_vers_cible_ennemi, 60)
 marquage_cible_ennemi(angle_median(angle_median(@contexte_radar_precedant,@plus_vielle_detection_radar),@contexte_prevision_time),@uptick_dist)
 @cumul_ticks = 8
end

def beam_center
 angle_median(radar_heading, @contexte_radar_precedant)
end

def tirer_canon(propagation)
# je tire tout le temps même quand je suis pas en mode accrochage ou debut accrochage
#   if propagation < 1
   fire @taux_de_tir
#   end
end


def maj_donnees_radar(events)
 if events['robot_scanned'].empty?
   if @cible_scannee
     perte_cible
     @msg = "LOOSE"
     @botlog.write  "perte cible\n" if @config.debug
   else
     @msg = "SCAN"
      @botlog.write  "scan cible\n" if @config.debug
     mode_recherche
   end
   @cible_scannee = false
 else
   td = events['robot_scanned'].min.first
   @distance_cible_plus_proche = td
   if @cible_scannee
     @msg = "LOCK"
      @botlog.write  "cible locke\n" if @config.debug
     cible_verrouille(td)
   else
     @msg  = "SEEK"
      @botlog.write  "acquisition cible\n" if @config.debug
     debut_detection(td)
   end
   @cible_scannee = true
 end
 @plus_vielle_detection_radar = @contexte_radar_precedant
 @contexte_radar_precedant = radar_heading
end


def maj_donnees_canon
 diff = angle_direction(gun_heading, @detecteur.angle_de_tir(x,y,time))
 @vitesse_arme_relative = limiteur(diff,-30,30)
 tirer_canon(diff)
rescue ListeCoordTropPetite
end

def anti_collision_murs(range)
 (2**((battlefield_width - range)/50.0))/(2**(battlefield_width/50.0))
end

def maj_context
 ranges = [x-size, battlefield_height-size-y, battlefield_width-size-x, y-size]
 normals = [0, 90, 180, 270]
 forces = ranges.map {|r| anti_collision_murs(r)}

 @xforce = forces[0] - forces[2]
 @yforce = forces[3] - forces[1]
 fa = Math.atan2(-@yforce,@xforce).to_deg

 objectif = trajectoire_cible_ennemi + 90
 unless soustraction_angles(heading, objectif) < 90
   objectif = (objectif + 180) % 360
 end

 diff = angle_direction(objectif, fa)
 objectif += diff*(forces.max)
 @vitesse_agulaire = limiteur(angle_direction(heading, objectif),-10,10)
end


def config_initiale

 @config = RobotConfig.new

 # log file
 @botlog = File.open("Rombot.log","w")  if @config.debug
 @botlog.write "Démmarrage du RomBot\n"  if @config.debug
 @coef_dir_taux_de_tir = coef_dir([@config.cible_proche,@config.taux_de_tir_bas],[@config.cible_loin,@config.taux_de_tir_haut])
 @ordonne_origine_taux_de_tir = ordonne_origine( @coef_dir_taux_de_tir, [@config.cible_proche,@config.taux_de_tir_bas])
 @botlog.write "le taux de tir répond à : f(x) = #{@coef_dir_taux_de_tir}.x + #{@ordonne_origine_taux_de_tir}\n"  if @config.debug
 @msg = "INIT"
 @touche = false
 @vitesse_base_radar = 60
 @radar_direction = 1
 @contexte_radar_precedant = 0
 @plus_vielle_detection_radar = 0
 @cumul_ticks = 0
 @cumul_crise = 0
 @taux_de_tir = @config.taux_de_tir_haut
 @cible_scannee = false
 @contexte_prevision_time = 0
 @pos_cible_ennemi_x = @pos_cible_ennemi_y = 0
 @vitesse_arme_relative = 0
 @vitesse_agulaire = 0
 @detecteur = DetecteurPredictif.new
 @check_vie_derniere = 100
 @time_derniere = 0
 @distance_cible_plus_proche = 1800

 @botlog.write "Fin INIT \n"  if @config.debug
end

def soustraction_angles(a,b)
 d = (a % 360 - b % 360).abs
 d > 180 ? 360 - d : d
end

# définir le décalage positif ou negatif
def angle_direction(a,b)
 azimut = soustraction_angles(a,b)
 if soustraction_angles(a + 1, b) < azimut
   azimut
 else
   -azimut
 end
end

def decalage_radar
 @vitesse_base_radar * @radar_direction
end

def angle_median(a,b)
 (angle_direction(a,b) / 2 + a) % 360
end

def amplitude_angle_vers_cible_ennemi
 360 * @config.vitesse_max_robot / (2 * Math::PI * distance_cible_ennemi)
end

def trajectoire_cible_ennemi
 Math.atan2(y- @pos_cible_ennemi_y, @pos_cible_ennemi_x - x).to_deg
end

def distance_cible_ennemi
 Math.sqrt((@pos_cible_ennemi_x - x)**2 + (@pos_cible_ennemi_y - y)**2)
end

def marquage_cible_ennemi(trajectoire, distance)
 rads = trajectoire.to_rad
 @pos_cible_ennemi_y = y - distance * Math.sin(rads)
 @pos_cible_ennemi_x = x + distance * Math.cos(rads)
 @detecteur.marquage(@pos_cible_ennemi_x,@pos_cible_ennemi_y,time)
 @botlog.write("scan cible x : #{@pos_cible_ennemi_x}\t y : #{@pos_cible_ennemi_y}\t pour time = #{time}\n")  if @config.debug

end

def limiteur(var, min, max)
 val = 0 + var
 if val > max
   max
 elsif val < min
   min
 else
   val
 end
end

end

# classe d'exception pour les moindres carrés
class ListeCoordTropPetite < RuntimeError; end


class DetecteurPredictif


 include MathRobot

def initialize(taille = 4)
 @config = RobotConfig.new
 @taille = taille || @config.range_correcteur_linaire
 @x = Array.new(@taille,0)
 @y = Array.new(@taille,0)
 @t = Array.new(@taille,0)
 @most_recent = 0
 @solution = nil
end



def resoud
 coef_dir_x, vx = reg_linaire(@t, @x)
 coef_dir_y, vy = reg_linaire(@t, @y)
 return [vx,vy,coef_dir_x,coef_dir_y]
end

# predits la position de la cible pour un time donné
def predit(time)
 raise ListeCoordTropPetite unless @solution
 vx, vy, coef_dir_x, coef_dir_y = @solution
 [coef_dir_x + vx*time, coef_dir_y + vy*time]
end


def marquage(x,y,time)
 @most_recent = (@most_recent + 1) % @taille
 @x[@most_recent] = x
 @y[@most_recent] = y
 @t[@most_recent] = time
 @solution = resoud
rescue
end



def point_cible(mon_x, mon_y, time)
 raise ListeCoordTropPetite unless @solution
 t = 0
 loop do
   x,y = predit(time+t) # on se base sur le dernier prédicat fiable
   break if carre_scalaire_du_vecteur(diff_vecteur([x,y],[mon_x,mon_y])) < @config.calcul_taux_obux*@config.calcul_taux_obux*t*t
   t += 1
   raise ListeCoordTropPetite if t > 100
 end
 predit(time+t)
end

# calcule e fonction des coordonné du point cible de l'angle de tir via l'Arctangente du vecteur entre source tank et cible
def angle_de_tir(mon_x,mon_y,time)
 x,y = point_cible(mon_x,mon_y,time)
 Math.atan2(mon_y-y,x-mon_x).to_deg
end


# On Utilise un régression linéaire pour déterminer le coef dir à suivre f(x) = ax + b
def reg_linaire(liste_x,liste_y)
 somme_des_produits = 0.0
 somme_des_x_au_carre = 0.0
 somme_des_x = 0.0
 somme_des_y = 0.0
 taille = liste_x.size
 # ma surcharge de Array va pas suffire
 somme_des_x = liste_x.sum
 somme_des_y = liste_y.sum
 taille.times {|i|
   somme_des_produits += liste_x[i]*liste_y[i]
   somme_des_x_au_carre += liste_x[i]*liste_x[i]
 }
 # calcule de a et b selon une regression linaire
 b = (taille*somme_des_produits - somme_des_x*somme_des_y) / (taille*somme_des_x_au_carre - somme_des_x*somme_des_x)
 a = (somme_des_y - b*somme_des_x) / taille

 raise ListeCoordTropPetite if a.nan? or b.nan? # on leve si a ou b tend vers - l'infini

 return [a,b]
end



end


