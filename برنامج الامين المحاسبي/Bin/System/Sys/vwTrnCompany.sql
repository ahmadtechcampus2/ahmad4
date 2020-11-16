#########################################################
CREATE  VIEW vwTrnCompany
AS  
	SELECT  
		Number,
		GUID,	
		[Name],	
		LatinName,
		Code,	
		Security,
		Notes,
		Phone,
		Fax,	
		EMail
	FROM  
		TrnCompany000
#########################################################		
CREATE  VIEW vwTrnCenter
AS  
	SELECT 
		Center.Number,
		Center.GUID,
		Center.[Name],
		Center.LatinName,
		Center.Code,
		Center.CostGuid,
		Center.AccountGuid,
		Center.BranchGuid,
		Center.CompanyGuid,
		Center.Security,
		Center.Notes,
		Center.Phone,
		Center.Fax,
		Center.EMail,
		Center.Address,
		co.coName AS CostName,
		ISNULL(company.[Name], '') AS CompanyName,
		br.[Name] AS BranchName
	FROM  
		TrnCenter000 AS center
		INNER JOIN vwCo AS co ON co.coGuid = center.CostGuid
		LEFT JOIN vwTrnBranch AS br ON br.Guid = Center.BranchGuid
		INNER JOIN [vwBr] AS [brv] ON br.AmnBranchGUID = [brv].[brGUID]
		LEFT JOIN vwTrnCompany AS company ON company.Guid = center.CompanyGuid
	UNION 
	SELECT 
		Center.Number,
		Center.GUID,
		Center.[Name],
		Center.LatinName,
		Center.Code,
		Center.CostGuid,
		Center.AccountGuid,
		Center.BranchGuid,
		Center.CompanyGuid,
		Center.Security,
		Center.Notes,
		Center.Phone,
		Center.Fax,
		Center.EMail,
		Center.Address,
		co.coName AS CostName,
		ISNULL(company.[Name], '') AS CompanyName,
		'' AS BranchName
	FROM  
		TrnCenter000 AS center
		INNER JOIN vwCo AS co ON co.coGuid = center.CostGuid
		LEFT JOIN vwTrnCompany AS company ON company.Guid = center.CompanyGuid
	where center.BranchGuid =0x0
#########################################################	
CREATE VIEW vwTrnVoucherproc	
AS
	SELECT 
		prc.GUID,
		prc.Number,
		prc.VoucherGuid,
		prc.Branch,
		br.[Name] AS BranchName,
		prc.[DateTime],
		prc.StateBefore, 
		prc.StateAfter, 
		prc.ProcType, 
		prc.UserGuid,
		us.LoginName AS UserName, 
		iSNULL(prc.CenterGuid, 0x0) AS CenterGUID,
		ISNULL(center.[Name], '') AS CenterName
	FROM 
		TrnVoucherproc000 AS prc
		INNER JOIN vwTrnBranch AS br ON br.Guid = prc.Branch
		INNER JOIN Us000 AS us ON us.GUID = prc.UserGuid
		LEFT JOIN TrnCenter000 AS center ON center.GUID = prc.CenterGuid
#########################################################	
#END