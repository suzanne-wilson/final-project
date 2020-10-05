/*****************************************************************************
** Project: RWD                                        
** Program Name: A0_setup.SAS                                 
** Purpose:  sets common study-report-level macro values and assigns some libraries  
**                                               
** Creation Date: 2020SEP27                                           
** Author: Suzanne Wilson, based on Jessica Chung's programs                                                   
** SAS Version:     9.4                                                     
** Input:                                                                   
** Output:                                                                  
*************************************************************************** 
** Modification History                                                     
** Date             Initials    Description                                 
** -----------------------------------------------------------------------  
** DDMMMYYY                                                                 
*************************************************************************** 
** Program Notes     
**  

***************************************************************************/

%let pgmname    = A0_setup;
%let study      = RWD;
%let ttl2       = &study Trial;
%let dir        = K:\Biostatistics\&stage\gstudy\&study ;           %*root directory location;

/*------------------------------------------------------------------
Part 3: setup programs and macros
--------------------------------------------------------------------*/

%let smac       = &dir\smacro;                                       %*location of macros;
%let macropgm   = K:\Biostatistics\DEV\gmacro;                       %*location of macros;
%let spgloc     = &dir\spgm;                                        %*location of SAS programs;

%put &smac;

%let report     = first_look;

%let _DBDt      = %str(20160810);
%let _DBDt2     = 2016_08_10;
%let extdt      = 10AUG2016;

%let smeta       = &dir\sdata\smeta ;
%let ads        = &dir\sData\sads\&_DBdt;                           %*location of analysis data sets;
%let sraw        = D:\PHDraw;                           %*location of analysis data sets;

%let rpath      = &dir\srpt\&report ;
%let rads       = &rpath\rdata\rads;                                %*location of SAS programs;
%let outdir     = &rpath\rout;                                      %*location of output;
%let outpath    = &rpath\rout ;
%let routdt     = &rpath\rout\&_DBdt ;
%let rlog       = &rpath\rout\&_DBdt\rlog;                          %*location of logs;
%let rmacro     = &rpath\rmacro;                                    %*location of output;
%let rpgloc     = &rpath\rpgm;                                      %*location of SAS programs;


options mlogic mlogicnest mprint mprintnest symbolgen source source2 mautosource 
        sasautos=("&macropgm" "&smac" "&macdir" sasautos) mautolocdisplay
        nocenter nodate nofmterr nonumber noovp nobyline 
        msglevel=i ps=51 ls = 256 missing='' formchar='|_---|+|---';

/*------------------------------------------------------------------
Part 1: Assign libraries
--------------------------------------------------------------------*/
libname sads     "&ads" inencoding=asciiany;
libname sraw     "&sraw" inencoding=asciiany;
libname rlogs    "&rlog" inencoding=asciiany;
libname routdt   "&routdt";
libname meta     "&smeta" inencoding=asciiany;
libname out 	 "D:\PHDRaw";
libname in 		 "D:\PHDRaw";

filename pgm     "&rpgloc";

/*------------------------------------------------------------------
Part 2: macros
--------------------------------------------------------------------*/

%*macro reads in zipped files downloaded from sftp site and converts their encoding to wlatin1;
%macro copy_to_new_encoding(from_dsname,to_dsname,new_encoding,dsname);
	filename target "D:\Temp\&dsname..sas7bdat";
	filename fromzip ZIP "D:\PHD zipped files\&dsname..sas7bdat.gz" GZIP;  
	data _null_;
		infile fromzip lrecl=256 recfm=F length=length eof=eof unbuf;
		file target lrecl=256 recfm=N ;
		input;
		put _infile_  $varying256. length;
		return;
	  eof:
	    stop;
	run;

	%global orig_encoding;

	%let prefix=goobly; 

	filename lngtstmt temp;
	data _null_; 
	   file lngtstmt; 
	   put ' '; 
	run; 

	filename kcvtused temp;
	data _null_; 
	   file kcvtused; 
	   put ' '; 
	run; 

	data temp2; 
	   x=1; 
	run; ;
	 
	%global sql_libname sql_memname; 
	data _null_; 
	   length libname memname $256; 
	   memname=scan("&from_dsname",-1,'.'); 
	   libname=ifc(index("&from_dsname",'.'),scan("&from_dsname",1,'.'),"WORK"); 
	   call symputx('sql_libname',upcase(libname)); 
	   call symputx('sql_memname',upcase(memname)); 
	run;
	proc sql; 
	   create table temp as select * from dictionary.tables 
	     where libname="&sql_libname." and memname="&sql_memname."; 
	   quit; 
	data _null_; 
	   set temp; 
	   call symputx('orig_encoding',scan(encoding,1,' ')); 
	run;

	proc contents data=&from_dsname out=temp(keep=name type length npos) noprint; 
	run;
	 
	proc sort data=temp; 
	   by name; 
	run; 

	%global nchars revise;
	%let revise=0;  
	data _null_; 
	   set temp end=eof;
	   retain nchars 0; 
	   nchars + (type=2); 
	   if eof;    
	     call symputx('nchars',nchars); 
	run;

	%if &nchars %then %do; 

	data temp2(keep=&prefix._name &prefix._length
	   rename=(&prefix._name=NAME)); 
	   set &from_dsname(encoding=binary) end=&prefix._eof; 
	   retain &prefix._revise 0; 
	   array &prefix._charlens{&nchars} _temporary_; 
	   array &prefix._charvars _character_; 

	   if _n_=1 then do over &prefix._charvars; 
	     &prefix._charlens{_i_}= -vlength(&prefix._charvars); 
	   end;

	   do over &prefix._charvars; 
	     &prefix._l = lengthc(kcvt(trim(&prefix._charvars),
	     "&orig_encoding.","&new_encoding.")); 
	     if &prefix._l > abs(&prefix._charlens{_i_}) then do; 
	        &prefix._charlens{_i_} = &prefix._l; 
	        &prefix._revise = 1; 
	        end;
	     end;

	     if &prefix._eof and &prefix._revise;
	     call symputx('revise',1); 
	     length &prefix._name $32 &prefix._length 8; 
	     do over &prefix._charvars; 
	        if &prefix._charlens{_i_} > 0 then do;
	           &prefix._name = vname(&prefix._charvars); 
	           &prefix._length = &prefix._charlens{_i_}; 
	           output temp2;
	           end;
	        end;
	     run; 

	%if &revise %then %do; 

	proc sort data=temp2; 
	   by name; 
	run;

	data temp; merge temp temp2(in=revised); 
	   by name;
	   if revised then length=&prefix._length; 
	   need_kcvt = revised; 
	run;
	 
	proc sort; 
	   by npos; 
	run;

	data _null_; 
	   set temp; 
	   file lngtstmt mod; 
	   length nlit $512 stmt $1024; 
	   nlit = nliteral(name); 
	   len = cats(ifc(type=2,'$',' '),length);
	   stmt = catx(' ','length',nlit,len,';');  
	   put stmt;
	   if need_kcvt; 
	     stmt = trim(nlit)||' = kcvt('||trim(nlit)||",""&orig_encoding
	."",""&new_encoding."");"; 
	   put stmt; 
	run;
	%end;
	%end;
	 
	data &to_dsname(encoding=&new_encoding);       
	   %include lngtstmt/source2; 
	   set &from_dsname(encoding=binary); 
	   %include kcvtused/source2; 
	run;

	filename lngtstmt clear; 
	filename kcvtused clear; 
	proc delete data=temp temp2; 
	run; 

%mend copy_to_new_encoding;

%copy_to_new_encoding(in.str_chgmstr, out.str_chgmstr, wlatin1, str_chgmstr);

%*unzips and reencodes by year;
%macro copy_by_year(year=);
	%copy_to_new_encoding(in.str_&year._pat_noapr, out.str_&year._pat_noapr, wlatin1, str_&year._pat_noapr);
	%copy_to_new_encoding(in.str_&year._patbill,out.str_&year._patbill,wlatin1, str_&year._patbill);
	%copy_to_new_encoding(in.str_&year._patcpt, out.str_&year._patcpt, wlatin1, str_&year._patcpt);
	%copy_to_new_encoding(in.str_&year._paticd_diag, out.str_&year._paticd_diag, wlatin1, str_&year._paticd_diag);
	%copy_to_new_encoding(in.str_&year._paticd_proc, out.str_&year._paticd_proc, wlatin1, str_&year._paticd_proc);
%mend copy_by_year;

%copy_by_year(year=2016);
%copy_by_year(year=2017);
%copy_by_year(year=2018);
%copy_by_year(year=2019);

%copy_to_new_encoding(in.str_chgmstr, 		out.str_chgmstr, 	wlatin1, str_chgmstr);
%copy_to_new_encoding(in.str_admsrc, 		out.str_admsrc, 	wlatin1, str_admsrc);
%copy_to_new_encoding(in.str_admtype, 		out.str_admtype, 	wlatin1, str_admtype);
%copy_to_new_encoding(in.str_cptcode, 		out.str_cptcode, 	wlatin1, str_cptcode);
%copy_to_new_encoding(in.str_disstat, 		out.str_disstat, 	wlatin1, str_disstat);
%copy_to_new_encoding(in.str_hospchg, 		out.str_hospchg, 	wlatin1, str_hospchg);
%copy_to_new_encoding(in.str_icdcode, 		out.str_icdcode, 	wlatin1, str_icdcode);
%copy_to_new_encoding(in.str_icdpoa, 		out.str_icdpoa, 	wlatin1, str_icdpoa);
%copy_to_new_encoding(in.str_msdrg, 		out.str_msdrg, 		wlatin1, str_msdrg);
%copy_to_new_encoding(in.str_msdrgmdc, 		out.str_msdrgmdc, 	wlatin1, str_msdrgmdc);
%copy_to_new_encoding(in.str_pattype, 		out.str_pattype, 	wlatin1, str_pattype);
%copy_to_new_encoding(in.str_payor, 		out.str_payor, 		wlatin1, str_payor);
%copy_to_new_encoding(in.str_physpec, 		out.str_physpec, 	wlatin1, str_physpec);
%copy_to_new_encoding(in.str_str_poorigin, 	out.str_poorigin, 	wlatin1, str_poorigin);
%copy_to_new_encoding(in.str_providers, 	out.str_providers, 	wlatin1, str_providers);
%copy_to_new_encoding(in.str_readmit, 		out.str_readmit, 	wlatin1, str_readmit);

