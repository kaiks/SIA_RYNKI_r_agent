SIA_RYNKI_r_agent
=================

Agent do serwera giełdowego na sia2013

###How to:

1. zainstaluj jruby - http://www.jruby.org/download

2. jruby -S gem install probability


na razie to chyba tyle

poczatki opisu:

* klient_szef to przykladowy agent:
wystawia zlecenia kupna i sprzedazy na kazdy z instrumentow po cenie (pol)aktualnej rzeczywistej

* klient_konserwatysta (nazwa jest troche bez sensu, tyczy sie tego, ze sie trzyma swoich akcji):
kupuje i sprzedaje po mniej lub bardziej losowej cenie
odpalac z parametrami, np.:
run_file klient_konserwatysta.rb 2 100

gdzie 2 to poczatkowy id uz a 100 to ilosc

* klient_spokojny.rb:
losuje sobie oczekiwany zysk na kupno i sprzedaz w odniesieniu do poczatkowej (ktora widzi) ceny rynkowej i zawsze kupuje/sprzedaje po tej cenie