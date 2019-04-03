
*** Simple test program
capture program drop mytest
program define mytest
	syntax varname, Command(string asis)
	
	if "`c(prefix)'" == "parallelize" {
		bsample
		`command' `1'
	}
	else {
		`command' `1'
	}
end


