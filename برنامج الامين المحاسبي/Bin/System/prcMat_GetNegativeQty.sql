#########################################################
CREATE FUNCTION fnMat_GetQtyByBranch(@matGUID UNIQUEIDENTIFIER, @StoreGUID UNIQUEIDENTIFIER, @Branch UNIQUEIDENTIFIER)
	RETURNS @Result TABLE (Bal FLOAT)
AS
BEGIN
	INSERT INTO @Result
	SELECT 
		SUM((CASE btIsInput WHEN 1 THEN 1 ELSE -1 END) * (biQty + biBonusQnt)) AS Qnt 
	FROM 
		vwExtended_Bi 
	WHERE 
		biMatPtr = @matGUID 
		AND (buIsPosted = 1)
		AND ((ISNULL(@Branch, 0x0) = 0X0) OR (buBranch = @Branch))
		AND ((ISNULL(@StoreGUID, 0x0) = 0X0) OR (biStorePtr = @StoreGUID))
	GROUP BY 
		CASE ISNULL(@Branch, 0x0) WHEN 0x0 THEN 0x0 ELSE buBranch END,
		CASE ISNULL(@StoreGUID, 0x0) WHEN 0x0 THEN 0x0 ELSE biStorePtr END

	RETURN
END
#########################################################
CREATE FUNCTION fnMatGetQtyByBranch(@matGUID UNIQUEIDENTIFIER, @StoreGUID UNIQUEIDENTIFIER, @Branch UNIQUEIDENTIFIER)
	RETURNS FLOAT 
AS
BEGIN
	RETURN (SELECT 
		SUM((CASE btIsInput WHEN 1 THEN 1 ELSE -1 END) * (biQty + biBonusQnt)) AS Qnt 
	FROM 
		vwExtended_Bi 
	WHERE 
		biMatPtr = @matGUID 
		AND (buIsPosted = 1)
		AND ((ISNULL(@Branch, 0x0) = 0X0) OR (buBranch = @Branch))
		AND ((ISNULL(@StoreGUID, 0x0) = 0X0) OR (biStorePtr = @StoreGUID))
	GROUP BY 
		CASE ISNULL(@Branch, 0x0) WHEN 0x0 THEN 0x0 ELSE buBranch END,
		CASE ISNULL(@StoreGUID, 0x0) WHEN 0x0 THEN 0x0 ELSE biStorePtr END)
END
#########################################################
CREATE PROC prcMat_GetNegativeQty
	@BillGUID UNIQUEIDENTIFIER,
	@IsDelete BIT = 0
AS 
	SET NOCOUNT ON 

	IF ISNULL(@BillGUID, 0x0) = 0x0
		RETURN 
	IF NOT EXISTS(SELECT * FROM [bu000] WHERE [GUID] = @BillGUID AND [IsPosted] = 1)
		RETURN 
	
	DECLARE 
		@IsCheckMatQtyByStore BIT,
		@IsEnableBranches BIT 

	SET @IsCheckMatQtyByStore = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM op000 WHERE Name = 'AmnCfg_MatQtyByStore' AND Type = 0), 0)
	SET @IsEnableBranches = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM op000 WHERE Name = 'EnableBranches' AND Type = 0), 0)

	CREATE TABLE #MatQty(mtGUID UNIQUEIDENTIFIER, stGUID UNIQUEIDENTIFIER, Qty FLOAT)

	IF @IsCheckMatQtyByStore = 0 
	BEGIN 		
		INSERT INTO #MatQty
		SELECT 
			mt.GUID,
			0x0,
			MAX(mt.Qty) - SUM(bi.Qty + bi.BonusQnt)
		FROM 
			bi000 bi
			INNER JOIN mt000 mt ON bi.MatGUID = mt.GUID 
		WHERE 
			bi.ParentGUID = @BillGUID 
			AND 
			(bi.Qty + bi.BonusQnt) > 0
			AND 
			mt.Type != 1
		GROUP BY
			mt.GUID

	END ELSE IF @IsEnableBranches = 1 
	BEGIN 
		INSERT INTO #MatQty
		SELECT 
			mt.GUID,
			CASE bi.StoreGUID WHEN 0x0 THEN bu.StoreGUID ELSE bi.StoreGUID END,
			MAX(ISNULL(fn.Bal, 0)) - SUM(bi.Qty + bi.BonusQnt) 
		FROM 
			bu000 bu
			INNER JOIN bi000 bi ON bu.GUID = bi.ParentGUID
			INNER JOIN mt000 mt ON bi.MatGUID = mt.GUID 
			OUTER APPLY dbo.fnMat_GetQtyByBranch(mt.GUID, CASE bi.StoreGUID WHEN 0x0 THEN bu.StoreGUID ELSE bi.StoreGUID END, bu.Branch) fn
		WHERE 
			bi.ParentGUID = @BillGUID 
			AND 
			(bi.Qty + bi.BonusQnt) > 0
			AND 
			mt.Type != 1
		GROUP BY
			mt.GUID,
			bu.Branch,
			CASE bi.StoreGUID WHEN 0x0 THEN bu.StoreGUID ELSE bi.StoreGUID END
	END ELSE BEGIN 
		INSERT INTO #MatQty
		SELECT 
			mt.GUID,
			CASE bi.StoreGUID WHEN 0x0 THEN bu.StoreGUID ELSE bi.StoreGUID END,
			MAX(ms.Qty) - SUM(bi.Qty + bi.BonusQnt)
		FROM 
			bu000 bu
			INNER JOIN bi000 bi ON bu.GUID = bi.ParentGUID
			INNER JOIN mt000 mt ON bi.MatGUID = mt.GUID 
			INNER JOIN ms000 ms ON ms.MatGUID = mt.GUID AND ms.StoreGUID = (CASE bi.StoreGUID WHEN 0x0 THEN bu.StoreGUID ELSE bi.StoreGUID END)
		WHERE 
			bi.ParentGUID = @BillGUID 
			AND 
			(bi.Qty + bi.BonusQnt) > 0
			AND 
			mt.Type != 1
		GROUP BY
			mt.GUID,
			CASE bi.StoreGUID WHEN 0x0 THEN bu.StoreGUID ELSE bi.StoreGUID END
	END 

	DECLARE @lang INT 
	SET @lang = [dbo].[fnConnections_GetLanguage]()

	IF @IsDelete = 0
	BEGIN 
		SELECT 
			q.*,
			CASE @lang
				WHEN 0 THEN mt.Name
				ELSE CASE mt.LatinName WHEN '' THEN mt.Name ELSE mt.LatinName END
			END mtName
		FROM 
			#MatQty q
			INNER JOIN mt000 mt ON q.mtGUID = mt.GUID
		WHERE 
			q.Qty < 0
	END ELSE BEGIN 
		SELECT TOP 1
			q.*,
			CASE @lang
				WHEN 0 THEN mt.Name
				ELSE CASE mt.LatinName WHEN '' THEN mt.Name ELSE mt.LatinName END
			END mtName
		FROM 
			#MatQty q
			INNER JOIN mt000 mt ON q.mtGUID = mt.GUID
		WHERE 
			q.Qty < 0
	END
#########################################################
#END
