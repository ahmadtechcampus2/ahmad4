###############################################
CREATE FUNCTION FnTrnRecycleGetLocalTransfer() RETURNS TABLE
-- œ«Œ·Ì…
AS
RETURN 
(
	SELECT 
		t.GUID
    FROM 
		TrnTransferVoucher000 AS t
    WHERE
		SourceType = 1 AND DestinationType = 1 
        AND IsFromStatement = 0
        AND State NOT IN (18, 13, 15)
)
#####################################################
CREATE FUNCTION FntrnRecycleGet_INOut_Transfer()
RETURNS TABLE
-- Œ«—ÃÌ… Ê«—œ… Ê’«œ—…
AS
RETURN 
(
	SELECT 
		t.GUID 
    FROM 
		TrnTransferVoucher000 AS t
    WHERE 
        SourceType = 2 AND DestinationType = 2
        AND IsFromStatement = 0
        AND State NOT IN (20, 13, 15)
)
#####################################################
CREATE FUNCTION FntrnRecycleGetOutTransfer()
RETURNS TABLE
AS
RETURN 
(
	SELECT 
		t.GUID 
	FROM 
		TrnTransferVoucher000 AS t
		--LEFT JOIN TrnStatement000 AS s ON s.Guid = t.OutStatementGuid
	WHERE 
		SourceType = 1 AND DestinationType = 2 
		AND state NOT IN (15, 18, 20) 
		--AND s.Guid IS NULL
)
#####################################################
CREATE FUNCTION FntrnRecycleGetInTransferByState() RETURNS TABLE
AS
RETURN 
(
	SELECT 
		t.GUID 
	FROM 
		TrnTransferVoucher000 AS t
		--LEFT JOIN TrnStatement000 AS s ON s.Guid = t.StatementGuid
	WHERE 
		SourceType = 2 AND DestinationType = 1 
		AND State NOT IN (4, 7, 8)
)
#####################################################
CREATE FUNCTION FntrnRecycleGetInTransfer()
RETURNS TABLE 
-- Œ«—ÃÌ… Ê«—œ…
AS
RETURN 
	(
		SELECT 
			t.GUID 
		FROM TrnTransferVoucher000 AS t
		--LEFT JOIN TrnStatement000 AS s ON s.Guid = t.InStatementPayedGuid
		WHERE
			SourceType = 2 AND DestinationType = 1
			--AND s.Guid IS NULL
	)
#####################################################
CREATE FUNCTION FntrnRecycleGet_INOut_TransferByState() RETURNS TABLE
AS
RETURN 
(
	SELECT 
		t.GUID 
	FROM 
		TrnTransferVoucher000 AS t
	WHERE 
		SourceType = 2 AND DestinationType = 2 
		AND State not in (15, 18, 20)
)
#####################################################		
CREATE FUNCTION FnTrnRecycleGetTransferVoucher()
RETURNS TABLE
-- Ã„Ì⁄ «·ÕÊ«·«  «·ﬁ«»·… ·· œÊÌ— 
AS
RETURN 
(
	SELECT [GUID] FROM [dbo].FnTrnRecycleGetLocalTransfer()
		UNION 
	SELECT [GUID] FROM [dbo].FntrnRecycleGetOutTransfer()
		UNION 
	SELECT [GUID] FROM [dbo].FntrnRecycleGet_INOut_TransferByState() -- FntrnRecycleGet_INOut_Transfer
		UNION 
	SELECT [GUID] FROM [dbo].FntrnRecycleGetInTransferByState() -- FntrnRecycleGetInTransfer
)
#####################################################
CREATE FUNCTION FnTrnRecycleGetInStatement()
RETURNS TABLE
-- ﬂ‘Ê›«   Ê«—œ…
AS
RETURN 
(
    SELECT 
		s.GUID
    FROM 
		TrnStatement000 AS s
		INNER JOIN TrnStatementItems000 AS I ON I.ParentGuid = S.Guid AND IsVoucherGenerated = 0
		INNER JOIN TrnStatementTypes000 AS T ON T.Guid = S.TypeGuid AND T.IsOut = 0
 --   INNER JOIN TrnTransfervoucher000 AS t ON t.StatementGuid = s.[GUID]
 --   INNER JOIN 
	--(
	--	SELECT GUID FROM [dbo].FntrnRecycleGetInTransfer()
	--		UNION 
	--	SELECT GUID FROM [dbo].FntrnRecycleGet_INOut_Transfer()
	--)  AS fn ON fn.[Guid] = t.[GUID] 
)
#####################################################     
CREATE FUNCTION FnTrnRecycleGetStatement()
RETURNS TABLE
-- Ã„Ì⁄ «·ﬂ‘Ê›«  «·ﬁ«»·… ·· œÊÌ— 
AS
RETURN 
	(
		SELECT 
			GUID 
		FROM [dbo].FnTrnRecycleGetInStatement()
)	
#####################################################
CREATE FUNCTION FnTrnRecylceGetInStatementItems() RETURNS TABLE 
-- √ﬁ·«„ «·ﬂ‘Ê›«  «·Ê«—œ… «·ﬁ«»·… ·· œÊÌ— 
AS
RETURN
(
	SELECT 
		I.GUID
    FROM 
		TrnStatement000 AS S
		INNER JOIN TrnStatementItems000 AS I ON I.ParentGuid = S.Guid AND IsVoucherGenerated = 0
		INNER JOIN TrnStatementTypes000 AS T ON T.Guid = S.TypeGuid AND T.IsOut = 0
	--SELECT item.[Guid]
	--FROM 
	--	TrnStatementItems000 AS item
	--	INNER JOIN 
	--		(
	--			SELECT GUID FROM [dbo].FntrnRecycleGetInTransfer()
	--			UNION 
	--			SELECT GUID FROM [dbo].FntrnRecycleGet_INOut_Transfer()
	--		) AS fn ON item.transfervoucherguid = fn.guid AND isVoucherGenerated = 0
)
#####################################################	
CREATE FUNCTION fnTrnRecycleGetMh()
RETURNS TABLE
-- ‰‘—… √”⁄«—
AS
RETURN
(
	SELECT GUID FROM trnMh000 WHERE DATE = (SELECT MAX(Date) FROM trnMH000)
)
--SELECT 
--	Tm.Guid
--FROM TrnMh000 AS Tm
--INNER JOIN (SELECT CurrencyGuid, MAX([Date]) AS [Date] FROM TrnMh000 GROUP BY CurrencyGuid) AS maxTm 
--ON maxTm.CurrencyGuid = Tm.CurrencyGuid AND Tm.[Date] = maxTm.[Date]
#####################################################	
#END
