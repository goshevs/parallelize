#! /usr/public/python/3.6.3/bin/python3

################################################################################
###
##
## 
##
##
##
##
##

import parallelize as p
import sys
        
if __name__ == '__main__':

    print('\nCommand arguments: ' + ' '.join(sys.argv[1::]) + '\n')
    args = p.parseArgs()

   # print('\nCOLLECT JOB:\n' + p.Job(args).simpleJob('collect'))
    print('\nMASTER JOB:\n' + p.Job(args).master())




