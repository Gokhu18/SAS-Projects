
/****** Please update the following ******/

*fiscal month of report month that you want to analyze;
%let month= 202001;		

*table of clients for adhoc analysis. **Important: make sure that client_id column is INT or BIGINT;
%let input_table= mktg.admin.the607_dual;

*if a user segment exists, change the value to "Y" and enter the segment name.  Otherwise change to "N";
%let user_segment= "N";
%let segment_name= mt_user;	   *Cannot be the same as an existing column in profile data set, best to just name it 'segment';

*pick a name for your output file.  The output file name will be this plus a timestamp;
%let output_file= nate_dual; 




/***** NO change required for anything below ************/

/* Location of the data file */
libname adhoc "U:\Analysis\Decision Support_Modeling\Client Development\Client Profile\Client Profile Code - Ad hoc\Data Files";
*libname adhoc "R:\client profile\Data\Aug19";

/* Output location */
%let output_loc=U:\Analysis\Decision Support_Modeling\Client Development\Client Profile\Client Profile Code - Ad hoc\Profiles;

/* Output list with variables */
%include "U:\Analysis\Decision Support_Modeling\Client Development\Client Profile\Client Profile Code - Ad hoc\Program files\output_list_adhoc.sas";


filename conn 'H:\SAS\SASCode';
%inc conn(include_parameters);

options mlogic symbolgen mprint noxwait compress=yes errors=1;


%macro now(fmt);
%sysfunc(datetime(),&fmt)
%mend now;

proc format;
picture file_datetime_fmt
other= '%Y%0m%0d %0H%0M%0S' (datatype=datetime);
run;


%put Begin Time: %now(datetime16.);


/* create new data set from the data file.  This will take 40-50 minutes to download from the shared drive */
/* you can start at the next step if the data file from the shared drive is already in your Work library */

data data_set;
	set adhoc.tda_clnt_&month.;
run;





/*************************************************** */
/******** If you already have the month data file in your Work library you can start here.  This will download your adhoc table and run the stats */
/******** highlight from here to the bottom.  Don't forget to re-run the table and segment name above if they changed */




/* Download the table of clients for adhoc analysis */

proc sql; connect to SASIONZA (server = &inc_ip_addr database = MKTG port = &inc_ip_port user = &inc_user password = &inc_password);
create table adhoc_download as select * from connection to SASIONZA
	(select * from &input_table.);
disconnect from SASIONZA;
quit; 



/* combine data sets and distinguish between funded, unfunded and not matched */

*no match;
proc sql;
create table nomatch as
select distinct a.client_id 
from adhoc_download a
left join data_set b
on a.client_id = b.client_id
where b.client_id is null;
quit;

*unfunded;
proc sql;
create table unfunded as
select distinct a.client_id
from adhoc_download a
inner join data_set b
on a.client_id = b.client_id
where b.funded_ind = 0;
quit;

*funded;
%macro funded;
	%if &user_segment.= "Y"
	%then %do;
proc sql;
create table funded as
select a.*,&segment_name.
from data_set a
inner join adhoc_download b
on a.client_id = b.client_id
where a.funded_ind = 1;
quit;
	%end;

	%else %do;
proc sql;
create table funded as
select a.*
from data_set a
inner join adhoc_download b
on a.client_id = b.client_id
where a.funded_ind = 1;
quit;
	%end;

%mend funded;

%funded;



/* get the summary counts */

proc sql;
select count(distinct client_id) into :total_cnt from adhoc_download;
select count(distinct client_id) into :funded_cnt from funded;
select count(distinct client_id) into :unfunded_cnt from unfunded;
select count(distinct client_id) into :nomatch_cnt from nomatch;
quit;



data summary_counts;
	total_clients= &total_cnt.;
	funded_clients= &funded_cnt.;
	unfunded_clients= &unfunded_cnt.;
	nomatch_clients= &nomatch_cnt.;
run;



/* Create a new copy of adhoc profile file that will receive exported data */

%let dir1= U:\Analysis\Decision Support_Modeling\Client Development\Client Profile\Client Profile Code - Ad hoc\Program files;
%let dir2= U:\Analysis\Decision Support_Modeling\Client Development\Client Profile\Client Profile Code - Ad hoc\Profiles;
%let new_file= %trim(&output_file) %trim(%now(file_datetime_fmt));
x copy "&dir1\adhoc_profile.xlsx" "&dir2\&new_file..xlsx";



/* Macro for profile summary */

%macro export_profile(classvar,dataset,sheet);

**summarize data;
proc means data= &dataset noprint;
	class &classvar;
	var %variable_list;;
	output out=output_&classvar %output_list;;
	where funded_ind=1;
run;


**transpose so it fits into Excel properly;
proc transpose data= output_&classvar
	out= trans_output_&classvar;
	id &classvar;
run;


*clean up data;
data trans_output_&classvar;
	set trans_output_&classvar;
	if _name_ in('_TYPE_') then delete;
	drop _label_;
run;


**export to Excel;
proc export data= trans_output_&classvar
	outfile= "&output_loc\&new_file..xlsx"
	dbms= xlsx
	replace;
	sheet= &sheet;
run;

%mend export_profile;



/* Run the macros that summarize and export the data */

%export_profile(classvar= %overall, dataset=data_set, sheet=overall);
%export_profile(classvar= %overall, dataset=funded, sheet=adhoc);




/* Conditionally run the user segment if it exists */

%macro user_sgmt;
	%if &user_segment.= "Y"
	%then %export_profile(classvar= &segment_name., dataset=funded, sheet=adhoc_sgmt);
%mend user_sgmt;

%user_sgmt;



/* Export the summary counts */

proc transpose data= summary_counts
	out= summary_counts;
run;

proc export data= summary_counts
	outfile= "&output_loc\&new_file..xlsx"
	dbms= xlsx
	replace;
	sheet= counts;
run;


/* delete the BAK file */
x del "&dir2\&new_file..xlsx.bak";

	
%put End Time: %now(datetime16.);
