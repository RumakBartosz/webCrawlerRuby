require 'mechanize'
require 'dbi'
require 'resolv'
require 'socket'
require 'net/http'
require 'uri'

url = ARGV[0].to_s
arg1 = ARGV[4].to_i
arg2 = ARGV[5].to_i

dbi_name = ARGV[1].to_s
dbi_user = ARGV[2].to_s
dbi_pass = ARGV[3].to_s

agent = Mechanize.new
page = agent.get(url)

agent_deep = Mechanize.new

link_helper = []

dbh = DBI.connect('DBI:Mysql:' + dbi_name + ':localhost', dbi_user, dbi_pass)
sth = dbh.prepare('INSERT INTO site(domena, ip, polaczenie) VALUES (?, ?, ?)')

def host_check(url, url2)
  uri = URI.parse(url)
  return true if uri.route_to(url2).host.nil?
  false
end

begin
  page.links.take(arg1).each do |link|
    "
    Pierwszy poziom przeszukiwania, w tym momencie wypełnianie zerami wartości ip
    z response servera.
    "
    begin
      unless URI.parse(page.uri.to_s).host != URI.parse(link.uri.to_s).host
        puts link.uri.to_s + 'same domain lvl 1'
        next
      end
      next if URI.parse(link.uri.to_s).host.nil?
      puts
      puts link.text
      puts page.uri.merge link.uri


      ip = URI.parse(link.uri.to_s).host
      address = Resolv.getaddress ip unless URI.parse(link.uri.to_s).host.nil?
      link_helper.push(address)
      sth.execute(ARGV[0], '0', link.href)
    rescue NoMethodError => e
      print "#{e} in #{link.href}"
      next
    rescue StandardError => e
      print "#{e} in #{link.href}"
      next
    end
  end
rescue StandardError => e
  print "#{e} in #{link.href}"
end

empty_ip = dbh.prepare('SELECT * FROM site WHERE ip = 0')
empty_ip.execute


i = 0
begin
  empty_ip.each do |element|
    "
    Drugi poziom, wymiana zer na response z ip, dla każdego podmienienia
    głębsze szukanie.
    "
    begin
      update = dbh.prepare('UPDATE site SET ip = ? WHERE polaczenie = ?')
      update.execute(link_helper[i], element[2])

      page_deep = agent_deep.get(element[2].to_s)


      page_deep.links.take(arg2).each do |link|
        "
        Wewnętrzna pętla o podobnym działaniu do pierwszego links.take(arg1).
        Wrzucenie linków jeżeli istnieją w różnej domenie.
        "
        begin
          unless URI.parse(page_deep.uri.to_s).host !=
                 URI.parse(link.uri.to_s).host
            puts link.uri.to_s + 'same domain lvl 2'
            next
          end
          next if URI.parse(link.uri.to_s).host.nil?

          puts
          puts link.text
          puts page.uri.merge link.uri

          ip_deep = URI.parse(link.uri.to_s).host
          unless URI.parse(link.uri.to_s).host.nil?
            address_deep = Resolv.getaddress ip_deep
          end
          sth.execute(page_deep.uri, address_deep, link.href)
          page_deep = agent_deep.get(link.uri)
        rescue Mechanize::ResponseCodeError => e
          puts "#{e} for #{link.uri}"
          sth.rollback
          next
        rescue Resolv::ResolvError => e
          puts "#{e} for #{link.uri}"
          sth.rollback
          next
        rescue StandardError => e
          puts "#{e} for #{element[2]}"
          sth.rollback
          next
        end
      end
    rescue Mechanize::ResponseCodeError => e
      puts "#{e} for #{element[2]}"
      next
    rescue Mechanize::ResponseCodeError => e
      puts "#{e} for #{element[2]}"
      next
    rescue NameError => e
      puts "#{e} for #{element[2]}"
      next
    rescue StandardError => e
      puts "#{e} for #{element[2]}"
      next
    end
    i += 1
  end
rescue StandardError => e
  puts "#{e} for db"

end

sth.finish
dbh.commit