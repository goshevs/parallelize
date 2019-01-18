********************************************************************************
*** Parallelize 
********************************************************************************
**
**
** Simo Goshev, Jason Bowman
**
** v. 0.01
**
**


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



***This is a prefix program (just like bootstrap, mi, xi, etc)
capture program drop parallelize
program define parallelize, eclass

	set prefix parallelize
	
	_on_colon_parse `0'
	
	local command `"`s(after)'"'
	local 0 `"`s(before)'"'
	   
	syntax [,USERname(string asis) PASSfile(string asis) SSHkey(string asis) *]
	
	no di in y _n "username: `username'"
	no di "password: `passfile'"
	no di "sshkey: `sshkey'"
	no di _n
	
	*** We can feed c(prefix) to -pchained-, -ifeats-, etc. (see conditionals in mytest)
	
	*** Here we need machinery to farm out the work and collect results; we need
	*** a message exchange interface for the user; need api functionality for 
	*** pulling and pushing data
	
	*** Execute the command
	`command'

end


