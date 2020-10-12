*=======================================================================*
| Program: 																|
|			devices_used_per_indication.sas								|
=========================================================================   
| P/A:   Jessica Chung						                     		|
=========================================================================   
| Description: 												        	|
|	Request for Ritu, figure out devices used per case for AIS,			|
|	ruptured, unruptured, ICAD											|
=========================================================================   
| Project: Global Market Intelligence meeting							|
=========================================================================   
| Input data:                                                   		|
|	1) PHD datasets 2016-2019											|
=========================================================================
| Output data:                                                   		|   
|	1) AIS, ruptured, unruptured, ICAD									|
=========================================================================   
| Date  created: 9/21/2020	      	                        	   		|                                                                  
=========================================================================
| Last run on:   9/21/2020												|
========================================================================*;


libname raw "D:\PHDRaw" access = readonly;
libname temp "D:\Temp";
libname PHD "D:\PHD";

*Get diagnoses for AIS, ruptured, unruptured, ICAD;
proc sql;
	create table temp.diagnoses as
	select distinct
		PAT.medrec_key
		,ICD.pat_key
		,PAT.prov_id
		,PAT.disc_mon
		,substr(left(put(PAT.disc_mon, z12.)), 6, 4) as dx_yr
		,substr(left(put(PAT.disc_mon, z12.)), 11, 2) as dx_mon
		,mdy(input(calculated dx_mon, 8.), PAT.disc_mon_seq, input(calculated dx_yr, 8.)) as dx_dt format date9.
		,max(case when ICD.icd_code like ('I63.%') then 1 else 0 end) as AIS
		,max(case when ICD.icd_code like ('I67.1%') then 1 else 0 end) as unruptured
	/*Assume SAH is ruptured aneurysm per https://www.fortherecordmag.com/archives/032811p27.shtml but it also covers ruptured berry aneurysm and ruptured congenital aneurysms*/
		,max(case when ICD.icd_code like ('I60.%') then 1 else 0 end) as ruptured
	/*Assume cerebral atherosclerosis is the same as ICAD*/
		,max(case when ICD.icd_code like ('I67.2%') then 1 else 0 end) as icad
	from raw.str_2017_paticd_diag	ICD
	left join
		 raw.str_2017_pat_noapr	PAT
	on
		 ICD.pat_key = PAT.pat_key
	where ICD.icd_pri_sec in ('P', 'S')
			and (
				ICD.icd_code like ('I63.%') or ICD.icd_code like ('I67.1%') or ICD.icd_code like ('I60.%') or ICD.icd_code like ('I67.2%')
				)
	group by 1, 2, 3

	order by pat_key, medrec_key, dx_dt;
quit;

*Now figure out how many got devices based on CPT codes;
proc sql;
	create table temp.cpt_raw as
	select distinct
		*
	from raw.str_2017_patcpt
	where CPT_code in ('61624', '75894', 'C1757', 'C1887')
	order by pat_key;
quit;

proc sql;
create table temp.hospchg2017 as
	select distinct CDM.hosp_chg_desc,
		CDM.hosp_chg_id
		from raw.str_hospchg	CDM
	where upper(hosp_chg_desc) like ('%C1757%') or upper(hosp_chg_desc) like ('%C1887%') or upper(hosp_chg_desc) like ('%61624%') or upper(hosp_chg_desc) like ('%75894%') ;
quit;

*Look through CPT codes from CDM table;
proc sql;
	create table temp.cdm_cpt as
	select distinct
		PATBILL.*
		,CDM.*
	from raw.str_2017_patbill	PATBILL
	inner join
		temp.hospchg2017 CDM
	on CDM.hosp_chg_id = PATBILL.hosp_chg_id	
	order by pat_key;
quit;

proc sql;
	create table temp.icd_dev as
	select distinct
		*	
		,'NEUROVASCULAR' as indication	

	from raw.str_2017_paticd_proc
	where icd_code like ('03LG3B%') or icd_code like ('03LG3D%') or icd_code like ('03VG3B%') or icd_code like ('03VG3D%') or icd_code like ('03VG3HZ%') or icd_code like ('03VG3DZ%')
		or icd_code in ('03CG3Z7', '03CK3Z7', '03CL3Z7', '03CP3Z7', '03CQ3Z7', '03CG3ZZ', '03CK3ZZ', '03CL3ZZ', '03CP3ZZ',
						'03CQ3ZZ', '03CG3Z7', '03CK3Z7', '03CL3Z7', '03CP3Z7', '03CQ3Z7', 'B31R1ZZ', 'B31RYZZ'
						'3E03317')
	order by pat_key
	;
quit;

*Look through MSDRG;
proc sql;
	create table msdrg as
	select distinct
		pat_key
	from raw.str_2017_pat_noapr 
	where ms_drg in (25, 26, 27, 23, 24, 61, 62, 63, 64, 65, 66)
	order by pat_key
	;
quit;
*Merge all the procedures together;
*Now sort out all the codes and make sure there are no dupications in pat_key;
data temp.proc_patkey;
	set 
		temp.cdm_cpt (in=in1 keep = pat_key serv_day rename=(serv_day=proc_day))
		temp.cpt_raw (in=in2 keep = pat_key)
		temp.icd_dev (in=in3 keep = pat_key proc_day)
		msdrg (in=in4 keep = pat_key)
	;
	*Assume if pulled from CPT dataset that it is outpatient and the day is 0;
	if in2 = 1 then proc_day = 0;
run;


proc sort nodupkey; by pat_key;
run;

proc format;
value inds 0='none'
			1='AIS only'
			2='ICAD only'
			3='AIS, ICAD'
			4='Ruptured only'
			5='AIS, Ruptured'
			6='ICAD, Ruptured'
			7='AIS, ICAD, Ruptured'
			8='Unruptured only'
			9='AIS, Unruptured'
			10='ICAD, Unruptured'
			11='AIS, ICAD, Unruptured'
			12='Ruptured, Unruptured'
			13='AIS, Ruptured, Unruptured'
			14='ICAD, Ruptured, Unruptured'
			15='AIS, ICAD, Ruptured, Unruptured'
			;
value indfive 0='none'
			1='AIS'
			2='ICAD'
			4='Aneurysm, ruptured'
			8='Aneurysm, unruptured'
	   other='Multiple indications';

value fran 1 = 'AIS'
			2 = 'ICAD'
		  4,8 = 'Hemorrhagic'
		other = 'Multiple';
run;




*Now merge the diagnosis data and the procedure data together to come up with the list of discharges that have the NV diagnosis and a procedure;
data phd.dxpx2017;
	merge temp.diagnoses (in=in1)
	      temp.proc_patkey (in=in2);
	length ind_five mult_ind $50;
	by pat_key;
	if in1 = 1 and in2 = 1;
	indications = sum(AIS, 2*icad, 4*ruptured, 8*unruptured);
	mult_ind = put(indications, inds.);
	ind_five = put(indications, indfive.);
	ind_fran = put(indications, fran.);
run;


** NOW GET THE DEVICE NAMES FROM THE CDM DATASET, MAKE SURE TO RESTRICT ON SUPPLY, OR AND RESTRICT ON STANDARDIZED CHARGE CODES ***;
*Join with CDM records and ICD records and PCS records;
proc sql;
	create table phd.devices_2017 as
	select distinct
		CDM.hosp_chg_desc
		,CDM.hosp_chg_id
		,PCS.std_chg_desc
		,PCS.std_chg_code
		,count(distinct COHORT.pat_key) as disc_cnt
	from phd.DXPX2017 COHORT
	inner join
		raw.str_2017_patbill	PATBILL
	on
		PATBILL.pat_key = COHORT.pat_key
	left join
		raw.str_hospchg	CDM
	on
		PATBILL.hosp_chg_id = CDM.hosp_chg_id
	left join
		raw.str_chgmstr	PCS
	on
		PATBILL.std_chg_code = PCS.std_chg_code
	where PCS.sum_dept_desc in ("SUPPLY", "OR") and PCS.std_chg_code in ('270270010000000', '270270028520000', '270270028810000', '270270041710000',
								'270270045610000', '270270045630000', '270270110050000', '270270110280000',
								'270270110720000', '270270112010000', '270270990700000', '270278005210000',
								'270278933710000', '270278995240000', '270278995600000', '270278933710000', '270270010320000', '270270010890000', '270270011610000', '270270011740000',
								'270272927800000', '270272927820000', '270272927840000', '270272930110000', '270270010000000', '270270010320000', '270270010890000', '270270011730000',
								'270272930110000', '270270110720000', '270270010000000', '270270011610000', '270270990700000', '270270045850000', '270270009380000', '270270013100000', 
								'270270990000002', '270272927810000', '270270010320000', '270270110590000', '270272911143000', '270270990120000', '270270028110000', '270270032870000', 
								'270270045820000', '360360372130000', '270270110050000', '270278002650000', '270270026760000', '360360365500000', '270278995240000', '270270026380000', 
								'270278992840000', '270270110060000', '270270110030000', '270270045610000', '270270110850000', '270270012190000', '270270112010000', '270278995700000', 
								'270278995600000', '270278933710000', '270270009270000', '270270011740000', '270270012260000', '270270010890000', '270270011200000', '270270042420000', 
								'270270001010000', '270270104550000', '270270054950000', '270270038890000', '270270002080000', '270270031180000', '270270058900000', '270272927840000', 
								'270272927800000', '270270054930000', '270270029410000', '270270006730000', '270272956400001', '270270101300000', '270270008850000', '270270013160000', 
								'270270009890000', '270270010860000', '270270110430000', '270270011620000', '360360100210000', '270270111780000', '270270028280000', '270270053270000', 
								'270270009160000', '270270009720000', '270270990000001', '270270030270000', '270270042590000', '270270011730000', '270272956380000', '270272927820000', 
								'270270008970000', '270278919730000', '270270002680000', '270270006600000', '270270006610000', '270270006630000', '270270006640000', '270270006650000',
								'270270008850000', '270270008910000', '270270008990000', '270270009070000', '270270009350000', '270270011200000', '270270011750000', '270270014790000',
								'270270014800000', '270270014830000', '270270027840000', '270270028110000', '270270028820000', '270270031360000', '270270032870000', '270270042190000'
								'270270045610000', '270270095090000', '270270110590000', '270270111940000', '270278995240000', '270270990280000', '270270031370000', '270270990530000',
								'250250014060000')

	group by 1
	order by hosp_chg_desc
	;
quit;


data temp.devices1;
	set phd.devices_2017;
	by hosp_chg_desc;
	delim = " ";
*Count the number of words in the text field;
    nwords = countw(hosp_chg_desc, delim);
	array word{*} $ word1-word14;
    do count = 1 to nwords;
        word[count] = scan(hosp_chg_desc, count, delim);
    end;
	if last.hosp_chg_desc then output;
run;

*Now create a macro called wordchka which scans each word to see if it matches for two words;
%macro worchka (keyword = , firstword = , secondword = , name= , franchise = , category = , company = );
	%do j = 0 %to 20 %by 4;
	%let k = %eval(&j * 3);
	%put &j;
	%put &k;
	data devices1;
		length dev_name $30. company_name $30. category $30. franchise $10.;
		set temp.devices1;
		tmpa = soundex(&firstword);
		tmpb = soundex(&secondword);
		%do i = 1 %to 14;
		tmp&i = soundex(upcase(word&i));
		comp1_&i=compged(tmpa, tmp&i);
		comp2_&i=compged(tmpb, tmp&i);
		spedis1_&i=spedis(upcase(word&i), &firstword);
		spedis2_&i=spedis(upcase(word&i), &secondword);
		%end;
	*Now check for any instance where the comged and spedis match for word 1 and word 2;
		array a comp1_1 - comp1_14;
		array b comp2_1 - comp2_14;
		array c spedis1_1 - spedis1_14;
		array d spedis2_1 - spedis2_14;
		do over d;
			if (a le &k) then chk1 = 1;
			if (b le &k) then chk2 = 1;
			if (c le &j) then chk3 = 1;
			if (d le &j) then chk4 = 1;
		end;
		sp = " ";
		if (chk1 = 1 and chk2 = 1 and chk3 = 1 and chk4 = 1) and dev_name = " " then do;
			dev_name = catx(sp, &firstword, &secondword);
			company_name = "&company";
			franchise = "&franchise";
			category = "&category";
		end;
	run;
	%end;
%mend worchka;
%worchka (keyword = 'SOLITAIRE 2', firstword = 'SOLITAIRE', secondword = '2', name = SOLITAIRE 2, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchka (keyword = 'AXS CATALYST 5', firstword = 'AXS', secondword = '5', name = AXS CATALYST 5, franchise = HEM, category=DELIVERY CATHETER HEM, company= STRYKER);
%worchka (keyword = 'CATALYST 5 132CM', firstword = 'CATALYST', secondword = '5', name = CATALYST 5 132CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchka (keyword = 'CATALYST 6 132 CM', firstword = 'CATALYST', secondword = '6', name = CATALYST 6 132 CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchka (keyword = 'CATALYST 7 125CM', firstword = 'CATALYST', secondword = '7', name = CATALYST 7 125CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchka (keyword = 'CATALYST 7 132CM', firstword = 'CATALYST', secondword = '7', name = CATALYST 7 132CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchka (keyword = 'JET 7', firstword = 'JET', secondword = '7', name = JET 7, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchka (keyword = 'JET7/3D', firstword = 'JET7/3D', secondword = '7', name = JET7/3D, franchise = AIS, category=AIS BUNDLE, company= PENUMBRA);
%worchka (keyword = 'FASTRACKER-10', firstword = 'FASTRACKER', secondword = '10', name = FASTRACKER-10, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'GDC-10 2D', firstword = 'GDC', secondword = '10', name = GDC-10 2D, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC-10 360 SOFT SR', firstword = 'GDC', secondword = '10', name = GDC-10 360 SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC-10 360 STANDARD SR', firstword = 'GDC', secondword = '10', name = GDC-10 360 STANDARD SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC-10 3D', firstword = 'GDC', secondword = '10', name = GDC-10 3D, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC�10 SOFT', firstword = 'GDC', secondword = '10', name = GDC�10 SOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC-10 SOFT 2D SR', firstword = 'GDC', secondword = '10', name = GDC-10 SOFT 2D SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC�10 SOFT SR', firstword = 'GDC', secondword = '10', name = GDC�10 SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC�10 ULTRASOFT', firstword = 'GDC', secondword = '10', name = GDC�10 ULTRASOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'EXCELSIOR XT-17 FLEX PRE-SHAPED', firstword = 'EXCELSIOR', secondword = '17', name = EXCELSIOR XT-17 FLEX PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'EXCELSIOR XT-17 FLEX STRAIGHT', firstword = 'EXCELSIOR', secondword = '17', name = EXCELSIOR XT-17 FLEX STRAIGHT, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'EXCELSIOR XT-17 PRE-SHAPED', firstword = 'EXCELSIOR', secondword = '17', name = EXCELSIOR XT-17 PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'FASTRACKER-18', firstword = 'FASTRACKER', secondword = '18', name = FASTRACKER-18, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'FASTRACKER-18 MX', firstword = 'FASTRACKER', secondword = '18', name = FASTRACKER-18 MX, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'FASTRACKER-18 MX 2 TIP', firstword = 'FASTRACKER', secondword = '18', name = FASTRACKER-18 MX 2 TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'GDC-18 2D', firstword = 'GDC', secondword = '18', name = GDC-18 2D, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC-18 360 STANDARD', firstword = 'GDC', secondword = '18', name = GDC-18 360 STANDARD, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC-18 3D', firstword = 'GDC', secondword = '18', name = GDC-18 3D, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC�18 FIBERED VORTX', firstword = 'GDC', secondword = '18', name = GDC�18 FIBERED VORTX, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'GDC-18 SOFT', firstword = 'GDC', secondword = '18', name = GDC-18 SOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'REPERFUSION CATHETER 026', firstword = 'REPERFUSION', secondword = '26', name = REPERFUSION CATHETER 026, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchka (keyword = 'SEPARATOR 026', firstword = 'SEPARATOR', secondword = '26', name = SEPARATOR 026, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchka (keyword = 'SEPARATOR FLEX 026', firstword = 'SEPARATOR', secondword = '26', name = SEPARATOR FLEX 026, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchka (keyword = 'REPERFUSION CATHETER 032', firstword = 'REPERFUSION', secondword = '32', name = REPERFUSION CATHETER 032, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchka (keyword = 'SEPARATOR 032', firstword = 'SEPARATOR', secondword = '32', name = SEPARATOR 032, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchka (keyword = 'SEPARATOR FLEX 032', firstword = 'SEPARATOR', secondword = '32', name = SEPARATOR FLEX 032, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchka (keyword = 'REPERFUSION CATHETER 041', firstword = 'REPERFUSION', secondword = '41', name = REPERFUSION CATHETER 041, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchka (keyword = 'SEPARATOR 041', firstword = 'SEPARATOR', secondword = '41', name = SEPARATOR 041, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchka (keyword = 'SEPARATOR 054', firstword = 'SEPARATOR', secondword = '54', name = SEPARATOR 054, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchka (keyword = 'MATRIX 2 360 SOFT SR', firstword = 'MATRIX', secondword = '360', name = MATRIX 2 360 SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'MATRIX 2 360 STANDARD SR', firstword = 'MATRIX', secondword = '360', name = MATRIX 2 360 STANDARD SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'MATRIX2 360 ULTRASOFT SR', firstword = 'MATRIX', secondword = '360', name = MATRIX2 360 ULTRASOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'MATRIX2 FIRM 360', firstword = 'MATRIX', secondword = '360', name = MATRIX2 FIRM 360, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TARGET 360 NANO', firstword = 'TARGET', secondword = '360', name = TARGET 360 NANO, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TARGET 360 SOFT', firstword = 'TARGET', secondword = '360', name = TARGET 360 SOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TARGET 360 STANDARD', firstword = 'TARGET', secondword = '360', name = TARGET 360 STANDARD, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TARGET 360 ULTRA', firstword = 'TARGET', secondword = '360', name = TARGET 360 ULTRA, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TARGET XL 360 SOFT', firstword = 'TARGET', secondword = '360', name = TARGET XL 360 SOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TARGET XL 360 STANDARD', firstword = 'TARGET', secondword = '360', name = TARGET XL 360 STANDARD, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TARGET XXL 360', firstword = 'TARGET', secondword = '360', name = TARGET XXL 360, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'EXCELSIOR 1018 1-TIP', firstword = 'EXCELSIOR', secondword = '1018', name = EXCELSIOR 1018 1-TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'EXCELSIOR 1018 2-TIP', firstword = 'EXCELSIOR', secondword = '1018', name = EXCELSIOR 1018 2-TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'EXCELSIOR 1018 PRE-SHAPED', firstword = 'EXCELSIOR', secondword = '1018', name = EXCELSIOR 1018 PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'MATRIX2 2D SOFT SR', firstword = 'MATRIX', secondword = '2D', name = MATRIX2 2D SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'MATRIX2 2D STANDARD SR', firstword = 'MATRIX', secondword = '2D', name = MATRIX2 2D STANDARD SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'MATRIX2 FIRM 2D', firstword = 'MATRIX', secondword = '2D', name = MATRIX2 FIRM 2D, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'AXIUM 3D', firstword = 'AXIUM', secondword = '3D', name = AXIUM 3D, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'HYDROSOFT 3D', firstword = 'HYDROSOFT', secondword = '3D', name = HYDROSOFT 3D, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'MATRIX2 3D-OMEGA STANDARD', firstword = 'MATRIX', secondword = '3D', name = MATRIX2 3D-OMEGA STANDARD, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'MATRIX2 FIRM 3D', firstword = 'MATRIX', secondword = '3D', name = MATRIX2 FIRM 3D, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TARGET 3D', firstword = 'TARGET', secondword = '3D', name = TARGET 3D, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'HYDROFRAME ADVANCED-10', firstword = 'HYDROFRAME', secondword = 'ADVANCE', name = HYDROFRAME ADVANCED-10, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'HYDROFRAME ADVANCED-18', firstword = 'HYDROFRAME', secondword = 'ADVANCE', name = HYDROFRAME ADVANCED-18, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'HYDROFRAME COMPLEX', firstword = 'HYDROFRAME', secondword = 'ADVANCE', name = HYDROFRAME COMPLEX, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'HYDROSOFT ADVANCED HELICAL COILS', firstword = 'HYDROSOFT', secondword = 'ADVANCE', name = HYDROSOFT ADVANCED HELICAL COILS, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'HYPERSOFT 3D ADVANCED COMPLEX', firstword = 'HYPERSOFT', secondword = 'ADVANCE', name = HYPERSOFT 3D ADVANCED COMPLEX, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'HYDROFILL ADVANCED', firstword = 'HYDROFILL', secondword = 'ADVANCED', name = HYDROFILL ADVANCED, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'NEUROFORM', firstword = 'NEUROFORM', secondword = 'ATLAS', name = NEUROFORM, franchise = HEM, category=ADJUNCTIVE STENT, company= STRYKER);
%worchka (keyword = 'NEUROFORM', firstword = 'NEUROFORM', secondword = 'ATLAS', name = NEUROFORM, franchise = HEM, category=STENT STABILIZER CATHETER, company= STRYKER);
%worchka (keyword = 'MERCI BALLOON GUIDE', firstword = 'MERCI', secondword = 'BALLOON', name = MERCI BALLOON GUIDE, franchise = AIS, category=BALLOON GUIDE CATHETER, company= STRYKER);
%worchka (keyword = 'LARGE BORE CATHETER', firstword = 'LARGE', secondword = 'BORE', name = LARGE BORE CATHETER, franchise = AIS, category=ASPIRATION CATHETER, company= JOHNSON & JOHNSON);
%worchka (keyword = 'AXS CATALYST 7', firstword = 'AXS', secondword = 'CAT', name = AXS CATALYST 7, franchise = HEM, category=DELIVERY CATHETER HEM, company= STRYKER);
%worchka (keyword = 'DAC', firstword = 'DELIVERY', secondword = 'CATHETER', name = DAC, franchise = HEM, category=DELIVERY CATHETER HEM, company= STRYKER);
%worchka (keyword = 'DAC', firstword = 'DELIVERY', secondword = 'CATHETER', name = DAC, franchise = AIS, category=DELIVERY CATHETER AIS, company= STRYKER);
%worchka (keyword = 'SELECT CATHETER', firstword = 'SELECT', secondword = 'CATHETER', name = SELECT CATHETER, franchise = HEM, category=DIAGNOSTIC CATHETER, company= PENUMBRA);
%worchka (keyword = 'ULTIPAQ CERECYTE 10 FINISH', firstword = 'ULTIPAQ', secondword = 'CERECYTE', name = ULTIPAQ CERECYTE 10 FINISH, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'DETACHABLE COIL CONNECTING CABLE', firstword = 'DETACHABLE', secondword = 'COIL', name = DETACHABLE COIL CONNECTING CABLE, franchise = HEM, category=COIL DETACHMENT DEVICE, company= STRYKER);
%worchka (keyword = 'I-ED COIL10 ', firstword = 'I-ED', secondword = 'COIL', name = I-ED COIL10 , franchise = HEM, category=COIL, company= KANEKA);
%worchka (keyword = 'I-ED COIL14', firstword = 'I-ED', secondword = 'COIL', name = I-ED COIL14, franchise = HEM, category=COIL, company= KANEKA);
%worchka (keyword = 'HYPERSOFT 3D COMPLEX', firstword = 'HYPERSOFT', secondword = 'COMPLEX', name = HYPERSOFT 3D COMPLEX, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'MICROPLEX COMPLEX-10', firstword = 'MICROPLEX', secondword = 'COMPLEX', name = MICROPLEX COMPLEX-10, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'MICROPLEX COMPLEX-18', firstword = 'MICROPLEX', secondword = 'COMPLEX', name = MICROPLEX COMPLEX-18, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'SMARTCOIL EXTRA SOFT COMPLEX', firstword = 'SMARTCOIL', secondword = 'COMPLEX', name = SMARTCOIL EXTRA SOFT COMPLEX, franchise = HEM, category=COIL, company= PENUMBRA);
%worchka (keyword = 'SMARTCOIL SOFT COMPLEX', firstword = 'SMARTCOIL', secondword = 'COMPLEX', name = SMARTCOIL SOFT COMPLEX, franchise = HEM, category=COIL, company= PENUMBRA);
%worchka (keyword = 'TRUFILL DCS ORBIT COMPLEX FILL', firstword = 'TRUFILL', secondword = 'COMPLEX', name = TRUFILL DCS ORBIT COMPLEX FILL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'TRUFILL DCS ORBIT COMPLEX FILL - TIGHT DISTAL LOOP', firstword = 'TRUFILL', secondword = 'COMPLEX', name = TRUFILL DCS ORBIT COMPLEX FILL - TIGHT DISTAL LOOP, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'TRUFILL DCS ORBIT COMPLEX STANDARD', firstword = 'TRUFILL', secondword = 'COMPLEX', name = TRUFILL DCS ORBIT COMPLEX STANDARD, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'TRUFILL DCS ORBIT COMPLEX STANDARD - TIGHT DISTAL LOOP', firstword = 'TRUFILL', secondword = 'COMPLEX', name = TRUFILL DCS ORBIT COMPLEX STANDARD - TIGHT DISTAL LOOP, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'TRUFILL DCS ORBIT MINI COMPLEX FILL', firstword = 'TRUFILL', secondword = 'COMPLEX', name = TRUFILL DCS ORBIT MINI COMPLEX FILL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'TRUFILL DCS ORBIT MINI COMPLEX FILL TDL', firstword = 'TRUFILL', secondword = 'COMPLEX', name = TRUFILL DCS ORBIT MINI COMPLEX FILL TDL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'TRANSFORM COMPLIANT', firstword = 'TRANSFORM', secondword = 'COMPLIANT', name = TRANSFORM COMPLIANT, franchise = HEM, category=REMODELING BALLOONS, company= STRYKER);
%worchka (keyword = 'JET D', firstword = 'JET', secondword = 'D', name = JET D, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchka (keyword = 'SPECTRA DELTAEXTRASOFT', firstword = 'SPECTRA', secondword = 'DELTA', name = SPECTRA DELTAEXTRASOFT, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'SPECTRA DELTAFILL', firstword = 'SPECTRA', secondword = 'DELTA', name = SPECTRA DELTAFILL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'INSTANT DETACHER', firstword = 'INSTANT', secondword = 'DETACHER', name = INSTANT DETACHER, franchise = HEM, category=COIL DETACHMENT DEVICE, company= MEDTRONIC);
%worchka (keyword = 'INZONE DETACHMENT SYSTEM', firstword = 'INZONE', secondword = 'DETACHMENT', name = INZONE DETACHMENT SYSTEM, franchise = HEM, category=COIL DETACHMENT DEVICE, company= STRYKER);
%worchka (keyword = 'HYDROFILL EMBOLIC', firstword = 'HYDROFILL', secondword = 'EMBOLIC', name = HYDROFILL EMBOLIC, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'TRACKER EXCEL- 14', firstword = 'TRACKER', secondword = 'EXCEL ', name = TRACKER EXCEL- 14, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'SOLITAIRE FR REVASCULARIZATION', firstword = 'SOLITAIRE', secondword = 'FR', name = SOLITAIRE FR REVASCULARIZATION, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchka (keyword = 'GALAXY G3', firstword = 'GALAXY', secondword = 'G3', name = GALAXY G3, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'GALAXY G3 XSFT', firstword = 'GALAXY', secondword = 'G3', name = GALAXY G3 XSFT, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'ORBIT GALAXY FILL ', firstword = 'ORBIT', secondword = 'GALAXY', name = ORBIT GALAXY FILL , franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'ORBIT GALAXY FRAME ', firstword = 'ORBIT', secondword = 'GALAXY', name = ORBIT GALAXY FRAME , franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'ORBIT GALAXY XTRASOFT', firstword = 'ORBIT', secondword = 'GALAXY', name = ORBIT GALAXY XTRASOFT, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'ORBIT GALAXY XTRASOFT-HELICAL', firstword = 'ORBIT', secondword = 'GALAXY', name = ORBIT GALAXY XTRASOFT-HELICAL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'SPECTRA GALAXY G3', firstword = 'SPECTRA', secondword = 'GALAXY', name = SPECTRA GALAXY G3, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'SPECTRA GALAXY G3 EXTRASOFT', firstword = 'SPECTRA', secondword = 'GALAXY', name = SPECTRA GALAXY G3 EXTRASOFT, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'AXIUM HELICAL', firstword = 'AXIUM', secondword = 'HELICAL', name = AXIUM HELICAL, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'HYDROCOIL 10 HELICAL', firstword = 'HYDROCOIL', secondword = 'HELICAL', name = HYDROCOIL 10 HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'HYDROCOIL 14 HELICAL', firstword = 'HYDROCOIL', secondword = 'HELICAL', name = HYDROCOIL 14 HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'HYDROCOIL 18 HELICAL', firstword = 'HYDROCOIL', secondword = 'HELICAL', name = HYDROCOIL 18 HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'HYDROSOFT HELICAL', firstword = 'HYDROSOFT', secondword = 'HELICAL', name = HYDROSOFT HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'HYPERSOFT HELICAL', firstword = 'HYPERSOFT', secondword = 'HELICAL', name = HYPERSOFT HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'MATRIX2 HELICAL SOFT SR', firstword = 'MATRIX', secondword = 'HELICAL', name = MATRIX2 HELICAL SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'MATRIX2 HELICAL ULTRASOFT SR', firstword = 'MATRIX', secondword = 'HELICAL', name = MATRIX2 HELICAL ULTRASOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'MICROPLEX HELICAL-10 REGULAR', firstword = 'MICROPLEX', secondword = 'HELICAL', name = MICROPLEX HELICAL-10 REGULAR, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'MICROPLEX HELICAL-10 SOFT', firstword = 'MICROPLEX', secondword = 'HELICAL', name = MICROPLEX HELICAL-10 SOFT, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'MICROPLEX HELICAL-18 REGULAR', firstword = 'MICROPLEX', secondword = 'HELICAL', name = MICROPLEX HELICAL-18 REGULAR, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'MICROPLEX HELICAL-18 SOFT', firstword = 'MICROPLEX', secondword = 'HELICAL', name = MICROPLEX HELICAL-18 SOFT, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'TARGET HELICAL NANO', firstword = 'TARGET', secondword = 'HELICAL', name = TARGET HELICAL NANO, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TARGET HELICAL ULTRA', firstword = 'TARGET', secondword = 'HELICAL', name = TARGET HELICAL ULTRA, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TRUFILL DCS ORBIT HELICAL FILL', firstword = 'TRUFILL', secondword = 'HELICAL', name = TRUFILL DCS ORBIT HELICAL FILL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'RENEGADE HI-FLO (NEURO)', firstword = 'RENEGADE', secondword = 'HI', name = RENEGADE HI-FLO (NEURO), franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'MICROPLEX HYPERSOFT', firstword = 'MICROPLEX', secondword = 'HYPERSOFT', name = MICROPLEX HYPERSOFT, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'MICROPLEX HYPERSOFT ADVANCED', firstword = 'MICROPLEX', secondword = 'HYPERSOFT', name = MICROPLEX HYPERSOFT ADVANCED, franchise = HEM, category=COIL, company= TERUMO);
%worchka (keyword = 'AXS INFINITY LONG SHEATH', firstword = 'AXS', secondword = 'INFINITY', name = AXS INFINITY LONG SHEATH, franchise = AIS, category=LONG SHEATH, company= STRYKER);
%worchka (keyword = 'SPECTRA MICRUSFRAME', firstword = 'SPECTRA', secondword = 'MICRUSFRAME', name = SPECTRA MICRUSFRAME, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'TREVO NXT', firstword = 'TREVO', secondword = 'NXT', name = TREVO NXT, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchka (keyword = 'AXIUM NYLON HELIX', firstword = 'AXIUM', secondword = 'NYLON', name = AXIUM NYLON HELIX, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'AXIUM PGLA 3D', firstword = 'AXIUM', secondword = 'PGLA', name = AXIUM PGLA 3D, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'AXIUM PGLA HELIX', firstword = 'AXIUM', secondword = 'PGLA', name = AXIUM PGLA HELIX, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE PLATINUM', firstword = 'SOLITAIRE', secondword = 'PLATINUM', name = SOLITAIRE PLATINUM, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchka (keyword = 'ULTIPAQ PLATINUM 10 FINISH', firstword = 'ULTIPAQ', secondword = 'PLATINUM', name = ULTIPAQ PLATINUM 10 FINISH, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchka (keyword = 'AXIUM PRIME 3D EXTRA SOFT', firstword = 'AXIUM', secondword = 'PRIME', name = AXIUM PRIME 3D EXTRA SOFT, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'AXIUM PRIME 3D FRAMING', firstword = 'AXIUM', secondword = 'PRIME', name = AXIUM PRIME 3D FRAMING, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'AXIUM PRIME 3D SUPER SOFT', firstword = 'AXIUM', secondword = 'PRIME', name = AXIUM PRIME 3D SUPER SOFT, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'AXIUM PRIME HELIX EXTRA SOFT', firstword = 'AXIUM', secondword = 'PRIME', name = AXIUM PRIME HELIX EXTRA SOFT, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'AXIUM PRIME HELIX SUPER SOFT', firstword = 'AXIUM', secondword = 'PRIME', name = AXIUM PRIME HELIX SUPER SOFT, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchka (keyword = 'TREVO PRO', firstword = 'TREVO', secondword = 'PRO', name = TREVO PRO, franchise = AIS, category=MICROCATHETER AIS, company= STRYKER);
%worchka (keyword = 'TREVO PRO', firstword = 'TREVO', secondword = 'PRO ', name = TREVO PRO, franchise = AIS, category=MICROCATHETER AIS, company= STRYKER);
%worchka (keyword = 'TREVO PROVUE', firstword = 'TREVO', secondword = 'PROVUE', name = TREVO PROVUE, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchka (keyword = 'TREVO XP PROVUE', firstword = 'TREVO', secondword = 'PROVUE', name = TREVO XP PROVUE, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchka (keyword = 'TREVO XP PROVUE SYSTEM', firstword = 'TREVO', secondword = 'PROVUE', name = TREVO XP PROVUE SYSTEM, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchka (keyword = '3D REVASCULARIZATION DEVICE', firstword = '3D', secondword = 'REVASCULARIZATION', name = 3D REVASCULARIZATION DEVICE, franchise = AIS, category=STENTRIEVER, company= PENUMBRA);
%worchka (keyword = '3MAX SEPARATOR', firstword = '3MAX', secondword = 'SEPARATOR', name = 3MAX SEPARATOR, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchka (keyword = '4MAX SEPARATOR', firstword = '4MAX', secondword = 'SEPARATOR', name = 4MAX SEPARATOR, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchka (keyword = 'EXCELSIOR SL-10 PRE-SHAPED', firstword = 'EXCELSIOR', secondword = 'SL', name = EXCELSIOR SL-10 PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'EXCELSIOR SL-10 STRAIGHT 1-TIP', firstword = 'EXCELSIOR', secondword = 'SL', name = EXCELSIOR SL-10 STRAIGHT 1-TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'EXCELSIOR SL-10 STRAIGHT 2-TIP', firstword = 'EXCELSIOR', secondword = 'SL', name = EXCELSIOR SL-10 STRAIGHT 2-TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchka (keyword = 'SMARTCOIL STANDARD', firstword = 'SMARTCOIL', secondword = 'STANDARD', name = SMARTCOIL STANDARD, franchise = HEM, category=COIL, company= PENUMBRA);
%worchka (keyword = 'SURPASS', firstword = 'SURPASS', secondword = 'STREAMLINE', name = SURPASS, franchise = HEM, category=FDS, company= STRYKER);
%worchka (keyword = 'TRANSFORM SUPER COMPLIANT', firstword = 'TRANSFORM', secondword = 'SUPER', name = TRANSFORM SUPER COMPLIANT, franchise = HEM, category=REMODELING BALLOONS, company= STRYKER);
%worchka (keyword = 'TREVO TRAK 21', firstword = 'TREVO', secondword = 'TRAK', name = TREVO TRAK 21, franchise = AIS, category=MICROCATHETER AIS, company= STRYKER);
%worchka (keyword = 'AXS VECTA', firstword = 'AXS', secondword = 'VECTA', name = AXS VECTA, franchise = HEM, category=DELIVERY CATHETER HEM, company= STRYKER);
%worchka (keyword = 'SMARTCOIL WAVE EXTRA SOFT', firstword = 'SMARTCOIL', secondword = 'WAVE', name = SMARTCOIL WAVE EXTRA SOFT, franchise = HEM, category=COIL, company= PENUMBRA);
%worchka (keyword = 'SOLITAIRE', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE FR REVASCULARIZATION', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE FR REVASCULARIZATION, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE X', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE X, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE X/MARKSMAN', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE X/MARKSMAN, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE X/PHENOM21', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE X/PHENOM21, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE X/PHENOM27', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE X/PHENOM27, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE X/REACT68/PHENOM21', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE X/REACT68/PHENOM21, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE X/REACT68/PHENOM27', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE X/REACT68/PHENOM27, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE X/REACT71/PHENOM21', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE X/REACT71/PHENOM21, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchka (keyword = 'SOLITAIRE X/REACT71/PHENOM27', firstword = 'SOLITAIRE', secondword = 'X', name = SOLITAIRE X/REACT71/PHENOM27, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchka (keyword = 'GUIDER XF', firstword = 'GUIDER', secondword = 'XF', name = GUIDER XF, franchise = HEM, category=GUIDE CATHETER, company= STRYKER);
%worchka (keyword = 'TARGET XL HELICAL', firstword = 'TARGET', secondword = 'XL', name = TARGET XL HELICAL, franchise = HEM, category=COIL, company= STRYKER);
%worchka (keyword = 'TREVO XP PROVUE', firstword = 'TREVO', secondword = 'XP', name = TREVO XP PROVUE, franchise = AIS, category=AIS BUNDLE, company= STRYKER);
%worchka (keyword = '10 COMPLEX FINISHING COIL', firstword = 'FINISHING', secondword = 'COIL', name = 10 COMPLEX FINISHING COIL, franchise = HEM, category=COIL, company= BALT);
%worchka (keyword = '10 COMPLEX FRAMING COIL', firstword = 'FINISHING', secondword = 'COIL', name = 10 COMPLEX FRAMING COIL, franchise = HEM, category=COIL, company= BALT);
%worchka (keyword = '10 FILLING COIL', firstword = 'FILLING', secondword = 'COIL', name = 10 FILLING COIL, franchise = HEM, category=COIL, company= BALT);
%worchka (keyword = '10 FINISHING COIL', firstword = 'FINISHING', secondword = 'COIL', name = 10 FINISHING COIL, franchise = HEM, category=COIL, company= BALT);
%worchka (keyword = '10 FRAMING COIL', firstword = 'FRAMING', secondword = 'COIL', name = 10 FRAMING COIL, franchise = HEM, category=COIL, company= BALT);
%worchka (keyword = '10 HELICAL FILLING COIL', firstword = 'FINISHING', secondword = 'COIL', name = 10 HELICAL FILLING COIL, franchise = HEM, category=COIL, company= BALT);
%worchka (keyword = '10 HELICAL FINISHING COIL', firstword = 'FINISHING', secondword = 'COIL', name = 10 HELICAL FINISHING COIL, franchise = HEM, category=COIL, company= BALT);
%worchka (keyword = '18 COMPLEX FRAMING COIL', firstword = 'FINISHING', secondword = 'COIL', name = 18 COMPLEX FRAMING COIL, franchise = HEM, category=COIL, company= BALT);
%worchka (keyword = '18 FRAMING COIL', firstword = 'FRAMING', secondword = 'COIL', name = 18 FRAMING COIL, franchise = HEM, category=COIL, company= BALT);


*Rename the dataset for another round of fuzzy matching;
data devices2;
set devices1;
run;
*Now create a macro called wordchk which scans each word to see if it matches for one word;
%macro worchk (keyword = , oneword = , name= , franchise = , category = , company = );
%do j = 0 %to 20 %by 4;
%let k = %eval(&j * 3);
%put &j;
%put &k;
data phd.devices2;
	length dev_name $30. company_name $30. category $30. franchise $10.;
	set devices2;
	tmp0 = soundex(&oneword);
	%do i = 1 %to 14;
	tmp&i = soundex(upcase(word&i));
	compged&i=compged(tmp0, tmp&i);
	spedis&i=spedis(upcase(word&i), &oneword);
	if (compged&i le &k and spedis&i le &j) and dev_name = " " then do;
		dev_name = &oneword;
		company_name = "&company";
		franchise = "&franchise";
		category = "&category";
	end;
	%end;
run;
%end;
%mend worchk;
%worchk (keyword = 'SOLITAIRE 2', oneword = 'SOLITAIRE', name = SOLITAIRE 2, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchk (keyword = 'AXS CATALYST 5', oneword = 'AXS', name = AXS CATALYST 5, franchise = HEM, category=DELIVERY CATHETER HEM, company= STRYKER);
%worchk (keyword = 'CATALYST 5 132CM', oneword = 'CATALYST', name = CATALYST 5 132CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchk (keyword = 'CATALYST 6 132 CM', oneword = 'CATALYST', name = CATALYST 6 132 CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchk (keyword = 'CATALYST 7 125CM', oneword = 'CATALYST', name = CATALYST 7 125CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchk (keyword = 'CATALYST 7 132CM', oneword = 'CATALYST', name = CATALYST 7 132CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchk (keyword = 'JET 7', oneword = 'JET', name = JET 7, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = 'JET7/3D', oneword = 'JET7/3D', name = JET7/3D, franchise = AIS, category=AIS BUNDLE, company= PENUMBRA);
%worchk (keyword = 'FASTRACKER-10', oneword = 'FASTRACKER', name = FASTRACKER-10, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'GDC-10 2D', oneword = 'GDC', name = GDC-10 2D, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC-10 360 SOFT SR', oneword = 'GDC', name = GDC-10 360 SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC-10 360 STANDARD SR', oneword = 'GDC', name = GDC-10 360 STANDARD SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC-10 3D', oneword = 'GDC', name = GDC-10 3D, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC�10 SOFT', oneword = 'GDC', name = GDC�10 SOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC-10 SOFT 2D SR', oneword = 'GDC', name = GDC-10 SOFT 2D SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC�10 SOFT SR', oneword = 'GDC', name = GDC�10 SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC�10 ULTRASOFT', oneword = 'GDC', name = GDC�10 ULTRASOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'EXCELSIOR XT-17 FLEX PRE-SHAPED', oneword = 'EXCELSIOR', name = EXCELSIOR XT-17 FLEX PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'EXCELSIOR XT-17 FLEX STRAIGHT', oneword = 'EXCELSIOR', name = EXCELSIOR XT-17 FLEX STRAIGHT, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'EXCELSIOR XT-17 PRE-SHAPED', oneword = 'EXCELSIOR', name = EXCELSIOR XT-17 PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'FASTRACKER-18', oneword = 'FASTRACKER', name = FASTRACKER-18, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'FASTRACKER-18 MX', oneword = 'FASTRACKER', name = FASTRACKER-18 MX, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'FASTRACKER-18 MX 2 TIP', oneword = 'FASTRACKER', name = FASTRACKER-18 MX 2 TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'GDC-18 2D', oneword = 'GDC', name = GDC-18 2D, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC-18 360 STANDARD', oneword = 'GDC', name = GDC-18 360 STANDARD, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC-18 3D', oneword = 'GDC', name = GDC-18 3D, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC�18 FIBERED VORTX', oneword = 'GDC', name = GDC�18 FIBERED VORTX, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'GDC-18 SOFT', oneword = 'GDC', name = GDC-18 SOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'REPERFUSION CATHETER 026', oneword = 'REPERFUSION', name = REPERFUSION CATHETER 026, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = 'SEPARATOR 026', oneword = 'SEPARATOR', name = SEPARATOR 026, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'SEPARATOR FLEX 026', oneword = 'SEPARATOR', name = SEPARATOR FLEX 026, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'REPERFUSION CATHETER 032', oneword = 'REPERFUSION', name = REPERFUSION CATHETER 032, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = 'SEPARATOR 032', oneword = 'SEPARATOR', name = SEPARATOR 032, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'SEPARATOR FLEX 032', oneword = 'SEPARATOR', name = SEPARATOR FLEX 032, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'REPERFUSION CATHETER 041', oneword = 'REPERFUSION', name = REPERFUSION CATHETER 041, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = 'SEPARATOR 041', oneword = 'SEPARATOR', name = SEPARATOR 041, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'SEPARATOR 054', oneword = 'SEPARATOR', name = SEPARATOR 054, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'MATRIX 2 360 SOFT SR', oneword = 'MATRIX', name = MATRIX 2 360 SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'MATRIX 2 360 STANDARD SR', oneword = 'MATRIX', name = MATRIX 2 360 STANDARD SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'MATRIX2 360 ULTRASOFT SR', oneword = 'MATRIX', name = MATRIX2 360 ULTRASOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'MATRIX2 FIRM 360', oneword = 'MATRIX', name = MATRIX2 FIRM 360, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TARGET 360 NANO', oneword = 'TARGET', name = TARGET 360 NANO, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TARGET 360 SOFT', oneword = 'TARGET', name = TARGET 360 SOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TARGET 360 STANDARD', oneword = 'TARGET', name = TARGET 360 STANDARD, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TARGET 360 ULTRA', oneword = 'TARGET', name = TARGET 360 ULTRA, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TARGET XL 360 SOFT', oneword = 'TARGET', name = TARGET XL 360 SOFT, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TARGET XL 360 STANDARD', oneword = 'TARGET', name = TARGET XL 360 STANDARD, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TARGET XXL 360', oneword = 'TARGET', name = TARGET XXL 360, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'EXCELSIOR 1018 1-TIP', oneword = 'EXCELSIOR', name = EXCELSIOR 1018 1-TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'EXCELSIOR 1018 2-TIP', oneword = 'EXCELSIOR', name = EXCELSIOR 1018 2-TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'EXCELSIOR 1018 PRE-SHAPED', oneword = 'EXCELSIOR', name = EXCELSIOR 1018 PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'ENVOY 5F', oneword = 'ENVOY', name = ENVOY 5F, franchise = HEM, category=GUIDE CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ENVOY XB 6F', oneword = 'ENVOY', name = ENVOY XB 6F, franchise = HEM, category=GUIDE CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'SOLITAIRE', oneword = 'SOLITAIRE', name = SOLITAIRE, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchk (keyword = 'MATRIX2 2D SOFT SR', oneword = 'MATRIX', name = MATRIX2 2D SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'MATRIX2 2D STANDARD SR', oneword = 'MATRIX', name = MATRIX2 2D STANDARD SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'MATRIX2 FIRM 2D', oneword = 'MATRIX', name = MATRIX2 FIRM 2D, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'AXIUM 3D', oneword = 'AXIUM', name = AXIUM 3D, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'HYDROSOFT 3D', oneword = 'HYDROSOFT', name = HYDROSOFT 3D, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'MATRIX2 3D-OMEGA STANDARD', oneword = 'MATRIX', name = MATRIX2 3D-OMEGA STANDARD, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'MATRIX2 FIRM 3D', oneword = 'MATRIX', name = MATRIX2 FIRM 3D, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TARGET 3D', oneword = 'TARGET', name = TARGET 3D, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'HYDROFRAME ADVANCED-10', oneword = 'HYDROFRAME', name = HYDROFRAME ADVANCED-10, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYDROFRAME ADVANCED-18', oneword = 'HYDROFRAME', name = HYDROFRAME ADVANCED-18, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYDROFRAME COMPLEX', oneword = 'HYDROFRAME', name = HYDROFRAME COMPLEX, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYDROSOFT ADVANCED HELICAL COILS', oneword = 'HYDROSOFT', name = HYDROSOFT ADVANCED HELICAL COILS, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYPERSOFT 3D ADVANCED COMPLEX', oneword = 'HYPERSOFT', name = HYPERSOFT 3D ADVANCED COMPLEX, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYDROFILL ADVANCED', oneword = 'HYDROFILL', name = HYDROFILL ADVANCED, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'NEUROFORM', oneword = 'NEUROFORM', name = NEUROFORM, franchise = HEM, category=ADJUNCTIVE STENT, company= STRYKER);
%worchk (keyword = 'NEUROFORM', oneword = 'NEUROFORM', name = NEUROFORM, franchise = HEM, category=STENT STABILIZER CATHETER, company= STRYKER);
%worchk (keyword = 'MERCI BALLOON GUIDE', oneword = 'MERCI', name = MERCI BALLOON GUIDE, franchise = AIS, category=BALLOON GUIDE CATHETER, company= STRYKER);
%worchk (keyword = 'LARGE BORE CATHETER', oneword = 'LARGE', name = LARGE BORE CATHETER, franchise = AIS, category=ASPIRATION CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'AXS CATALYST 7', oneword = 'AXS', name = AXS CATALYST 7, franchise = HEM, category=DELIVERY CATHETER HEM, company= STRYKER);
%worchk (keyword = 'DAC', oneword = 'DELIVERY', name = DAC, franchise = HEM, category=DELIVERY CATHETER HEM, company= STRYKER);
%worchk (keyword = 'DAC', oneword = 'DELIVERY', name = DAC, franchise = AIS, category=DELIVERY CATHETER AIS, company= STRYKER);
%worchk (keyword = 'SELECT CATHETER', oneword = 'SELECT', name = SELECT CATHETER, franchise = HEM, category=DIAGNOSTIC CATHETER, company= PENUMBRA);
%worchk (keyword = 'ULTIPAQ CERECYTE 10 FINISH', oneword = 'ULTIPAQ', name = ULTIPAQ CERECYTE 10 FINISH, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'I-ED COIL10 ', oneword = 'I-ED', name = I-ED COIL10 , franchise = HEM, category=COIL, company= KANEKA);
%worchk (keyword = 'I-ED COIL14', oneword = 'I-ED', name = I-ED COIL14, franchise = HEM, category=COIL, company= KANEKA);
%worchk (keyword = 'HYPERSOFT 3D COMPLEX', oneword = 'HYPERSOFT', name = HYPERSOFT 3D COMPLEX, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'MICROPLEX COMPLEX-10', oneword = 'MICROPLEX', name = MICROPLEX COMPLEX-10, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'MICROPLEX COMPLEX-18', oneword = 'MICROPLEX', name = MICROPLEX COMPLEX-18, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'SMARTCOIL EXTRA SOFT COMPLEX', oneword = 'SMARTCOIL', name = SMARTCOIL EXTRA SOFT COMPLEX, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'SMARTCOIL SOFT COMPLEX', oneword = 'SMARTCOIL', name = SMARTCOIL SOFT COMPLEX, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'TRUFILL DCS ORBIT COMPLEX FILL', oneword = 'TRUFILL', name = TRUFILL DCS ORBIT COMPLEX FILL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRUFILL DCS ORBIT COMPLEX FILL - TIGHT DISTAL LOOP', oneword = 'TRUFILL', name = TRUFILL DCS ORBIT COMPLEX FILL - TIGHT DISTAL LOOP, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRUFILL DCS ORBIT COMPLEX STANDARD', oneword = 'TRUFILL', name = TRUFILL DCS ORBIT COMPLEX STANDARD, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRUFILL DCS ORBIT COMPLEX STANDARD - TIGHT DISTAL LOOP', oneword = 'TRUFILL', name = TRUFILL DCS ORBIT COMPLEX STANDARD - TIGHT DISTAL LOOP, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRUFILL DCS ORBIT MINI COMPLEX FILL', oneword = 'TRUFILL', name = TRUFILL DCS ORBIT MINI COMPLEX FILL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRUFILL DCS ORBIT MINI COMPLEX FILL TDL', oneword = 'TRUFILL', name = TRUFILL DCS ORBIT MINI COMPLEX FILL TDL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRANSFORM COMPLIANT', oneword = 'TRANSFORM', name = TRANSFORM COMPLIANT, franchise = HEM, category=REMODELING BALLOONS, company= STRYKER);
%worchk (keyword = 'JET D', oneword = 'JET', name = JET D, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = 'SPECTRA DELTAEXTRASOFT', oneword = 'SPECTRA', name = SPECTRA DELTAEXTRASOFT, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'SPECTRA DELTAFILL', oneword = 'SPECTRA', name = SPECTRA DELTAFILL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'INSTANT DETACHER', oneword = 'INSTANT', name = INSTANT DETACHER, franchise = HEM, category=COIL DETACHMENT DEVICE, company= MEDTRONIC);
%worchk (keyword = 'INZONE DETACHMENT SYSTEM', oneword = 'INZONE', name = INZONE DETACHMENT SYSTEM, franchise = HEM, category=COIL DETACHMENT DEVICE, company= STRYKER);
%worchk (keyword = 'HYDROFILL EMBOLIC', oneword = 'HYDROFILL', name = HYDROFILL EMBOLIC, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'TRACKER EXCEL- 14', oneword = 'TRACKER', name = TRACKER EXCEL- 14, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'SOLITAIRE FR REVASCULARIZATION', oneword = 'SOLITAIRE', name = SOLITAIRE FR REVASCULARIZATION, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchk (keyword = 'GALAXY G3', oneword = 'GALAXY', name = GALAXY G3, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'GALAXY G3 XSFT', oneword = 'GALAXY', name = GALAXY G3 XSFT, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ORBIT GALAXY FILL ', oneword = 'ORBIT', name = ORBIT GALAXY FILL , franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ORBIT GALAXY FRAME ', oneword = 'ORBIT', name = ORBIT GALAXY FRAME , franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ORBIT GALAXY XTRASOFT', oneword = 'ORBIT', name = ORBIT GALAXY XTRASOFT, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ORBIT GALAXY XTRASOFT-HELICAL', oneword = 'ORBIT', name = ORBIT GALAXY XTRASOFT-HELICAL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'SPECTRA GALAXY G3', oneword = 'SPECTRA', name = SPECTRA GALAXY G3, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'SPECTRA GALAXY G3 EXTRASOFT', oneword = 'SPECTRA', name = SPECTRA GALAXY G3 EXTRASOFT, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'AXIUM HELICAL', oneword = 'AXIUM', name = AXIUM HELICAL, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'HYDROCOIL 10 HELICAL', oneword = 'HYDROCOIL', name = HYDROCOIL 10 HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYDROCOIL 14 HELICAL', oneword = 'HYDROCOIL', name = HYDROCOIL 14 HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYDROCOIL 18 HELICAL', oneword = 'HYDROCOIL', name = HYDROCOIL 18 HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYDROSOFT HELICAL', oneword = 'HYDROSOFT', name = HYDROSOFT HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYPERSOFT HELICAL', oneword = 'HYPERSOFT', name = HYPERSOFT HELICAL, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'MATRIX2 HELICAL SOFT SR', oneword = 'MATRIX', name = MATRIX2 HELICAL SOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'MATRIX2 HELICAL ULTRASOFT SR', oneword = 'MATRIX', name = MATRIX2 HELICAL ULTRASOFT SR, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'MICROPLEX HELICAL-10 REGULAR', oneword = 'MICROPLEX', name = MICROPLEX HELICAL-10 REGULAR, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'MICROPLEX HELICAL-10 SOFT', oneword = 'MICROPLEX', name = MICROPLEX HELICAL-10 SOFT, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'MICROPLEX HELICAL-18 REGULAR', oneword = 'MICROPLEX', name = MICROPLEX HELICAL-18 REGULAR, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'MICROPLEX HELICAL-18 SOFT', oneword = 'MICROPLEX', name = MICROPLEX HELICAL-18 SOFT, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'TARGET HELICAL NANO', oneword = 'TARGET', name = TARGET HELICAL NANO, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TARGET HELICAL ULTRA', oneword = 'TARGET', name = TARGET HELICAL ULTRA, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TRUFILL DCS ORBIT HELICAL FILL', oneword = 'TRUFILL', name = TRUFILL DCS ORBIT HELICAL FILL, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'RENEGADE HI-FLO (NEURO)', oneword = 'RENEGADE', name = RENEGADE HI-FLO (NEURO), franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'MICROPLEX HYPERSOFT', oneword = 'MICROPLEX', name = MICROPLEX HYPERSOFT, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'MICROPLEX HYPERSOFT ADVANCED', oneword = 'MICROPLEX', name = MICROPLEX HYPERSOFT ADVANCED, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'AXS INFINITY LONG SHEATH', oneword = 'AXS', name = AXS INFINITY LONG SHEATH, franchise = AIS, category=LONG SHEATH, company= STRYKER);
%worchk (keyword = 'SPECTRA MICRUSFRAME', oneword = 'SPECTRA', name = SPECTRA MICRUSFRAME, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TREVO NXT', oneword = 'TREVO', name = TREVO NXT, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchk (keyword = 'AXIUM NYLON HELIX', oneword = 'AXIUM', name = AXIUM NYLON HELIX, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'AXIUM PGLA 3D', oneword = 'AXIUM', name = AXIUM PGLA 3D, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'AXIUM PGLA HELIX', oneword = 'AXIUM', name = AXIUM PGLA HELIX, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'SOLITAIRE PLATINUM', oneword = 'SOLITAIRE', name = SOLITAIRE PLATINUM, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchk (keyword = 'ULTIPAQ PLATINUM 10 FINISH', oneword = 'ULTIPAQ', name = ULTIPAQ PLATINUM 10 FINISH, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'AXIUM PRIME 3D EXTRA SOFT', oneword = 'AXIUM', name = AXIUM PRIME 3D EXTRA SOFT, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'AXIUM PRIME 3D FRAMING', oneword = 'AXIUM', name = AXIUM PRIME 3D FRAMING, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'AXIUM PRIME 3D SUPER SOFT', oneword = 'AXIUM', name = AXIUM PRIME 3D SUPER SOFT, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'AXIUM PRIME HELIX EXTRA SOFT', oneword = 'AXIUM', name = AXIUM PRIME HELIX EXTRA SOFT, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'AXIUM PRIME HELIX SUPER SOFT', oneword = 'AXIUM', name = AXIUM PRIME HELIX SUPER SOFT, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'TREVO PRO', oneword = 'TREVO', name = TREVO PRO, franchise = AIS, category=MICROCATHETER AIS, company= STRYKER);
%worchk (keyword = 'TREVO PROVUE', oneword = 'TREVO', name = TREVO PROVUE, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchk (keyword = 'TREVO XP PROVUE', oneword = 'TREVO', name = TREVO XP PROVUE, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchk (keyword = 'TREVO XP PROVUE SYSTEM', oneword = 'TREVO', name = TREVO XP PROVUE SYSTEM, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchk (keyword = '3D REVASCULARIZATION DEVICE', oneword = '3D', name = 3D REVASCULARIZATION DEVICE, franchise = AIS, category=STENTRIEVER, company= PENUMBRA);
%worchk (keyword = '3MAX SEPARATOR', oneword = '3MAX', name = 3MAX SEPARATOR, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = '4MAX SEPARATOR', oneword = '4MAX', name = 4MAX SEPARATOR, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'EXCELSIOR SL-10 PRE-SHAPED', oneword = 'EXCELSIOR', name = EXCELSIOR SL-10 PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'EXCELSIOR SL-10 STRAIGHT 1-TIP', oneword = 'EXCELSIOR', name = EXCELSIOR SL-10 STRAIGHT 1-TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'EXCELSIOR SL-10 STRAIGHT 2-TIP', oneword = 'EXCELSIOR', name = EXCELSIOR SL-10 STRAIGHT 2-TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'SMARTCOIL STANDARD', oneword = 'SMARTCOIL', name = SMARTCOIL STANDARD, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'SURPASS', oneword = 'SURPASS', name = SURPASS, franchise = HEM, category=FDS, company= STRYKER);
%worchk (keyword = 'TRANSFORM SUPER COMPLIANT', oneword = 'TRANSFORM', name = TRANSFORM SUPER COMPLIANT, franchise = HEM, category=REMODELING BALLOONS, company= STRYKER);
%worchk (keyword = 'TREVO TRAK 21', oneword = 'TREVO', name = TREVO TRAK 21, franchise = AIS, category=MICROCATHETER AIS, company= STRYKER);
%worchk (keyword = 'AXS VECTA', oneword = 'AXS', name = AXS VECTA, franchise = HEM, category=DELIVERY CATHETER HEM, company= STRYKER);
%worchk (keyword = 'SMARTCOIL WAVE EXTRA SOFT', oneword = 'SMARTCOIL', name = SMARTCOIL WAVE EXTRA SOFT, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'SOLITAIRE X', oneword = 'SOLITAIRE', name = SOLITAIRE X, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchk (keyword = 'SOLITAIRE X/MARKSMAN', oneword = 'SOLITAIRE', name = SOLITAIRE X/MARKSMAN, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'SOLITAIRE X/PHENOM21', oneword = 'SOLITAIRE', name = SOLITAIRE X/PHENOM21, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'SOLITAIRE X/PHENOM27', oneword = 'SOLITAIRE', name = SOLITAIRE X/PHENOM27, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'SOLITAIRE X/REACT68/PHENOM21', oneword = 'SOLITAIRE', name = SOLITAIRE X/REACT68/PHENOM21, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'SOLITAIRE X/REACT68/PHENOM27', oneword = 'SOLITAIRE', name = SOLITAIRE X/REACT68/PHENOM27, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'SOLITAIRE X/REACT71/PHENOM21', oneword = 'SOLITAIRE', name = SOLITAIRE X/REACT71/PHENOM21, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'SOLITAIRE X/REACT71/PHENOM27', oneword = 'SOLITAIRE', name = SOLITAIRE X/REACT71/PHENOM27, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'GUIDER XF', oneword = 'GUIDER', name = GUIDER XF, franchise = HEM, category=GUIDE CATHETER, company= STRYKER);
%worchk (keyword = 'TARGET XL HELICAL', oneword = 'TARGET', name = TARGET XL HELICAL, franchise = HEM, category=COIL, company= STRYKER);
%worchk (keyword = 'TREVO XP PROVUE', oneword = 'TREVO', name = TREVO XP PROVUE, franchise = AIS, category=AIS BUNDLE, company= STRYKER);
%worchk (keyword = '3MAX', oneword = '3MAX', name = 3MAX, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = '4MAX', oneword = '4MAX', name = 4MAX, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = '5MAX', oneword = '5MAX', name = 5MAX, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = '5MAX ACE', oneword = '5MAX', name = 5MAX ACE, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = '5MAX ACE 060', oneword = '5MAX', name = 5MAX ACE 060, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = '5MAX ACE 064', oneword = '5MAX', name = 5MAX ACE 064, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = '5MAX ACE 068', oneword = '5MAX', name = 5MAX ACE 068, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = '5MAX ACE KIT', oneword = '5MAX', name = 5MAX ACE KIT, franchise = AIS, category=ASPIRATION CATHETER, company= PENUMBRA);
%worchk (keyword = '5MAX SEPARATOR', oneword = '5MAX', name = 5MAX SEPARATOR, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'ACCERO', oneword = 'ACCERO', name = ACCERO, franchise = AIS, category=STENTRIEVER, company= ACANDIS);
%worchk (keyword = 'ACE 060/3D', oneword = 'ACE', name = ACE 060/3D, franchise = AIS, category=AIS BUNDLE, company= PENUMBRA);
%worchk (keyword = 'AGILITY', oneword = 'AGILITY', name = AGILITY, franchise = HEM, category=GUIDEWIRE, company= JOHNSON & JOHNSON);
%worchk (keyword = 'APOLLO', oneword = 'APOLLO', name = APOLLO, franchise = HEM, category=LIQUID EMBOLICS, company= MEDTRONIC);
%worchk (keyword = 'APOLLO SYSTEM', oneword = 'APOLLO', name = APOLLO SYSTEM, franchise = HEM, category=ICH DEVICES, company= PENUMBRA);
%worchk (keyword = 'APOLLO TUBING', oneword = 'APOLLO', name = APOLLO TUBING, franchise = HEM, category=ICH DEVICES, company= PENUMBRA);
%worchk (keyword = 'APOLLO WAND', oneword = 'APOLLO', name = APOLLO WAND, franchise = HEM, category=ICH DEVICES, company= PENUMBRA);
%worchk (keyword = 'ARC', oneword = 'ARC', name = ARC, franchise = AIS, category=DELIVERY CATHETER AIS, company= MEDTRONIC);
%worchk (keyword = 'ARC MINI', oneword = 'ARC', name = ARC MINI, franchise = AIS, category=DELIVERY CATHETER AIS, company= MEDTRONIC);
%worchk (keyword = 'ARISTOTLE 14', oneword = 'ARISTOTLE', name = ARISTOTLE 14, franchise = HEM, category=GUIDEWIRE, company= SCIENTIA);
%worchk (keyword = 'ARISTOTLE 18', oneword = 'ARISTOTLE', name = ARISTOTLE 18, franchise = HEM, category=GUIDEWIRE, company= SCIENTIA);
%worchk (keyword = 'ARISTOTLE 24', oneword = 'ARISTOTLE', name = ARISTOTLE 24, franchise = HEM, category=GUIDEWIRE, company= SCIENTIA);
%worchk (keyword = 'ARTEMIS', oneword = 'ARTEMIS', name = ARTEMIS, franchise = ICH, category=ICH DEVICES, company= PENUMBRA);
%worchk (keyword = 'ASCENT', oneword = 'ASCENT', name = ASCENT, franchise = HEM, category=REMODELING BALLOONS, company= JOHNSON & JOHNSON);
%worchk (keyword = 'AVENIR', oneword = 'AVENIR', name = AVENIR, franchise = HEM, category=COIL, company= WALLABY);
%worchk (keyword = 'AVIGO', oneword = 'AVIGO', name = AVIGO, franchise = HEM, category=GUIDEWIRE, company= MEDTRONIC);
%worchk (keyword = 'AXS INFINITY LONG SHEATH', oneword = 'INFINITY', name = AXS INFINITY LONG SHEATH, franchise = AIS, category=LONG SHEATH, company= STRYKER);
%worchk (keyword = 'AXS UNIVERSAL', oneword = 'AXS', name = AXS UNIVERSAL, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= STRYKER);
%worchk (keyword = 'BALLAST 088', oneword = 'BALLAST', name = BALLAST 088, franchise = AIS, category=LONG SHEATH, company= BALT);
%worchk (keyword = 'BENCHMARK 071', oneword = 'BENCHMARK', name = BENCHMARK 071, franchise = HEM, category=GUIDE CATHETER, company= PENUMBRA);
%worchk (keyword = 'BENCHMARK 071 KIT', oneword = 'BENCHMARK', name = BENCHMARK 071 KIT, franchise = HEM, category=GUIDE CATHETER, company= PENUMBRA);
%worchk (keyword = 'BRAINPATH APPROACH', oneword = 'BRAINPATH', name = BRAINPATH APPROACH, franchise = ICH, category=ICH DEVICES, company= NICO);
%worchk (keyword = 'CAPTURE', oneword = 'CAPTURE', name = CAPTURE, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchk (keyword = 'CELLO', oneword = 'CELLO', name = CELLO, franchise = AIS, category=BALLOON GUIDE CATHETER, company= MEDTRONIC);
%worchk (keyword = 'CHAPERON', oneword = 'CHAPERON', name = CHAPERON, franchise = HEM, category=GUIDE CATHETER, company= TERUMO);
%worchk (keyword = 'CHIKAI', oneword = 'CHIKAI', name = CHIKAI, franchise = HEM, category=GUIDEWIRE, company= ASAHI INTECC);
%worchk (keyword = 'CHIKAI ', oneword = 'CHIKAI', name = CHIKAI , franchise = HEM, category=GUIDEWIRE, company= ASAHI INTECC);
%worchk (keyword = 'CLIQ', oneword = 'CLIQ', name = CLIQ, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= STRYKER);
%worchk (keyword = 'COIL 400 COMPLEX EXTRA SOFT', oneword = 'COIL400', name = COIL 400 COMPLEX EXTRA SOFT, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'COIL 400 COMPLEX SOFT', oneword = 'COIL400', name = COIL 400 COMPLEX SOFT, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'COIL 400 COMPLEX STANDARD', oneword = 'COIL400', name = COIL 400 COMPLEX STANDARD, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'COIL 400 CURVE EXTRA SOFT', oneword = 'COIL400', name = COIL 400 CURVE EXTRA SOFT, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'COIL 400 J SOFT', oneword = 'COIL400', name = COIL 400 J SOFT, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'COMANECI', oneword = 'COMANECI', name = COMANECI, franchise = HEM, category=ADJUNCTIVE STENT, company= RAPID MEDICAL);
%worchk (keyword = 'COMANECI 17', oneword = 'COMANECI', name = COMANECI 17, franchise = HEM, category=ADJUNCTIVE STENT, company= RAPID MEDICAL);
%worchk (keyword = 'COMANECI PETIT', oneword = 'COMANECI', name = COMANECI PETIT, franchise = HEM, category=ADJUNCTIVE STENT, company= RAPID MEDICAL);
%worchk (keyword = 'COMPASS', oneword = 'COMPASS', name = COMPASS, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'CONCENTRIC', oneword = 'CONCENTRIC', name = CONCENTRIC, franchise = AIS, category=BALLOON GUIDE CATHETER, company= STRYKER);
%worchk (keyword = 'CONNECTING CABLE', oneword = 'CONNECTING', name = CONNECTING CABLE, franchise = HEM, category=COIL DETACHMENT DEVICE, company= JOHNSON & JOHNSON);
%worchk (keyword = 'COSMOS ADVANCED-10', oneword = 'COSMOS', name = COSMOS ADVANCED-10, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'COSMOS ADVANCED-18', oneword = 'COSMOS', name = COSMOS ADVANCED-18, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'COSMOS COMPLEX-10', oneword = 'COSMOS', name = COSMOS COMPLEX-10, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'COSMOS COMPLEX-18', oneword = 'COSMOS', name = COSMOS COMPLEX-18, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'COURIER', oneword = 'COURIER', name = COURIER, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'COURIER ENZO', oneword = 'COURIER', name = COURIER ENZO, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'DELTAFILL 10', oneword = 'DELTAFILL', name = DELTAFILL 10, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'DELTAFILL 18', oneword = 'DELTAFILL', name = DELTAFILL 18, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'DELTAXSFT 10', oneword = 'DELTAXSFT', name = DELTAXSFT 10, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'DETACHMENT BOX', oneword = 'DETACHMENT', name = DETACHMENT BOX, franchise = HEM, category=COIL DETACHMENT DEVICE, company= BALT);
%worchk (keyword = 'DETACHMENT HANDLE', oneword = 'DETACHMENT', name = DETACHMENT HANDLE, franchise = HEM, category=COIL DETACHMENT DEVICE, company= PENUMBRA);
%worchk (keyword = 'ECHELON 10', oneword = 'ECHELON', name = ECHELON 10, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'ECHELON 10 STRAIGHT', oneword = 'ECHELON', name = ECHELON 10 STRAIGHT, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'ECHELON 14', oneword = 'ECHELON', name = ECHELON 14, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'ECHELON 14 STRAIGHT', oneword = 'ECHELON', name = ECHELON 14 STRAIGHT, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'ELECTRO DETACH GENERATOR V4', oneword = 'ELECTRO', name = ELECTRO DETACH GENERATOR V4, franchise = HEM, category=COIL DETACHMENT DEVICE, company= KANEKA);
%worchk (keyword = 'EMBOTRAP', oneword = 'EMBOTRAP', name = EMBOTRAP, franchise = AIS, category=STENTRIEVER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ENGINE', oneword = 'ENGINE', name = ENGINE, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'ENPOWER CONTROL CABLE', oneword = 'ENPOWER', name = ENPOWER CONTROL CABLE, franchise = HEM, category=COIL DETACHMENT DEVICE, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ENPOWER DETACHMENT CONTROL BOX', oneword = 'ENPOWER', name = ENPOWER DETACHMENT CONTROL BOX, franchise = HEM, category=COIL DETACHMENT DEVICE, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ENTERPRISE', oneword = 'ENTERPRISE', name = ENTERPRISE, franchise = HEM, category=ADJUNCTIVE STENT, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ENVOY 6F', oneword = 'ENVOY', name = ENVOY 6F, franchise = HEM, category=GUIDE CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ENVOY 7F', oneword = 'ENVOY', name = ENVOY 7F, franchise = HEM, category=GUIDE CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ENVOY DA 6F', oneword = 'ENVOY', name = ENVOY DA 6F, franchise = HEM, category=GUIDE CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'ENVOY DA XB 6F', oneword = 'ENVOY', name = ENVOY DA XB 6F, franchise = HEM, category=GUIDE CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'EXCELSIOR XT-27 FLEX PRE-SHAPED', oneword = 'EXCELSIOR', name = EXCELSIOR XT-27 FLEX PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'EXCELSIOR XT-27 FLEX STRAIGHT', oneword = 'EXCELSIOR', name = EXCELSIOR XT-27 FLEX STRAIGHT, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'EXCELSIOR XT-27 PRE-SHAPED', oneword = 'EXCELSIOR', name = EXCELSIOR XT-27 PRE-SHAPED, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'EXCELSIOR XT-27 STRAIGHT', oneword = 'EXCELSIOR', name = EXCELSIOR XT-27 STRAIGHT, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'FARGO', oneword = 'FARGO', name = FARGO, franchise = HEM, category=GUIDE CATHETER, company= BALT);
%worchk (keyword = 'FARGOMAX', oneword = 'FARGOMAX', name = FARGOMAX, franchise = HEM, category=GUIDE CATHETER, company= BALT);
%worchk (keyword = 'FARGOMINI', oneword = 'FARGOMINI', name = FARGOMINI, franchise = HEM, category=GUIDE CATHETER, company= BALT);
%worchk (keyword = 'FASTRACKER-18', oneword = 'FASTRACKER-18', name = FASTRACKER-18, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'FLOWGATE', oneword = 'FLOWGATE', name = FLOWGATE, franchise = AIS, category=BALLOON GUIDE CATHETER, company= STRYKER);
%worchk (keyword = 'FRED', oneword = 'FRED', name = FRED, franchise = HEM, category=FDS, company= TERUMO);
%worchk (keyword = 'FUBUKI', oneword = 'FUBUKI', name = FUBUKI, franchise = HEM, category=GUIDE CATHETER, company= ASAHI INTECC);
%worchk (keyword = 'FUBUKI 043', oneword = 'FUBUKI', name = FUBUKI 043, franchise = HEM, category=GUIDE CATHETER, company= ASAHI INTECC);
%worchk (keyword = 'GALAXY G3 MINI', oneword = 'GALAXY', name = GALAXY G3 MINI, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'GATEWAY', oneword = 'GATEWAY', name = GATEWAY, franchise = ICAD, category=ANGIOPLASTY BALLOON, company= STRYKER);
%worchk (keyword = 'GLIDESHEATH SLENDER', oneword = 'GLIDESHEATH', name = GLIDESHEATH SLENDER, franchise = HEM, category=SHEATH, company= TERUMO);
%worchk (keyword = 'GLIDEWIRE', oneword = 'GLIDEWIRE', name = GLIDEWIRE, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'GLIDEWIRE GOLD 11', oneword = 'GLIDEWIRE', name = GLIDEWIRE GOLD 11, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'GLIDEWIRE GOLD 14', oneword = 'GLIDEWIRE', name = GLIDEWIRE GOLD 14, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'GLIDEWIRE GOLD 16', oneword = 'GLIDEWIRE', name = GLIDEWIRE GOLD 16, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'GLIDEWIRE GOLD 18', oneword = 'GLIDEWIRE', name = GLIDEWIRE GOLD 18, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'HANDHELD DETACHMENT CABLE', oneword = 'HANDHELD', name = HANDHELD DETACHMENT CABLE, franchise = HEM, category=COIL DETACHMENT DEVICE, company= BALT);
%worchk (keyword = 'HEADLINER 12', oneword = 'HEADLINER', name = HEADLINER 12, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'HEADLINER 14', oneword = 'HEADLINER', name = HEADLINER 14, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'HEADLINER 16', oneword = 'HEADLINER', name = HEADLINER 16, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'HEADWAY 17 ADVANCED', oneword = 'HEADWAY', name = HEADWAY 17 ADVANCED, franchise = HEM, category=MICROCATHETER HEM, company= TERUMO);
%worchk (keyword = 'HEADWAY 21', oneword = 'HEADWAY', name = HEADWAY 21, franchise = HEM, category=MICROCATHETER HEM, company= TERUMO);
%worchk (keyword = 'HEADWAY 27', oneword = 'HEADWAY', name = HEADWAY 27, franchise = HEM, category=MICROCATHETER HEM, company= TERUMO);
%worchk (keyword = 'HEADWAY DUO 156', oneword = 'HEADWAY', name = HEADWAY DUO 156, franchise = HEM, category=MICROCATHETER HEM, company= TERUMO);
%worchk (keyword = 'HEADWAY DUO 167', oneword = 'HEADWAY', name = HEADWAY DUO 167, franchise = HEM, category=MICROCATHETER HEM, company= TERUMO);
%worchk (keyword = 'HELIPAQ', oneword = 'HELIPAQ', name = HELIPAQ, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'HELIPAQ 10', oneword = 'HELIPAQ', name = HELIPAQ 10, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'HELIPAQ 18', oneword = 'HELIPAQ', name = HELIPAQ 18, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'HYBRID', oneword = 'HYBRID', name = HYBRID, franchise = HEM, category=GUIDEWIRE, company= BALT);
%worchk (keyword = 'HYDROCOIL', oneword = 'HYDROCOIL', name = HYDROCOIL, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYDROSOFT', oneword = 'HYDROSOFT', name = HYDROSOFT, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYDROSOFT, V-TRAK ADVANCED COILS', oneword = 'HYDROSOFT,', name = HYDROSOFT, V-TRAK ADVANCED COILS, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'HYPERFORM', oneword = 'HYPERFORM', name = HYPERFORM, franchise = HEM, category=REMODELING BALLOONS, company= MEDTRONIC);
%worchk (keyword = 'HYPERGLIDE', oneword = 'HYPERGLIDE', name = HYPERGLIDE, franchise = HEM, category=REMODELING BALLOONS, company= MEDTRONIC);
%worchk (keyword = 'LVIS', oneword = 'LVIS', name = LVIS, franchise = HEM, category=ADJUNCTIVE STENT, company= TERUMO);
%worchk (keyword = 'MAGIC', oneword = 'MAGIC', name = MAGIC, franchise = HEM, category=MICROCATHETER HEM, company= BALT);
%worchk (keyword = 'MARATHON', oneword = 'MARATHON', name = MARATHON, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'MARKSMAN', oneword = 'MARKSMAN', name = MARKSMAN, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'MARKSMAN 160 CM', oneword = 'MARKSMAN', name = MARKSMAN 160 CM, franchise = AIS, category=MICROCATHETER AIS, company= MEDTRONIC);
%worchk (keyword = 'MAX', oneword = 'MAX', name = MAX, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= PENUMBRA);
%worchk (keyword = 'MEDELA DOMINANT FLEX', oneword = 'MEDELA', name = MEDELA DOMINANT FLEX, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= STRYKER);
%worchk (keyword = 'MERCI', oneword = 'MERCI', name = MERCI, franchise = AIS, category=MICROCATHETER AIS, company= STRYKER);
%worchk (keyword = 'MERCI', oneword = 'MERCI', name = MERCI, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchk (keyword = 'MERCI MICROCATHETER 14X', oneword = 'MERCI', name = MERCI MICROCATHETER 14X, franchise = AIS, category=MICROCATHETER AIS, company= STRYKER);
%worchk (keyword = 'MERCI MICROCATHETER 18 PLUS', oneword = 'MERCI', name = MERCI MICROCATHETER 18 PLUS, franchise = AIS, category=MICROCATHETER AIS, company= STRYKER);
%worchk (keyword = 'MERCI MICROCATHETER 18L', oneword = 'MERCI', name = MERCI MICROCATHETER 18L, franchise = AIS, category=MICROCATHETER AIS, company= STRYKER);
%worchk (keyword = 'MI-AXUS SUPER 90 GUIDE CATHETER', oneword = 'MI-AXUS', name = MI-AXUS SUPER 90 GUIDE CATHETER, franchise = AIS, category=LONG SHEATH, company= MIVI NEUROSCIENCE);
%worchk (keyword = 'MICRUSFRAME', oneword = 'MICRUSFRAME', name = MICRUSFRAME, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'MICRUSFRAME C 14', oneword = 'MICRUSFRAME', name = MICRUSFRAME C 14, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'MICRUSFRAME S 10', oneword = 'MICRUSFRAME', name = MICRUSFRAME S 10, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'MICRUSFRAME S 18', oneword = 'MICRUSFRAME', name = MICRUSFRAME S 18, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'MINDFRAME', oneword = 'MINDFRAME', name = MINDFRAME, franchise = AIS, category=STENTRIEVER, company= MEDTRONIC);
%worchk (keyword = 'MIRAGE 0.08', oneword = 'MIRAGE', name = MIRAGE 0.08, franchise = HEM, category=GUIDEWIRE, company= MEDTRONIC);
%worchk (keyword = 'MIVI Q3 DISTAL ACCESS CATHETER', oneword = 'MIVI', name = MIVI Q3 DISTAL ACCESS CATHETER, franchise = AIS, category=ASPIRATION CATHETER, company= MIVI NEUROSCIENCE);
%worchk (keyword = 'MIVI Q4 DISTAL ACCESS CATHETER', oneword = 'MIVI', name = MIVI Q4 DISTAL ACCESS CATHETER, franchise = AIS, category=ASPIRATION CATHETER, company= MIVI NEUROSCIENCE);
%worchk (keyword = 'MIVI Q5 DISTAL ACCESS CATHETER', oneword = 'MIVI', name = MIVI Q5 DISTAL ACCESS CATHETER, franchise = AIS, category=ASPIRATION CATHETER, company= MIVI NEUROSCIENCE);
%worchk (keyword = 'MIVI Q6 DISTAL ACCESS CATHETER', oneword = 'MIVI', name = MIVI Q6 DISTAL ACCESS CATHETER, franchise = AIS, category=ASPIRATION CATHETER, company= MIVI NEUROSCIENCE);
%worchk (keyword = 'MYRIAD', oneword = 'MYRIAD', name = MYRIAD, franchise = ICH, category=ICH DEVICES, company= NICO);
%worchk (keyword = 'NAUTICA 14 XL', oneword = 'NAUTICA', name = NAUTICA 14 XL, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'NAVIEN 058', oneword = 'NAVIEN', name = NAVIEN 058, franchise = HEM, category=DELIVERY CATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'NAVIEN 072', oneword = 'NAVIEN', name = NAVIEN 072, franchise = HEM, category=DELIVERY CATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'NEURON 53', oneword = 'NEURON', name = NEURON 53, franchise = HEM, category=GUIDE CATHETER, company= PENUMBRA);
%worchk (keyword = 'NEURON 70', oneword = 'NEURON', name = NEURON 70, franchise = HEM, category=GUIDE CATHETER, company= PENUMBRA);
%worchk (keyword = 'NEURON MAX', oneword = 'NEURON', name = NEURON MAX, franchise = HEM, category=GUIDE CATHETER, company= PENUMBRA);
%worchk (keyword = 'NEURON MAX', oneword = 'NEURON', name = NEURON MAX, franchise = AIS, category=LONG SHEATH, company= PENUMBRA);
%worchk (keyword = 'NEUROPATH', oneword = 'NEUROPATH', name = NEUROPATH, franchise = HEM, category=GUIDE CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'NEUROPATH 5 F', oneword = 'NEUROPATH', name = NEUROPATH 5 F, franchise = HEM, category=GUIDE CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'NEUROPATH 6 F', oneword = 'NEUROPATH', name = NEUROPATH 6 F, franchise = HEM, category=GUIDE CATHETER, company= JOHNSON & JOHNSON);
%worchk (keyword = 'NEUROSCOUT', oneword = 'NEUROSCOUT', name = NEUROSCOUT, franchise = HEM, category=GUIDEWIRE, company= JOHNSON & JOHNSON);
%worchk (keyword = 'NXT HELIX STANDARD 10', oneword = 'NXT', name = NXT HELIX STANDARD 10, franchise = HEM, category=COIL, company= MEDTRONIC);
%worchk (keyword = 'OFFSET', oneword = 'OFFSET', name = OFFSET, franchise = AIS, category=DELIVERY CATHETER HEM, company= STRYKER);
%worchk (keyword = 'ONYX', oneword = 'ONYX', name = ONYX, franchise = HEM, category=LIQUID EMBOLICS, company= MEDTRONIC);
%worchk (keyword = 'OPTIMA', oneword = 'OPTIMA', name = OPTIMA, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = 'OPTIMA INSTANT DETACHMENT SYSTEM', oneword = 'OPTIMA', name = OPTIMA INSTANT DETACHMENT SYSTEM, franchise = HEM, category=COIL DETACHMENT DEVICE, company= BALT);
%worchk (keyword = 'ORION-21 150CM', oneword = 'ORION-21', name = ORION-21 150CM, franchise = AIS, category=MICROCATHETER AIS, company= MEDTRONIC);
%worchk (keyword = 'PHENOM', oneword = 'PHENOM', name = PHENOM, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'PHENOM', oneword = 'PHENOM', name = PHENOM, franchise = HEM, category=DELIVERY CATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'PHENOM 160 CM', oneword = 'PHENOM', name = PHENOM 160 CM, franchise = AIS, category=MICROCATHETER AIS, company= MEDTRONIC);
%worchk (keyword = 'PHIL', oneword = 'PHIL', name = PHIL, franchise = HEM, category=LIQUID EMBOLICS, company= TERUMO);
%worchk (keyword = 'PIPELINE', oneword = 'PIPELINE', name = PIPELINE, franchise = HEM, category=FDS, company= MEDTRONIC);
%worchk (keyword = 'PLATO 27', oneword = 'PLATO', name = PLATO 27, franchise = HEM, category=MICROCATHETER HEM, company= SCIENTIA);
%worchk (keyword = 'POD400', oneword = 'POD400', name = POD400, franchise = HEM, category=COIL, company= PENUMBRA);
%worchk (keyword = 'PORTAL EXT EXTENSION WIRE', oneword = 'PORTAL', name = PORTAL EXT EXTENSION WIRE, franchise = HEM, category=GUIDEWIRE, company= PHENOX);
%worchk (keyword = 'PORTAL STEERABLE HYDROPHYLIC GUIDEWIRE', oneword = 'PORTAL', name = PORTAL STEERABLE HYDROPHYLIC GUIDEWIRE, franchise = HEM, category=GUIDEWIRE, company= PHENOX);
%worchk (keyword = 'PRESSURE SENSING ACCESS SYSTEM', oneword = 'PRESSURE', name = PRESSURE SENSING ACCESS SYSTEM, franchise = HEM, category=SHORT SHEATH, company= ENDOPHYS);
%worchk (keyword = 'PROWLER 10', oneword = 'PROWLER', name = PROWLER 10, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'PROWLER 14', oneword = 'PROWLER', name = PROWLER 14, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'PROWLER 27', oneword = 'PROWLER', name = PROWLER 27, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'PROWLER PLUS', oneword = 'PROWLER', name = PROWLER PLUS, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'PROWLER SELECT LP-ES', oneword = 'PROWLER', name = PROWLER SELECT LP-ES, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'PROWLER SELECT PLUS', oneword = 'PROWLER', name = PROWLER SELECT PLUS, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'PULSERIDER', oneword = 'PULSERIDER', name = PULSERIDER, franchise = HEM, category=ADJUNCTIVE STENT, company= JOHNSON & JOHNSON);
%worchk (keyword = 'PX 400', oneword = 'PX', name = PX 400, franchise = HEM, category=MICROCATHETER HEM, company= PENUMBRA);
%worchk (keyword = 'PX SLIM', oneword = 'PX', name = PX SLIM, franchise = HEM, category=MICROCATHETER HEM, company= PENUMBRA);
%worchk (keyword = 'RAPIDTRANSIT', oneword = 'RAPIDTRANSIT', name = RAPIDTRANSIT, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'REACT/SOLITAIRE PLATINUM', oneword = 'REACT/SOLITAIRE', name = REACT/SOLITAIRE PLATINUM, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'REACT68', oneword = 'REACT68', name = REACT68, franchise = AIS, category=ASPIRATION CATHETER, company= MEDTRONIC);
%worchk (keyword = 'REACT68', oneword = 'REACT68', name = REACT68, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'REACT68/RIPTIDE', oneword = 'REACT68/RIPTIDE', name = REACT68/RIPTIDE, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'REACT68/RIPTIDE/SOLITAIRE PLATINUM', oneword = 'REACT68/RIPTIDE/SOLITAIRE', name = REACT68/RIPTIDE/SOLITAIRE PLATINUM, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'REACT71', oneword = 'REACT71', name = REACT71, franchise = AIS, category=ASPIRATION CATHETER, company= MEDTRONIC);
%worchk (keyword = 'REACT71/RIPTIDE', oneword = 'REACT71/RIPTIDE', name = REACT71/RIPTIDE, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'REACT71/RIPTIDE/SOLITAIRE PLATINUM', oneword = 'REACT71/RIPTIDE/SOLITAIRE', name = REACT71/RIPTIDE/SOLITAIRE PLATINUM, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'REACT71/SOLITAIRE PLATINUM', oneword = 'REACT71/SOLITAIRE', name = REACT71/SOLITAIRE PLATINUM, franchise = AIS, category=AIS BUNDLE, company= MEDTRONIC);
%worchk (keyword = 'REBAR 10', oneword = 'REBAR', name = REBAR 10, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'REBAR 14', oneword = 'REBAR', name = REBAR 14, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'REBAR 18', oneword = 'REBAR', name = REBAR 18, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'REBAR 27', oneword = 'REBAR', name = REBAR 27, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'RENEGADE-18 2 TIP', oneword = 'RENEGADE-18', name = RENEGADE-18 2 TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'REVIVE IC', oneword = 'REVIVE', name = REVIVE IC, franchise = AIS, category=DELIVERY CATHETER AIS, company= JOHNSON & JOHNSON);
%worchk (keyword = 'RIPTIDE', oneword = 'RIPTIDE', name = RIPTIDE, franchise = AIS, category=ASPIRATION ADJUNCTIVE, company= MEDTRONIC);
%worchk (keyword = 'SCEPTER C', oneword = 'SCEPTER', name = SCEPTER C, franchise = HEM, category=REMODELING BALLOONS, company= TERUMO);
%worchk (keyword = 'SCEPTER XC', oneword = 'SCEPTER', name = SCEPTER XC, franchise = HEM, category=REMODELING BALLOONS, company= TERUMO);
%worchk (keyword = 'SILVERSPEED 10', oneword = 'SILVERSPEED', name = SILVERSPEED 10, franchise = HEM, category=GUIDEWIRE, company= MEDTRONIC);
%worchk (keyword = 'SILVERSPEED 14', oneword = 'SILVERSPEED', name = SILVERSPEED 14, franchise = HEM, category=GUIDEWIRE, company= MEDTRONIC);
%worchk (keyword = 'SILVERSPEED 16', oneword = 'SILVERSPEED', name = SILVERSPEED 16, franchise = HEM, category=GUIDEWIRE, company= MEDTRONIC);
%worchk (keyword = 'SMART COIL DETACHMENT HANDLE', oneword = 'SMART', name = SMART COIL DETACHMENT HANDLE, franchise = HEM, category=COIL DETACHMENT DEVICE, company= PENUMBRA);
%worchk (keyword = 'SOFIA 5F', oneword = 'SOFIA', name = SOFIA 5F, franchise = HEM, category=DELIVERY CATHETER HEM, company= TERUMO);
%worchk (keyword = 'SOFIA 5F 125CM', oneword = 'SOFIA', name = SOFIA 5F 125CM, franchise = AIS, category=ASPIRATION CATHETER, company= TERUMO);
%worchk (keyword = 'SOFIA 6F', oneword = 'SOFIA', name = SOFIA 6F, franchise = HEM, category=DELIVERY CATHETER HEM, company= TERUMO);
%worchk (keyword = 'SOFIA EX 058', oneword = 'SOFIA', name = SOFIA EX 058, franchise = HEM, category=DELIVERY CATHETER HEM, company= TERUMO);
%worchk (keyword = 'SOFIA PLUS 6F 125 CM', oneword = 'SOFIA', name = SOFIA PLUS 6F 125 CM, franchise = AIS, category=ASPIRATION CATHETER, company= TERUMO);
%worchk (keyword = 'SOFIA PLUS 6F 131 CM', oneword = 'SOFIA', name = SOFIA PLUS 6F 131 CM, franchise = AIS, category=ASPIRATION CATHETER, company= TERUMO);
%worchk (keyword = 'SURPASS EVOLVE', oneword = 'SURPASS', name = SURPASS EVOLVE, franchise = HEM, category=FDS, company= STRYKER);
%worchk (keyword = 'SYNCHRO', oneword = 'SYNCHRO', name = SYNCHRO, franchise = HEM, category=GUIDEWIRE, company= STRYKER);
%worchk (keyword = 'SYPHONTRAK', oneword = 'SYPHONTRAK', name = SYPHONTRAK, franchise = HEM, category=DELIVERY CATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRACKER 17 2-TIP', oneword = 'TRACKER', name = TRACKER 17 2-TIP, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'TRACSTAR LARGE DISTAL PLATFORM', oneword = 'TRACSTAR', name = TRACSTAR LARGE DISTAL PLATFORM, franchise = AIS, category=LONG SHEATH, company= IMPERATIVE CARE);
%worchk (keyword = 'TRACSTAR LARGE DISTAL PLATFORM ', oneword = 'TRACSTAR', name = TRACSTAR LARGE DISTAL PLATFORM , franchise = AIS, category=LONG SHEATH, company= IMPERATIVE CARE);
%worchk (keyword = 'TRANSEND', oneword = 'TRANSEND', name = TRANSEND, franchise = HEM, category=GUIDEWIRE, company= STRYKER);
%worchk (keyword = 'TRANSIT', oneword = 'TRANSIT', name = TRANSIT, franchise = HEM, category=MICROCATHETER HEM, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRAXCESS', oneword = 'TRAXCESS', name = TRAXCESS, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'TRAXCESS 14', oneword = 'TRAXCESS', name = TRAXCESS 14, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'TRAXCESS 14EX', oneword = 'TRAXCESS', name = TRAXCESS 14EX, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'TRAXCESS DOCKING WIRE', oneword = 'TRAXCESS', name = TRAXCESS DOCKING WIRE, franchise = HEM, category=GUIDEWIRE, company= TERUMO);
%worchk (keyword = 'TREVO PRO', oneword = 'TREVO', name = TREVO PRO, franchise = AIS, category=STENTRIEVER, company= STRYKER);
%worchk (keyword = 'TRUFILL DCS SYRINGE II', oneword = 'TRUFILL', name = TRUFILL DCS SYRINGE II, franchise = HEM, category=COIL DETACHMENT DEVICE, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRUFILL N-BCA', oneword = 'TRUFILL', name = TRUFILL N-BCA, franchise = HEM, category=LIQUID EMBOLICS, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TRUFILL PUSHABLE', oneword = 'TRUFILL', name = TRUFILL PUSHABLE, franchise = HEM, category=COIL, company= JOHNSON & JOHNSON);
%worchk (keyword = 'TURBOTRACKER', oneword = 'TURBOTRACKER', name = TURBOTRACKER, franchise = HEM, category=MICROCATHETER HEM, company= STRYKER);
%worchk (keyword = 'ULTRAFLOW HPC', oneword = 'ULTRAFLOW', name = ULTRAFLOW HPC, franchise = HEM, category=MICROCATHETER HEM, company= MEDTRONIC);
%worchk (keyword = 'VECTA 71 125CM', oneword = 'VECTA', name = VECTA 71 125CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchk (keyword = 'VECTA 71 132CM', oneword = 'VECTA', name = VECTA 71 132CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchk (keyword = 'VECTA 74 125CM', oneword = 'VECTA', name = VECTA 74 125CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchk (keyword = 'VECTA 74 132CM', oneword = 'VECTA', name = VECTA 74 132CM, franchise = AIS, category=ASPIRATION CATHETER, company= STRYKER);
%worchk (keyword = 'VELOCITY', oneword = 'VELOCITY', name = VELOCITY, franchise = HEM, category=MICROCATHETER HEM, company= PENUMBRA);
%worchk (keyword = 'VELOCITY 160 CM', oneword = 'VELOCITY', name = VELOCITY 160 CM, franchise = AIS, category=MICROCATHETER AIS, company= PENUMBRA);
%worchk (keyword = 'VFC VERSATILE RANGE FILL ', oneword = 'VFC', name = VFC VERSATILE RANGE FILL , franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'VFC VERSATILE RANGE FILL ADVANCED', oneword = 'VFC', name = VFC VERSATILE RANGE FILL ADVANCED, franchise = HEM, category=COIL, company= TERUMO);
%worchk (keyword = 'V-GRIP', oneword = 'V-GRIP', name = V-GRIP, franchise = HEM, category=COIL DETACHMENT DEVICE, company= TERUMO);
%worchk (keyword = 'VIA 17', oneword = 'VIA', name = VIA 17, franchise = HEM, category=MICROCATHETER HEM, company= TERUMO);
%worchk (keyword = 'VIA 21', oneword = 'VIA', name = VIA 21, franchise = HEM, category=MICROCATHETER HEM, company= TERUMO);
%worchk (keyword = 'VIA 27', oneword = 'VIA', name = VIA 27, franchise = HEM, category=MICROCATHETER HEM, company= TERUMO);
%worchk (keyword = 'VIA 33', oneword = 'VIA', name = VIA 33, franchise = HEM, category=MICROCATHETER HEM, company= TERUMO);
%worchk (keyword = 'VIEWSITE', oneword = 'VIEWSITE', name = VIEWSITE, franchise = ICH, category=ICH DEVICES, company= VYCOR MEDICAL);
%worchk (keyword = 'WALRUS', oneword = 'WALRUS', name = WALRUS, franchise = AIS, category=BALLOON GUIDE CATHETER, company= Q�APEL MEDICAL);
%worchk (keyword = 'WEB', oneword = 'WEB', name = WEB, franchise = HEM, category=EMBOLIZATION DEVICE DETACHMENT CONTROLLER, company= TERUMO);
%worchk (keyword = 'WEB', oneword = 'WEB', name = WEB, franchise = HEM, category=EMBOLIZATION DEVICE, company= TERUMO);
%worchk (keyword = 'WEDGE', oneword = 'WEDGE', name = WEDGE, franchise = AIS, category=DELIVERY CATHETER HEM, company= TERUMO);
%worchk (keyword = 'WINGSPAN', oneword = 'WINGSPAN', name = WINGSPAN, franchise = ICAD, category=ISCHEMIC STENT, company= STRYKER);
%worchk (keyword = 'X-CELERATOR 10', oneword = 'X-CELERATOR', name = X-CELERATOR 10, franchise = HEM, category=GUIDEWIRE, company= MEDTRONIC);
%worchk (keyword = 'X-CELERATOR 14', oneword = 'X-CELERATOR', name = X-CELERATOR 14, franchise = HEM, category=GUIDEWIRE, company= MEDTRONIC);
%worchk (keyword = 'X-PEDION', oneword = 'X-PEDION', name = X-PEDION, franchise = HEM, category=GUIDEWIRE, company= MEDTRONIC);
%worchk (keyword = 'ZOOM 35', oneword = 'ZOOM', name = ZOOM 35, franchise = AIS, category=ASPIRATION CATHETER, company= IMPERATIVE CARE);
%worchk (keyword = 'ZOOM 45', oneword = 'ZOOM', name = ZOOM 45, franchise = AIS, category=ASPIRATION CATHETER, company= IMPERATIVE CARE);
%worchk (keyword = 'ZOOM 55', oneword = 'ZOOM', name = ZOOM 55, franchise = AIS, category=ASPIRATION CATHETER, company= IMPERATIVE CARE);
%worchk (keyword = 'ZOOM 71', oneword = 'ZOOM', name = ZOOM 71, franchise = AIS, category=ASPIRATION CATHETER, company= IMPERATIVE CARE);
%worchk (keyword = 'ZOOM 88 LARGE DISTAL PLATFORM', oneword = 'ZOOM', name = ZOOM 88 LARGE DISTAL PLATFORM, franchise = AIS, category=LONG SHEATH, company= IMPERATIVE CARE);
%worchk (keyword = 'ZOOM 88 LARGE DISTAL PLATFORM ', oneword = 'ZOOM', name = ZOOM 88 LARGE DISTAL PLATFORM , franchise = AIS, category=LONG SHEATH, company= IMPERATIVE CARE);
%worchk (keyword = '10 COMPLEX FINISHING COIL', oneword = 'FINISHING', name = 10 COMPLEX FINISHING COIL, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = '10 COMPLEX FRAMING COIL', oneword = 'FINISHING', name = 10 COMPLEX FRAMING COIL, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = '10 FILLING COIL', oneword = 'FILLING', name = 10 FILLING COIL, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = '10 FINISHING COIL', oneword = 'FINISHING', name = 10 FINISHING COIL, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = '10 FRAMING COIL', oneword = 'FRAMING', name = 10 FRAMING COIL, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = '10 HELICAL FILLING COIL', oneword = 'FINISHING', name = 10 HELICAL FILLING COIL, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = '10 HELICAL FINISHING COIL', oneword = 'FINISHING', name = 10 HELICAL FINISHING COIL, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = '18 COMPLEX FRAMING COIL', oneword = 'FINISHING', name = 18 COMPLEX FRAMING COIL, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = '18 FRAMING COIL', oneword = 'FRAMING', name = 18 FRAMING COIL, franchise = HEM, category=COIL, company= BALT);
%worchk (keyword = 'DETACHABLE COIL CONNECTING CABLE', oneword = 'DETACHABLE', name = DETACHABLE COIL CONNECTING CABLE, franchise = HEM, category=COIL DETACHMENT DEVICE, company= STRYKER);



*Get devices discharge count and name;

proc sql;
create table dev_cnt as
select distinct
	franchise
	,category
	,company_name
	,dev_name
	,sum(disc_cnt) as disc_tot
from phd.devices2
where dev_name ne " "
group by 1, 2, 3, 4
order by 1, 2, 3, 4
;
quit;

proc print data=dev_cnt(obs=25 where=(dev_name ne " "));
run;

proc sql;
	create table sub_pcs as
	select PCS.*
	from raw.str_chgmstr	PCS
	where PCS.sum_dept_desc in ("SUPPLY", "OR") and PCS.std_chg_code in ('270270010000000', '270270028520000', '270270028810000', '270270041710000',
								'270270045610000', '270270045630000', '270270110050000', '270270110280000',
								'270270110720000', '270270112010000', '270270990700000', '270278005210000',
								'270278933710000', '270278995240000', '270278995600000', '270278933710000', '270270010320000', '270270010890000', '270270011610000', '270270011740000',
								'270272927800000', '270272927820000', '270272927840000', '270272930110000', '270270010000000', '270270010320000', '270270010890000', '270270011730000',
								'270272930110000', '270270110720000', '270270010000000', '270270011610000', '270270990700000', '270270045850000', '270270009380000', '270270013100000', 
								'270270990000002', '270272927810000', '270270010320000', '270270110590000', '270272911143000', '270270990120000', '270270028110000', '270270032870000', 
								'270270045820000', '360360372130000', '270270110050000', '270278002650000', '270270026760000', '360360365500000', '270278995240000', '270270026380000', 
								'270278992840000', '270270110060000', '270270110030000', '270270045610000', '270270110850000', '270270012190000', '270270112010000', '270278995700000', 
								'270278995600000', '270278933710000', '270270009270000', '270270011740000', '270270012260000', '270270010890000', '270270011200000', '270270042420000', 
								'270270001010000', '270270104550000', '270270054950000', '270270038890000', '270270002080000', '270270031180000', '270270058900000', '270272927840000', 
								'270272927800000', '270270054930000', '270270029410000', '270270006730000', '270272956400001', '270270101300000', '270270008850000', '270270013160000', 
								'270270009890000', '270270010860000', '270270110430000', '270270011620000', '360360100210000', '270270111780000', '270270028280000', '270270053270000', 
								'270270009160000', '270270009720000', '270270990000001', '270270030270000', '270270042590000', '270270011730000', '270272956380000', '270272927820000', 
								'270270008970000', '270278919730000', '270270002680000', '270270006600000', '270270006610000', '270270006630000', '270270006640000', '270270006650000',
								'270270008850000', '270270008910000', '270270008990000', '270270009070000', '270270009350000', '270270011200000', '270270011750000', '270270014790000',
								'270270014800000', '270270014830000', '270270027840000', '270270028110000', '270270028820000', '270270031360000', '270270032870000', '270270042190000'
								'270270045610000', '270270095090000', '270270110590000', '270270111940000', '270278995240000', '270270990280000', '270270031370000', '270270990530000',
								'250250014060000')
	;
quit;


proc sql;
	create table phd.devices_2017 as
	select distinct
		CDM.hosp_chg_desc
		,CDM.hosp_chg_id
		,PCS.std_chg_desc
		,PCS.std_chg_code
		,count(distinct COHORT.pat_key) as disc_cnt
	from phd.DXPX COHORT
	inner join
		raw.str_2017_patbill	PATBILL
	on
		PATBILL.pat_key = COHORT.pat_key
	left join
		raw.str_hospchg	CDM
	on
		PATBILL.hosp_chg_id = CDM.hosp_chg_id
	left join
		sub_pcs	PCS
	on
		PATBILL.std_chg_code = PCS.std_chg_code
	group by 1
	order by hosp_chg_desc
	;
quit;


proc print data=raw.str_2017_patbill(obs=25);
run;
