######################################################### 
CREATE VIEW vwUSX
AS
	SELECT
		[guid] AS [usGuid],
		[bAdmin] AS [usbAdmin],
		[maxDiscount] AS [usMaxDiscount],
		[minPrice] AS [usMinPrice],
		[bActive] AS [usbActive],
		[branchReadMask] AS [usBranchReadMask],
		[branchWriteMask] AS [usBranchWriteMask],
		[maxPrice] AS [usMaxPrice]
	FROM
		[usx]

#########################################################
#END