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
	
	syntax, CONspecs(string asis) [JOBspecs(string asis) DATAspecs(string asis) imports(string asis) EXECspecs(string asis) hash dryrun *]

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
	if "`dryrun'" == "" {
		noi _setupAndSubmit "`host'" `"`path'"' `"`loc'"' `"`s(pURL)'"' `"`command'"' "`nrep'" "`jobname'" "`cbfreq'" "`s(email)'" "`nodes'" "`ppn'" "`pmem'" "`walltime'" "`work'" "`coll'" "`mon'" "`argPass'" "`hash'"
	}
	
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
	file write `dirsHandle' "wget -q https://raw.githubusercontent.com/goshevs/parallelize/master/ado/_runBundle.do -P ./`remoteDir'/scripts/; "
	file write `dirsHandle' "wget -q https://raw.githubusercontent.com/goshevs/parallelize/master/imports/genericMonitor.do -P ./`remoteDir'/scripts/imports/; "

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


*** Utility to check progress and pull output

capture program drop callCluster
program define callCluster
	
	syntax, Request(string asis) [CONspecs(string asis) JOBspecs(string asis) OUTloc(string asis) KEEPremote]
	
	if "`request'" ~= "checkProgress" & "`request'" ~= "pullData" {
		noi di _n in r "'`request'' is not a valid request type"
		exit 489
	}

	noi di in y _n "Connecting to the cluster..."
	
	*** Collect CONNECTION parameters
	if "`s(sshHost)'" == "" {  // if no .ssh configuration for the connection
	
		if "`conspecs'" == "" | "`jobspecs'" == "" {	
			noi di _n in r "Found no connection or job specs left behind by -parallelize-" _n ///
			"Please, provide these specs to continue."
			exit 489
		}
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
		if "`c(os)'" == "Windows" {
			local getUsername `"powershell.exe -command "ssh -G sirius | Select-String -Pattern 'user\ +'""'
			qui ashell `getUsername'
			local username "`r(o2)'"
			gettoken ltocken username: username, parse(" ")
			local username = ltrim("`username'")
		}
		else {
			local getUsername `"ssh -G sirius | grep -e "user " | cut -s -d " " -f2"'
			qui ashell `getUsername'
			local username "`r(o1)'"
		}
	}
	
	*** Collect JOB-related parameters
	local jobname "`s(jobname)'"
	if "`s(jobname)'" == "" {
		_parseSpecs `"`jobspecs'"'
		
		*** <><><> Collect and check user input
		foreach arg in jobname {
			if "`s(`arg')'" ~= "" {
				local `arg' "`s(`arg')'"
			}
			else {
				noi di _n in r "Please, provide argument `arg' in connection specs"
				exit 489
			}
		}
	}
	
	*** Copy to desktop of outloc is not provided
	if "`outloc'" == "" {
		local outloc "%HOMEPATH%/Desktop/parallelize-`jobname'"  // this windows!
		local outlocDisplay "~/Desktop/parallelize-`jobname'"
	}
	
	
	if "`request'" == "checkProgress" {
		qui ashell powershell.exe -command "ssh `host' 'showq -n -r | grep `username' | grep `jobname' | wc -l; showq -n -i | grep `username' | grep `jobname' | wc -l; date'"
		local runningJobs "`r(o1)'"
		local idleJobs "`r(o2)'"
		local time "`r(o3)'"
		
		if "`runningJobs'" ~= "0" | "`idleJobs'" ~= "0" {
		
			noi di _n in y "***********************************************************" _n ///
						   "* Report on running and idle jobs " _n ///
						   "* Time: `time'"  _n ///
						   "***********************************************************" _n ///
						   "* Username: `username'" _n ///
						   "* Jobname: `jobname'" _n ///
						   "* Jobs " _n ///
						   "*     Running: `runningJobs'" _n ///
						   "*     Idle   : `idleJobs'" _n ///
						   "***********************************************************" 
		}
		else {
			noi di _n in y "***********************************************************" _n ///
						   "* Report on running and idle jobs " _n ///
						   "* Time: `time'"  _n ///
						   "***********************************************************" _n ///
						   "* Username: `username'" _n ///
						   "* Jobname: `jobname'" _n ///
						   "* " _n ///
						   "* JOB HAS BEEN COMPLETED!" _n ///
						   "***********************************************************" 
		}				   
	}
	else if "`request'" == "pullData" {
		*** SSH to the cluster
		qui ashell powershell.exe -command "ssh `host' 'cat \.parallelize_st_bn_`jobname' | xargs ls -d '"
		local remoteDir "`r(o1)'"
		
		***<><><> TODO: Check if remote directory exists
		if ("`remoteDir'" == "." | "`remoteDir'" == "" ){
			noi di _n in r "The directory of job `jobname' is no longer accessible by this program. " _n ///
			"The directory and/or associated files may have been removed."
			exit 489
		}

		qui shell powershell.exe -command "scp -r `host':~/`remoteDir'/data/final/ `outloc'"
		noi di in y _n " * Output collected and copied to `outlocDisplay'"
		
		if "`keepremote'" == "" {
			*** Clean up the home directory on the cluster
			qui shell powershell.exe -command "ssh `host' 'rm -rf ~/.parallelize_st_bn_`jobname' ~/`remoteDir''"
			noi di _n in y " * Job directory and all related files were purged from the cluster"
		}
			
	}
end
