#########################################################
CREATE FUNCTION fnGetBTSortCostPrice(@BTType INT, @BTBillType INT, @BTSortNum INT, @BTIsInput BIT)
	RETURNS TABLE
AS 
	RETURN (
		SELECT TOP 1 
			ISNULL(ActualSort, 0) AS ActualSort, 
			ISNULL(IsRelated, 0) AS IsRelated
		FROM BTSortCostPrice000 
		WHERE 
			BTType = @BTType AND BTBillType = @BTBillType AND BTIsInput = @BTIsInput
			AND (((BTSortNum = @BTSortNum) AND (@BTType = 2 /*only std bill types*/)) OR (@BTType != 2)))
#########################################################
CREATE FUNCTION fnBT_IfAnyRelatedCostAffected(@BtGUID UNIQUEIDENTIFIER)
	RETURNS BIT
AS BEGIN 
	IF EXISTS (SELECT 1 FROM bt000 WHERE GUID = @BtGUID AND bAffectCostPrice = 1)
		RETURN 1

	DECLARE @RelatedBtGUID UNIQUEIDENTIFIER
	SET @RelatedBtGUID = 0x0

	-- „‰«ﬁ·«  ÌœÊÌ…
	IF EXISTS (SELECT * FROM tt000 WHERE InTypeGUID = @BtGUID OR OutTypeGUID = @BtGUID)
	BEGIN 		
		SELECT @RelatedBtGUID = InTypeGUID FROM tt000 WHERE OutTypeGUID = @BtGUID
		IF ISNULL(@RelatedBtGUID, 0x0) = 0x0
			SELECT @RelatedBtGUID = OutTypeGUID FROM tt000 WHERE InTypeGUID = @BtGUID

		IF EXISTS (SELECT 1 FROM bt000 WHERE GUID = @RelatedBtGUID AND bAffectCostPrice = 1)
			RETURN 1

		RETURN 0
	END 

	-- „‰«ﬁ·«  ﬁÌ«”Ì…
	IF EXISTS (SELECT * FROM bt000 WHERE GUID = @BtGUID AND [Type] = 2 AND [SortNum] IN (3, 4, 7, 8))
	BEGIN 
		IF EXISTS (SELECT * FROM bt000 WHERE GUID = @BtGUID AND [Type] = 2 AND [SortNum] = 3)
			SELECT @RelatedBtGUID = [GUID] FROM bt000 WHERE [Type] = 2 AND [SortNum] = 4
		IF EXISTS (SELECT * FROM bt000 WHERE GUID = @BtGUID AND [Type] = 2 AND [SortNum] = 4)
			SELECT @RelatedBtGUID = [GUID] FROM bt000 WHERE [Type] = 2 AND [SortNum] = 3

		IF EXISTS (SELECT * FROM bt000 WHERE GUID = @BtGUID AND [Type] = 2 AND [SortNum] = 7)
			SELECT @RelatedBtGUID = [GUID] FROM bt000 WHERE [Type] = 2 AND [SortNum] = 8
		IF EXISTS (SELECT * FROM bt000 WHERE GUID = @BtGUID AND [Type] = 2 AND [SortNum] = 8)
			SELECT @RelatedBtGUID = [GUID] FROM bt000 WHERE [Type] = 2 AND [SortNum] = 7

		IF EXISTS (SELECT 1 FROM bt000 WHERE GUID = @RelatedBtGUID AND bAffectCostPrice = 1)
			RETURN 1
		RETURN 0
	END 

	-- »ÿ«ﬁ«  «· ﬂ·Ì›
	IF EXISTS (SELECT * FROM bt000 WHERE GUID = @BtGUID AND [Type] = 3 AND [BillType] IN (4, 5))
	BEGIN 
		IF EXISTS (SELECT * FROM bt000 WHERE GUID = @BtGUID AND [Type] = 3 AND [BillType] = 4)
			SELECT @RelatedBtGUID = [GUID] FROM bt000 WHERE [Type] = 3 AND [BillType] = 5
		IF EXISTS (SELECT * FROM bt000 WHERE GUID = @BtGUID AND [Type] = 3 AND [BillType] = 5)
			SELECT @RelatedBtGUID = [GUID] FROM bt000 WHERE [Type] = 3 AND [BillType] = 4

		IF EXISTS (SELECT 1 FROM bt000 WHERE GUID = @RelatedBtGUID AND bAffectCostPrice = 1)
			RETURN 1
		RETURN 0
	END 


	RETURN 0
END 
#########################################################
CREATE FUNCTION fnGetBillsTypesList (
	@SrcGuid [UNIQUEIDENTIFIER] = 0x0,
	@UserGUID [UNIQUEIDENTIFIER] = 0x0)
	RETURNS @Result TABLE( [GUID] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])
AS
BEGIN
	IF ISNULL(@UserGUID, 0x0) = 0x0
		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

	IF ISNULL(@SrcGuid, 0x0)= 0x0
		INSERT INTO @Result
			SELECT
					[GUID],
					[BrowseSec],
					[ReadPriceSec]
				FROM
					[dbo].[fnGetUserBillsSec]( @UserGUID ) AS [fn]
					--INNER JOIN ( SELECT DISTINCT TypeGUID FROM bu000) AS b ON fn.GUID = b.TypeGUID
					INNER JOIN [vwBt] AS [b] ON [fn].[GUID] = [b].[btGUID]
	ELSE
		INSERT INTO @Result
			SELECT
					[IdType],
					[dbo].[fnGetUserBillSec_Browse](@UserGUID, [IdType]),
					[dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, [IdType])
				FROM
					[dbo].[RepSrcs] AS [r] 
					--INNER JOIN ( SELECT DISTINCT TypeGUID FROM bu000) AS b	ON r.IdType = b.TypeGUID
					INNER JOIN [vwBt] AS [b] ON [r].[IdType] = [b].[btGUID]
				WHERE
					[IdTbl] = @SrcGuid
	RETURN
END
/*
EXECUTE [repTransAcc] 'ecd353e1-2ae4-4392-92e9-fad8c81ed642', '3fe2382a-f9b6-4698-984d-6e43d063aca1', 'bb72c33f-4534-487d-90c5-bc21a56e4615', '1/1/2003', '5/20/2003'
select * from dbo.fnGetBillsTypesList( 'bb72c33f-4534-487d-90c5-bc21a56e4615', NULL)
select * from py000
SELECT DISTINCT TypeGUID FROM bu000
select * from dbo.fnGetUserBillsSec( 0x0)
*/
#########################################################
CREATE FUNCTION fnGetBillsTypesList2 ( 
	@SrcGuid [UNIQUEIDENTIFIER] = 0x0, 
	@UserGUID [UNIQUEIDENTIFIER] = 0x0,
	@SortAffectCostType BIT = 0) 
	RETURNS @Result TABLE( [GUID] [UNIQUEIDENTIFIER], [PostedSecurity] [INT], [ReadPriceSecurity] [INT], [UnPostedSecurity] [INT], 
		[PriorityNum] [INT], [SamePriorityOrder] [INT], [SortNumber] INT)
AS 
BEGIN 
	DECLARE @TempTable TABLE ( [GUID] [UNIQUEIDENTIFIER], [PostedSecurity] [INT], [ReadPriceSecurity] [INT], [UnPostedSecurity] [INT])
	IF ISNULL(@UserGUID, 0x0) = 0x0 
		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	DECLARE @IsSortBillTypesForCost BIT 
	SET @IsSortBillTypesForCost = CASE WHEN ISNULL((SELECT TOP 1 Value FROM op000 WHERE Name = 'AmnCfg_SortBillTypesForCost' AND Type = 0), '1') = '1' THEN 1 ELSE 0 END

	IF ISNULL(@SrcGuid, 0x0)= 0x0 
		INSERT INTO @TempTable 
			SELECT 
					[GUID],
					[BrowsePostSec], 
					[ReadPriceSec],
					[BrowseUnPostSec]
				FROM 
					[vwBt] AS [b]
					INNER JOIN  [dbo].[fnGetUserBillsSec2]( @UserGUID ) AS [fn] ON [fn].[GUID] = [b].[btGUID]
			
	ELSE 
		INSERT INTO @TempTable 
			SELECT 
					[IdType], 
					[BrowsePostSec], 
					[ReadPriceSec],
					[BrowseUnPostSec]
				FROM 
					[dbo].[RepSrcs] AS [r]
					INNER JOIN  [dbo].[fnGetUserBillsSec2]( @UserGUID) AS [fn] ON [fn].[GUID] = [r].[IdType]
				WHERE 
					[IdTbl] = @SrcGuid 


	INSERT INTO @Result	
	SELECT 
		[bt].[GUID], [PostedSecurity], [ReadPriceSecurity] , [UnPostedSecurity],
		CASE @IsSortBillTypesForCost 
			WHEN 1 THEN 
				CASE 
					WHEN ((btAffectCostPrice = 1) OR (@SortAffectCostType = 0)) THEN ISNULL(btSort.ActualSort, 0) 
					ELSE CASE ISNULL(btSort.IsRelated, 0) WHEN 0 THEN btSort.ActualSort + 100 ELSE CASE dbo.fnBT_IfAnyRelatedCostAffected(bt.GUID) WHEN 1 THEN ISNULL(btSort.ActualSort, 0) ELSE btSort.ActualSort + 100 END END
				END  
			ELSE ISNULL(btSort.ActualSort, 0)
		END,
		CASE [vwBT].[btType] 
			WHEN 3 THEN
				CASE [vwBT].[btBillType] 
					WHEN 5 THEN 2 /*≈Œ.  ﬂ·›…*/
					ELSE 1
				END
			WHEN 2 THEN 
				CASE [vwBT].[btSortNum]
					WHEN 7 THEN 2 /*≈œŒ«· »ﬁÌœ*/
					WHEN 3 THEN 2 /*≈œŒ«· „” Êœ⁄*/
					ELSE 1
				END
			WHEN 4 THEN 
				CASE [vwBT].[btBillType] 
					WHEN 0 THEN 2 /*≈œŒ«· „‰«ﬁ·…*/
					ELSE 1
				END
			ELSE 1
		END,
		CASE [vwBT].[btType] 
			WHEN 1 THEN [vwBT].[btSortNum]
			WHEN 3 THEN CASE [vwBT].[btBillType] WHEN 0 THEN [vwBT].[btSortNum] ELSE 1 END 
			WHEN 4 THEN CASE [vwBT].[btBillType] WHEN 0 THEN [vwBT].[btSortNum] ELSE 1 END 
			WHEN 5 THEN CASE [vwBT].[btBillType] WHEN 5 THEN [vwBT].[btSortNum] ELSE 1 END 
			WHEN 6 THEN CASE [vwBT].[btBillType] WHEN 4 THEN [vwBT].[btSortNum] ELSE 1 END 
			WHEN 9 THEN [vwBT].[btSortNum]
			WHEN 10 THEN [vwBT].[btSortNum]
			ELSE 1
		END
	FROM 
		[vwBT] 
		INNER JOIN @TempTable AS bt ON [bt].[GUID] = [vwBT].[btGUID]
		OUTER APPLY dbo.fnGetBTSortCostPrice([vwBT].[btType], [vwBT].[btBillType], [vwBT].[btSortNum], [vwBT].[btIsInput]) btSort
	
	RETURN 
END 
#########################################################
#END
