###########################################################################
CREATE VIEW vwRestDriver
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
   FROM [RestVendor000] where type=0
###########################################################################
#END