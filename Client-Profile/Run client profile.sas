
/* Please update the variables below */

%let month1 = 201903;			/* fiscal month - start of trailing 12 months */
%let month2 = 202002;			/* fiscal month - report month	*/
%let date1 = '2019-11-01';      /* first calendar day of report month */
%let date2 = '2019-11-30';      /* last calendar day of report month */
%let date1a = '01nov19'd;		/* first calendar day of report month in SAS format */
%let date2b = '30nov19'd;	 	/* last calendar day of report month in SAS format */
%let trdate12mo = '2018-12-01';      /* first calendar day of trailing 12 months */
%let trdate1 = '01dec18'd;		/* first calendar day of trailing 12 months in SAS format */
%let trdate2 = '01sep19'd;      /* first calendar of of trailing 3 mos in SAS format */
%let fscl_mth_seq_nbr= 1190;    /* fiscal month seq number for report month from time master*/

%let data_month = Nov19;		/* folder name for R: drive data location */
%let FY= FY2020;     			/* Fiscal year for the folder location on shared drive*/
%let mon= Nov 2019 Profile;   	/* folder name on the shared drive */




/***** NO change required for anything below ************/

filename conn 'H:\SAS\SASCode';
%inc conn(include_parameters);

libname tda "R:\client profile\Data\&data_month";

/* Output location */
%let output_loc=U:\Analysis\Decision Support_Modeling\Client Development\Client Profile\Client Profile Code - Month\&FY.\&mon.;
%let output_file= client_profile;

/* Output list with macros and variables */
%include "U:\Analysis\Decision Support_Modeling\Client Development\Client Profile\Client Profile Code - Month\&FY.\&mon.\output_list.sas";


options mlogic symbolgen mprint compress=yes noxwait errors=1;


%macro now(fmt=datetime16.);
%sysfunc(datetime(),&fmt)
%mend now;

%put Begin Time: %now;




/* Get the data from EW.  This runs as one group and creates mktg..the607_profile_ew_data.  Data will be downloaded in the next step */


proc sql; connect to SASIONZA (server = &inc_ip_addr database = MKTG port = &inc_ip_port user = &inc_user password = &inc_password);
execute( 

/* create table with Retail clients */
drop table the607_profile_clients_accts if exists;

create table the607_profile_clients_accts as
select
c.client_id
,a.acct_id
,a.acct_nbr
,a.ofc_cd
,a.bos_acct_type_cd
,a.branch_id
,a.acct_open_dt
,a.acct_close_dt
,a.acct_stat_cd
,a.liqd_val_amt
,o.legacy_cd

from edw_admin.admin.acct a
inner join edw_admin.admin.acct_client_hist c
on a.acct_id = c.acct_id and c.curr_ind = 'Y'
inner join edw_admin.admin.vw_ref_ofc_cd o
on a.ofc_cd = o.ofc_cd
and o.client_group_nm = 'Retail'     /* Retail accounts only */

distribute on (client_id);



/* client data hub info */
drop table the607_profile_datahub if exists;

create table the607_profile_datahub as
select
client_id
,csg_id
,case when funded_client = 'Y' then 1 else 0 end as funded_ind
,ret_seg_eff as sgmt_cd
,ret_subseg_eff as sgmt_sub_cd
,bcg_segment as ds_sgmt_cd
,bcg_sub_segment as ds_sgmt_sub_cd
,ret_op_segment
,ret_op_sub_segment
,case when gender_ind = 'M' then 1
	  when gender_ind = 'F' then 0 
	  else null end as male
,case when gender_ind = 'F' then 1
	  when gender_ind = 'M' then 0 
	  else null end as female
,case when dbs_ind = 'Y' then 1 else 0 end as dbs_client
,case when first_acct_open_dt < '1980-01-01' then null else first_acct_open_dt end as first_acct_open_dt
,case when selective_client = 'Y' then 1 else 0 end as selective_ind
,case when essential_client = 'Y' then 1 else 0 end as essential_ind
,case when personalized_client = 'Y' then 1 else 0 end as personalized_ind
,case when (selective_client = 'Y' or essential_client = 'Y' or personalized_client = 'Y') then 1 else 0 end as ims_client
,case when client_age < 0 then null
      when client_age > 105 then null
      else client_age end as client_age
,asia_client
,asia_dual
,brokerageandims_liq_bal
,brkg_liq_bal
,individual_brkg_liq_bal
,retirement_brkg_liq_bal
,other_brkg_liq_bal
,selective_balance
,essential_balance
,personalized_balance
,brkg_mrgn_bal_amt
,brkg_tot_posn_amt
,selective_posn_bal
,essential_posn_bal
,personalized_posn_bal
,cash
,stockeqty
,etf
,options
,mutfund
,bond_debent
,bond_muni
,cdo
,cd
,govt_trsy
,fi_total
,warrant
,other
,case when highest_optn_lvl = 'C' then 1 else 0 end as opt_tier1
,case when highest_optn_lvl in('L','S') then 1 else 0 end as opt_tier2
,case when highest_optn_lvl = 'F' then 1 else 0 end as opt_tier3
,first_margin_apprvd_dt
,case when first_margin_apprvd_dt is not null then 1 else 0 end as mrgn_apprv_ind
,first_option_apprvd_dt
,case when first_option_apprvd_dt is not null then 1 else 0 end as option_apprv_ind
,first_fut_apprvd_dt
,case when first_fut_apprvd_dt is not null then 1 else 0 end as fut_apprv_ind
,first_fx_apprvd_dt
,case when first_fx_apprvd_dt is not null then 1 else 0 end as fx_apprv_ind

from mktg_camp.admin.client_data_hub_hist d

where d.fscl_mth_id = &month2.
and d.client_id not in(73136357)

distribute on (client_id);


/* create table with distinct client_id */
drop table the607_profile_distinct_clients if exists;

create table the607_profile_distinct_clients as
select distinct client_id
from the607_profile_datahub
distribute on (client_id);




/* end of month account information */
drop table the607_profile_eom if exists;

create table the607_profile_eom as
select
client_id
,sum(case when acct_stat_cd <> 'C' then 1 else 0 end) as accounts_count      /* exclude closed accounts, Nate changed 9/20/18 */
,sum(case when liqd_val_amt > 0 then 1 else 0 end) as funded_accts_cnt
,max(case when bos_acct_type_cd in ('FE','F','R','FR') then 1 else 0 end) as individual_acct_ind
,max(case when bos_acct_type_cd in ('I','IL','IO','IP','IR','IS','K','IE','IX',
                             'IT','IB','IY','IZ','IV','IM','IH','IF','IN',
                             'IK','II','IU','IA','ID') then 1 else 0 end) as retirement_acct_ind
,max(case when bos_acct_type_cd in ('I','IO','IP','IS','K','IE','IX',
                             'IY','IZ','IV','IM','IH','IF','IN',
                             'IK','II','IU','IA','ID') then 1 else 0 end) as contributory_ret_acct_ind  /* 9/20/18 Nate exclude 2 Rollover types and 2 Beneficiary types */
,max(case when bos_acct_type_cd in ('IL','IR') then 1 else 0 end) as rollover_ret_acct_ind
,max(case when bos_acct_type_cd in ('I','IL','IP','IS','IB','IE','IH','IM','IO','IR','IV','IX','IY','IZ','IT') then 1 else 0 end) as ira_acct_ind
,max(case when bos_acct_type_cd not in ('I','IL','IP','IS','IB','IE','IH','IM','IO','IR','IV','IX','IY','IZ','IT') then 1 else 0 end) as non_ira_acct_ind
,max(case when bos_acct_type_cd in ('TC','TE','CP','J','FJ') then 1 else 0 end) as joint_acct_ind
,max(case when bos_acct_type_cd in ('CS','D','G','U','TX','T','CU','FG','FI','FT') then 1 else 0 end) as beneficiary_acct_ind
,max(case when bos_acct_type_cd in ('S','P','V','C','UA','FC','FL','FP','FU') then 1 else 0 end) as business_acct_ind

from the607_profile_clients_accts c

group by client_id

distribute on (client_id);



/* Revenue info */
drop table the607_profile_revenue if exists;

create table the607_profile_revenue as
select
c.client_id
,sum(case when d.fncl_trans_catg_descr = 'Transaction Revenue' then r.fncl_trans_amt end) as trans_rev
,sum(case when d.fncl_trans_type_nm in('Rack Margin Interest','Negotiated Margin Interest','Margin Cost of Lending')
 then r.fncl_trans_amt end) as margin_rev
,sum(case when d.fncl_trans_catg_descr in('Spread Rev','Other Interest Spread Revenue')
 and d.fncl_trans_type_nm not in('Rack Margin Interest','Negotiated Margin Interest','Margin Cost of Lending')
 then r.fncl_trans_amt end) as spread_rev
,sum(case when d.fncl_trans_catg_descr = 'Asset-Based Fee Rev' then r.fncl_trans_amt end) as asset_based_rev
,sum(case when d.fncl_trans_catg_descr = 'Other Revenue' then r.fncl_trans_amt end) as other_rev

from the607_profile_clients_accts c
inner join analytics_ops.admin.c360_fncl_mth_fact r
on c.acct_id = r.acct_id
inner join dm_ops.admin.vw_fncl_trans_type_dim d
on r.fncl_trans_type_cd = d.fncl_trans_type_cd

where
d.fncl_trans_catg_nm = 'Revenue'
and r.fscl_mth_id between &month1. and &month2.

group by client_id

distribute on (client_id);



/* Trades info */
drop table the607_profile_trades if exists;

create table the607_profile_trades as
with timer as(
select dt_nm, fscl_mth_seq_nbr
from edw_admin.admin.vw_tm_mst
where fscl_mth_id between &month1. and &month2.)

select
c.client_id
,sum(total_trades) as trades
,sum(case when scrty_type_cd = 'S' then total_trades else 0 end) as equity_trd
,sum(case when scrty_type_cd = 'O' then total_trades else 0 end) as option_trd
,sum(case when scrty_type_cd = 'F' then total_trades else 0 end) as mutual_fund_trd
,sum(case when scrty_type_cd = 'B' then total_trades else 0 end) as fixed_income_trd
,sum(case when scrty_type_cd in('I','W') then total_trades else 0 end) as other_security_trd
,sum(case when scrty_type_cd in ('FF','FO') then total_trades else 0 end) as fut_trd
,sum(case when scrty_type_cd = 'FX' then total_trades else 0 end) as fx_trd
,sum(case when (comm <= 0 or comm is null) then total_trades else 0 end) as free_trd
,sum(case when t.fscl_mth_seq_nbr = &fscl_mth_seq_nbr. then total_trades else 0 end) as trades_1mo
,sum(case when t.fscl_mth_seq_nbr >= (&fscl_mth_seq_nbr. - 5) then total_trades else 0 end) as trades_6mo

from the607_profile_clients_accts c
inner join analytics_cons.admin.revenue_trade_fact d
on c.acct_id = d.acct_id
inner join timer t
on d.recording_dt = t.dt_nm

group by client_id

distribute on (client_id);



/* Asset movement info */
drop table the607_profile_transfers if exists;

create table the607_profile_transfers as
select
c.client_id
,sum(assets_in) as assets_in
,sum(assets_out) as assets_out
,sum(client_directed_nna) as client_nna

from the607_profile_clients_accts c
inner join edw_admin.admin.vw_acct_net_new_assets a
on c.acct_id = a.acct_id

where
a.acct_id not in (1021315092,1020273856,1020276986,1003224315)
and a.fscl_mth_id between &month1. and &month2.

group by c.client_id

distribute on (client_id);



/* IXI info */
drop table the607_profile_ixi if exists;

create table the607_profile_ixi as
select
c.client_id
,i.tot_asset_amt as ixi_tot_assets
,i.stock_asset_amt as ixi_stock_assets
,i.bond_asset_amt as ixi_bond_assets
,i.mutlfnd_asset_amt as ixi_mutfund_assets
,i.depst_asset_amt as ixi_dep_assets
,i.annty_asset_amt as ixi_annty_assets
,i.other_asset_amt as ixi_other_assets

from the607_profile_distinct_clients c
inner join edw_admin.admin.ixi_wealth_complt_curr i
on c.client_id = i.client_id

distribute on (client_id);



/*** Revised Platform usage - using platform tables updated Aug 2019 */

drop table the607_profile_platform if exists;

create table the607_profile_platform as
with timer as(
select dt_nm, fscl_mth_seq_nbr
from edw_admin.admin.vw_tm_mst
where fscl_mth_id between &month1. and &month2.
group by 1,2)

select 
p.client_id
,count(distinct case when grid = 1 and t.fscl_mth_seq_nbr = &fscl_mth_seq_nbr. then event_dt end) as grid_site_1mo
,count(distinct case when tdax_mobile_web = 1 and t.fscl_mth_seq_nbr = &fscl_mth_seq_nbr. then event_dt end) as tdax_1mo
,count(distinct case when tos = 1 and t.fscl_mth_seq_nbr = &fscl_mth_seq_nbr. then event_dt end) as tos_1mo
,count(distinct case when tda_mobile = 1 and t.fscl_mth_seq_nbr = &fscl_mth_seq_nbr. then event_dt end) as tdam_1mo
,count(distinct case when mobile_trader = 1 and t.fscl_mth_seq_nbr = &fscl_mth_seq_nbr. then event_dt end) as mtrader_1mo

,count(distinct case when grid = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-5 then event_dt end) as grid_site_6mo
,count(distinct case when tdax_mobile_web = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-5 then event_dt end) as tdax_6mo
,count(distinct case when tos = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-5 then event_dt end) as tos_6mo
,count(distinct case when tda_mobile = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-5 then event_dt end) as tdam_6mo
,count(distinct case when mobile_trader = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-5 then event_dt end) as mtrader_6mo

,count(distinct case when grid = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-11 then event_dt end) as grid_site_12mo
,count(distinct case when tdax_mobile_web = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-11 then event_dt end) as tdax_12mo
,count(distinct case when tos = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-11 then event_dt end) as tos_12mo
,count(distinct case when tda_mobile = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-11 then event_dt end) as tdam_12mo
,count(distinct case when mobile_trader = 1 and t.fscl_mth_seq_nbr >= &fscl_mth_seq_nbr.-11 then event_dt end) as mtrader_12mo

from analytics_cons.admin.acct_platform_clicks p
join timer t
	on p.event_dt = t.dt_nm

group by 1
distribute on (client_id);




/* Inbound calls */
drop table the607_profile_calls if exists;

create table the607_profile_calls as
with timer as (
select dt_nm
from edw_admin.admin.vw_tm_mst
where fscl_mth_id between &month1. and &month2.)

select
c.client_id
,sum(case when a.call_id is not null then 1 else 0 end) as inbound_calls

from the607_profile_clients_accts c
inner join edw_admin.admin.cti_call a
on c.acct_id = a.acct_id
and a.in_out = 'I'
inner join timer t
on a.rec_cr_dt = t.dt_nm

group by client_id

distribute on (client_id);



/*Scottrade legacy clients 
**the607_sct_dual_clients table includes a list of clients who were dual-relationship with SCT at the time of conversion Feb 23, 2018;
**we will consider the dual-relationship clients to be TDA clients, hence they are being excluded in this step;*/
drop table the607_profile_sct if exists;

create table the607_profile_sct as
select
c.client_id
,1 as sct_client

from the607_profile_clients_accts c
left join mktg.admin.the607_sct_dual_clients s
on c.client_id = s.client_id
where c.legacy_cd = 'SCT'
and s.client_id is null

group by 1
distribute on (client_id);


/* Branch and financial consultant activity */
drop table the607_profile_branch1 if exists;
drop table the607_profile_branch2 if exists;
drop table the607_profile_branch3 if exists;

create table the607_profile_branch1 as
select distinct client_id, 1 as branch_contact
from mktg_camp.admin.cim_365d_ic_cntct_supp_clnt_lvl
distribute on (client_id);

create table the607_profile_branch2 as
select distinct client_id, 1 as branch_activity
from mktg_camp.admin.cim_365d_ic_actvy_supp_clnt_lvl
distribute on (client_id);

create table the607_profile_branch3 as
select distinct a.client_id, 1 as branch_attempt
from mktg_camp.admin.cim_365d_ic_attmpt_supp_clnt_lvl a
left join mktg_camp.admin.cim_365d_ic_cntct_supp_clnt_lvl b
on a.client_id = b.client_id
where b.client_id is null
distribute on (client_id);



/* FC or SFC */
drop table the607_fc_sfc if exists;

create temp table nt1 as (
select sales_crm_user_id,emp_alias_id,rank() over (partition by sales_crm_user_id order by eff_ts desc) as rank 
from edw_admin.admin.sales_crm_user_hist
where curr_ind = 'Y'
);

create table the607_fc_sfc as
select
d.client_id
,t.role_type

from edw_admin.admin.tmp_vw_ods_csg h
inner join mktg_camp.admin.client_data_hub_hist d
on h.csg_id = d.csg_id
inner join nt1 uh
on h.ivstmt_cnsltnt_id = uh.sales_crm_user_id and rank = 1
inner join edw_admin.admin.emp_hist eh
on uh.emp_alias_id = eh.emp_alias_id and eh.curr_ind = 1
inner join edw_admin.admin.vw_ref_job_title_type job
on eh.job_title_type_cd = job.job_title_type_cd
left join mktg.admin.cim_job_titles t
on job.nm = t.nm

where d.fscl_mth_id = &month2.

distribute on (client_id);



/* create final table */
drop table the607_profile_ew_data if exists;

create table the607_profile_ew_data as
select
a.client_id
,a.csg_id
,a.funded_ind
,a.sgmt_cd
,a.sgmt_sub_cd
,a.ds_sgmt_cd
,a.ds_sgmt_sub_cd
,a.ret_op_segment
,a.ret_op_sub_segment
,a.male
,a.female
,a.dbs_client
,a.first_acct_open_dt
,a.selective_ind
,a.essential_ind
,a.personalized_ind
,a.ims_client
,a.client_age
,a.asia_client
,a.asia_dual
,a.brokerageandims_liq_bal
,a.brkg_liq_bal
,a.individual_brkg_liq_bal
,a.retirement_brkg_liq_bal
,a.other_brkg_liq_bal
,a.selective_balance
,a.essential_balance
,a.personalized_balance
,a.brkg_mrgn_bal_amt
,a.brkg_tot_posn_amt
,a.selective_posn_bal
,a.essential_posn_bal
,a.personalized_posn_bal
,a.cash
,a.stockeqty
,a.etf
,a.options
,a.mutfund
,a.bond_debent
,a.bond_muni
,a.cdo
,a.cd
,a.govt_trsy
,a.fi_total
,a.warrant
,a.other
,a.opt_tier1
,a.opt_tier2
,a.opt_tier3
,a.first_margin_apprvd_dt
,a.mrgn_apprv_ind
,a.first_option_apprvd_dt
,a.option_apprv_ind
,a.first_fut_apprvd_dt
,a.fut_apprv_ind
,a.first_fx_apprvd_dt
,a.fx_apprv_ind
,b.accounts_count
,b.funded_accts_cnt
,b.individual_acct_ind
,b.retirement_acct_ind
,b.contributory_ret_acct_ind
,b.rollover_ret_acct_ind
,b.ira_acct_ind
,b.non_ira_acct_ind
,b.joint_acct_ind
,b.beneficiary_acct_ind
,b.business_acct_ind
,c.trans_rev
,c.margin_rev
,c.spread_rev
,c.asset_based_rev
,c.other_rev
,d.trades
,d.equity_trd
,d.option_trd
,d.mutual_fund_trd
,d.fixed_income_trd
,d.other_security_trd
,d.fut_trd
,d.fx_trd
,d.free_trd
,d.trades_1mo
,d.trades_6mo
,e.assets_in
,e.assets_out
,e.client_nna
,f.ixi_tot_assets
,f.ixi_stock_assets
,f.ixi_bond_assets
,f.ixi_mutfund_assets
,f.ixi_dep_assets
,f.ixi_annty_assets
,f.ixi_other_assets
,g.grid_site_1mo
,g.grid_site_6mo
,g.grid_site_12mo
,g.tdam_1mo
,g.tdam_6mo
,g.tdam_12mo
,g.tos_1mo
,g.tos_6mo
,g.tos_12mo
,g.mtrader_1mo
,g.mtrader_6mo
,g.mtrader_12mo
,g.tdax_1mo
,g.tdax_6mo
,g.tdax_12mo
,j.inbound_calls
,l.sct_client
,m.branch_contact
,n.branch_activity
,o.branch_attempt
,p.role_type

from the607_profile_datahub a
left join the607_profile_eom b
	on a.client_id = b.client_id
left join the607_profile_revenue c
	on a.client_id = c.client_id
left join the607_profile_trades d
	on a.client_id = d.client_id
left join the607_profile_transfers e
	on a.client_id = e.client_id
left join the607_profile_ixi f
	on a.client_id = f.client_id
left join the607_profile_platform g
	on a.client_id = g.client_id
left join the607_profile_calls j
	on a.client_id = j.client_id
left join the607_profile_sct l
	on a.client_id = l.client_id
left join the607_profile_branch1 m
	on a.client_id = m.client_id
left join the607_profile_branch2 n
	on a.client_id = n.client_id
left join the607_profile_branch3 o
	on a.client_id = o.client_id
left join the607_fc_sfc p
	on a.client_id = p.client_id

distribute on (client_id);


/* drop the tables no longer needed.  Only keep the607_profile_ew_data and the607_profile_clients_accts */
drop table the607_profile_distinct_clients;
drop table the607_profile_datahub;
drop table the607_profile_eom;
drop table the607_profile_revenue;
drop table the607_profile_trades;
drop table the607_profile_transfers;
drop table the607_profile_ixi;
drop table the607_profile_platform;
drop table the607_profile_calls;
drop table the607_profile_sct;
drop table the607_profile_branch1;
drop table the607_profile_branch2;
drop table the607_profile_branch3;
drop table the607_fc_sfc;

)
by SASIONZA;
disconnect from SASIONZA;
quit;





/*  download the data from EW.  This usually takes 20-30 min depending on EW workload  */

data tda.data_download;
	set edw_mktg.the607_profile_ew_data
	(bulkunload=yes);
run;


%put End Netezza Time: %now;



/* Data step to create columns used in calculations */

data tda.data_setup1;
	set tda.data_download;

	if inbound_calls=. then inbound_calls=0;
	if trans_rev=. then trans_rev=0;
	if margin_rev=. then margin_rev=0;
	if spread_rev=. then spread_rev=0;
	if asset_based_rev=. then asset_based_rev=0;
	if other_rev=. then other_rev=0;
	if trades=. then trades=0;
	if equity_trd=. then equity_trd=0;
	if option_trd=. then option_trd=0;
	if mutual_fund_trd=. then mutual_fund_trd=0;
	if fixed_income_trd=. then fixed_income_trd=0;
	if other_security_trd=. then other_security_trd=0;
	if fut_trd=. then fut_trd=0;
	if fx_trd=. then fx_trd=0;
	if free_trd=. then free_trd=0;
	if assets_in=. then assets_in=0;
	if assets_out=. then assets_out=0;
	if client_nna=. then client_nna=0;
	if grid_site_1mo=. then grid_site_1mo=0;
	if grid_site_6mo=. then grid_site_6mo=0;
	if grid_site_12mo=. then grid_site_12mo=0;
	if tdam_1mo=. then tdam_1mo=0;
	if tdam_6mo=. then tdam_6mo=0;
	if tdam_12mo=. then tdam_12mo=0;
	if tos_1mo=. then tos_1mo=0;
	if tos_6mo=. then tos_6mo=0;
	if tos_12mo=. then tos_12mo=0;
	if mtrader_1mo=. then mtrader_1mo=0;
	if mtrader_6mo=. then mtrader_6mo=0;
	if mtrader_12mo=. then mtrader_12mo=0;
	if inbound_calls=. then inbound_calls=0;
	if pm_accts_flag=. then pm_accts_flag=0;
	if sct_client=. then sct_client=0;
	if branch_contact=. then branch_contact=0;
	if branch_activity=. then branch_activity=0;
	if branch_attempt=. then branch_attempt=0;
	if role_type = 'fc' then fc=1;
	if role_type = 'fc' then sfc=0;
	if role_type = 'sr_fc' then sfc=1;
	if role_type = 'sr_fc' then fc=0;
	if ds_sgmt_cd = '' then ds_sgmt_cd= 'Not Tagged';
	if ds_sgmt_sub_cd = '' then ds_sgmt_sub_cd= 'Not Tagged';
	if ret_op_segment = '' then ret_op_segment = 'Not Tagged';
	if ret_op_sub_segment = '' then ret_op_sub_segment = 'Not Tagged';


	age_18l   = (client_age < 18);
	age_18_30 = (18 <= client_age <= 29);
	age_30_39 = (30 <= client_age <= 39);
	age_40_44 = (40 <= client_age <= 44);
	age_45_49 = (45 <= client_age <= 49);
	age_50_54 = (50 <= client_age <= 54);
	age_55_59 = (55 <= client_age <= 59);
	age_60_64 = (60 <= client_age <= 64);
	age_65_74 = (65 <= client_age <= 74);
	age_75p   = (client_age >= 75);

	tenure_years = (&date2b. - first_acct_open_dt)/365;
	new_client_3mo_1yr= (&trdate1. <= first_acct_open_dt < &trdate2.);
	mew_client_3mo= (first_acct_open_dt >= &trdate2.);

	grid_site_1mo_ind= grid_site_1mo > 0;
	grid_site_6mo_ind= grid_site_6mo > 0;
	grid_site_12mo_ind= grid_site_12mo > 0;
	tdam_1mo_ind= tdam_1mo > 0;
	tdam_6mo_ind= tdam_6mo > 0;
	tdam_12mo_ind= tdam_12mo > 0;
	tos_1mo_ind= tos_1mo > 0;
	tos_6mo_ind= tos_6mo > 0;
	tos_12mo_ind= tos_12mo > 0;
	mtrader_1mo_ind= mtrader_1mo > 0;
	mtrader_6mo_ind= mtrader_6mo > 0;
	mtrader_12mo_ind= mtrader_12mo > 0;

	trades_1mo_ind= trades_1mo > 0;
	trades_6mo_ind= trades_6mo > 0;
	trades_12mo_ind= trades > 0;

	assets_in_ind= assets_in > 0;

	new_margin_appr= (first_margin_apprvd_dt >= &date1a.);
	new_option_apprv= (first_option_apprvd_dt >= &date1a.);
	new_fut_apprv= (first_fut_apprvd_dt >= &date1a.) ;
	new_fx_apprv= (first_fx_apprvd_dt >= &date1a.);

	total_liq_bal= brokerageandims_liq_bal;
	total_posn_bal= sum(brkg_tot_posn_amt,selective_posn_bal,essential_posn_bal,personalized_posn_bal);
	total_mrgn_bal= -brkg_mrgn_bal_amt;
	total_cash_bal= cash;
	fi_no_cd_bal= fi_total - cd;
	other_posn_bal= sum(warrant,other);
	ira_liq_bal= retirement_brkg_liq_bal;
	non_ira_liq_bal= sum(individual_brkg_liq_bal,other_brkg_liq_bal,selective_balance,essential_balance,personalized_balance);

	balances_100l= 		(0 <= total_liq_bal < 100); 
	balances_100_3k= 	(100 <= total_liq_bal < 3000); 
	balances_3k_10k=	(3000 <= total_liq_bal < 10000); 
	balances_10k_25k=	(10000 <= total_liq_bal < 25000); 
	balances_25k_100k=	(25000 <= total_liq_bal < 100000); 
	balances_100k_250k=	(100000 <= total_liq_bal < 250000); 
	balances_250k_1M=	(250000 <= total_liq_bal < 1000000);  
	balances_1MH=		(total_liq_bal >= 1000000);
	hac_client = 		(total_liq_bal >= 100000);

	total_rev= sum(trans_rev,margin_rev,spread_rev,asset_based_rev,other_rev);
	qualified_ind= total_liq_bal >= 3000;

	free_trades= free_trd;
	commission_trades= trades - free_trades;

	ixi_other_assets_alt= sum(ixi_annty_assets,ixi_other_assets);

	if sgmt_sub_cd='AT-Tier1' then ATTier1=1; else ATTier1=0;
	if sgmt_sub_cd='AT-Tier2' then ATTier2=1; else ATTier2=0;
	if sgmt_sub_cd='AT-Tier3' then ATTier3=1; else ATTier3=0;
	if sgmt_sub_cd='CORE-Accum' then CoreAcc=1; else CoreAcc=0;
	if sgmt_sub_cd='CORE-Ret' then CoreRet=1; else CoreRet=0;
	if sgmt_sub_cd='CORE-Young' then CoreYoung=1; else CoreYoung=0;
	if sgmt_sub_cd='EMRG-Core' then EMRGCore=1; else EMRGCore=0;
	if sgmt_sub_cd='EMRG-Lo' then EMRGLow=1; else EMRGLow=0;
	if sgmt_sub_cd='EMRG-PCS' then EMRGPCS=1; else EMRGPCS=0;
	if sgmt_sub_cd='PCS-Diseng' then PCSDis=1; else PCSDis=0;
	if sgmt_sub_cd='PCS-Eng' then PCSEng=1; else PCSEng=0;

	if ds_sgmt_sub_cd='WorkingEMP' then EmpWork=1; else EmpWork=0;
	if ds_sgmt_sub_cd='Ret-EMP' then EmpRet=1; else EmpRet=0;
	if ds_sgmt_sub_cd='WorkingSUP' then SuppWork=1; else SuppWork=0;
	if ds_sgmt_sub_cd='Ret-SUP' then SuppRet=1; else SuppRet=0;
	if ds_sgmt_sub_cd='AFF/POSEXP' then ExpPosAff=1; else ExpPosAff=0;
	if ds_sgmt_sub_cd='AFF/NEGEXP' then ExpNegAff=1; else ExpNegAff=0;
	if ds_sgmt_sub_cd='Non-AFFEXP' then ExpPosNon=1; else ExpPosNon=0;
	if ds_sgmt_sub_cd='Daunted' then Daunt=1; else Daunt=0;
	if ds_sgmt_sub_cd='Not Tagged' then Notag=1; else Notag=0;
	if ds_sgmt_sub_cd='New Client' then Newclient=1; else Newclient=0;

	if ret_op_segment = 'Trader' then Trader=1; else Trader=0;
	if ret_op_segment = 'Engaged_Investor' then EngagedInvestor=1; else EngagedInvestor=0;
	if ret_op_segment = 'Investor' then Investor=1; else Investor=0;
	if ret_op_segment = 'Unengaged' then Unengaged=1; else Unengaged=0;
	if ret_op_segment = 'New Client' then New_client=1; else New_client=0;
	if ret_op_segment = 'Not Tagged' then Not_tagged=1; else Not_tagged=0;

run;



/* Householding factor */
proc sql noprint;
select count(distinct client_id)/count(distinct csg_id) into :hh_factor from tda.data_download where funded_ind=1;
quit;



/* IXI and HH SOW calculations.  Missing values are imputed and some other adjustments are made */

** find the median values using funded clients;
proc means data=tda.data_setup1 n nmiss min max mean sum median noprint;
	where funded_ind= 1;
	var ixi_tot_assets
		ixi_stock_assets
		ixi_bond_assets
		ixi_mutfund_assets
		ixi_dep_assets
		ixi_other_assets_alt;
	output out= ixi_median median= sum= / autoname;
run;



data ixi_median;
    set ixi_median;
    call symput('tot_asset_amt_med', ixi_tot_assets_median);
    call symput('stock_asset_amt_med', ixi_stock_assets_median);
	call symput('bond_asset_amt_med', ixi_bond_assets_median);
    call symput('mutlfnd_asset_amt_med', ixi_mutfund_assets_median);
    call symput('depst_asset_amt_med', ixi_dep_assets_median);
    call symput('other_asset_amt_med', ixi_other_assets_alt_median);
	call symput('stock_asset_percent', divide(ixi_stock_assets_sum,ixi_tot_assets_sum));
	call symput('bond_asset_percent', divide(ixi_bond_assets_sum,ixi_tot_assets_sum));
	call symput('mutlfnd_asset_percent', divide(ixi_mutfund_assets_sum,ixi_tot_assets_sum));
	call symput('depst_asset_percent', divide(ixi_dep_assets_sum,ixi_tot_assets_sum));
	call symput('other_asset_percent', divide(ixi_other_assets_alt_sum,ixi_tot_assets_sum));
run;




/* Clean up the IXI data to give us a better estimate of HH assets */

data tda.data_setup2;
	set tda.data_setup1;

	**impute the median value where missing, and then adjust upward if the TDA value is higher;
	if ixi_tot_assets=. and funded_ind=1 then
	ixi_tot_assets=&tot_asset_amt_med.;
	if (total_liq_bal) > ixi_tot_assets and funded_ind=1 then
	ixi_tot_assets=round(total_liq_bal);

	if ixi_stock_assets=. and funded_ind=1 then 
	ixi_stock_assets=&stock_asset_amt_med.;
	if (stockeqty) > ixi_stock_assets and funded_ind=1 then 
	ixi_stock_assets=round(stockeqty); 

	if ixi_bond_assets=. and funded_ind=1 then
	ixi_bond_assets=&bond_asset_amt_med.;
	if (fi_no_cd_bal) > ixi_bond_assets and funded_ind=1 then
	ixi_bond_assets=round(fi_no_cd_bal);

	if ixi_mutfund_assets=. and funded_ind=1 then
	ixi_mutfund_assets=&mutlfnd_asset_amt_med.; 
	if (mutfund) > ixi_mutfund_assets and funded_ind=1 then
	ixi_mutfund_assets=round(mutfund); 

	if ixi_dep_assets=. and funded_ind=1 then
	ixi_dep_assets=&depst_asset_amt_med.; 
	if (total_cash_bal) > ixi_dep_assets and funded_ind=1 then
	ixi_dep_assets=round(total_cash_bal); 

	if ixi_other_assets_alt =. and funded_ind=1 then
	ixi_other_assets_alt=&other_asset_amt_med.; 


	**if tot_asset_amt does not equal the sum of the 6 categories, then make adjustments;
	if ixi_tot_assets > sum(ixi_stock_assets, ixi_bond_assets, ixi_mutfund_assets, ixi_dep_assets,
	ixi_other_assets_alt) and funded_ind=1 then do;

	sumfix=sum(ixi_stock_assets, ixi_bond_assets, ixi_mutfund_assets, ixi_dep_assets,
	ixi_other_assets_alt);

	if sumfix ne 0 then do;
	ixi_stock_assets = round(ixi_tot_assets*(ixi_stock_assets/sumfix));
	ixi_bond_assets = round(ixi_tot_assets*(ixi_bond_assets/sumfix));
	ixi_mutfund_assets = round(ixi_tot_assets*(ixi_mutfund_assets/sumfix));
	ixi_dep_assets = round(ixi_tot_assets*(ixi_dep_assets/sumfix));
	ixi_other_assets_alt = round(ixi_tot_assets*(ixi_other_assets_alt/sumfix));
	end;

	else if sumfix=0 then do;
	ixi_stock_assets = round(ixi_tot_assets*&stock_asset_percent.);
	ixi_bond_assets = round(ixi_tot_assets*&bond_asset_percent.);
	ixi_mutfund_assets = round(ixi_tot_assets*&mutlfnd_asset_percent.);
	ixi_dep_assets = round(ixi_tot_assets*&depst_asset_percent.);
	ixi_other_assets_alt = round(ixi_tot_assets*&other_asset_percent.);
	end;

	end;


	else if ixi_tot_assets < sum(ixi_stock_assets, ixi_bond_assets, ixi_mutfund_assets, ixi_dep_assets,
	ixi_other_assets_alt) and funded_ind=1 then do;

	sumfix=sum(ixi_stock_assets, ixi_bond_assets, ixi_mutfund_assets, ixi_dep_assets,
	ixi_other_assets_alt);

	ixi_tot_assets=sumfix;

	end;


	**adjust for household factor;
	ixi_tot_assets= ixi_tot_assets/&hh_factor.;
	ixi_stock_assets= ixi_stock_assets/&hh_factor.;
	ixi_bond_assets= ixi_bond_assets/&hh_factor.;
	ixi_mutfund_assets= ixi_mutfund_assets/&hh_factor.;
	ixi_dep_assets= ixi_dep_assets/&hh_factor.;
	ixi_other_assets_alt= ixi_other_assets_alt/&hh_factor.;

	hh_sow= total_liq_bal/ixi_tot_assets;
	hh_equity_sow= stockeqty/ixi_stock_assets;
	hh_mfund_sow= mutfund/ixi_mutfund_assets;
	hh_fi_sow= fi_no_cd_bal/ixi_bond_assets;
	hh_cash_sow= total_cash_bal/ixi_dep_assets;

	ixi_100kl= (0 <= ixi_tot_assets < 100000);
	ixi_100k_250k= (100000 <= ixi_tot_assets < 250000);
	ixi_250k_500k= (250000 <= ixi_tot_assets < 500000);
	ixi_500k_1M= (500000 <= ixi_tot_assets < 1000000);
	ixi_1Mh= (ixi_tot_assets >= 1000000);

	informat ixi_range $10. ixi_sgmt $15. ixi_ds $20.;
	if (ixi_tot_assets < 100000) then ixi_range= '<100k';
	else if (100000 <= ixi_tot_assets < 500000) then ixi_range= '100k-500k';
	else if (500000 <= ixi_tot_assets < 1000000) then ixi_range= '500k-1M';
	else if (ixi_tot_assets >= 1000000) then ixi_range= '>1M';

	ixi_sgmt= trim(sgmt_cd)||trim(ixi_range);
	ixi_ds= trim(ds_sgmt_cd)||trim(ixi_range);
	ixi_opseg= trim(ret_op_segment)||trim(ixi_range);

run;




/* create the final data set */

data tda.tda_clnt_&month2.;
	set tda.data_setup2;
run;




/* Macro for profile summary */

%macro export_profile(classvar=);

**summarize data;
proc means data=tda.tda_clnt_&month2. noprint;
	class &classvar;
	var %variable_list;;
	output out=output_&classvar %output_list;;
	where funded_ind=1 and sgmt_cd ne '';
run;


**transpose so it fits into Excel properly;
proc transpose data=output_&classvar
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
	outfile= "&output_loc\&output_file..xlsx"
	dbms= xlsx
	replace;
	sheet= &classvar;
run;


%mend export_profile;



/* Run the macros that summarize and export the data */

%export_profile(classvar= funded_ind);
%export_profile(classvar= sct_client);
%export_profile(classvar= sgmt_cd);
%export_profile(classvar= sgmt_sub_cd);
%export_profile(classvar= ds_sgmt_cd);
%export_profile(classvar= ds_sgmt_sub_cd);
%export_profile(classvar= ixi_range);
%export_profile(classvar= ixi_sgmt);
%export_profile(classvar= ixi_ds);
%export_profile(classvar= ret_op_segment);
%export_profile(classvar= ixi_opseg);


/* delete BAK file */
x del "&output_loc\&output_file..xlsx.bak";


%put End Time: %now;
