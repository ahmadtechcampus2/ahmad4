###########################################################################
CREATE VIEW vwRestCaptin
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
	[VnPassword] 
   FROM [RestVendor000] where type=1
###########################################################################
#END