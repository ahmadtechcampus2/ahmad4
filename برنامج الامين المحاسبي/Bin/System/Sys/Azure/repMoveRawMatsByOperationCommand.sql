###########################################################
CREATE PROCEDURE repMoveRawMatsByOperationCommand
	@OperationCommandGuid    [UNIQUEIDENTIFIER],  
	@StoreGuid				 [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON 
	
	DECLARE @MatGuid [UNIQUEIDENTIFIER]
	DECLARE @CostGuid [UNIQUEIDENTIFIER]
	DECLARE @MatQty [INT]
	SELECT @MatGuid = ProducedMatGuid
			,@CostGuid = CostCenter
			,@MatQty = RequiredQty
		FROM OperationCommand000
		WHERE Guid = @OperationCommandGuid

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
	
	UPDATE #TMP SET Qty = Qty * @MatQty
	
	DECLARE @OutBillType [UNIQUEIDENTIFIER]
	DECLARE @OutRetBillType [UNIQUEIDENTIFIER]

	SELECT @OutBillType = Value FROM Op000 WHERE Name = 'OcOutBillTypeGuid'
	SELECT @OutRetBillType = Value FROM Op000 WHERE Name = 'OcOutReturnBillTypeGuid'

	SELECT 
		Bi.MatGuid
		, SUM( CASE Bu.TypeGuid WHEN @OutBillType THEN 1 WHEN @OutRetBillType THEN -1 ELSE 0 END * CASE ISNULL(Bi.CostGuid, 0x0) WHEN 0x0 THEN CASE Bu.CostGuid WHEN @CostGuid THEN 1 ELSE 0 END ELSE CASE Bi.CostGuid WHEN @CostGuid THEN 1 ELSE 0 END END * Qty ) Qty 
		, SUM( CASE Bi.StoreGuid WHEN @StoreGuid THEN CASE BT.BILLTYPE WHEN 0 THEN BI.QTY WHEN 3 THEN BI.QTY WHEN 4 THEN BI.QTY WHEN 1 THEN -BI.QTY WHEN 2 THEN -BI.QTY WHEN 5 THEN -BI.QTY END ELSE 0 END) Stock
		INTO #MatMove
	FROM Bi000 bi
		INNER JOIN Bu000 Bu ON Bi.ParentGuid = Bu.Guid
		INNER JOIN Bt000 Bt ON Bu.TypeGUID = Bt.GUID 
		WHERE   Bi.MatGuid IN ( SELECT MatGuid FROM #Tmp )
			AND Bu.IsPosted = 1
	GROUP BY MatGuid

	SELECT Tmp.MatGuid
			,(Mt.Code + '-' + Mt.Name) AS MatName
			,Tmp.Qty RequiredQty
			,Mt.AvgPrice Price
			,ISNULL(MatMove.Qty, 0) MovedQty
			,(Tmp.Qty - ISNULL(MatMove.Qty, 0) ) AS StillQty
			,ISNULL(MatMove.Stock, 0) Stock
	FROM #Tmp Tmp
		INNER JOIN Mt000 Mt ON Mt.Guid = Tmp.MatGuid
		LEFT JOIN #MatMove MatMove ON MatMove.MatGuid = Tmp.MatGuid
###########################################################
#END
