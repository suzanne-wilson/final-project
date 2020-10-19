*=======================================================================*
| Program: 																|
|			B03_language_processing.sas									|
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
%*read in Ben Nelsons spreadsheet of sku numbers and devices;
%*pro tip: there are non-readable characters in some fields in the alternate_skus column;
%*to find them, select the blank values at top of dropdown menu (not (blank) values);

data sku_match; *(keep=sku_number sku_to_desc);
	set sraw.master_sku_list;  *(where=(upcase(manufacturer) in('STRYKER', 'MEDTRONIC', 'PENUMBRA')));
	length sku_to_desc $300 sku_number $50;
	*if sku not in('XCEL');
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
proc sort data=sku_match out=sku_match1(keep=sku_number sku_to_desc) nodupkey;
	by sku_number sku_to_desc;
run;

%*remove duplicates;
proc sort data=sku_match out=sku_match2(keep=sku_number ta_category) nodupkey;
	by sku_number ta_category;
run;

%*remove duplicates;
proc sort data=sku_match out=sku_match3(keep=sku_number device_category) nodupkey;
	by sku_number device_category;
run;
%*check values for formatting, other issues;
proc print data= sku_match3(obs=15);
run;

%*remove duplicates;
proc sort data=sku_match out=sku_match4(keep=sku_number manufacturer) nodupkey;
	by sku_number manufacturer;
run;
%*check values for formatting, other issues;
proc print data= sku_match4(obs=15);
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

%*;

%*create a format to pick up manufacturer names;
%dset_to_format(indata= sku_match2, 
					  target_value= sku_number,  
					  format_value=ta_category,  
					  value_len=$30, 		/*IMPORTANT: include $ if the formatted value is character*/  
					  fmtname=tacat,  
					  c_or_n=c );

proc print data=ctrl noobs;
   title 'The CTRL Data Set';
run;


%*create a format to pick up manufacturer names;
%dset_to_format(indata= sku_match3, 
					  target_value= sku_number,  
					  format_value=device_category,  
					  value_len=$30, 		/*IMPORTANT: include $ if the formatted value is character*/  
					  fmtname=devcat,  
					  c_or_n=c );

proc print data=ctrl noobs;
   title 'The CTRL Data Set';
run;


%*create a format to pick up manufacturer names;
%dset_to_format(indata= sku_match4, 
					  target_value= sku_number,  
					  format_value=manufacturer,  
					  value_len=$30, 		/*IMPORTANT: include $ if the formatted value is character*/  
					  fmtname=mfrcat,  
					  c_or_n=c );

proc print data=ctrl noobs;
   title 'The CTRL Data Set';
run;


%*billing records associated with procedures to treat stroke;
data temp.devproc2017; 
	set phd.dev_byproc_2017; 
	length word1-word6 $50;
	by hosp_chg_desc;

	*parse out single words separated by a space;
	array words{*} $ word1-word6;
	array finds{*}  find1-find6;

	do i = 1 to dim(words);
		words{i} =scan(hosp_chg_desc,i);
	  	if words{i} ne ' ' then do;
			sku_found = put(upcase(words{i}),$skus.);
			if sku ne 1 then sku=sku_found ne 'NO_MATCH';
			mfr_found = put(upcase(words{i}),$mfrcat.);
			if manuf ne 1 then manuf = mfr_found ne 'NO_MATCH';
			ta_found = put(upcase(words{i}),$tacat.);
			if ta ne 1 then ta = ta_found ne 'NO_MATCH';
			devcat_found = put(upcase(words{i}),$devcat.);
			if devcat ne 1 then devcat = devcat_found ne 'NO_MATCH';

			finds{i} = sku_found ne 'NO_MATCH' or mfr_found ne 'NO_MATCH' or ta_found ne 'NO_MATCH' or devcat_found ne 'NO_MATCH' ;
		end;
   	end;
	device_found = sum(find1-find6) gt 0;
run;

%*split into train and test datasets;
data train_set test_set;
	set orig_with_flags;
	if mod(_obs_/4) eq 0 then output test_set;
	else output train_set;
run;


ods output ParameterEstimates=ParameterEstimates OddsRatios=OddsRatios;
proc logistic data = train_set descending;
	class sku_found(param=ref ref=first) devcat_found(param=ref ref=first);
	&modlabel : model device_found(event = '1') =sku_found devcat /expb;
	title "Model: &modlabel";
run;

%*select the subset of microcatheters and then use regular expressions to identify the devcices;
data matches(where=(any_match eq 1)) sykcomp(where=(syk_match eq 1 or compmatch eq 1)) all;
	set phd.dev_byproc_2017; 
	length mfr word1-word6 $200;
	if STD_CHG_DESC eq 'MICROCATHETER';

		mfr=' ';
		MDTmatch=0;
		BALTmatch=0;
		TVmatch=0;
		JJmatch =0;
		PENmatch =0;
		syk_match=0;
		 ; 

	pl1='/CATH/i';
	cathmatch=prxmatch(pl1,upcase(std_chg_desc)) gt 0;

	%macro rule_outs(target=);
		if &target eq 1 then do;
			ruleouts='/coil|balloon|target|sling|guiding|guide|diagnostic|introducer/i';
			romatch1=prxmatch(upcase(ruleouts),hosp_chg_desc) gt 0;
			romatch2=prxmatch(upcase(ruleouts),std_chg_desc) gt 0;
			if romatch1 eq 1 or romatch2 eq 1 then &target =0;
		end;
	%mend rule_outs;

	%rule_outs(target=cathmatch);


	if cathmatch eq 1 then do;
		patternid = '/\d[Mm][Mm][Xx]\d.*\d[Cc][Mm]/i';
		match=prxmatch(patternid,hosp_chg_desc) gt 0;

		patternid2 = '/\d.*[Mm]\s*[Xx]\s*\d\s*\d[MCmc][Mm]/i';
		match2=prxmatch(patternid2,hosp_chg_desc) gt 0;

		ExcelsiorID1='/[Xx][Tt].*17/i';
		mlmatch=prxmatch(ExcelsiorID1,hosp_chg_desc) gt 0;

		ExcelsiorID2='/[Ss][Ll].*10/i';
		m2match=prxmatch(ExcelsiorID2,hosp_chg_desc) gt 0;

		stryker_dev='/Tracker|Excelsior|Renegade/i';
		STRmatch=prxmatch(stryker_dev,hosp_chg_desc) gt 0;

		medtronic='/MEDTRON|MARATHON|ULTRAFLOW|REBAR|PHENOM|ECHELON|MARKSMAN/i';
		MDTmatch=prxmatch(medtronic,hosp_chg_desc) gt 0;

		terumovia='/VIA\s*\d\s*\d|HEADWAY|TERUMO/i';
		TVmatch=prxmatch(terumovia,hosp_chg_desc) gt 0;

		PENUMBRA='/PENUMBRA|PX 400|PX SLIM|VELOCITY/i';
		PENmatch=prxmatch(PENUMBRa,hosp_chg_desc) gt 0;

		JandJ='/TRANSIT|PROWLER/i';
		JJmatch=prxmatch(JandJ,hosp_chg_desc) gt 0;

		balt='/BALT|MAGIC/i';
		BALTmatch=prxmatch(balt,hosp_chg_desc) gt 0;

		%macro colabel(mfr1=, mfr2=);
			if prxmatch("&mfr1.|&mfr2",hosp_chg_desc) gt 0 then company="&mfr1";
		%mend colabel;

		%rule_outs(target=syk_match);
		%rule_outs(target=compmatch);

		syk_match=sum(mlmatch,m2match,STRmatch) gt 0;
		compmatch=SUM(MDTmatch, BALTmatch, TVmatch, JJmatch, PENmatch ) gt 0;

		array words{*} $ word1-word6;
		do i = 1 to dim(words);
			words{i} =scan(hosp_chg_desc,i);
		end;

		label  	MDTmatch = 'Medtronic'
				BALTmatch  = 'Balt'
				TVmatch  = 'Terumo'
				JJmatch  = 'JandJ'
				PENmatch  = 'Penumbra'
				syk_match = 'Stryker'
				;

		array mfrs{*} MDTmatch BALTmatch TVmatch JJmatch PENmatch syk_match; 

		do i = 1 to dim(mfrs);
			if missing(mfr) eq 1 then do;
				if mfrs{i} eq 1 then mfr=label(mfrs{i});
			end;
		end;
		if missing(mfr) eq 1 then mfr='Other';
		end;

	any_match=sum(syk_match,compmatch) gt 0;
  
run;

%*datasets to upload to power BI and use for visualizations;
proc sql;
	create table phd.MICROcaths as
	select 	a.*,
			b.*,
			c.*,
			propcase(c.prov_division) as prop_division
	from matches a
	left join 
		raw.str_2017_pat_noapr b
		on a.pat_key = b.pat_key
	left join 
		raw.str_providers c
		on b.prov_id = c.prov_id
	where missing(a.mfr) eq 0
	order by a.pat_key
	;
	quit;

	proc sql;
	create table orig_with_flags as
	select a.*,
			b.pat_key,
			b.ruptured,
			b.unruptured,
			b.AIS,
			b.ICAD,
			b.ruptured eq 1 or b.unruptured eq 1 as HEM,
			case
				when b.ICAD eq 1 then 'ICAD' 
				when b.AIS eq 1 then 'AIS'
				when b.ruptured eq 1 or b.unruptured eq 1 then 'Hemorrhagic'
				else 'Other'
			end as franchise
	from phd.MICROcaths a
	left join
		phd.dxpx2017 b
		on a.pat_key = b.pat_key
	order by a.pat_key
	;
	
quit;

proc sql;
	create table for_kmeans as
	select a.prov_division,
	b.bill_charges  ,
	b.bill_cost  
	from phd.devices_for_viz a
	left join
		temp.cdm_cpt b
		on a.hosp_chg_id = b.hosp_chg_id
	order by a.hosp_chg_id
	;
quit;

data phd.for_kmeans(keep=bill_: std_qty pat_key);
set temp.cdm_cpt; 
run;

ods graphics on;

proc princomp data=for_kmeans cov plots=score(ellipse);
   var bill_charges  bill_cost  bill_var_cost  bill_fix_cost;
   id prov_division;
run;
ods graphics off;

%*output to excel file;
%let sout = K:\Biostatistics\DEV\gstudy\RWD\sout;
%macro outxls(sasin=, xlsname=);
    ods listing close;
	%let title=&sasin;
    ods excel file="&sout\&xlsname..xlsx" style=normal;
    ods excel options(
      frozen_headers='1' Frozen_RowHeaders='1' orientation="landscape" row_repeat='1'   
      Print_Header="&amp;C &title &amp;A"
      print_footer="&amp;C &title (generated on &amp;D) &amp;R Page &amp;P of &amp;N"
      autofilter="All" 
      flow='tables'
   );

   ods excel options(sheet_name="&sasin" absolute_column_width= "12");

   proc print data=&sasin. noobs label;
   run; 

   ods excel close;
   ods listing;
%mend outxls;

%outxls(sasin=orig_with_flags, xlsname=orig_with_flags);


