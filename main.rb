#!/usr/bin/env ruby
require 'net/http'
require 'nkf'
require 'rubygems'
require 'uri'
require 'arduino_firmata'
require 'term/ansicolor'
include Term::ANSIColor


arduino = ArduinoFirmata.connect ARGV.shift
pin_num = 11 #Green
pin_num = 10 #Blue
pin_num = 9  #Red

puts "ArduinoFirmata Connect!!"
sleep 1 #演出 ちょっと遅れるとかっこいい

w = 0
day = 0
#気象庁のアメダスのデータ（1時間ごと更新）
#http://www.jma.go.jp/jp/amedas_h/today-46106.html
Net::HTTP.start('www.jma.go.jp',80){|http|
  response = http.get("/jp/amedas_h/today-46106.html")
    day = Time.now
    t = day.hour
    #0時->24時に
    if t == 0
      t = 24
    end
    #毎時00分ちょうどではなく10分くらいに更新がある
    if day.min < 10
      if t == 1
        t = 24
      else
        t = t - 1
      end
    end
    w = response.body.to_s
    w = w.scan(/<tr>\n\t\t\t\t\t\t\t\t<td class="time left">#{t}<\/td>\n\t\t\t\t\t\t\t\t<td class="block middle">(.+?)<\/td><td class="block middle">(.+?)<\/td><td class="block middle">(.+?)<\/td><td class="block middle">(.+?)<\/td><td class="block middle">(.+?)<\/td><td class="block middle">(.+?)<\/td><td class="block middle">(.+?)<\/td>/)
    w = w[0]
    w.delete_at(2)
    w.delete_at(3)
    #w = w.to_f
    puts "アメダスのデータ"
    sleep 0.75 #演出 ちょっと遅れるとかっこいい
    puts "現在時刻: #{t} 時"
    puts "気温: #{w[0]} ℃"
    puts "降水量: #{w[1]} mm"
    puts "風速: #{w[2]} m/s"
    puts "湿度: #{w[3]} %"
    puts "気圧: #{w[4]} hPa"
    puts
}

#気象データを変数に格納
kion = w[0].to_f
ame = w[1].to_f
kaze = w[2].to_f
shitsu = w[3].to_i
#kiatsu = w[4].to_f

sleep 0.5 #演出

#部屋の気温
lm35 = arduino.analog_read(0)*100*5/1024
puts "部屋の気温: #{lm35} ℃"

#部屋の明るさ
cds = arduino.analog_read(1)
puts "部屋の明るさ: #{cds}"

#不快指数
di = 0.81 * lm35 + 0.01 * shitsu * (0.99 * kion - 14.3) + 46.3
di = di.to_i
puts "不快指数: #{di}"
puts

sleep 1 #演出

#気温
#部屋の気温と外気温を比較する
#暑い->赤 やや暑い->桃 白->同じ やや寒い->水 寒い->青
if kion > lm35 + 5
  kg = 0
  kb = 0
  kr = 3
  print "気温の色: "
  print red,"赤"+"\n"
  print reset
elsif kion > lm35 + 2
  kg = 1
  kb = 1
  kr = 3
  print "気温の色: "
  print magenta,"桃"+"\n"
  print reset
elsif kion > lm35 - 2
  kg = 3
  kb = 3
  kr = 3
  print "気温の色: "
  print white,"白"+"\n"
  print reset
elsif kion > lm35 - 8
  kg = 1
  kb = 3
  kr = 1
  print "気温の色: "
  print cyan,"水"+"\n"
  print reset
else
  kg = 0
  kb = 3
  kr = 0
  print "気温の色: "
  print blue,"青"+"\n"
  print reset
end

#湿度
#不快指数 = 0.81*温度+0.01*湿度(0.99*温度-14.3)+46.3
#di>=80 -> 不快  di>=75 -> やや不快  di<75 -> 快適  di<60 ->乾燥
#不快->緑 やや不快->薄緑 快適->白 乾燥->黃
dg = 3
if di >= 80
  db = 0
  dr = 0
  print "湿度の色: "
  print green,"緑"+"\n"
  print reset
elsif di > 70
  db = 1
  dr = 1
  print "湿度の色: "
  print green,"薄緑"+"\n"
  print reset
elsif di > 60
  db = 3
  dr = 3
  print "湿度の色: "
  print white,"白"+"\n"
  print reset
else
  db = 0
  dr = 3
  print "湿度の色: "
  print yellow,"黃"+"\n"
  print reset
end

#降水量
#5mm以上->青 1mm以上->水色 0mm->白
rb = 3
if ame >= 5.0
  rg = 0
  rr = 0
  print "降水の色: "
  print blue,"青"+"\n"
  print reset
elsif ame > 0.0
  rg = 1
  rr = 1
  print "降水の色: "
  print cyan,"水"+"\n"
  print reset
else
  rg = 3
  rr = 3
  print "降水の色: "
  print white,"白"+"\n"
  print reset
end

#点滅間隔
#LEDの色の変化の速さ
#強いほどsleepが短い
if kaze >= 10
  slp = 0.01
else
  slp = (10-kaze)/150
  slp = slp.round(3)
  pslp = slp*255
  pslp = pslp.round(1)
  puts "点滅間隔: #{pslp} 秒"
end

#Arduinoで実行されるloop
loop do
  g_led = 0
  b_led = 0
  r_led = 0

  #気温
  while r_led>=255 || b_led<255
    g_led += kg
    b_led += kb
    r_led += kr
    arduino.analog_write(11,g_led)
    arduino.analog_write(10,b_led)
    arduino.analog_write(9,r_led)
    sleep slp
    if r_led==255 || b_led==255
      break
    end
  end
  sleep 0.5
  while r_led>0 || b_led>0
    g_led -= kg
    b_led -= kb
    r_led -= kr
    arduino.analog_write(11,g_led)
    arduino.analog_write(10,b_led)
    arduino.analog_write(9,r_led)
    sleep slp
  end
  sleep 0.1

  #湿度
  while g_led<255
    g_led += dg
    b_led += db
    r_led += dr
    arduino.analog_write(11,g_led)
    arduino.analog_write(10,b_led)
    arduino.analog_write(9,r_led)
    sleep slp
  end
  sleep 0.5
  while g_led>0
    g_led -= dg
    b_led -= db
    r_led -= dr
    arduino.analog_write(11,g_led)
    arduino.analog_write(10,b_led)
    arduino.analog_write(9,r_led)
    sleep slp
  end
  sleep 0.1

  #降水量
  while b_led<255
    g_led += rg
    b_led += rb
    r_led += rr
    arduino.analog_write(11,g_led)
    arduino.analog_write(10,b_led)
    arduino.analog_write(9,r_led)
    sleep slp
  end
  sleep 0.5
  while b_led>0
    g_led -= rg
    b_led -= rb
    r_led -= rr
    arduino.analog_write(11,g_led)
    arduino.analog_write(10,b_led)
    arduino.analog_write(9,r_led)
    sleep slp
  end
  sleep 1.0
end
