
*** Simple test program
capture program drop mytest
program define mytest
	syntax newvarname, Command(string asis)
	clear all
	if "`c(prefix)'" == "parallelize" {
		set obs 10
		gen x = rnormal()
	}
	else {
		set obs 5
		gen x = 1
	}
	`command' x	
end


