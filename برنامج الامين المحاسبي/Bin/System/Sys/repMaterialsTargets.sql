############################################################################
CREATE PROCEDURE repMaterialsTargets 
	@StoreGuid			[UNIQUEIDENTIFIER] = 0x00,
	@PeriodGuid			[UNIQUEIDENTIFIER] = 0x00,
	@MaterialGuid		[UNIQUEIDENTIFIER] = 0x00,
	@GroupGuid			[UNIQUEIDENTIFIER] = 0x00,
	@TargetsAreSet		[BIT] = 0,
	@StoresWithTargets	[BIT] = 0,
	@MaterialsWithTargets	[BIT] = 1
AS 
	SET NOCOUNT ON  	
	
	CREATE TABLE [#Result](  
		[StoreGuid]		[UNIQUEIDENTIFIER],  
		[StoreCode]		[NVARCHAR](MAX) COLLATE ARABIC_CI_AI,
		[StoreName] 	[NVARCHAR](MAX) COLLATE ARABIC_CI_AI,  
		[PeriodGuid]	[UNIQUEIDENTIFIER],  
		[PeriodCode]	[NVARCHAR](MAX) COLLATE ARABIC_CI_AI,
		[PeriodName] 	[NVARCHAR](MAX) COLLATE ARABIC_CI_AI,  		
		[MaterialGuid]	[UNIQUEIDENTIFIER],  
		[MaterialCode]	[NVARCHAR](MAX) COLLATE ARABIC_CI_AI,
		[MaterialName]	[NVARCHAR](MAX) COLLATE ARABIC_CI_AI,   
		[TargetQty]		[FLOAT],
		[SalesPrice]	[FLOAT],
		[TargetPrice]	[FLOAT]
	   	)  
DECLARE @sql NVARCHAR(max)
	   	
IF (@TargetsAreSet = 1)
BEGIN
	set @sql = 'SELECT 
				stGuid,
				StoreCode,
				StoreName,
				bdpGuid,
				PeriodCode,
				PeriodName,
				mtGuid,
				MatCode,
				MatName,
				TargetQty,
				SalesPrice,
				TargetPrice
			FROM vwMatTargets AS vwMT '
	IF (@StoreGuid <> 0x00) 
	BEGIN
		SET @sql = @sql + ' INNER JOIN (SELECT * FROM fnGetLeafStores (''' + CAST(@StoreGuid AS NVARCHAR(255)) + ''')) AS fnLeafST 
					on (vwMT.stGuid = fnLeafST.StoreGuid) '
	END
	IF (@PeriodGuid <> 0x00)
	BEGIN
		SET @sql = @sql + ' INNER JOIN (SELECT * FROM fnGetLeafPeriods (''' + CAST(@PeriodGuid AS NVARCHAR(255)) + ''')) AS fnLeafPE 
					on (vwMT.bdpGuid = fnLeafPE.PeriodGuid) '
	END
	IF (@GroupGuid <> 0x00)
	BEGIN
		SET @sql = @sql + ' INNER JOIN (SELECT * FROM fnGetMaterialsList (''' + CAST(@GroupGuid AS NVARCHAR(255)) + ''')) AS fnMatList 
					on (vwMT.mtGuid = fnMatList.GUID) '
	END
	IF (@MaterialGuid <> 0x00) 
	BEGIN
		SET @sql = @sql + ' WHERE vwMT.mtGuid = ''' + CAST(@MaterialGuid AS NVARCHAR(255)) + ''''
	END			
	
	SET @sql = @sql + ' ORDER BY PeriodName '		
	INSERT INTO [#Result] 
	EXECUTE (@sql)		
	SELECT * FROM [#Result]
END
ELSE IF (@TargetsAreSet = 0) 
BEGIN 
	IF (@StoresWithTargets = 0 AND @MaterialsWithTargets = 0) 
	BEGIN  
		INSERT INTO [#Result]  
		SELECT	 
			st.[GUID], 
			st.Code, 
			st.Name, 
			p.[Guid],  
			p.Code,  
			p.Name,  
			mt.mtGUID, 
			mt.mtCode, 
			mt.mtName, 
			0, 
			0, 
			0			  
		FROM vwmt AS mt 
		LEFT JOIN mattargets000 AS mttarg ON mt.mtGUID = mttarg.mtguid  
		LEFT JOIN vwLeafStores AS st ON 1 = 1 
		LEFT JOIN vwLeafPeriods AS p ON 1 = 1 
		WHERE mttarg.mtguid IS NULL 
	END 
	ELSE IF (@StoresWithTargets = 1 AND @MaterialsWithTargets = 0) 
	BEGIN 
		--- just stores which have targets 
		INSERT INTO [#Result]  
		SELECT  
			st.[GUID], 
			st.Code, 
			st.Name, 
			p.[Guid],  
			p.Code,  
			p.Name,  
			mt.mtGUID, 
			mt.mtCode, 
			mt.mtName, 
			0, 
			0, 
			0	 
		FROM vwmt AS mt 
		LEFT JOIN mattargets000 AS mttarg ON mt.mtGUID = mttarg.mtguid  
		LEFT JOIN vwLeafStores AS st ON st.[GUID] IN (SELECT stguid FROM mattargets000) 
		LEFT JOIN vwLeafPeriods AS p ON 1 = 1  
		WHERE mttarg.mtguid IS NULL	
		
		 
	END 
	ELSE IF (@StoresWithTargets = 0 AND @MaterialsWithTargets = 1) 
	BEGIN 
		--- just materials which have targets 
		INSERT INTO [#Result]  
		SELECT  
			st.[GUID], 
			st.Code, 
			st.Name, 
			p.[Guid],  
			p.Code,  
			p.Name,  
			mt.mtGUID, 
			mt.mtCode, 
			mt.mtName, 
			0, 
			0, 
			0	 
		FROM vwmt AS mt 
		LEFT JOIN mattargets000 AS mttarg ON mt.mtGUID NOT IN (SELECT mtguid FROM mattargets000) 
		LEFT JOIN vwLeafStores AS st ON 1 = 1 
		LEFT JOIN vwLeafPeriods AS p ON 1 = 1  
		WHERE mttarg.mtguid IS NULL	
		EXCEPT
		SELECT  
			vwMtTr.stGuid, 
			vwMtTr.StoreCode, 
			vwMtTr.StoreName, 
			vwMtTr.bdpGuid,  
			vwMtTr.PeriodCode,  
			vwMtTr.PeriodName,  
			vwMtTr.mtGUID, 
			vwMtTr.MatCode, 
			vwMtTr.MatName, 
			0, 
			0, 
			0	
			
		FROM vwMatTargets vwMtTr 
	END 
	ELSE IF (@StoresWithTargets = 1 AND @MaterialsWithTargets = 1) 
	BEGIN 
		----- stores have targets and materials have targets 
		INSERT INTO [#Result]  
		SELECT  
			st.[GUID], 
			st.Code, 
			st.Name, 
			p.[Guid],  
			p.Code,  
			p.Name,  
			mt.mtGUID, 
			mt.mtCode, 
			mt.mtName, 
			0, 
			0, 
			0	 
		FROM vwmt AS mt 
		LEFT JOIN mattargets000 AS mttarg ON mt.mtGUID NOT IN (SELECT mtguid FROM mattargets000) 
		LEFT JOIN vwLeafStores AS st ON st.[GUID] IN (SELECT stguid FROM mattargets000) 
		LEFT JOIN vwLeafPeriods AS p ON 1 = 1 
		WHERE mttarg.mtguid IS NULL 
		
		EXCEPT
		SELECT  
			vwMtTr.stGuid, 
			vwMtTr.StoreCode, 
			vwMtTr.StoreName, 
			vwMtTr.bdpGuid,  
			vwMtTr.PeriodCode,  
			vwMtTr.PeriodName,  
			vwMtTr.mtGUID, 
			vwMtTr.MatCode, 
			vwMtTr.MatName, 
			0, 
			0, 
			0	
			
		FROM vwMatTargets vwMtTr
	END 
	SELECT * FROM [#Result] 
	WHERE ( 
		((StoreGuid = @StoreGuid) OR (@StoreGuid = 0x00)) AND 
		((PeriodGuid = @PeriodGuid) OR (@PeriodGuid = 0x00)) AND 
		((MaterialGuid = @MaterialGuid) OR (@MaterialGuid = 0x00)) AND 
		(MaterialGuid in (SELECT * FROM fnGetMaterialsList (@GroupGuid)))  
		)	
	Order by MaterialCode, StoreCode, PeriodCode
END
############################################################################
CREATE PROCEDURE prcOrderlimit
	@IsStoreCheck INT = 0,
	@IsBranchCheck INT = 0,
	@IsAllMattcheck INT = 0, 
	@IsGroupCheck INT = 0 
AS
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT]);

	SELECT
		Bi.biMatPtr AS MatGuid,
		mt.[Security] AS MatSecurity,
		BI.mtName AS MatName,
		CASE WHEN @IsGroupCheck = 1 THEN gr.Name ELSE N'' END AS MatGroup,
		mt.Unity AS MatUnit,
		mt.code AS code,
		CASE WHEN @IsStoreCheck = 1 THEN s.[Guid] ELSE 0x END AS StGuid,
		CASE WHEN @IsStoreCheck = 1 THEN s.[Security] ELSE 0 END AS StSecurity,
		CASE WHEN @IsStoreCheck = 1 THEN s.Name ELSE N'' END AS StName,
		CASE WHEN @IsBranchCheck = 1 THEN br.Name ELSE N'' END AS BranchName,
		(SUM(CASE WHEN BI.btIsInput = 1 THEN BI.biQty ELSE - BI.biQty END)-SUM(CASE WHEN BI.btIsInput = 1 THEN  - BI.biBillBonusQnt ELSE  BI.biBillBonusQnt END))AS Balance,
		mt.OrderLimit AS OrderLimit,
	    CASE WHEN @IsStoreCheck = 1 THEN BI.buStorePtr ELSE 0x END AS MatStorePtr,
		BI.mtGroup AS MatGroupPtr
	INTO #Result
	FROM
		vwExtended_bi AS BI 
		LEFT JOIN (MatOrderLimitAlert000 AS c
		CROSS APPLY dbo.fnGetMaterials(ISNULL(c.MatGuid, 0x), ISNULL(c.GrpGuid, 0x)) AS M) ON Bi.biMatPtr = M.[Guid] 
		LEFT JOIN st000 AS s ON s.GUID = BI.buStorePtr
		LEFT JOIN br000 AS br ON br.GUID = BI.buBranch
		JOIN mt000 AS mt ON mt.Guid = Bi.biMatPtr
	    JOIN vdGr AS gr ON gr.GUID = bi.mtGroup
	WHERE 
		mt.OrderLimit <> 0 AND ((M.Guid IS NOT NULL AND @IsAllMattcheck= 0) OR @IsAllMattcheck = 1) 
	GROUP BY 
		Bi.biMatPtr,
		mt.[Security],
		BI.mtName,
		mt.code,
		CASE WHEN @IsStoreCheck = 1 THEN s.[Guid] ELSE 0x END,
		CASE WHEN @IsStoreCheck = 1 THEN s.[Security] ELSE 0 END,
		CASE WHEN @IsStoreCheck = 1 THEN s.Name ELSE N'' END,
		CASE WHEN @IsBranchCheck = 1 THEN br.Name ELSE N'' END,
		CASE WHEN @IsGroupCheck = 1 THEN gr.Name ELSE N'' END,
		mt.Unity,
		mt.OrderLimit,
		CASE WHEN @IsStoreCheck = 1 THEN BI.buStorePtr ELSE 0x END,
		BI.mtGroup
		--BI.biBillBonusQnt
	HAVING 
		(SUM(CASE WHEN BI.btIsInput = 1 THEN BI.biQty ELSE - BI.biQty END)-SUM(CASE WHEN BI.btIsInput = 1 THEN  - BI.biBillBonusQnt ELSE  BI.biBillBonusQnt END)) < mt.OrderLimit;
	
 	EXEC prcCheckSecurity;

	SELECT * FROM #Result ORDER BY code Asc ;
	SELECT * FROM #SecViol;
############################################################################
#END
