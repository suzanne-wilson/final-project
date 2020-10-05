*=======================================================================*
| Program: 																|
|			B01_cleaning.sas									|
=========================================================================   
| P/A:   Suzanne Wilson						                     		|
=========================================================================   
| Description: 												        	|
|	Used to identify clusters of devices and procedures by indication	|
|	 															|
=========================================================================   
| Project: for general use		 										|
=========================================================================   
| Input data:                                                   		|
|	1) 											|
=========================================================================
| Output data:                                                   		|   
|	1) N/A																|
=========================================================================   
| Date  created: 9/27/2020	      	                        	   		|                                                                  
=========================================================================
| Last run on:   10/4/2020												|
========================================================================*;

libname phd  "D:\PHD";
libname raw  "D:\PHDRaw" access = readonly;
libname temp "C:\Users\SWilson\Documents\PHD\";
libname sraw "D:\PHDRaw" access = readonly;


%macro dset_to_format(indata= , 
					  target_value= ,  
					  format_value=,  
					  value_len=, 		/*IMPORTANT: include $ if the formatted value is character*/  
					  fmtname=,  
					  c_or_n= );
	data ctrl;
	   length label &value_len ;
	   set &indata.(rename=(&target_value = start &format_value = label)) end=last;
	   retain fmtname "&fmtname" type "&c_or_n";
	   output;
	   if last then do;
	      hlo='O';
	      label='NO_MATCH';
	      output;
	   end;
	run;

	proc format library=work cntlin=ctrl;
	run;
%mend dset_to_format;

/*------------------------------------------------------------------
Part 3: setup programs and macros
--------------------------------------------------------------------*/
%*read in Ben Nelson's spreadsheet of sku numbers and devices;
%*pro tip: there are non-readable characters in some fields in the alternate_skus column;
%*to find them, select the blank values at top of dropdown menu (not (blank) values);

data sku_match_big3(keep=sku_number sku_to_desc);
	set sraw.master_sku_list(where=(upcase(manufacturer) in('STRYKER', 'MEDTRONIC', 'PENUMBRA')));
	length sku_to_desc $300 sku_number $50;
	if sku not in('XCEL');
	sku_number=strip(sku);
	sku_to_desc = strip(Manufacturer||' '||strip(brand)||', '||Diameter||' X '|| Length || ' (SKU:'|| strip(sku_number)||')');
	output;

	if missing(Alternate_SKUs) eq 0 then do;
		sku_number=strip(Alternate_SKUs);
		sku_to_desc = strip(Manufacturer||' '||strip(brand)||', '||Diameter||' X '|| Length || ' (SKU:'|| strip(sku_number)||')');
		output;
	end;
run;

%*remove duplicates;
proc sort data=sku_match_big3 out=sku_match1 nodupkey;
	by sku_number sku_to_desc;
run;

%*check values for formatting, other issues;
proc print data= sku_match1(obs=15);
run;

%*create a format to pick up sku values when applied to word variable;
%dset_to_format(indata= sku_match1, 
					  target_value= sku_number,  
					  format_value=sku_to_desc,  
					  value_len=$300, 		/*IMPORTANT: include $ if the formatted value is character*/  
					  fmtname=skus,  
					  c_or_n=c );
quit;

proc print data=ctrl noobs;
   title 'The CTRL Data Set';
run;

%*create a list of unique manufacturer values;
proc sql;
	create table mfrs as
	select distinct upcase(manufacturer) as manufacturers,
		   calculated manufacturers as mfr
	from sraw.master_sku_list;
quit;

proc print data=mfrs; run;

%*create a format to pick up manufacturer names;
%dset_to_format(indata= mfrs, 
					  target_value= mfr,  
					  format_value=manufacturers,  
					  value_len=$30, 		/*IMPORTANT: include $ if the formatted value is character*/  
					  fmtname=mfr,  
					  c_or_n=c );

proc print data=ctrl noobs;
   title 'The CTRL Data Set';
run;

%*hospital description of charges;
data phd.chgbyword(keep= word HOSP_CHG_DESC HOSP_chg_id count);
	set raw.STR_hospchg; 
	length word $50;
	by hosp_chg_id;
	count=0;
	%*parse out single words separated by a space;
   	do until(word=' ');
      count+1;
      word=scan(HOSP_CHG_DESC, count, ' ');
	  if word ne ' ' then output;
   	end;
run;

%*apply formats to parsed word dataset to pull matches by SKU number or manufacturer;
data phd.brands(where=(sku_found ne 'NO_MATCH' or mfr_found ne 'NO_MATCH'));
	set phd.chgbyword;
	sku_found = put(upcase(word),$skus.);
	mfr_found = put(upcase(word),$mfr.);
run;

%*print first 100 obs of stryker products found;
proc print data=phd.brands(obs=100 where=(mfr_found='STRYKER'));
   title 'The phd.brands Data Set';
run;

%*frequency of matches by match method;
proc freq data=phd.brands order=freq;
tables sku_found*mfr_found/list missing missprint;
run;

%*create dataset of unique hosp_chg_id codes to be merged with chrgmster file;
proc sort data=phd.brands out=phd.unique_hci nodupkey;
	by HOSP_chg_id;
run;
			

%*print first 100 obs of unique charge ids found;
proc print data=phd.unique_hci(obs=100);
   title 'The phd.unique_hci Data Set';
run;

%*merge with chargemaster file;
