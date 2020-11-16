##########################################################
CREATE PROC prcGetAccBillPrevBalance
	@BillGuid uniqueidentifier, 
	@CurGuid uniqueidentifier = NULL
AS 
	SET NOCOUNT ON
	
	DECLARE 
		@Date datetime,
		@AccGuid uniqueidentifier,
		@CustomerGUID uniqueidentifier

	SELECT @AccGuid = [cu].[AccountGuid], @CustomerGUID = cu.GUID, @Date = [bu].[Date], @CurGuid = ISNULL(@CurGuid, bu.CurrencyGuid)
	FROM 
		[bu000] bu 
		INNER JOIN [cu000] cu ON [cu].[Guid] = [bu].CustGuid
	WHERE bu.Guid = @BillGuid;

	-- Total balance
	SELECT 0 AS [Type], ISNULL(SUM( FixedEnDebit) - SUM( FixedEnCredit),0) AS Balance
		FROM
			[dbo].[fnExtended_En_Fixed]( @CurGuid) fn
			LEFT JOIN(SELECT DISTINCT er1.EntryGuid,[ch].[state] from  [er000] AS [er1]
			INNER JOIN [Ch000] AS [ch] ON [ch].[Guid] = [er1].[ParentGuid]) AS [er] ON [fn].[ceGuid] = [er].[EntryGuid]
		WHERE 
			enAccount = @AccGuid
			AND enCustomerGUID = @CustomerGUID
			AND [enDate] <= @Date
			AND ISNULL([er].[state],1) != 0
	UNION ALL
	-- cheques balance only
	SELECT 
		1, SUM(CH.chVal * CASE CH.ChDir WHEN 1 THEN -1 ELSE 1 END) - SUM(COL.collectedValue * CASE CH.ChDir WHEN 1 THEN -1 ELSE 1 END)
	FROM
		vwCh AS CH
		LEFT JOIN vwcolch AS COL ON CH.chGUID = COL.chGUID
	WHERE 
		chAccount = @AccGuid
		AND chCustomerGUID = @CustomerGUID
		AND CH.chDate <= @Date
		AND ch.chState IN(0, 2, 4, 7, 10, 11, 14);
##########################################################
#END