
%macro overall;
funded_ind
%mend overall;



%macro variable_list;

accounts_count

/* demographics info */
male
female
client_age
age_18l
age_18_30
age_30_39
age_40_44
age_45_49
age_50_54
age_55_59
age_60_64
age_65_74
age_75p
tenure_years

/* accounts info */
qualified_ind
individual_acct_ind
joint_acct_ind
retirement_acct_ind
contributory_ret_acct_ind
rollover_ret_acct_ind
beneficiary_acct_ind
business_acct_ind
selective_ind
essential_ind
personalized_ind

/* new clients */
mew_client_3mo
new_client_3mo_1yr

/* logins and app usage info */
grid_site_1mo
grid_site_6mo
grid_site_12mo
grid_site_1mo_ind
grid_site_6mo_ind
grid_site_12mo_ind
tos_1mo
tos_6mo
tos_12mo
tos_1mo_ind
tos_6mo_ind
tos_12mo_ind
tdam_1mo
tdam_6mo
tdam_12mo
tdam_1mo_ind
tdam_6mo_ind
tdam_12mo_ind
mtrader_1mo
mtrader_6mo
mtrader_12mo
mtrader_1mo_ind
mtrader_6mo_ind
mtrader_12mo_ind

/* Branch activity and contacts */
branch_activity
branch_attempt
fc
sfc
inbound_calls

/* balances and positions info */
total_liq_bal
balances_100l
balances_100_3k
balances_3k_10k 
balances_10k_25k
balances_25k_100k 
balances_100k_250k
balances_250k_1M
balances_1MH
total_posn_bal
total_mrgn_bal
total_cash_bal
stockeqty
etf
options
mutfund
fi_total
other_posn_bal
ira_liq_bal
non_ira_liq_bal


/* Revenue info */
total_rev
trans_rev
margin_rev
spread_rev
asset_based_rev
other_rev

/* Trades info */
trades
equity_trd
option_trd
mutual_fund_trd
fut_trd
fx_trd
fixed_income_trd
other_security_trd
trades_1mo_ind
trades_6mo_ind
trades_12mo_ind
commission_trades
free_trades
new_margin_appr
new_option_apprv
new_fut_apprv
new_fx_apprv
mrgn_apprv_ind
option_apprv_ind
fut_apprv_ind
fx_apprv_ind

/* Transfers info */
assets_in
assets_out
client_nna
assets_in_ind

/* IXI and HH SOW info */
ixi_tot_assets
ixi_stock_assets
ixi_mutfund_assets
ixi_bond_assets
ixi_dep_assets
ixi_other_assets_alt
ixi_100kl
ixi_100k_250k
ixi_250k_500k
ixi_500k_1M
ixi_1Mh
hh_sow
hh_equity_sow
hh_mfund_sow
hh_fi_sow
hh_cash_sow

/*Segmentation */
attier1
attier2
attier3
pcseng
pcsdis
coreacc
coreret
coreyoung
emrgcore
emrglow
emrgpcs
empwork
empret
suppwork
suppret
expposaff
expnegaff
expposnon
daunt
notag
newclient

/* Series 400 segmentation */
trader
engagedinvestor
investor
unengaged
new_client
not_tagged

%mend variable_list;



%macro output_list;

mean(accounts_count)=

/* demographics info */
mean(
male
female
client_age
age_18l
age_18_30
age_30_39
age_40_44
age_45_49
age_50_54
age_55_59
age_60_64
age_65_74
age_75p
tenure_years)=
p25(tenure_years)=
p50(tenure_years)=
p75(tenure_years)=

/* accounts info */
mean(
qualified_ind
individual_acct_ind
joint_acct_ind
retirement_acct_ind
contributory_ret_acct_ind
rollover_ret_acct_ind
beneficiary_acct_ind
business_acct_ind
essential_ind
selective_ind
personalized_ind)=

/* new clients */
mean(mew_client_3mo
new_client_3mo_1yr)=

/* logins and app usage info */
mean(
grid_site_1mo
grid_site_6mo
grid_site_12mo
grid_site_1mo_ind
grid_site_6mo_ind
grid_site_12mo_ind
tos_1mo
tos_6mo
tos_12mo
tos_1mo_ind
tos_6mo_ind
tos_12mo_ind
tdam_1mo
tdam_6mo
tdam_12mo
tdam_1mo_ind
tdam_6mo_ind
tdam_12mo_ind
mtrader_1mo
mtrader_6mo
mtrader_12mo
mtrader_1mo_ind
mtrader_6mo_ind
mtrader_12mo_ind)=

/* Branch activity and contacts */
mean(
branch_activity
branch_attempt
fc
sfc
inbound_calls)=

/* balances and positions info */
mean(total_liq_bal
balances_100l
balances_100_3k
balances_3k_10k 
balances_10k_25k
balances_25k_100k 
balances_100k_250k
balances_250k_1M
balances_1MH
total_posn_bal
total_mrgn_bal
total_cash_bal)=
p25(total_cash_bal)=
p50(total_cash_bal)=
p75(total_cash_bal)=
mean(
stockeqty
etf
options
mutfund
fi_total
other_posn_bal)=
sum(
total_liq_bal
total_posn_bal
stockeqty
etf
options
mutfund
fi_total
other_posn_bal
total_cash_bal)=
mean(
ira_liq_bal
non_ira_liq_bal)=


/* Revenue info */
mean(total_rev)=
p25(total_rev)=
p50(total_rev)=
p75(total_rev)=
mean(
trans_rev
margin_rev
spread_rev
asset_based_rev
other_rev)=
sum(
total_rev
trans_rev
margin_rev
spread_rev
asset_based_rev
other_rev)=

/* Trades info */
mean(trades)=
p25(trades)=
p50(trades)=
p75(trades)=
mean(
equity_trd
option_trd
mutual_fund_trd
fut_trd
fx_trd
fixed_income_trd
other_security_trd)=
sum(
trades
equity_trd
option_trd
mutual_fund_trd
fut_trd
fx_trd
fixed_income_trd
other_security_trd)=
mean(
trades_1mo_ind
trades_6mo_ind
trades_12mo_ind
commission_trades
free_trades)=
sum(
new_margin_appr
mrgn_apprv_ind
new_option_apprv
option_apprv_ind
new_fut_apprv
fut_apprv_ind
new_fx_apprv
fx_apprv_ind)=


/* Transfers info */
mean(assets_in)=
p25(assets_in)=
p50(assets_in)=
p75(assets_in)=
mean(
assets_out
client_nna
assets_in_ind)=
sum(
assets_in
assets_out
client_nna)=

/* IXI and HH SOW info */

mean(
ixi_tot_assets
ixi_stock_assets
ixi_mutfund_assets
ixi_bond_assets
ixi_dep_assets
ixi_other_assets_alt)=
sum(
ixi_tot_assets
ixi_stock_assets
ixi_mutfund_assets
ixi_bond_assets
ixi_dep_assets
ixi_other_assets_alt)=
mean(
ixi_100kl
ixi_100k_250k
ixi_250k_500k
ixi_500k_1M
ixi_1Mh
hh_sow
hh_equity_sow
hh_mfund_sow
hh_fi_sow
hh_cash_sow)=

/*Segmentation */
mean(
attier1
attier2
attier3
pcseng
pcsdis
coreacc
coreret
coreyoung
emrgcore
emrglow
emrgpcs
empwork
empret
suppwork
suppret
expposaff
expnegaff
expposnon
daunt
newclient
notag
trader
engagedinvestor
investor
unengaged
new_client
not_tagged)=


/autoname

%mend output_list;
