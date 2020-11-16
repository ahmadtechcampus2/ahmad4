#########################################################
CREATE VIEW vtTrnOffice
AS
	SELECT * FROM TrnOffice000
#########################################################
CREATE VIEW vbTrnOffice
AS
	SELECT v.*
	FROM vtTrnOffice AS v 
	INNER JOIN fnBranch_GetCurrentUserReadMask(DEFAULT) AS f ON v.branchMask & f.Mask <> 0
#########################################################
CREATE VIEW vcTrnOffice
AS
	SELECT * FROM vbTrnOffice
#########################################################
CREATE VIEW vdTrnOffice
AS
	SELECT * FROM vbTrnOffice
#########################################################
CREATE  VIEW vwTrnOffice
AS  
	SELECT  
		Number AS OfNumber,
		GUID AS OfGUID, 
		Code AS OfCode,
		Name AS OfName, 
		AccGUID AS OfAccGUID, 
		WagesAccGUID AS OfWagesAccGUID, 
		Security AS OfSecurity,
		Company AS OfCompany,
		City AS OfCity,
		State AS OfState,
		bLocal AS OfbLocal
	FROM  
		vbTrnOffice
#########################################################	
CREATE FUNCTION VwTrnBranchOffice()
	RETURNS @Result Table 
		([Type] [INT], 
		[Number] [INT], 
		[GUID] [uniqueidentifier], 
		[Name] [nvarchar] (250) COLLATE Arabic_CI_AI ,
		[Code] [nvarchar] (100) COLLATE Arabic_CI_AI ,
		[AccGuid] [uniqueidentifier], 
		[WagesAccGUID] [uniqueidentifier])
AS	
BEGIN 
	INSERT INTO @Result
	SELECT 
		1, 
		[Number],
		[GUID],
		[Name],
		[Code],
		[BranchAccGUID],
		[WagesAccGUID]
	FROM vwTrnBranch 
			
	INSERT INTO @Result
	SELECT 
		2, 
		[OfNumber],
		[OfGUID],
		[OfName],
		[OfCode],
		[OfAccGUID],
		[OfWagesAccGUID]
	FROM vwTrnOffice
RETURN 
END
#########################################################	
#END