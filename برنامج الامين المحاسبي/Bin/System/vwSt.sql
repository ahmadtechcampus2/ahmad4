#########################################################
CREATE VIEW vtSt
AS
	SELECT * FROM [st000]

#########################################################
CREATE VIEW vbSt
AS
	SELECT [v].*
	FROM [vtSt] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0
	
#########################################################
CREATE VIEW vcSt
AS
	SELECT * FROM [vbSt]

#########################################################
CREATE VIEW vdSt
AS
	SELECT [vbSt].*, ISNULL(st.Name, '') Parent FROM [vbSt] LEFT JOIN st000 st ON st.[GUID] = [vbSt].ParentGUID WHERE [vbSt].[Kind] = 0
#########################################################
CREATE VIEW vdstNoSons
AS
	SELECT * FROM [vdst] 
#########################################################
CREATE VIEW vwAllStores
AS
	SELECT [vbSt].*, ISNULL(st.Name, '') Parent FROM [vbSt] LEFT JOIN st000 st ON st.[GUID] = [vbSt].ParentGUID
#########################################################
CREATE VIEW vwSt
AS  
	SELECT  
		st.GUID			AS stGUID,  
		st.Number		AS stNumber, 
		st.ParentGUID	AS stParent,  
		st.Code			AS stCode,  
		st.Name			AS stName,  
		st.Notes		AS stNotes,  
		st.Address		AS stAddress,  
		st.Keeper		AS stKeeper,  
		st.AccountGUID	AS stAccount,  
		st.LatinName	AS stLatinName,  
		st.Security		AS stSecurity, 
		st.branchMask	AS stBranchMask,
		ISNULL(ac.acName, '') AS acName,
		ISNULL(vbst.Name, '') AS ParentName,
		st.Kind AS stKind
	FROM  
		vbSt AS st
		Left JOIN vwAc AS ac ON ac.acGuid = st.AccountGuid
		Left JOIN vbST ON vbSt.GUID = st.ParentGuid

#########################################################
#END