################################################################################
####################
####################			HOWTO
####################
################################################################################

1) PARAMETRY

	Wszystkie parametry (wraz z opisem) bior�ce udzia� w losowaniu wsp�czynnik�w reguluj�cych zachowanie agenta 
	znajduj� si� w pliku GLOBALS.rb.

2) URUCHAMIANIE
	
	Odpalenie run_single.bat <liczba agentow> skutkuje procesem rejestracji podanej liczby kont, wylosowaniem parametrow
	dla <liczba agentow> (kazdy ma osobne parametry!) agentow typu IrrationalPanicAgent, a nastepnie uruchomieniem
	<liczba agentow> watk�w, kt�re s� zasiedlone przez tych agent�w.
	
	UWAGA: Skrypt przekierowuje wyjscie stdout i stderr do plikow o nazwach <patrz skrypt>.
	
	Odpalenie run.bat <liczba proces> <liczba agentow per proces> skutkuje tym samym co run_single.bat tylko dla kazdego
	z uruchomionych <liczba procesow> procesow. 
	
	UWAGA: Skrypt przekierowuje wyjscie stdout i stderr KAZDEGO Z PROCESOW do plikow o nazwach <patrz skrypt>.
