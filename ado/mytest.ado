
*** Simple test program
capture program drop mytest
program define mytest
	syntax varname, Command(string asis)
	
	if "`c(prefix)'" == "parallelize" {
		sleep 60000 // 1 min; 10000 = 10 sec
		bsample
		`command' `1'
	}
	else {
		noi di "`1'"
	}
end


