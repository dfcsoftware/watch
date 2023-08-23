#!/usr/bin/perl
# doncohoon.com:80 46.229.168.68 - - [29/Mar/2018:07:36:35 -0400] "GET /mythweb/tv/channel/1052/1517563800 HTTP/1.1" 200 6156 "-" "Mozilla/5.0 (compatible; SemrushBot/1.2~bl; +http://www.semrush.com/bot.html)"
while (<>) {
  if(/"GET.*HTTP/) {
    @array = split(/ /);
    print("$array[0] - $array[1] "); # 0=nginx, 1=apache2
    if ($array[6] =~ "GET") {
      print("$array[7]\n");
    } else {
      print("$array[6]\n");
    }
  }
}
