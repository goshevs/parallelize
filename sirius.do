
********************************************************************************
*** Functions
********************************************************************************

*** Parser of log file
cap mata: mata drop _parse_file()
mata:
void _parse_file(string scalar fname) {
	myfile = fopen(fname, "r")   // open the file
	myline = fget(myfile)        // read a line
	while ((myline=fget(myfile))!=J(0,0,"")) { // read line by line
		myline = ustrfrom(myline, "UTF-16", 2)
		if (ustrregexm(myline, "Connecting|Connection|Authenticated|Transferred|Exit")) {
			sprintf("%s", usubinstr(myline,"debug1: ", "",.))
		}
    }	
	fclose(myfile)
}
end

********************************************************************************
*** This is a call for submitting a job to Sirius

tempfile mylog
* noi di "`mylog'"
* sleep 2000 
* confirm file "`mylog'"

sleep 2000  // replace this with a test for file created

*** Move the do file over
winexec powershell.exe -command "scp -v c:/Users/goshev/Desktop/evd/scripts/evdWorkingRemote-v2.do sirius:~/projects/evd/scripts/ 2>&1> `mylog'"
mata: _parse_file("`mylog'")


*** Submit a job to the cluster
*** https://www.stata.com/support/faqs/data-management/malformed-end-of-line-sequences/

*** Compose the submit file
local pbsTitle "#! /bin/bash`=char(10)'# Submit the job to the scheduler`=char(10)'# Torqu stderr, stdout and Stata log are saved in working directory`=char(10)'"
local pbsHeader "qsub <<EOF`=char(10)'#PBS -A interactive_job`=char(10)'#PBS -N evdImputation`=char(10)'#PBS -S /bin/bash`=char(10)'"
local pbsResources "#PBS -l nodes=1:ppn=10,pmem=1gb,walltime=10:00:00`=char(10)'"
local pbsCommands "module load stata/15`=char(10)'cd ~/projects/evd/pbs`=char(10)'"
local pbsDofile "stata-mp -b ~/projects/evd/scripts/evdWorkingRemote-v2.do lca 3 5`=char(10)'"
local pbsEnd "EOF`=char(10)'"

*** Combine all parts
local pbsFileContent "`pbsTitle'`pbsHeader'`pbsResources'`pbsCommands'`pbsDofile'`pbsEnd'"

*** Initialize a filename and a temp file
tempfile pbsSubmit
tempname myfile

*** Write out the content to the file
file open `myfile' using `pbsSubmit', write text replace
file write `myfile' "`pbsFileContent'"
file close `myfile'

*** Submit to sirius
shell powershell.exe -command "Get-Content `pbsSubmit' | ssh sirius 'bash -s'"

*** Check status of queues
* winexec powershell.exe -command "ssh sirius 'showq' 2>&1 > C:\Users\goshev\Desktop\dir.log"



/* 
 
 *** Felix Leung ***
** https://www.statalist.org/forums/forum/general-stata-discussion/general/1125928-is-there-any-way-to-get-stdout-echoed-in-the-results-window-from-shell-in-windows***

capture program drop win_stream
cap mata: mata drop win_stream()

program define win_stream
	mata win_stream(`"`0'"')
end

mata:
void win_stream(string scalar cmd) {
    tf = st_tempfilename()
    stata(sprintf("shell echo --begin-- > %s", tf))

    tf_bat = st_tempfilename() + ".bat"
    fh_cmd = fopen(tf_bat, "rw")
    fput(fh_cmd, sprintf("%s\necho --end--", cmd))
    fclose(fh_cmd)
    stata(sprintf("winexec %s >> %s 2>&1", tf_bat, tf))
    
    pos = 0
    thisl = ""
    while (thisl != "--end--") {
        fh = fopen(tf, "r")    // "r": read-only
        fseek(fh, pos, -1)     // go to position pos with respect to -1, i.e. beginning of the file
        thisl = fget(fh); thisl
        pos = ftell(fh)        // store the new position
        fclose(fh)
    }
}
end

win_stream ping 8.8.8.8 -n 5
*/
