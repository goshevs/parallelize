********************************************************************************
*** Generating test data  
**
**
**
**
**
**
**
**

clear
set more off

set obs 100

gen id = _n
gen x1 = rnormal() * 100
gen x2 = rnormal()



