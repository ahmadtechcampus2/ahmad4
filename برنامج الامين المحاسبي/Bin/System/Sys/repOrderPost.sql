##################################################################################
CREATE PROCEDURE repOrderPost
	@OrderGuid UNIQUEIDENTIFIER
AS
	
	SET NOCOUNT ON;

	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	DECLARE @StatesTbls Table(
		[Guid]		UNIQUEIDENTIFIER,
		Number		INT,
		Name		NVARCHAR(500),
		LatinName	NVARCHAR(500),
		[Type]		INT,
		PostQty		INT,
		Operation	INT,
		billGuid    UNIQUEIDENTIFIER,
		FixedBill   BIT,
		QtyCompleted BIT,
		BillType     INT,
		oitvsGuid	UNIQUEIDENTIFIER,
		parentGuid	UNIQUEIDENTIFIER,
		OTGuid		UNIQUEIDENTIFIER,
		Selected	BIT,
		SubSNumber	INT,
		Note		NVARCHAR(1000),
		StateOrder  INT,
		IsQtyReserved	BIT
);

	DECLARE 
		@TypeGuid UNIQUEIDENTIFIER,
		@IsSellBill BIT;

	SELECT
		@IsSellBill = btIsOutput,
		@TypeGuid = buType
	FROM
		vwBu
	WHERE
		buGUID = @OrderGuid;

	INSERT INTO @StatesTbls EXEC GetOrderStates @IsSellBill, 0, @TypeGuid;
	
	DECLARE @Result TABLE (
		MaterialGuid UNIQUEIDENTIFIER,
		[ItemGuid]	UNIQUEIDENTIFIER,
		MaterialDescription NVARCHAR(MAX),
		[Required] FLOAT,
		Achieved FLOAT,
		StateGuid UNIQUEIDENTIFIER,
		StateName NVARCHAR(MAX),
		StateQuantity FLOAT,
		Number INT,
		UNitName NVARCHAR(MAX),
		[RequiredBonus] FLOAT,
		AchievedBonus FLOAT
		);
 
	INSERT INTO @Result
	SELECT
		bi.biMatPtr,
		bi.biGuid,
		mt.mtCode + '-' + (CASE @Lang WHEN 0 THEN mt.mtName ELSE (CASE mt.mtLatinName WHEN N'' THEN mt.mtName ELSE mt.mtLatinName END) END ),
		bi.biBillQty,
		SUM(CASE WHEN ori.oribuGuid <> 0x0 AND st.QtyCompleted <> 0 AND ori.oriQty > 0 THEN ori.oriQty / (CASE WHEN bi.mtUnitFact <> 0 THEN bi.mtUnitFact ELSE 1 END) ELSE 0 END),
		ori.oriTypeGuid,
		CASE @Lang WHEN 0 THEN st.Name ELSE (CASE st.LatinName WHEN N'' THEN st.Name ELSE st.LatinName END) END ,
		SUM(ori.oriQty / (CASE WHEN bi.mtUnitFact <> 0 THEN bi.mtUnitFact ELSE 1 END)),
		bi.biNumber,
		bi.mtUnityName,
		bi.biBillBonusQnt,
		SUM(CASE WHEN ori.oribuGuid <> 0x0 AND ori.oriBonusPostedQty > 0 THEN ori.oriBonusPostedQty / (CASE WHEN bi.mtUnitFact <> 0 THEN bi.mtUnitFact ELSE 1 END) ELSE 0 END)
	FROM
		vwExtended_bi bi
		INNER JOIN vwMt mt ON bi.biMatPtr = mt.mtGUID
		INNER JOIN vwORI ori ON bi.biGUID = ori.oriPOIGUID
		INNER JOIN @StatesTbls st ON ori.oriTypeGuid = st.[Guid]
	WHERE
		bi.buGUID = @OrderGuid
	GROUP BY
		bi.biMatPtr,
		bi.biGuid,
		st.Number,
		ori.oriTypeGUID,
		mt.mtCode + '-' + (CASE @Lang WHEN 0 THEN mt.mtName ELSE (CASE mt.mtLatinName WHEN N'' THEN mt.mtName ELSE mt.mtLatinName END) END ),
		bi.biBillQty, 
		biBillBonusQnt,
		CASE @Lang WHEN 0 THEN st.Name ELSE (CASE st.LatinName WHEN N'' THEN st.Name ELSE st.LatinName END) END ,
		bi.biNumber,
		bi.mtUnityName  
		
	SELECT * FROM @Result ORDER BY Number
##################################################################################
CREATE FUNCTION fnOrderIsAnyItemPosted(@OrderGuid UNIQUEIDENTIFIER, @ItemGuid UNIQUEIDENTIFIER = 0x0) 
	RETURNS BIT 
BEGIN 
	IF EXISTS(SELECT * FROM ori000 ori INNER JOIN bu000 bu ON bu.guid = ori.buGuid WHERE POGuid = @OrderGuid AND (POIGUID = @ItemGuid OR @ItemGuid = 0x0))
		RETURN 1
	DECLARE 
		@TypeGuid UNIQUEIDENTIFIER, 
		@MinStateGUID UNIQUEIDENTIFIER
	SELECT
		@TypeGuid = TypeGuid 
	FROM
		bu000 
	WHERE
		GUID = @OrderGuid
	
	
	DECLARE @ORT TABLE(guid UNIQUEIDENTIFIER, Number INT)
	INSERT INTO @ORT
	SELECT oit.GUID, oit.Number
	FROM 
		oit000 oit 
		INNER JOIN oitvs000 oitvs ON oit.GUID = oitvs.ParentGUID 
	WHERE oitvs.OTGUID = @TypeGuid
	ORDER BY oit.Number 
	SET @MinStateGUID = (SELECT TOP 1 guid FROM @ORT where Number = (SELECT MIN(Number) FROM @ORT))
	DECLARE @Result TABLE (
		[ItemGuid]	UNIQUEIDENTIFIER,
		StateQuantity FLOAT,
		StateGUID UNIQUEIDENTIFIER,
		Number INT)
 
	INSERT INTO @Result
	SELECT
		bi.Guid,
		SUM(ori.Qty),
		ort.guid,
		ort.Number
	FROM
		bi000 bi 
		INNER JOIN mt000 mt ON bi.MatGuid = mt.GUID
		INNER JOIN ori000 ori ON bi.GUID = ori.POIGUID
		INNER JOIN @ORT ort ON ort.guid = ori.TypeGuid
	WHERE
		bi.ParentGUID = @OrderGuid
	AND 
		(bi.GUID = @ItemGuid OR @ItemGuid = 0x0)
	GROUP BY
		bi.Guid,
		ort.guid,
		ort.Number
	
	IF EXISTS (SELECT * FROM @Result WHERE StateQuantity <> 0 AND StateGUID <> @MinStateGUID)
		RETURN 1 
	RETURN 0
END 
##################################################################################
CREATE PROCEDURE repOrderPostQtyByState
	@OrderGuid UNIQUEIDENTIFIER
AS
	
	SET NOCOUNT ON;

	SET NOCOUNT ON;
	DECLARE @StatesTbls Table(
		[Guid]		UNIQUEIDENTIFIER,
		Number		INT,
		Name		NVARCHAR(500),
		LatinName	NVARCHAR(500),
		[Type]		INT,
		PostQty		INT,
		Operation	INT,
		billGuid    UNIQUEIDENTIFIER,
		FixedBill   BIT,
		QtyCompleted BIT,
		BillType     INT,
		oitvsGuid	UNIQUEIDENTIFIER,
		parentGuid	UNIQUEIDENTIFIER,
		OTGuid		UNIQUEIDENTIFIER,
		Selected	BIT,
		SubSNumber	INT,
		Note		NVARCHAR(1000),
		StateOrder  INT,
		IsQtyReserved	BIT
);
	DECLARE 
		@TypeGuid UNIQUEIDENTIFIER,
		@IsSellBill BIT;
	SELECT
		@IsSellBill = btIsOutput,
		@TypeGuid = buType
	FROM
		vwBu
	WHERE
		buGUID = @OrderGuid;
	INSERT INTO @StatesTbls EXEC GetOrderStates @IsSellBill, 0, @TypeGuid;
	
	DECLARE @PostData TABLE (
		MaterialGuid UNIQUEIDENTIFIER,
		[ItemGuid]	UNIQUEIDENTIFIER,
		MaterialDescription NVARCHAR(MAX),
		[Required] FLOAT,
		Achieved FLOAT,
		StateGuid UNIQUEIDENTIFIER,
		StateName NVARCHAR(250),
		StateQuantity FLOAT,
		Number INT,
		UNitName NVARCHAR(250),
		FirstState BIT);
 
	INSERT INTO @PostData
	SELECT
		bi.biMatPtr,
		bi.biGuid,
		mt.mtCode + '-' + mt.mtName,
		bi.biBillQty,
		SUM(CASE WHEN ori.oribuGuid <> 0x0 AND st.QtyCompleted <> 0 AND ori.oriQty > 0 THEN ori.oriQty / (CASE WHEN bi.mtUnitFact <> 0 THEN bi.mtUnitFact ELSE 1 END) ELSE 0 END),
		ori.oriTypeGuid,
		st.Name,
		SUM(ori.oriQty / (CASE WHEN bi.mtUnitFact <> 0 THEN bi.mtUnitFact ELSE 1 END)),
		bi.biNumber,
		bi.mtUnityName,
		CASE WHEN PostQty IN (SELECT MIN(PostQty) FROM dbo.fnGetOrderItemTypes() IT INNER JOIN OITVS000 OIT ON OIT.ParentGuid = IT.GUID GROUP BY OTGUID) THEN 1 ELSE 0 END 
	FROM
		vwExtended_bi bi
		INNER JOIN vwMt mt ON bi.biMatPtr = mt.mtGUID
		INNER JOIN vwORI ori ON bi.biGUID = ori.oriPOIGUID
		INNER JOIN @StatesTbls st ON ori.oriTypeGuid = st.[Guid]
	WHERE
		bi.buGUID = @OrderGuid
	GROUP BY
		bi.biMatPtr,
		bi.biGuid,
		st.Number,
		ori.oriTypeGUID,
		mt.mtCode + '-' + mt.mtName,
		bi.biBillQty, 
		st.Name,
		bi.biNumber,
		bi.mtUnityName,
		PostQty  


	DECLARE @Result TABLE (
		MaterialGuid UNIQUEIDENTIFIER,
		Number INT,
		TotalQty FLOAT)

	
	INSERT INTO @Result
	SELECT
		MaterialGuid,
		Number,
		SUM(StateQuantity)
	FROM
		@PostData
	WHERE FirstState = 0
	GROUP BY 
		Number,
		MaterialGuid

	SELECT * FROM @Result
##################################################################################
#END
