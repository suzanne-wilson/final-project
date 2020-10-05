*=======================================================================*
| Program: 																|
|			k_means.sas									|
=========================================================================   
| P/A:   Suzanne Wilson						                     		|
=========================================================================   
| Description: 												        	|
|	Used to identify clusters of devices and procedures by indication	|
|	 															|
=========================================================================   
| Project: Vecta TRAP			 										|
=========================================================================   
| Input data:                                                   		|
|	1) PHD datasets 2016-2019											|
=========================================================================
| Output data:                                                   		|   
|	1) N/A																|
=========================================================================   
| Date  created: 8/7/2020	      	                        	   		|                                                                  
=========================================================================
| Last run on:   8/7/2020												|
========================================================================*;

libname phd  "D:\PHD";
libname raw "D:\PHDRaw" access = readonly;

/* run fastclus for k from 3 to 8 */

%macro doFASTCLUS;

     %do k= 3 %to 8;

          proc fastclus

               data= phd.brands

               out= fcOut

               maxiter= 100

               converge= 0          /* run to complete convergence */

               radius= 100          /* look for initial centroids that are far apart */

               maxclusters= &k

               summary;

          run;

     %end;

%mend;

%doFASTCLUS
