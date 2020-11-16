###################################
CREATE VIEW vwBillRel
AS
	SELECT
		[GUID] AS [brGUID],
		[Type] AS [brType],
		[BillGUID] AS [brBillGUID],
		[ParentGUID] AS [brParentGUID],
		[ParentNumber] AS [brParentNumber]
	FROM  
		[BillRel000]

###################################
#END