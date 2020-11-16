#########################################################
CREATE VIEW vtAs
AS
	SELECT 
		[ASS].[Number], 
		[ASS].[GUID], 
		[ASS].[Code], 
		[ASS].[Name], 
		[ASS].[LatinName], 
		[ASS].[ParentGUID], 
		[ASS].[CurrencyGUID], 
		[ASS].[CurrencyVal], 
		[ASS].[CalcType], 
		[ASS].[LifeExp], 
		[ASS].[AccGUID], 
		[ASS].[DepAccGUID], 
		[ASS].[AccuDepAccGUID], 
		[ASS].[Spec], 
		[ASS].[Notes], 
		[mt].[Security],
		[mt].[branchMask] 
	FROM 
		[As000] [ASS] inner join [mt000] [mt] on [ASS].[ParentGuid] = [mt].[GUID]

#########################################################
CREATE VIEW vbAs
AS
SELECT *
		FROM
			[vtAs] 
		WHERE
			(vtAs.branchMask = 0 OR (dbo.[fnBranch_getCurrentUserReadMask_scalar](DEFAULT) & vtAs.branchMask <> 0))
#########################################################
CREATE VIEW vcAs
AS
	SELECT * FROM [vbAs]

#########################################################
CREATE VIEW vdAs
AS
	SELECT DISTINCT * FROM [vbAs]

#########################################################
CREATE VIEW vwAs 
AS 
	SELECT  
		[Number] AS [asNumber],  
		[GUID] AS [asGUID],  
		[Code] AS [asCode], 
		[Name] AS [asName],  
		[LatinName] AS [asLatinName],  
		[ParentGUID] AS [asParentGUID],  
		[CurrencyGUID] AS [asCurrencyGUID],  
		[CurrencyVal] AS [asCurrencyVal],  
		[CalcType] AS [asCalcType],  
		[LifeExp] AS [asLifeExp],  
		[AccGUID] AS [asAccGUID],  
		[DepAccGUID] AS [asDepAccGUID],  
		[AccuDepAccGUID] AS [asAccuDepAccGUID],  
		[Spec] AS [asSpec],  
		[Notes] AS [asNotes],  
		[Security] AS [asSecurity] 
	FROM  
		[vdAs]

#########################################################
CREATE VIEW vwAssetDetails
AS  
	SELECT  
		[AD].[GUID] AS [GUID], 
		[SNC].[SN] AS [Code], 
		[mt].[Name] AS [Name], 
		[mt].[Security] AS [Security], 
		[AD].[Number] AS [Number] 
	FROM 
		[as000] AS [Ass]  
		INNER JOIN [AD000] AS [AD] ON [Ass].[GUID] = [AD].[ParentGuid] 
		INNER JOIN [SNC000] AS [SNC] ON [SNC].[GUID] = [AD].[SNGuid] 
		INNER JOIN [mt000] mt ON [mt].[Guid] = [Ass].[ParentGUID] 
#########################################################
CREATE VIEW vwAssetsBr
AS
	SELECT ad.* from ad000 ad
	JOIN vfBr 
	ON ad.BrGuid = vfBr.[GUID]
#########################################################
#END