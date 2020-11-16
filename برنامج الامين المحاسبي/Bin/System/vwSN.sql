#########################################################
CREATE VIEW vwSN
AS 
	SELECT 
		[sn].[GUID], 
		[sn].[SN], 
		[sn].[MatGUID] AS [MatPtr], 
		[sn].[Item] AS [SortNum], 
		[in_bi].[buType] AS [inType], 
		[in_bi].[buGUID] AS [inBill], 
		ISNULL( [in_bi].[buNumber], 0) AS [inNumber], 
		ISNULL( [in_bi].[biStorePtr], 0x0) AS [inStorePtr], 
		ISNULL( [in_bi].[stName], '')  AS [InStoreName], 
		ISNULL( [in_bi].[biprice], 0) AS [InPrice],
		ISNULL( [in_bi].[buSecurity], 0) AS [InBuSecurity],

		--[dbo].[fnGetUserBillSec_Browse]( [dbo].[fnGetCurrentUserGUID], [IdType]) AS ,
		-- [dbo].[fnGetUserBillSec_ReadPrice]( [dbo].[fnGetCurrentUserGUID], [buType]) AS InReadPriceSec,
		---[fnGetUserBillSec_ReadPrice]( [fnGetCurrentUserGUID], [buType]) AS InReadPriceSec,
		[dbo].[fnGetUserSec]
		(
			( SELECT [UserGUID] FROM [Connections] 	WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()), 
			[dbo].[fnRID_BILL](), 
			[in_bi].[buType],
			1, 
			8
		) AS [InReadPriceSec],

		[sn].[InGUID] AS [InItem], 
		[in_bi].[btAbbrev] AS [inName], 
		[in_bi].[btLatinAbbrev] AS [inLatinName], 
		 
		[out_bi].[buType] AS [outType], 
		[out_bi].[buGUID] AS [outBill], 
		ISNULL( [out_bi].[buNumber], 0) AS [outNumber], 
		ISNULL( [out_bi].[biStorePtr], 0x0) AS [outStorePtr], 
		ISNULL( [out_bi].[stName], '')  AS [OutStoreName], 
		ISNULL( [out_bi].[biprice], 0) AS [OutPrice],
		ISNULL( [out_bi].[buSecurity], 0) AS [OutBuSecurity],
		[dbo].[fnGetUserSec]((SELECT [UserGUID] FROM [Connections] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()), [dbo].[fnRID_BILL](), [out_bi].[buType] /*@Type*/, 1, 8) AS [OUTReadPriceSec],

		[sn].[OutGUID] AS [outItem],
		[out_bi].[btAbbrev] AS [outName],
		[out_bi].[btLatinAbbrev] AS [outLatinName]
	FROM
		([vwExtended_bi_st] AS [in_bi] RIGHT OUTER JOIN [sn000] AS [sn] ON [in_bi].[biGUID] = [sn].[InGUID]) 
		LEFT OUTER JOIN [vwExtended_bi_st] AS [out_bi] ON [sn].[OutGUID] = [out_bi].[biGUID] 

/*
select *from vwExtended_bi
select buSecurity , bureadPriceSecurity from vwExtended_bi
select * from vwSN

*/


#########################################################
CREATE VIEW  vw_SN
AS
	SELECT DISTINCT
	
	[A].[GUID],
	--[A].[Item],
	1 AS [Security]
	,[mt].[Code]  AS [Code]
	,[mt].[NAME] AS [mtName]
	,[mt].[LatinName] AS [mtLatinName]
	,[mt].[Guid] AS [mtGuid]
	,[SN] AS [Name],[SN]
	FROM [SNC000] AS [A]
	INNER JOIN snt000 snt ON A.GUID = snt.ParentGUID 
	INNER JOIN [vcmt] AS [mt] ON [mt].[Guid] = [A].[MatGuid]
	WHERE [SN] !='' -- AND [A].[QTY] <> 0

#########################################################
CREATE VIEW vcSNs
AS 
	SELECT [c].[guid],[c].[sn],[t].[biGuid],[stguid],[c].[MatGuid],[t].[buGuid],[t].[Item],[t].[Notes], c.Qty
	FROM [snc000] [c] INNER JOIN [snt000] [t] ON [c].[guid] = [t].[parentguid]
#########################################################
CREATE FUNCTION fncSN
		( @MatGUID AS [UNIQUEIDENTIFIER],@StGuid UNIQUEIDENTIFIER,@SN NVARCHAR(100) = '') 
	RETURNS TABLE 
AS 
	RETURN(  
		SELECT  
			 [s].[Guid],
			 [s].[SN]  
		FROM  
			[vcSNs] s 
			INNER JOIN [bu000] b ON b.Guid = s.buGuid 
			INNER JOIN bt000 bt ON bt.Guid = b.typeGuid
			JOIN vwMT AS mt ON mt.mtGUID = s.MatGuid
		WHERE  
			[MatGUID] = @MatGUID 
			AND (@StGuid = 0X00 OR StGuid =  @StGuid)
			AND b.IsPosted = 1
			AND (@SN = '' OR s.sn = @SN)
		GROUP BY 
			[s].[Guid], 
			[s].[SN],
			mt.mtForceOutSN
		HAVING 
			(mt.mtForceOutSN > 0 AND SUM(CASE [bIsInput] WHEN 1 THEN 1 ELSE -1 END) = 1) OR mt.mtForceOutSN <= 0) 
#########################################################
CREATE FUNCTION fnSNRefundSales (@MatGUID AS UNIQUEIDENTIFIER, @SN NVARCHAR(100) = '') 
	RETURNS TABLE 
AS 
	RETURN(  
			SELECT SNTbl.[guid], SNTbl.SN  
			FROM  
				vcSNs AS SNTbl 
				INNER JOIN vwBu AS bu ON bu.buGUID = SNTbl.buGuid
				INNER JOIN bt000 AS bt ON bt.[GUID] = bu.buType
			WHERE  
				SNTbl.MatGUID = @MatGUID
				AND SNTbl.Qty in (0, -1)
				AND bu.buDirection = -1
				ANd bt.BillType = 1
				AND bu.buIsPosted = 1
				AND(@SN = '' OR SNTbl.sn = @SN)
			GROUP BY SNTbl.[guid], SNTbl.sn)
#########################################################
CREATE FUNCTION fncSN_Refund
		(@buGuid UNIQUEIDENTIFIER, @MatGUID AS [UNIQUEIDENTIFIER],@StGuid UNIQUEIDENTIFIER,@SN NVARCHAR(100) = '') 
	RETURNS TABLE 
AS 
	RETURN(  
		SELECT  
			 [s].[Guid],
			 [s].[SN]			
		FROM  
			[vcSNs] s 
			INNER JOIN [bu000] b ON b.Guid = s.buGuid
			INNER JOIN bt000 bt ON bt.Guid = b.typeGuid
			JOIN vwMT AS mt ON mt.mtGUID = s.MatGuid
		WHERE  
			[MatGUID] = @MatGUID 
			AND (@StGuid = 0X00 OR StGuid =  @StGuid)
			AND b.IsPosted = 1
			AND (@SN = '' OR SN = @SN)
			AND b.GUID = @buGuid
		GROUP BY 
			[s].[Guid], 
			[s].[SN],
			mt.mtForceOutSN
		HAVING mt.mtForceOutSN > 0)
#########################################################
CREATE PROCEDURE prcCheckDeleteBillSN(@billGuid UNIQUEIDENTIFIER)
AS
	SET NOCOUNT ON

	IF EXISTS(SELECT sn.snGuid
				FROM vwMt mt 
					INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
					INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
					INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
					WHERE b.buGUID = @billGuid AND (b.buIsPosted = 1 OR bt.btAutoPost = 1))
	BEGIN
		SELECT sn.snGuid, SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) AS qty
		INTO #result
		FROM vwMt mt 
			INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
			INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
			INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
		WHERE 
			b.buGUID != @billGuid AND mt.mtForceInSN = 1 AND mt.mtForceOutSN = 1 AND (b.buIsPosted = 1 OR bt.btAutoPost = 1)
		GROUP BY 
			sn.snGuid
		HAVING 
			SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) NOT IN (0, 1)


		INSERT INTO #result
		SELECT sn.snGuid, SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) AS qty
		FROM vwMt mt 
			INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
			INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
			INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
		WHERE 
			b.buGUID != @billGuid AND (mt.mtForceOutSN = 1 OR mt.mtForceInSN = 1) AND (b.buIsPosted = 1 OR bt.btAutoPost = 1)
		GROUP BY
			sn.snGuid
		HAVING 
			SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) NOT IN (-1, 0, 1)


		SELECT COUNT(qty) AS SNsIssuesAfterDelSelectedBill FROM #result
	END
	ELSE
		SELECT 0 AS SNsIssuesAfterDelSelectedBill
#########################################################
CREATE PROCEDURE prcCheckDeleteTransportSN(@inBillGuid UNIQUEIDENTIFIER, @outBillGuid UNIQUEIDENTIFIER)
AS
	SET NOCOUNT ON
	IF EXISTS(SELECT sn.snGuid
				FROM vwMt mt 
					INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
					INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
					INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
					WHERE b.buGUID = @outBillGuid AND (b.buIsPosted = 1 OR bt.btAutoPost = 1))
	BEGIN
		SELECT b.buStorePtr, sn.snGuid, SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE - 1 END) AS qty
		INTO #result
		FROM vwMt mt 
			INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
			INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
			INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
		WHERE 
			b.buGUID != @inBillGuid AND b.buGUID != @outBillGuid 
			AND mt.mtForceInSN = 1 AND mt.mtForceOutSN = 1 
			AND (b.buIsPosted = 1 OR bt.btAutoPost = 1)
		GROUP BY 
			b.buStorePtr, sn.snGuid
		HAVING 
			SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) NOT IN (0, 1)


		INSERT INTO #result
		SELECT b.buStorePtr, sn.snGuid, SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) AS qty
		FROM vwMt mt 
			INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
			INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
			INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
		WHERE 
			b.buGUID != @inBillGuid AND b.buGUID != @outBillGuid 
			AND (mt.mtForceOutSN = 1 OR mt.mtForceInSN = 1) 
			AND (b.buIsPosted = 1 OR bt.btAutoPost = 1)
		GROUP BY
			b.buStorePtr, sn.snGuid
		HAVING 
			SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) NOT IN (-1, 0, 1)


		SELECT COUNT(qty) AS SNsIssuesAfterDelSelectedTransport FROM #result
	END
	ELSE
		SELECT 0 AS SNsIssuesAfterDelSelectedTransport
#########################################################
#END