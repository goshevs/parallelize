*** Examples

local pathBasename "~/Desktop/gitProjects/parallelize"

*** Load the ado's
do "`pathBasename'/assets/stataScripts/parallelize.ado"  // we should pull this from gitHub

*** Define locations
local locConf "`pathBasename'/config1"
local locData "c:/Users/goshev/Desktop/gitProjects/parallelize/myData.dta"  // full path is required (by scp)
local locProg "https://raw.githubusercontent.com/goshevs/parallelize/devel/assets/stataScripts/mytest.ado"
local eMailAddress "" 

*** Generate data
do "`pathBasename'/examples/simdata.do"
save "`pathBasename'/myData", replace
clear

* capture erase "~/Desktop/test.do"

*** Execute the command
parallelize,  /// 
        con(sshHost="sirius") /// con(configFile = "`locConf'"  profile="sirius") ///  
        job(nodes="1" ppn="1" pmem="1gb" walltime="00:05:00" jobname="myTest")  ///
        data(file= "`locData'" loc="local") ///
        exec(nrep="5" cbfreq="30s" email="`eMailAddress'" ): mytest x1, c(sum) //pURL = "`locProg'"

exit

*** Check progress
checkProgress, username(goshev)

exit

*** Collect output from cluster
local outDir "c:/Users/goshev/Desktop"  // full path is required (by scp)
outRetrieve, out(`outDir')

exit
