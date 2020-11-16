#########################################################
CREATE PROC prcItemSecurityExtended_InstallISRTs
AS
	SET NOCOUNT ON
	EXEC [prcItemSecurityExtended_AddISRT] 'Account', 'ac000', 'fnGetAccountsTree', '«·Õ”«»« ', 'Accounts', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'CostJob', 'co000', 'fnGetCostsTree', '„—«ﬂ“ «·ﬂ·›…', 'Jobs Costing', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'Material', 'mt000', 'fnGetMaterialsTree', '«·„Ê«œ Ê «·„Õ„Ê⁄« ', 'Materials', 'GroupGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'Group', 'gr000', '', '', '', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'Store', 'st000', 'fnGetStoresTree', '«·„” Êœ⁄« ', 'Stores', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'SubProfitCenter', 'SubProfitCenter000', 'fnGetPFCsTree', '„—«ﬂ“ «·—»ÕÌ…', 'Profit Centers', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'MainProfitCenter', 'MainProfitCenter000', '', '' , '', 'ParentGuid'
	-- re-optimize views:
	EXEC [prcItemSecurityExtended_Optimize]
#########################################################
#END