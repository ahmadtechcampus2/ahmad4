#########################################################
CREATE VIEW vtCh
AS
	SELECT * FROM [ch000]

#########################################################
CREATE VIEW vbCh
AS
	SELECT [ch].*
	FROM [vtCh] AS [ch] INNER JOIN [vwBr] AS [br] ON [ch].[GUID] = [br].[brGUID]

#########################################################
CREATE VIEW vcCh
AS
	SELECT * FROM [vbCh]

#########################################################
CREATE VIEW vwCh
AS
	SELECT
		[GUID] AS [chGUID],
		[TypeGUID] AS [chType],
		[Number] AS [chNumber],
		[ParentGUID] AS [chParent],
		[Dir] AS [chDir],
		[AccountGUID] AS [chAccount],
		[Account2GUID] AS [chAccount2],
		-- CEntry1 AS chCEntry1,
		[Date] AS [chDate],
		[DueDate] AS [chDueDate],
		[ColDate] AS [chColDate],
		[Num] AS [chNum],
		[BankGUID] AS [chBankGUID],
		[Notes] AS [chNotes],
		[Val] AS [chVal],
		[CurrencyGUID] AS [chCurrencyPtr],
		[CurrencyVal] AS [chCurrencyVal],
		[State] AS [chState], 
		[Security] AS [chSecurity],
		-- CEntry2 AS CEntry2,
		[PrevNum] AS [chPrevNum],
		[IntNumber] AS [chIntNumber],
		[FileInt] AS [chFileInt],
		[FileExt] AS [chFileExt],
		[FileDate] AS [chFileDate], 
		[OrgName] AS [chOrgName],
		[Cost1GUID] AS [chCost1GUID],
		[Cost2GUID] AS [chCost2GUID],
		[Account2GUID] AS [chAccount2GUID],
		[BranchGUID] AS [chBranchGUID],
		[Notes2] AS [chNotes2],
		TransferCheck AS chTransferCheck,
		EndorseAccGUID,
		[CustomerGuid] AS [chCustomerGUID]
	FROM 
		[vbCh]
#########################################################
CREATE  VIEW VCCC
AS
	SELECT
		[vw].[GUID] AS [chGUID],
		[vw].[TypeGUID] AS [chType],
		[vw].[Number] AS [chNumber],
		[vw].[ParentGUID] AS [chParent],
		[vw].[Dir] AS [chDir],
		[vw].[AccountGUID] AS [chAccount],
		[vw].[Account2GUID] AS [chAccount2],
		-- CEntry1 AS chCEntry1,
		[vw].[Date] AS [chDate],
		[vw].[DueDate] AS [chDueDate],
		[vw].[ColDate] AS [chColDate],
		[vw].[Num] AS [chNum],
		[vw].[BankGUID] AS [chBankGUID],
		[vw].[Notes] AS [chNotes],
		[vw].[Val] AS [chVal],
		[vw].[CurrencyGUID] AS [chCurrencyPtr],
		[vw].[CurrencyVal] AS [chCurrencyVal],
		[vw].[State] AS [chState], 
		[vw].[Security] AS [chSecurity],
		-- CEntry2 AS CEntry2,
		[vw].[PrevNum] AS [chPrevNum],
		[vw].[IntNumber] AS [chIntNumber],
		[vw].[FileInt] AS [chFileInt],
		[vw].[FileExt] AS [chFileExt],
		[vw].[FileDate] AS [chFileDate], 
		[vw].[OrgName] AS [chOrgName],
		[vw].[Cost1GUID] AS [chCost1GUID],
		[vw].[Cost2GUID] AS [chCost2GUID],
		[vw].[Account2GUID] AS [chAccount2GUID],
		[vw].[BranchGUID] AS [chBranchGUID],
		[bu].[Number] as [chBillNumber],
		[bu].[TypeGUid] as [ParentType],
		[vw].[Notes2] AS [chNotes2]
		
	FROM 
		[vbCh] as [vw], [bu000] as [bu] where [vw].[ParentGuid] = [bu].[Guid] 
#########################################################
CREATE FUNCTION fnCh
	(@Type AS [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN SELECT 
		* 
	FROM
		[vbCh]
	WHERE
		[TypeGUID] = @Type 
#########################################################
#END