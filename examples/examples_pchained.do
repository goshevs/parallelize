*** Examples

local pathBasename "~/Desktop/gitProjects/parallelize"

*** Load the ado's
do "`pathBasename'/assets/stataScripts/parallelize.ado"  // we should pull this from gitHub

*** Denerate data and save it to a file
clear
do "~/Desktop/gitProjects/pchained/simdata.ado"
simdata 1000 3
save "`pathBasename'/myDataPchained.dta", replace
clear


*** Define locations
local locConf "`pathBasename'/config1"
local locData "c:/Users/goshev/Desktop/gitProjects/parallelize/myDataPchained.dta"  // full path is required (by scp)
local locProg "https://raw.githubusercontent.com/goshevs/pchained/parallel/pchained.ado"
local locWork "`pathBasename'/assets/stataScripts/plugins/pchainedWork.do"
local locColl "c:/Users/goshev/Desktop/gitProjects/parallelize/assets/stataScripts/plugins/pchainedCollect.do"  // full path is required (by scp)
local eMailAddress "" 

*** Generate data
*do "`pathBasename'/examples/simdata.do"
*save "`pathBasename'/myData", replace
* clear

* capture erase "~/Desktop/test.do"

*** Execute the command
parallelize,  /// 
        con(sshHost="sirius") /// con(configFile = "`locConf'"  profile="sirius") ///  
        job(nodes="1" ppn="1" pmem="1gb" walltime="00:05:00" jobname="myPchained")  ///
        data(file= "`locData'" loc="local" uid="id time") ///
		plugins(work="`locWork'" coll="`locColl'") /// work and output collection plugins
        exec(nrep="5" cbfreq="30s" email="`eMailAddress'" pURL = "`locProg'"): ///
		pchained (s1_i, noimputed scale), i(id) t(time) mio(add(50) chaindots rseed(123456))
		
exit

*** Check progress
checkProgress, username(goshev)

exit

*** Collect output from cluster
local outDir "c:/Users/goshev/Desktop"  // full path is required (by scp)
outRetrieve, out(`outDir')

exit
