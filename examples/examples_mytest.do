*** Examples

local pathBasename "~/Desktop/gitProjects/parallelize"

*** Load the ado's
do "`pathBasename'/assets/stataScripts/parallelize.ado"  // we should pull this from gitHub

*** Define locations
local locConf "`pathBasename'/config1"
local locData "c:/Users/goshev/Desktop/gitProjects/parallelize/myData.dta"  // full path is required (by scp)
local locWork "`pathBasename'/assets/stataScripts/plugins/mytestWork.do"
local locColl "c:/Users/goshev/Desktop/gitProjects/parallelize/assets/stataScripts/plugins/mytestCollect.do"  // full path is required (by scp)
local locProg "https://raw.githubusercontent.com/goshevs/parallelize/pchained/assets/stataScripts/mytest.ado"
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
        data(file= "`locData'" loc="local" uid="test") ///
		plugins(work="`locWork'" coll="`locColl'") ///
        exec(nrep="5" cbfreq="30s" email="`eMailAddress'" pURL = "`locProg'"): mytest x1, c(sum)

exit

*** Check progress
checkProgress, username(goshev)

exit

*** Collect output from cluster
local outDir "c:/Users/goshev/Desktop"  // full path is required (by scp)
outRetrieve, out(`outDir')

exit
