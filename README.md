# Stata package `parallelize`


*Developers*: Simo Goshev, Jason Bowman   
*Maintainer*: Simo Goshev  
*Group*: BC Research Services


## Introduction

Although a fairly large number of commands in Stata are internally parallelized,
the speed of execution of specific algorithms such as bootstrapping, jackknifing and imputation 
could be accelerated by utilizing a computing cluster. The aim of package `parallelize` is to help researchers 
in parallelizing their analyses and submitting jobs directly from their local 
copy of Stata to the Linux computing cluster at Boston College (and potentially any
cluster running Torque(PBS)).



## Installation


To load package `parallelize`, include the following line in your do file:

```
qui do "https://raw.githubusercontent.com/goshevs/parallelize/master/assets/stataScripts/parallelize.ado"
```

<br>

## Update on our development effort


Over the past several months, we reached a couple of important milestones:

1. We developed a python API to Box that enables pulling and pushing of
data directly from/to Box, thus eliminating a series of intermediate steps.

2. We developed and tested successfully the job submission, monitoring and
output collection functionality.

**Development continues!**

<br>

## Command `parallelize`

`parallelize` is used to define a connection, decribe the specifics of the job and
submit jobs to the computing cluster

### Syntax

```
parallelize, CONspecs(string) [JOBspecs(string) ///
             DATAspecs(string) EXECspecs(string)]: command

```
<br>

`parallelize` takes the following arguments:

**Required**

| argument    | description            |
|-------------|------------------------|
| *CONspecs*  | connection specification; two flavors, see below for syntax |
| *command*   | command to be parallelized on the cluster |


<br>

**Optional and conditionally required arguments:**

| argument       | description            |
|----------------|------------------------|
| *JOBspecs*    | the specification of a parallel job; see below for syntax |
| *DATAspecs*    | specification of the data to be used; see below for syntax |
| *EXECspecs*    | execution specifications; see below for syntax |


<br>

**Syntax for `CONspecs`**

`CONspecs` can be specified in two ways:

- `con(configFile="" profile="")`, where
	- `configFile` is the path and file name of the configuration file to be used by 
	`ssh` to connection to the cluster
	- `profile` is the name of the profile in the configuration file to be used, or
- `con(sshHost="")`, where:
	- `sshHost` is the name of the host in the ssh `config` file located in `.ssh/` to be 
	used to connect to the cluster

The configuration file should be specified in 
[this](https://github.com/goshevs/parallelize/blob/devel/config) format.
 
<br>

**Syntax for `JOBspecs`**

`JOBspecs` defines the resource requirements for a parallel job. It has the following syntax:

`job(nodes="" ppn="" pmem="" walltime="" jobname="")`

where:

- `nodes` is the number of nodes requested
- `ppn` is the number of virtual processors per node 
- `pmem` is the RAM per processor
- `walltime` is the length of time allocated to the job, or job's runtime
- `jobname` is the name that will be applied to all parallel jobs

<br>

**Syntax for `DATAspecs`**

`DATAspecs` defines the data file and its location. It is specified in the following way:
 
`data(inFile="" loc="")`

where:

- `inFile` should include the path and name of the data file
- `loc` takes the values of `local`, `cluster`, or `box` to indicate where the
data file is housed.

<br>

**Syntax for `EXECspecs`**

`EXECspecs` defines execution parameters. It has the following syntax:

`exec(nrep="" progUrl="" cbfreq="" email="" )`

where: 

- `nrep` is the number of parallel jobs needed
- `progUrl` is the URL of a `do` or `ado` file which has to be imported prior to running `command`.
- `cbfreq` is the callback frequency of the monitoring process (could be defined in seconds, minutes, hours and days)
- `email` instructs Torque to send an email to the specified email address once all jobs are completed.


<br>

## Command `outRetrieve`

`outRetrieve` is used to collect the output of `parallelize`.


### Syntax

```
outRetrieve, OUTloc(string)

```
<br>

`outRetrieve` takes the following argument:

**Required**

| argument    | description            |
|-------------|------------------------|
| *OUTloc*    | the location on the user's machine where output would be stored |


Note: `outRetrieve` copies a directory called `final` to `OUTloc`; the file in that 
directory contains the combined output of all individual jobs.


<br>


## Examples (preliminary)


```
local pathBasename "~/Desktop/gitProjects/parallelize"

*** Load the ado's
do "`pathBasename'/assets/stataScripts/parallelize.ado"

*** Define locations
local locConf "`pathBasename'/config1"
local locData "c:/Users/goshev/Desktop/gitProjects/parallelize/myData.dta"  // full path is required (for scp)
local locProg "https://raw.githubusercontent.com/goshevs/parallelize/devel/assets/stataScripts/mytest.ado"
local eMailAddress "myemailaddress@host.domain" 

*** Generate data
do "`pathBasename'/examples/simdata.do"
save "`pathBasename'/myData", replace
clear

*** Run code
parallelize,  /// 
        con(sshHost="sirius") /// con(configFile = "`locConf'"  profile="sirius") ///  
        job(nodes="1" ppn="1" pmem="1gb" walltime="00:10:00" jobname="myTest")  ///
        data(file= "`locData'" loc="local") ///
        exec(nrep="10" cbfreq="30s" pURL = "`locProg'" email="`eMailAddress'" ): mytest x1, c(sum) 
		
		
		
*** Collect output from cluster
local outDir "c:/Users/goshev/Desktop"  // full path is required (by scp)
outRetrieve, out(`outDir')
		
```
