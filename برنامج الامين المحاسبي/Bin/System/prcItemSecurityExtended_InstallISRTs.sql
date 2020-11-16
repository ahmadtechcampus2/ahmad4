#########################################################
CREATE PROC prcItemSecurityExtended_InstallISRTs
AS
	SET NOCOUNT ON
	EXEC [prcItemSecurityExtended_AddISRT] 'Account', 'ac000', 'fnGetAccountsTree', '��������', 'Accounts', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'CostJob', 'co000', 'fnGetCostsTree', '����� ������', 'Jobs Costing', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'Material', 'mt000', 'fnGetMaterialsTree', '������ � ���������', 'Materials', 'GroupGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'Group', 'gr000', '', '', '', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'Store', 'st000', 'fnGetStoresTree', '����������', 'Stores', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'SubProfitCenter', 'SubProfitCenter000', 'fnGetPFCsTree', '����� �������', 'Profit Centers', 'ParentGuid'
	EXEC [prcItemSecurityExtended_AddISRT] 'MainProfitCenter', 'MainProfitCenter000', '', '' , '', 'ParentGuid'
	-- re-optimize views:
	EXEC [prcItemSecurityExtended_Optimize]
#########################################################
#END