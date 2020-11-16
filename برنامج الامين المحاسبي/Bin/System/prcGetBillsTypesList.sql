#########################################################
CREATE PROCEDURE prcGetBillsTypesList
	@SrcGuid [UNIQUEIDENTIFIER] = NULL,
	@UserGUID [UNIQUEIDENTIFIER] = NULL
AS 
/* 
This procedure: 
	- returns the Type, Security of provided @SrcGuid.
	- returns all types when @Source is NULL. 
	- can get the UserID if not specified. 
*/ 
	SET NOCOUNT ON
	SELECT
		[GUID],
		[Security],
		[ReadPriceSecurity]
	FROM
		[dbo].[fnGetBillsTypesList](@SrcGuid, @UserGuid)

#########################################################
CREATE PROCEDURE prcGetBillsTypesList2
	@SrcGuid [UNIQUEIDENTIFIER] = NULL, 
	@UserGUID [UNIQUEIDENTIFIER] = NULL
AS  
/*
This procedure:  
	- returns the Type, Security of provided @SrcGuid. 
	- returns all types when @Source is NULL.  
	- can get the UserID if not specified.  
*/  
	SET NOCOUNT ON
	SELECT 
		[GUID], 
		[PostedSecurity] AS [Security],
		[ReadPriceSecurity],
		[UnPostedSecurity]
	FROM 
		[dbo].[fnGetBillsTypesList2](@SrcGuid, @UserGuid, DEFAULT)
#########################################################
CREATE PROCEDURE prcGetBillsTypesList3
	@SrcGuid [UNIQUEIDENTIFIER] = NULL, 
	@UserGUID [UNIQUEIDENTIFIER] = NULL,
	@SortAffectCostType	BIT = 0
AS  
/*
This procedure:  
	- returns the Type, Security of provided @SrcGuid. 
	- returns all types when @Source is NULL.  
	- can get the UserID if not specified.  
*/  
	SET NOCOUNT ON
	SELECT 
		[GUID], 
		[PostedSecurity] AS [Security],
		[ReadPriceSecurity],
		[UnPostedSecurity],
		[PriorityNum],
		[SamePriorityOrder],
		[SortNumber]
	FROM 
		[dbo].[fnGetBillsTypesList2](@SrcGuid, @UserGuid, @SortAffectCostType)
#########################################################
#END