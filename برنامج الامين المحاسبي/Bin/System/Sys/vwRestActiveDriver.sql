###########################################################################
CREATE VIEW vwRestActiveDriver
AS  
 SELECT 
	[Number], 
	[GUID], 
	[Type], 
	[Code], 
	[Name], 
	[LatinName], 
	[Phone], 
	[Address], 
	[Certificate], 
	[BirthDate], 
	[Work], 
	[Notes], 
	[Security], 
	[AccountGUID], 
	[BranchMask],
	[DepartID],
	[IsAllAddress],
	[IsInactive]
   FROM [RestVendor000] where IsInactive = 0 AND type = 0
###########################################################################
#END