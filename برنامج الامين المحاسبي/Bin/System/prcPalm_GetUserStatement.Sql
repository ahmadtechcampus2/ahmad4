#########################################################
CREATE PROCEDURE prcPalm_GetUserStatement
		@PalmUserName [NVARCHAR](250)			
AS

SET NOCOUNT ON

	DECLARE @CustAccGUID [uniqueidentifier]
	DECLARE @CustCondId [INT]
	DECLARE @GLStartDate [datetime]
	DECLARE @GLEndDate [datetime]
	SELECT @CustAccGUID = [CustAccGUID], @CustCondId = [CustCondId], @GLStartDate = [GLStartDate], @GLEndDate = [GLEndDate] FROM [vwPl] WHERE [PalmUserName] = @PalmUserName


CREATE TABLE [#CustCond]([GUID] [uniqueidentifier], [Security] [INT])
INSERT INTO [#CustCond] EXEC [prcPalm_GetCustsList] @CustCondId

--SELECT cuAccount FROM vwCUac
CREATE TABLE [#CustomerTbl]([GUID] [uniqueidentifier], [cuAccount] [uniqueidentifier])
INSERT INTO [#CustomerTbl]
SELECT [accu].[cuGUID], [accu].[cuAccount]
FROM
	[vwCuAc]  as [accu]   
	INNER JOIN [dbo].[fnGetCustsOfAcc](@CustAccGUID) AS [f]    
		ON [accu].[cuGUID] = [f].[GUID]      
	INNER JOIN [#CustCond] AS [cuco] ON [cuco].[GUID] = [accu].[cuGUID]

CREATE TABLE [#CustStatement](         
		[CustomerID] [uniqueidentifier],
		[LineType] [INT],
		[Debit] [Float],          
		[Credit] [Float],          
		[EntryDate] [DateTime],
		[Note] [NVARCHAR](255) COLLATE ARABIC_CI_AI         
	 )              

------------------------------   
--	Export Statement     
--        
-----------------------------------        
CREATE TABLE [#CustEntrySum](         
		[GUID] [uniqueidentifier],
		[SumDebit] [Float],          
		[SumCredit] [Float],          
		[PrevBalance] [Float]        
	 )              
---------------------------------------------------------        
DECLARE	@PREVBALANCESTR		[NVARCHAR](100)        
DECLARE	@FROMDATESTR		[NVARCHAR](100)        
DECLARE	@TODATESTR			[NVARCHAR](100)        
DECLARE	@EMPTYSTR			[NVARCHAR](100)        
DECLARE	@SUMDEBITSTR		[NVARCHAR](100)        
DECLARE	@SUMCREDITSTR		[NVARCHAR](100)        
DECLARE	@BALANCESTR			[NVARCHAR](100)        
SET	@PREVBALANCESTR = 'Previous'        
SET	@FROMDATESTR = 'From Date'        
SET	@TODATESTR = 'To Date'        
SET	@EMPTYSTR = ' '        
SET	@SUMDEBITSTR = 'Total Debit'        
SET	@SUMCREDITSTR = 'Total Credit'        
SET	@BALANCESTR = 'Total Balance'        
---------------------------------------------------------        

INSERT INTO         
	[#CustStatement]
SELECt         
	[cu].[GUID],
	100,        
	[enDebit],
	[enCredit],
	[enDate],
	[enNotes]
FROm        
	[vwEN] AS [en]        
	INNER JOIN [#CustomerTbl] AS [cu]        
		ON [en].[enAccount] = [cu].[cuAccount]
WHERE        
	[enDate] Between @GLStartDate AND @GLEndDate
ORDER BY        
	[cu].[GUID],
	[en].[enDate]
---------------------------------------------------------        
INSERT INTO         
	[#CustEntrySum]        
SELECt         
	[cu].[GUID],        
	Sum([en].[enDebit]) AS [SumDebit],        
	Sum([en].[enCredit]) AS [SumCredit],        
	0 AS PrevBalance        
FROm        
	[vwEN] AS [en]        
	INNER JOIN [#CustomerTbl] AS [cu]        
		ON [en].[enAccount] = [cu].[cuAccount]        
WHERE        
	[enDate] Between @GLStartDate AND @GLEndDate
GROUP BY        
	[cu].[GUID]  
---------------------------------------------------------        
UPDATE
	[#CustEntrySum]
SET
	[PrevBalance] =  ISNULL([b].[Balaance], 0)        
FROM        
(        
	SELECT        
		SUM([en].[enDebit] - [en].[enCredit]) AS [Balaance],
		[cu].[GUID] AS [CuID]
	FROm        
		[vwEN] AS [en]        
		INNER JOIN [#CustomerTbl] AS [cu]        
			ON [en].[enAccount] = [cu].[cuAccount]
	WHERE        
		[enDate] < @GLStartDate
	GROUP BY
		[cu].[GUID]
) AS [b]        
WHERE
	[GUID] = [b].[CuID]
--------------------------------------------------------        
DECLARE @c_en CURSOR
DECLARE              
	@GUID [uniqueIdentifier],        
	@SumDebit [Float],          
	@SumCredit [Float],          
	@PrevBalance [Float]        
SET @c_en = CURSOR FAST_FORWARD        
FOR        
	SELECt         
		[GUID],          
		[SumDebit],          
		[SumCredit],          
		[PrevBalance]        
	FROM        
		[#CustEntrySum]	        
	ORDER BY        
		[GUID]        
OPEN @c_en        
FETCH NEXT FROM @c_en INTO        
	@GUID,        
	@SumDebit,        
	@SumCredit,        
	@PrevBalance        
WHILE @@FETCH_STATUS = 0        
BEGIN             
		---------- Insert BrevBalance        
		INSERT INTO [#CustStatement] VALUES (@GUID, 1, @PrevBalance, 0, @GLStartDate, @PREVBALANCESTR )			        
		---------- Insert FromDate        
		INSERT INTO [#CustStatement] VALUES (@GUID, 2, 0, 0, @GLStartDate, @FROMDATESTR)			        
		---------- Insert ToDate        
		INSERT INTO [#CustStatement] VALUES (@GUID, 3, 0, 0, @GLEndDate, @TODATESTR)        
		---------- Insert Empty Line        
		INSERT INTO [#CustStatement] VALUES (@GUID, 4, 0, 0, @GLEndDate, @EMPTYSTR )			        
		---------- Insert Empty Line        
		INSERT INTO [#CustStatement] VALUES (@GUID, 101, 0, 0, @GLEndDate, @EMPTYSTR )        
		---------- Insert SumDebit        
		INSERT INTO [#CustStatement] VALUES (@GUID, 102, @SumDebit, 0, @GLEndDate, @SUMDEBITSTR)        
		---------- Insert SumCredit        
		INSERT INTO [#CustStatement] VALUES (@GUID, 103, 0, @SumCredit, @GLEndDate, @SUMCREDITSTR)			        
		---------- Insert Balance        
		INSERT INTO [#CustStatement] VALUES (@GUID, 104, 0, @PrevBalance + @SumDebit - @SumCredit, @GLEndDate, @BALANCESTR  )			        
	        
	FETCH NEXT FROM @c_en INTO        
	@GUID,        
	@SumDebit,        
	@SumCredit,        
	@PrevBalance        
END  
CLOSE @c_en
DEALLOCATE @c_en

	INSERT INTO [PalmGUID]
	SELECT DISTINCT 
		[st].[CustomerID]
	FROM
		[#CustStatement] AS [st] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [st].[CustomerID]
	WHERE
		[pg].[GUID] IS NULL
	
SELECT         
	[pg].[Number] AS [CustomerID],   
	[LineType],
	[Debit],        
	[Credit],        
	[EntryDate],        
	[Note]        
FROM         
	[#CustStatement] AS [st]        
	INNER JOIN [#CustomerTbl] AS [cu] ON [cu].[GUID] = [st].[CustomerID]
	INNER JOIN [PalmGUID] As [pg] on [pg].[GUID] = [st].[CustomerID]
ORDER By         
	[st].[CustomerID],         
	[st].[LineType],         
	[st].[EntryDate]        

drop table [#CustStatement]
#########################################################
#END