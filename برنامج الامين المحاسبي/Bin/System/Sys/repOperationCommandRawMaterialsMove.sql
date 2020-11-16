###########################################################
CREATE PROCEDURE repOperationCommandRawMaterialsMove
	@OperationCommandGuid    [UNIQUEIDENTIFIER] 
AS  
	SET NOCOUNT ON  
	
	DECLARE @MatGuid [UNIQUEIDENTIFIER] 
	DECLARE @CostGuid [UNIQUEIDENTIFIER] 
	SELECT @MatGuid = ProducedMatGuid 
			,@CostGuid = CostCenter 
		FROM OperationCommand000 
		WHERE Guid = @OperationCommandGuid 
	-- Accessing tempdb not supported in Azure
	--IF EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '#TMP')    
	--	DROP TABLE #Tmp 
	CREATE TABLE #Tmp  
	  (    
		[selectedGuid]                     [UNIQUEIDENTIFIER],    
		[Guid]                     [UNIQUEIDENTIFIER],    
		[ParentGuid]         [UNIQUEIDENTIFIER],   
		[ClassPtr]           NVARCHAR (255) COLLATE ARABIC_CI_AI,   
		[FormName]           NVARCHAR (255) COLLATE ARABIC_CI_AI,   
		[MatGuid]            [UNIQUEIDENTIFIER],    
		[MatName]           NVARCHAR (255) COLLATE ARABIC_CI_AI,    
		[Qty]                [FLOAT]                ,    
		[QtyInForm]                [FLOAT]                ,    
		[Path]                   [NVARCHAR](1000)  ,    
		[Unit]			[INT],	    
		[IsSemiReadyMat]   [INT],   
	  )    
	INSERT INTO #Tmp EXEC prcGetManufacMaterialTree  @MatGuid 
	DECLARE @OutBillType			[UNIQUEIDENTIFIER] 
	DECLARE @OutRetBillType			[UNIQUEIDENTIFIER] 
	DECLARE @MatMoveCalcualtionType	[INT]
	SELECT @OutBillType = Value FROM Op000 WHERE Name = 'OcOutBillTypeGuid' 
	SELECT @OutRetBillType = Value FROM Op000 WHERE Name = 'OcOutReturnBillTypeGuid' 
	SET @MatMoveCalcualtionType = 0
	SELECT @MatMoveCalcualtionType = Value FROM Op000 WHERE Name = 'OcMatMoveCalcualtionType' 
	
	SELECT  
		Bi.MatGuid 
		,(Mt.Code + '-' + Mt.Name) AS MatName 
		,CASE @MatMoveCalcualtionType WHEN 0 THEN CONVERT(NVARCHAR, VwBuBi.BuFormatedNumber, 111)  ELSE CONVERT(NVARCHAR, Bu.Date, 111)  END ColName
		, SUM( CASE Bu.TypeGuid WHEN @OutBillType THEN 1 WHEN @OutRetBillType THEN -1 ELSE 0 END * CASE CASE ISNULL(Bi.CostGuid, 0x0) WHEN 0x0 THEN Bu.CostGuid ELSE Bi.CostGuid END WHEN @CostGuid THEN 1 ELSE 0 END * Bi.Qty ) Qty 
	INTO #Result
	FROM Bi000 bi 
		INNER JOIN Bu000 Bu ON Bi.ParentGuid = Bu.Guid 
		INNER JOIN VwBuBi ON VwBuBi.BiGuid = Bi.Guid 
		INNER JOIN Bt000 Bt ON Bu.TypeGUID = Bt.GUID  
		INNER JOIN Mt000 Mt ON Mt.Guid = Bi.MatGuid 
		WHERE   Bi.MatGuid IN ( SELECT MatGuid FROM #Tmp ) 
			AND Bu.IsPosted = 1 
			AND ( Bu.TypeGuid = @OutBillType OR Bu.TypeGuid = @OutRetBillType ) 
	GROUP BY CASE @MatMoveCalcualtionType WHEN 0 THEN CONVERT(NVARCHAR, VwBuBi.BuFormatedNumber, 111) ELSE CONVERT(NVARCHAR, Bu.Date, 111)  END, MatGuid, Mt.Code, Mt.Name 
	ORDER BY CASE @MatMoveCalcualtionType WHEN 0 THEN CONVERT(NVARCHAR, VwBuBi.BuFormatedNumber, 111)  ELSE CONVERT(NVARCHAR, Bu.Date, 111)  END

	SELECT * FROM #Result WHERE Qty <> 0
###########################################################
#END
