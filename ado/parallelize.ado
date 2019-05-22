********************************************************************************
*** Parallelize 
********************************************************************************
**
**
** Simo Goshev, Jason Bowman
** Lead developer and maintainer: Simo Goshev
**
**
** v. 0.05
**
**

***This is a prefix program (just like bootstrap, mi, xi, etc)
capture program drop parallelize
program define parallelize, sclass

	set prefix parallelize
	
	sreturn clear
	
	_on_colon_parse `0'
	
	local command `"`s(after)'"'
	local 0 `"`s(before)'"'
	
	syntax, CONspecs(string asis) [JOBspecs(string asis) DATAspecs(string asis) imports(string asis) EXECspecs(string asis) hash *]

	*** Parse CONNECTION specs
	_parseSpecs `"`conspecs'"'

	*** Collect all parameters
	if "`s(sshHost)'" == "" {  // if no .ssh configuration for the connection
	
		*** Parse the config file
		noi _parseConfig
		
		*** <><><> Collect and check user input
		foreach arg in username host port {
			if "`s(`arg')'" ~= "" {
				local `arg' "`s(`arg')'"
			}
			else {
				noi di _n in r "Please, provide argument `arg' in connection specs"
				exit 489
			}
		}
		local host "`username'@`host'"
	}
	else {
		local host "`s(sshHost)'"
	}
	
	*** Parse JOB specs
	_parseSpecs `"`jobspecs'"'

	*** <><><> Collect and check user input
	foreach arg in nodes ppn pmem walltime jobname {
		if "`s(`arg')'" ~= "" {
			local `arg' "`s(`arg')'"
		}
		else {
			noi di _n in r "Please, provide argument `arg' in job specs"
			exit 489
		}
	}
	
	*** Parse DATA specs
	_parseSpecs `"`dataspecs'"'
	
	*** <><><> Collect and check user input
	foreach arg in path loc {
		if "`s(`arg')'" ~= "" {
			local `arg' "`s(`arg')'"
		}
		else {
			noi di _n in r "Please, provide argument `arg' in data specs"
			exit 489
		}
	}
	
	*** Replace space with ## in the argPass strings 
	local argPass "0"
	if "`s(argPass)'" ~= "" {
		local argPass "`=subinstr("`s(argPass)'"," ", "##", .)'"
	}
	
	*** Parse IMPORTS specs
	_parseSpecs `"`imports'"'
	foreach arg in work coll mon {
		if "`s(`arg')'" ~= "" {
			local `arg' "`s(`arg')'"
		}
		else {
			noi di _n in r "Please, provide argument `arg' in imports specs"
			exit 489
		}
	}
	
	*** Parse EXEC specs
	_parseSpecs `"`execspecs'"'
	
	*** <><><> Collect and check user input
	foreach arg in nrep cbfreq {
		if "`s(`arg')'" ~= "" {
			local `arg' "`s(`arg')'"
		}
		else {
			noi di _n in r "Please, provide argument `arg' in execution specs"
			exit 489
		}
	}
	
	*** Compose and transfer content to remote machine
	
	// if command is pchained, need to extract i and t and pass them to _runBundle collect
	
	noi _setupAndSubmit "`host'" `"`path'"' `"`loc'"' `"`s(pURL)'"' `"`command'"' "`nrep'" "`jobname'" "`cbfreq'" "`s(email)'" "`nodes'" "`ppn'" "`pmem'" "`walltime'" "`work'" "`coll'" "`mon'" "`argPass'" "`hash'"
	
	sreturn local command "parallelize"
	
	*** We can feed c(prefix) to -pchained-, -ifeats-, etc. (see conditionals in mytest)
	
	*** Here we need machinery to farm out the work and collect results; we need
	*** a message exchange interface for the user; need api functionality for 
	*** pulling and pushing data

end


*** Function which parses all specs
capture program drop _parseSpecs
program define _parseSpecs, sclass

	args specs

	local rightHS "([a-zA-Z0-9@\\\/:~,\._ ]*)"
	local strregex "([a-zA-Z]+)[ ]*=[ ]*(\'|\"|[ ]*)`rightHS'(\'|\"|[ ]*)"

	while regexm(`"`specs'"', `"`strregex'"') {
		local arg   `=regexs(0)'
		local myKey `=regexs(1)'
		local myVal `=regexs(3)'
		local specs = trim(subinstr(`"`specs'"', `"`arg'"', "", .))
		
		** Post to sreturn
		sreturn local `myKey' `"`myVal'"'
	}
end

*** Parse the config file
capture program drop _parseConfig
program define _parseConfig, sclass
	
	tempname myConf 
	file open `myConf' using "`s(configFile)'", r
	
	file read `myConf' line
	while r(eof) == 0 { 
		if regexm("`macval(line)'", "\[`s(profile)'\]") {
			file read `myConf' line
			_parseSpecs `"`macval(line)'"'
			while `"`macval(line)'"' ~= "" {
				_parseSpecs `"`macval(line)'"'
				file read `myConf' line
			}
		}
		file read `myConf' line
	}
end
	
*** Writing files and sending them to the remote machine
capture program drop _setupAndSubmit
program define _setupAndSubmit, sclass

	args host path dloc url command nrep jobname callback email nodes ppn pmem walltime work coll mon argPass hash

	
	tempname remoteDir
	
	if "`hash'" ~= "" {
		*** Hash date and time to create a tempdir
		ashell powershell.exe -command "echo 'Creating a directory name...'; ssh `host' 'date | md5sum | cut -c1-20'"
		local remoteDir "`r(o2)'"
	}
	
	*** LOCATION OF DATA
	if regexm("`path'", "^(.+/)*(.+)$") {
			local fDir `=regexs(1)'
			local fName `=regexs(2)'
	}
	
	if "`dloc'" == "local" {
		local scpString "`fDir'/`fName'"
		if "`fName'" == "" {
			local scpString "`fDir'/*.*"
		}
		local dataDir "~/`remoteDir'/data/initial"
	}
	else if "`dloc'" == "remote" {
		local dataDir "`fDir'/`fName'"
	}
	else {
		*** TODO: stored on box ***
	}
	
	*** IMPORTS ***
	
	*** Parse out filenames of work, collection and monitoring files
	if regexm("`work'", "^(.+/)*(.+)$") {
		local wFName "`=regexs(2)'"
	}
	if regexm("`coll'", "^(.+/)*(.+)$") {
		local cFName "`=regexs(2)'"
	}	
	if regexm("`mon'", "^(.+/)*(.+)$") {
		local mFName "`=regexs(2)'"
	}	
	
	
	*** Handle no email request
	if "`email'" == "" {
		local email = 0
	}

	*** Format command syntax, extract command name
	local dCommand: word 1 of `command'
	local command = ltrim("`command'")

		
	*** WRITE REMOTE WORK FILE
	tempfile workJob 
	tempname inHandle outHandle
	
	// PLUGIN for WORK recasting; This is where magic happens
	
	file open `inHandle' using "`work'", read
	file open `outHandle' using `workJob', write text replace

	file read `inHandle' line
	while r(eof) == 0 { 
		if regexm(`"`line'"', "^[ ]*\*+.*") {
			file write `outHandle' `"`macval(line)'`=char(10)'"'
		}
		else {
			file write `outHandle' `"`line'`=char(10)'"'
		}
		file read `inHandle' line
	}
	file close `inHandle'
	file close `outHandle'
	
	
	
	*** REMOTE SETUP SCRIPT
	
	tempfile remoteSetup
	tempname dirsHandle
	
	*** Compose and write out REMOTE SETUP SCRIPT
	file open `dirsHandle' using `remoteSetup', write
	file write `dirsHandle' "echo '`remoteDir'' > .parallelize_st_bn_`jobname' && "
	file write `dirsHandle' "mkdir -p `remoteDir'/scripts/imports `remoteDir'/logs && "
	file write `dirsHandle' "mkdir -p `remoteDir'/data/initial `remoteDir'/data/output/data/ `remoteDir'/data/output/metadata/  `remoteDir'/data/final/data  `remoteDir'/data/final/metadata && "
	* file write `dirsHandle' "wget -q https://raw.githubusercontent.com/goshevs/parallelize/devel/ado/_runBundle.do -P ./`remoteDir'/scripts/; "
	file write `dirsHandle' "echo 'Done!'"
	file close `dirsHandle'
	
	
	*** REMOTE SUBMISSION SCRIPT
	
	tempfile remoteSubmit
	tempname submitHandle
	
	*** Compose and write out REMOTE SUBMIT SCRIPT
	file open `submitHandle' using `remoteSubmit', write
	file write `submitHandle' "cd `remoteDir'/logs && "
	file write `submitHandle' "`find /usr/public/stata -name stata-mp 2>/dev/null` -b "
	file write `submitHandle' "../scripts/_runBundle.do master ~/`remoteDir' `nrep' `jobname' 0 `callback' `email' `nodes' `ppn' `pmem' `walltime' `wFName' `cFName' `mFName' `argPass' && "
	file write `submitHandle' "echo 'Done!'"
	file close `submitHandle'


	*shell powershell.exe -noexit -command "Get-Content `pHolder'"
	*shell powershell.exe -noexit -command "ssh `host'"
	
	
	**** CALL THE SHELL AND EXECUTE ALL OPERATIONS
	
	*** Not tested on macOS and Linux
	if "`c(os)'" == "Windows" {
		local osCat "Get-Content -Raw"
		local shellCommand "powershell.exe -command"
	}
	else {
		local osCat "cat"
		local shellCommand ""
	}
	
	**** Write out the command string
	local myCommand "echo 'Setting up directory structure... '; `osCat' `remoteSetup'| ssh `host' 'bash -s';"
	local myCommand "`myCommand' echo 'Copying work file... '; scp -q `workJob' `host':~/`remoteDir'/scripts/imports/`wFName'; echo 'Done!';"
	local myCommand "`myCommand' echo 'Copying collection import... '; scp -q `coll' `host':~/`remoteDir'/scripts/imports/`cFName'; echo 'Done!';"
	local myCommand "`myCommand' echo 'Copying monitoring import... '; scp -q `mon' `host':~/`remoteDir'/scripts/imports/`mFName'; echo 'Done!';"
	
	if "`dloc'" == "local" {
		local myCommand "`myCommand' echo 'Copying data... '; scp -q `scpString' `host':~/`remoteDir'/data/initial/; echo 'Done!';"
	}
	local myCommand "`myCommand' scp C:/Users/goshev/Desktop/gitProjects/parallelize/ado/_runBundle.do `host':~/`remoteDir'/scripts/; echo 'Done!';"
	* local myCommand "`myCommand' scp C:/Users/goshev/Desktop/gitProjects/parallelize/assets/stataScripts/mytest.ado `host':~/`remoteDir'/scripts/; echo 'Done!';"

	local myCommand "`myCommand' echo 'Submitting masterJob... '; `osCat' `remoteSubmit' | ssh `host' 'bash -s';"
	
	*** Execute the command
	shell `shellCommand' "`myCommand'"
	
	/* OLD FUNCTIONING VERSION
	
	
	if "`c(os)'" == "Windows" {
		local myCommand "echo 'Setting up directory structure... '; Get-Content -Raw `remoteDirs' | ssh `host' 'bash -s'; echo 'Done!';"
		local myCommand "`myCommand' echo 'Copying work file...'; scp `workJob' `host':~/`remoteDir'/scripts/_workJob.do; echo 'Done!'"
		if "`dloc'" == "local" {
			local myCommand "`myCommand' echo 'Copying data...'; scp `dfile' `host':~/`remoteDir'/data/initial; echo 'Done!'"
		}
		shell powershell.exe -noexit -command "`myCommand'"
	}
	*/
	
	
	
	
	
	/*		
			
			
	*** Run remote script on cluster and move data (if needed)
	if "`c(os)'" == "Windows" {
		shell powershell.exe -noexit -command "echo 'Setting up directory structure... '; Get-Content -Raw `remoteDirs' | ssh `host' 'bash -s'; echo 'Done!';"
		shell powershell.exe -noexit -command "echo 'Copying work file...'; scp `workJob' `host':~/`remoteDir'/scripts/_workJob.do; echo 'Done!'"
		if "`dloc'" == "local" {
			shell powershell.exe -noexit -command "echo 'Copying data...'; scp `dfile' `host':~/`remoteDir'/data/initial; echo 'Done!'"
		}
		* shell powershell.exe -command "echo 'Submitting masterJob... '; Get-Content -Raw `remoteSubmit' | ssh `host' 'bash -s'; echo 'Done!'"
		
		
		/*
		* | ssh `host' 'bash -s'"
		* shell powershell.exe -noexit -command "Get-Content `remoteScript' | ssh `host' 'bash -s'"
		
		* shell powershell.exe -noexit -command "ssh `host' 'mkdir `remoteDir''; Get-Content `toCopyOver' | ssh `host' 'cat > ~/`remoteDir'/jobWork.do'"
		* Get-Content `pbsSubmit' | ssh sirius 'bash -s'"
		*shell powershell.exe -noexit -command "ssh `host' 'mkdir `mydir'; printf '`jobWork'' > ~/`remoteDir'/jobWork.do'"
		* shell powershell.exe -noexit -command "ssh `host' 'mkdir `mydir'; echo 'this is a test' ~/`remoteDir'/mytest.txt'"
		*/
	}
	else {
		
		*shell echo "this is a test" | ssh sirius 'cat > ~/mytest.txt'
	}
	*/
	
end


*** Utility to check progress and collect output
capture program drop callCluster
program define callCluster
	
	syntax, Request(string asis) [CONspecs(string asis) JOBspecs(string asis) OUTloc(string asis)]
	
	*** Collect all parameters
	if "`s(sshHost)'" == "" {  // if no .ssh configuration for the connection
	
		*** Parse connection specs
		_parseSpecs `"`conspecs'"'
			
		*** Parse the config file
		noi _parseConfig
		
		*** <><><> Collect and check user input
		foreach arg in username host port {
			if "`s(`arg')'" ~= "" {
				local `arg' "`s(`arg')'"
			}
			else {
				noi di _n in r "Please, provide argument `arg' in connection specs"
				exit 489
			}
		}
		
		*** Get username from ssh config file
		*** ssh -G sirius | grep -e "user " | cut -s -d " " -f2
		
		local host "`username'@`host'"
		if "`jobname'" == "" {
			noi di in r "jobname is a required argument"
			exit 489
		}
	}
	else {
		local host "`s(sshHost)'"
		local jobname "`s(jobname)'"
		if "`username'" == "" {
			noi di in r "username is a required argument"
			exit 489
		}
	}
	
	
	local host
	local jobname
	local username
	
	
	
	
	if "`request'" == "checkProgress" {
		ashell powershell.exe -command "ssh `host' 'showq -n -r | grep `username' | grep `jobname' | wc -l; showq -n -i | grep `username' | grep `jobname' | wc -l; date'"
		local runningJobs "`r(o1)'"
		local idleJobs "`r(o2)'"
		local time "`r(o3)'"
		
		noi di _n in y "***********************************************************" _n ///
					   "* Report on running and idle jobs " _n ///
					   "* Time: `time'"  _n ///
					   "***********************************************************" _n ///
					   "* Username: `username'" _n ///
					   "* Jobname: `jobname'" _n ///
					   "* Jobs " _n ///
					   "*     Completed: ??? " _n ///
					   "*     Running: `runningJobs'" _n ///
					   "*     Idle   : `idleJobs'" _n ///
					   "***********************************************************" 
	
	}
	else if "`request'" == "collectOutput" {
		*** SSH to the cluster
		ashell powershell.exe -command "ssh `host' cat ~/.parallelize_st_bn_`jobname'; "
		
		local remoteDir "`r(o1)'"
	
		***<><><> Check if remote directory exists

		shell powershell.exe -command "scp -r `host':~/`remoteDir'/data/final/ `outloc'"
		noi di in y _n "Output collected and copied to `outloc'/final"
		
	}
	else {
		noi di _n in r "Not a valid request type"
		exit 489
	}
end


*** Check progress of job
capture program drop checkProgress
program define checkProgress

	syntax [, CONspecs(string asis) jobname(string asis) username(string asis)]
	
	qui {
		*** Collect all parameters
		if "`s(sshHost)'" == "" {  // if no .ssh configuration for the connection
		
			*** Parse connection specs
			_parseSpecs `"`conspecs'"'
				
			*** Parse the config file
			noi _parseConfig
			
			*** <><><> Collect and check user input
			foreach arg in username host port {
				if "`s(`arg')'" ~= "" {
					local `arg' "`s(`arg')'"
				}
				else {
					noi di _n in r "Please, provide argument `arg' in connection specs"
					exit 489
				}
			}
			local host "`username'@`host'"
			if "`jobname'" == "" {
				noi di in r "jobname is a required argument"
				exit 489
			}
		}
		else {
			local host "`s(sshHost)'"
			local jobname "`s(jobname)'"
			if "`username'" == "" {
				noi di in r "username is a required argument"
				exit 489
			}
		}
		
		*** Show the number of active jobs
		
		ashell powershell.exe -command "ssh `host' 'showq -n -r | grep `username' | grep `jobname' | wc -l; showq -n -i | grep `username' | grep `jobname' | wc -l; date'"
		local runningJobs "`r(o1)'"
		local idleJobs "`r(o2)'"
		local time "`r(o3)'"
		
		noi di _n in y "***********************************************************" _n ///
					   "* Report on running and idle jobs " _n ///
					   "* Time: `time'"  _n ///
					   "***********************************************************" _n ///
					   "* Username: `username'" _n ///
					   "* Jobname: `jobname'" _n ///
					   "* Jobs " _n ///
					   "*     Completed: ??? " _n ///
					   "*     Running: `runningJobs'" _n ///
					   "*     Idle   : `idleJobs'" _n ///
					   "***********************************************************" 
	}
end


*** Collecting results and bringing them back to local machine
*** This is basically parallelize postprocessing
capture program drop outRetrieve
program define outRetrieve, sclass

	syntax, OUTloc(string asis) [CONspecs(string asis) jobname(string asis)]
	

	qui {
	
		*** Collect all parameters
		if "`s(sshHost)'" == "" {  // if no .ssh configuration for the connection

			*** Parse connection specs
			_parseSpecs `"`conspecs'"'
		
			*** Parse the config file
			noi _parseConfig
			
			*** <><><> Collect and check user input
			foreach arg in username host port {
				if "`s(`arg')'" ~= "" {
					local `arg' "`s(`arg')'"
				}
				else {
					noi di _n in r "Please, provide argument `arg' in connection specs"
					exit 489
				}
			}
			local host "`username'@`host'"
		}
		else {
			local host "`s(sshHost)'"
			local jobname "`s(jobname)'"
		}
	}

	
	*** SSH to the cluster
	ashell powershell.exe -command "ssh `host' cat ~/.parallelize_st_bn_`jobname'; "
	
	local remoteDir "`r(o1)'"
	* noi di "`remoteDir'"
	
	***<><><> Check if remote directory exists

	shell powershell.exe -command "scp -r `host':~/`remoteDir'/data/final/ `outloc'"
	noi di in y _n "Output collected and copied to local machine"

	*** Clean up the home directory on the cluster
	
	
	
	
	/*
	if "`c(os)'" == "Windows" {
		local osCat "Get-Content -Raw"
		local shellCommand "powershell.exe -command"
	}
	else {
		local osCat "cat"
		local shellCommand ""
	}
	
	**** Write out the command string
	local myCommand "echo 'Setting up directory structure... '; `osCat' `remoteSetup'| ssh `host' 'bash -s';"
	local myCommand "`myCommand' echo 'Copying work file... '; scp -q `workJob' `host':~/`remoteDir'/scripts/_workJob.do; echo 'Done!';"
	if "`dloc'" == "local" {
		local myCommand "`myCommand' echo 'Copying data... '; scp -q `dfile' `host':~/`remoteDir'/data/initial/;echo 'Done!';"
	}
	local myCommand "`myCommand' scp C:/Users/goshev/Desktop/gitProjects/parallelize/assets/stataScripts/_runBundle.do `host':~/`remoteDir'/scripts/; echo 'Done!';"
	local myCommand "`myCommand' scp C:/Users/goshev/Desktop/gitProjects/parallelize/assets/stataScripts/mytest.ado `host':~/`remoteDir'/scripts/; echo 'Done!';"

	local myCommand "`myCommand' echo 'Submitting masterJob... '; `osCat' `remoteSubmit' | ssh `host' 'bash -s';"
	
	*** Execute the command
	shell `shellCommand' "`myCommand'"
	
	*/
	
	
*** Establish a connection
*** Retrieve the contents of .parallelizeStataBasename
*** Append all files
*** Copy file over to a directory
*** Delete basename dir and and .parallelizeStataBasename

end


	
exit
	
	
	
	
	
/*
local test "con(configFile = 'c:\Users\goshev\Desktop\gitProjects\parallelize\config' profile='sirius')"
_parseSpecs "`test'"
local test "con(configFile = '~/Desktop/gitProjects/parallelize/config' profile='sirius')"
_parseSpecs "`test'"

sreturn list
*/
exit




*** Format of connection string:
**** con([configFile = "<path/filename>" profile="<string>"]|[ssh="<hostName>"])
*** Examples:
**** con(configFile = "c:\Users\goshev\Desktop\gitProjects\parallelize\config" profile="sirius") 
**** con(ssh="sirius")

*** Format of individual job specs:
**** job(nodes="" ppn="" walltime="" jobname="") // qsub -l and -N arguments

*** Format of data specs:
**** data(inFile="" loc="<local | cluster | box>") // fname=~/path/filename

*** Format of execution specs:
**** exec(nrep="" progUrl="")



