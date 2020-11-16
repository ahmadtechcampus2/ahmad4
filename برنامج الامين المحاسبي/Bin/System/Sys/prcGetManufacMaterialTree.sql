###############################################################################
CREATE PROCEDURE prcGetManufacMaterialTree
	@MATGUID    [UNIQUEIDENTIFIER],  
	@ClassPtr 	[NVARCHAR] (255) = '', 
	@PARENTPATH [NVARCHAR](max) = '',
	@ParentParentGUID [UNIQUEIDENTIFIER] = 0x00 
AS   
BEGIN	  
	SET NOCOUNT ON   
	DECLARE @MAINFORM  [UNIQUEIDENTIFIER] 
	DECLARE @SELECTED UNIQUEIDENTIFIER 
	DECLARE @MAINSELECTED UNIQUEIDENTIFIER 
	DECLARE @MAINSELECTEDQTY FLOAT 
	DECLARE @MAT UNIQUEIDENTIFIER 
	DECLARE @CNT INT 
	DECLARE @PPATH [NVARCHAR](1000) 
	DECLARE @PARENTQTY FLOAT 
	DECLARE @PARENTQTYINFORM FLOAT 
      
	SELECT TOP 1 
		@MAINFORM = [PARENTGUID]   
	FROM 
		MI000 MI  
		INNER JOIN MN000 MN ON MN.[GUID] = MI.PARENTGUID  
	WHERE   
		MN.TYPE = 0 
		AND 
		MI.TYPE = 0 
		AND 
		MATGUID = @MATGUID  
	ORDER BY
		MN.[Date] DESC,
		MN.Number DESC 
                 
	IF (@PARENTPATH = '')  
	BEGIN  
		IF NOT EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '##TREEBUFFER')  
		CREATE TABLE ##TREEBUFFER  
		(  
			[SELECTEDGUID]          [UNIQUEIDENTIFIER],
			[GUID]                  [UNIQUEIDENTIFIER],
			[PARENTGUID]			[UNIQUEIDENTIFIER], -- Form GUID
			[ParentParentGUID]		[UNIQUEIDENTIFIER], -- Parent Form GUID
			[MATGUID]				[UNIQUEIDENTIFIER],
			[ISHALFREADYMAT]		[BIT],
			[PATH]                  [NVARCHAR](1000),
			[PARENTPATH]            [NVARCHAR](1000),
			[QTY]					[FLOAT],
			[QtyInForm]             [FLOAT],
			[Unit]					[INT],
			[TYPE]                  [INT],
			[IsSemiReadyMat]		[INT],
			[NeededFormsCountTemp]	[FLOAT],
			[IsResultOfFormWithMoreThanOneProducedMaterial] [BIT]
		)  
		SET @PARENTPATH = '0'  
		SET @MAINSELECTED = @MATGUID 
		SET @PARENTQTY = 1 
		SET @PARENTQTYINFORM = 1 
			
		SELECT 
			@MAINSELECTEDQTY = MI.QTY 
		FROM 
			MI000 MI 
			INNER JOIN MN000 MN ON MN.[Guid] = MI.ParentGuid 
		WHERE 
			MI.[Type] = 0
			AND 
			MN.[Type] = 0 
			AND 
			MI.MatGuid = @MAINSELECTED 
		ORDER BY
			MN.[Date] DESC,
			MN.Number DESC
	END 	 
	ELSE 
	BEGIN
		SELECT 
			@PARENTQTYINFORM = MI.QTY 
		FROM 
			MI000 MI 
			INNER JOIN MN000 MN ON MN.Guid = MI.ParentGuid 
		WHERE
			MI.Type = 0 
			AND 
			MN.Type = 0
			AND
			MI.MatGuid = @MATGUID
		ORDER BY
			MN.[Date] DESC,
			MN.Number DESC
	END
	
	SELECT 
		@PARENTQTY = QTY 
	FROM 
		##TREEBUFFER 
	WHERE 
		MATGuid = @MATGUID

	INSERT INTO ##TREEBUFFER 
	SELECT 
		MI.[GUID], --just a placeholder
		MI.[GUID], 
		MI.PARENTGUID, 
		@ParentParentGUID,
		MI.MATGUID, 
		DBO.ISHALFREADYMAT(MI.MATGUID), 
		@PARENTPATH + '.' + CAST((DBO.ISHALFREADYMAT(MI.MATGUID)) AS NVARCHAR(100)) + CAST((MI.Number) AS NVARCHAR(100)), 
		@PARENTPATH,
		(MI.Qty * @PARENTQTY / CASE WHEN @PARENTQTYINFORM <> 0 THEN @PARENTQTYINFORM ELSE 1 END), 
		MI.Qty, 
		MI.Unity, 
		MI.[TYPE], 
		CASE MI.MatGuid WHEN @MAINSELECTED THEN 1 ELSE 0 END, 
		(@PARENTQTY / CASE WHEN @PARENTQTYINFORM <> 0 THEN @PARENTQTYINFORM ELSE 1 END),
		CASE WHEN (SELECT COUNT(MI2.MatGUID) ProducedMatsCount FROM MI000 MI2 WHERE MI2.[TYPE] = 0 AND MI2.PARENTGUID = MI.ParentGUID) > 1 THEN 1 ELSE 0 END
	FROM   
		MI000 MI 
		INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID 
		INNER JOIN FM000 FM ON FM.GUID = MN.FORMGUID 
	WHERE 
		MN.Type = 0 
		AND 
		(MI.TYPE = 1 OR (MI.MatGuid = @MAINSELECTED AND @ClassPtr <> ''))
		AND 
		MI.PARENTGUID = @MAINFORM 
	ORDER BY 
		DBO.ISHALFREADYMAT(MI.MATGUID) 
       
	SELECT TOP 1  
        @SELECTED = [GUID],  
        @MAT = [MATGUID],  
        @PPATH = [PATH],
		@ParentParentGUID = [ParentGUID] 
    FROM 
		##TREEBUFFER  
    WHERE 
		ISHALFREADYMAT = 1  
    ORDER BY 
		[PATH]

    IF (@SELECTED <> 0X0)  
    BEGIN  
		UPDATE ##TREEBUFFER 
		SET 
			[ISHALFREADYMAT] = 0, 
			[IsSemiReadyMat] = 1 
		WHERE 
			[GUID] = @SELECTED
            
		EXEC prcGetManufacMaterialTree @MAT, @ClassPtr, @PPATH, @ParentParentGUID
	END  
	IF (@PARENTPATH = '0')  
	BEGIN  
		SET @CNT = (SELECT COUNT(*) FROM ##TREEBUFFER WHERE ISHALFREADYMAT = 1)  
		IF (@CNT = 0)  
		BEGIN  
			UPDATE ##TREEBUFFER 
			SET 
				QtyInForm = MI.Qty 
			FROM 
				MI000 MI, 
				##TREEBUFFER TREE, 
				MN000 MN  
			WHERE 
				TREE.IsSemiReadyMat = 1  
				AND MI.Type = 0  
				AND MI.MatGuid = TREE.MatGuid 
				AND MN.Guid = MI.ParentGuid 
				AND MN.Type = 0 
             
			SELECT 
				@MAINSELECTED SelectedGuid,
				[TREE].[GUID],
				[TREE].[PARENTGUID], 
				[TREE].[ParentParentGUID],
				@ClassPtr ClassPtr, 
				[FM].[Name] AS FORMNAME, 
				[MATGUID], 
				[MT].[NAME] AS MATNAME,
				[TREE].[QTY] / @MAINSELECTEDQTY QTY,
				[TREE].[QtyInForm],
				[TREE].[PATH], 
				[TREE].[PARENTPATH], 
				[TREE].[Unit], 
				[TREE].[IsSemiReadyMat], 
				([TREE].[QTY] / @MAINSELECTEDQTY) / [TREE].[QtyInForm] AS [NeededFormsCountTemp],
				[TREE].[IsResultOfFormWithMoreThanOneProducedMaterial]
			FROM 
				##TREEBUFFER TREE  
				LEFT JOIN MN000 MN ON [MN].[GUID] = [TREE].[PARENTGUID]                   
				LEFT JOIN FM000 FM ON [FM].[GUID] = [MN].[FORMGUID]  
				LEFT JOIN MT000 MT ON [MT].[GUID] = [TREE].[MATGUID]  
			ORDER BY 
				[TREE].[PATH]                 
			
			DROP TABLE ##TREEBUFFER  
		END  
	END
END
################################################################################
#END