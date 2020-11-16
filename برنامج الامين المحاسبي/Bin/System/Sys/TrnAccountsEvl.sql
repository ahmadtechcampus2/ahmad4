####################################################
CREATE PROCEDURE PrcTrnAccountsEvaluation
             @AccGUID UNIQUEIDENTIFIER,
             @EndDate DATETIME,
             @CurrencyGUID UNIQUEIDENTIFIER = 0x0
AS
SET NOCOUNT ON 

IF @CurrencyGUID = 0x0
         SET @CurrencyGUID = (SELECT CurrencyGUID FROM ac000 WHERE GUID = @AccGUID)

CREATE TABLE #Result(Balance FLOAT ,--«·—’Ìœ »⁄„·… «·Õ”«»
                     EqBalance FLOAT ,--«·ﬁÿ⁄ «·„ﬂ«›∆
                     AccCurrencyVal FLOAT DEFAULT 0,--«· ⁄«œ· «·Ê”ÿÌ
                     Notes NVARCHAR(255))
INSERT INTO #Result(Balance, EqBalance, Notes)
                     
SELECT ISNULL(sum([e].[debit]/[e].[currencyval]) - sum([e].[credit]/[e].[currencyval]),0),
       ISNULL(sum([e].[debit]) - sum([e].[credit]),0),  
       '' 
FROM [en000] [e] 
INNER JOIN [ce000] [c]  on [e].[parentGuid] = [c].[guid]
WHERE [c].[isPosted] <> 0
AND   [e].[accountGuid] = @AccGUID
AND   [e].currencyGUID  = @CurrencyGUID
AND   [c].date <= @EndDate

UNION

SELECT ISNULL(sum([e].[debit]/[e].[currencyval]) - sum([e].[credit]/[e].[currencyval]),0),
       ISNULL(sum([e].[debit]) - sum([e].[credit]),0),  
       '«·Õ”«» „ Õ—ﬂ »€Ì— ⁄„· Â' 
FROM [en000] [e] INNER JOIN [ce000] [c] on [e].[parentGuid] = [c].[guid]
WHERE [c].[isPosted] <> 0
AND   [e].[accountGuid] = @AccGUID
AND   [e].currencyGUID <> @CurrencyGUID
AND   [c].date <= @EndDate

UPDATE #Result
SET AccCurrencyVal = EqBalance / Balance
WHERE Balance <> 0 

DECLARE @TestVal1 FLOAT, @TestVal2 FLOAT 
SET @TestVal1 = (SELECT AccCurrencyVal FROM #Result where Notes = '')	
SET @TestVal2 = (SELECT AccCurrencyVal FROM #Result where Notes <> '')

IF (ABS(@TestVal1) > 10000)--So There is too Small Balance....
    UPDATE #Result
    SET AccCurrencyVal = 0
    WHERE Notes = ''

IF (ABS(@TestVal2) > 10000)
    UPDATE #Result
    SET AccCurrencyVal = 0--So There is too Small Balance in Different Curency
    WHERE Notes <> ''

SELECT * FROM #Result

####################################################
CREATE PROCEDURE TrnGenAccountsEvlEntry
	@EvlGUID         UNIQUEIDENTIFIER,
	@PositiveDiffAcc UNIQUEIDENTIFIER,
	@NegativeDiffAcc UNIQUEIDENTIFIER,
	@EntryGUID       UNIQUEIDENTIFIER,
	@INDEX           INT
As
SET NOCOUNT ON

DECLARE @defaultCur     UNIQUEIDENTIFIER,
        @EqBalance      FLOAT,
        @EqEvaluatedBal FLOAT

SELECT @defaultCur = guid FROM my000 WHERE CurrencyVal = 1

SELECT @EqBalance = EquivilantBalance,
       @EqEvaluatedBal = EqEvlBalance
FROM TrnAccountsEvlDetail000
WHERE GUID = @EvlGUID
---------TO GENERATE ENTRIES-------------
INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
		   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
	           CostGUID, ContraAccGUID, CustomerGUID)
                   
SELECT             @INDEX, AccEvl.Date, (CASE WHEN @EqEvaluatedBal > @EqBalance THEN @EqEvaluatedBal-@EqBalance ELSE 0 END),
                                   (CASE WHEN @EqEvaluatedBal > @EqBalance THEN 0 ELSE @EqBalance-@EqEvaluatedBal END),
                   AccEvlDetail.Notes, AccEvlDetail.CurrencyGuid, ABS(AccEvlDetail.EquivilantBalance/0.0000000001), @EntryGUID,
                   AccEvlDetail.AccountGuid, 0x0, (CASE WHEN @EqEvaluatedBal > @EqBalance THEN @PositiveDiffAcc ELSE @NegativeDiffAcc END),dbo.fnGetAccountTopCustomer(AccEvlDetail.AccountGuid)
FROM TrnAccountsEvlDetail000 As AccEvlDetail
INNER JOIN TrnAccountsEvl000 As AccEvl on AccEvlDetail.ParentGuid = AccEvl.Guid
WHERE AccEvlDetail.GUID = @EvlGUID
 

UNION 

SELECT              @INDEX + 1, AccEvl.Date, (CASE WHEN @EqEvaluatedBal > @EqBalance THEN 0 ELSE @EqBalance-@EqEvaluatedBal END),
                                    (CASE WHEN @EqEvaluatedBal > @EqBalance THEN @EqEvaluatedBal-@EqBalance ELSE 0 END),
                    AccEvlDetail.Notes, @defaultCur, 1, @EntryGUID,
                    (CASE WHEN @EqEvaluatedBal > @EqBalance THEN @PositiveDiffAcc ELSE @NegativeDiffAcc END) , 0x0, AccEvlDetail.AccountGuid, dbo.fnGetAccountTopCustomer(CASE WHEN @EqEvaluatedBal > @EqBalance THEN @PositiveDiffAcc ELSE @NegativeDiffAcc END)
FROM TrnAccountsEvlDetail000 As AccEvlDetail
INNER JOIN TrnAccountsEvl000 As AccEvl on AccEvlDetail.ParentGuid = AccEvl.Guid
WHERE AccEvlDetail.GUID = @EvlGUID

####################################################
CREATE PROCEDURE prctrnAccEvlGenEntries
	@MasterGUID		UNIQUEIDENTIFIER,
	@PositiveDiffAcc UNIQUEIDENTIFIER,
	@NegativeDiffAcc UNIQUEIDENTIFIER,
	@IsModify		 Bit = 0
AS 
SET NOCOUNT ON

DECLARE @Cur CURSOR,
        @DetailGUID UNIQUEIDENTIFIER
SET @Cur = CURSOR FAST_FORWARD FOR 
SELECT GUID FROM TrnAccountsEvlDetail000 
WHERE parentGUID = @MasterGUID 
AND Notes <>  '«·Õ”«» „ Õ—ﬂ »€Ì— ⁄„· Â'  
order by Number
-----------------INSERTING INTO CE000
DECLARE @OldEntryGuid    UNIQUEIDENTIFIER,
        @EntryNum        INT,
        @EntryGUID       UNIQUEIDENTIFIER,
        @defaultCur      UNIQUEIDENTIFIER,
        @Ammount         FLOAT,
        @BranchGUID      UNIQUEIDENTIFIER

SELECT @OldEntryGuid = entryGUID,
       @BranchGUID = BranchGUID
FROM TrnAccountsEvl000
WHERE guid = @MasterGUID

Declare @CreateDate DateTime,
		@CreateUserGuid UNIQUEIDENTIFIER

EXEC  prcDisableTriggers 'ce000' 
EXEC  prcDisableTriggers 'en000' 
IF (IsNull(@OldEntryGuid, 0x0) = 0x0) 
   SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)		
ELSE 
   BEGIN	
	SELECT @EntryNum = NUMBER, @CreateDate = CreateDate, @CreateUserGuid = CreateUserGUID
	FROM ce000  WHERE GUID =  @OldEntryGuid
	DELETE FROM ce000 WHERE Guid = @OldEntryGuid
	DELETE FROM en000 WHERE ParentGuid = @OldEntryGuid
	DELETE FROM er000 WHERE EntryGuid = @OldEntryGuid
   END	
SET @EntryGUID = NEWID()
SELECT @defaultCur = guid FROM my000 WHERE CurrencyVal = 1
SELECT @Ammount = SUM(ABS(EqEvlBalance - EquivilantBalance))
FROM TrnAccountsEvlDetail000
WHERE parentGUID = @MasterGUID
INSERT INTO ce000(Number, DATE, PostDate, Debit, Credit, 
	          Notes, CurrencyVal, IsPosted, Branch, GUID, CurrencyGUID, Security) 
SELECT            @EntryNum, 
                  [Date],
                  [Date], 
                  @Ammount, 
                  @Ammount,
                  Note, 1, 0, @BranchGUID, @EntryGUID, @defaultCur, 1    
FROM TrnAccountsEvl000  
WHERE GUID = @MasterGUID
-----------------
OPEN @Cur
FETCH FROM @Cur INTO @DetailGUID
DECLARE @Index INT
SET @INDEX = 0
WHILE @@FETCH_STATUS = 0 
   BEGIN
   EXEC TrnGenAccountsEvlEntry @DetailGUID, @PositiveDiffAcc,  @NegativeDiffAcc, @EntryGUID, @INDEX
   SET @INDEX = @INDEX + 2
   FETCH FROM @Cur INTO @DetailGUID
   END
CLOSE @Cur
DEALLOCATE @Cur

UPDATE TrnAccountsEvl000 SET EntryGUID = @entryGUID WHERE GUID = @MasterGUID

INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)  
	SELECT @EntryGUID, @MasterGUID , 518 , number
	FROM TrnAccountsEvl000
WHERE guid = @MasterGUID

UPDATE [ce000] SET [IsPosted] = 1,
	CreateDate =
		CASE WHEN @IsModify = 1 THEN  @CreateDate ELSE GETDATE() END,
	CreateUserGUID =
		CASE WHEN @IsModify = 1 THEN  @CreateUserGuid ELSE [dbo].[fnGetCurrentUserGUID]() END,
	LastUpdateDate = 
		CASE WHEN @IsModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
	LastUpdateUserGUID =
		CASE WHEN @IsModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
	WHERE Guid = @entryGUID  

EXEC prcEnableTriggers 'ce000'   
EXEC prcEnableTriggers 'en000'  

-- return data about generated entry     
SELECT @EntryGUID AS EntryGuid , @entryNum  AS EntryNumber
####################################################
CREATE PROCEDURE Prc_Periodic_TrnAccountsEvaluation
             @AccGUID UNIQUEIDENTIFIER, 
             @EndDate DATETIME,
             @bFromTransferBulletin BIT = 1
AS 
/*
Procedures for  periodic evaluation :
1-Prc_Periodic_TrnAccountsEvaluation
*/
SET NOCOUNT ON  
	DECLARE @CurrencyGUID	UNIQUEIDENTIFIER,
			@EvlVal			FLOAT,
			@Guid			UNIQUEIDENTIFIER
			
	SET @CurrencyGUID = (SELECT CurrencyGUID FROM ac000 WHERE GUID = @AccGUID) 
	IF (@bFromTransferBulletin = 1)
		SET @EvlVal = (Select InVal From fnTrnGetCurrencyInOutVal(@CurrencyGUID, @EndDate))
	ELSE
	BEGIN
		SET @EvlVal = (SELECT TOP 1 [CurrencyVal] FROM [mh000] 
						WHERE [CurrencyGUID] = @CurrencyGUID AND [Date] <= @EndDate 
						ORDER BY [Date] DESC) 
		IF @EvlVal IS NULL 
			SET @EvlVal = (SELECT [CurrencyVal] FROM [my000] WHERE [GUID] = @CurrencyGUID) 
	END	
		
SET @Guid   = NewId()

CREATE TABLE #Result(
						 [Guid]					UNIQUEIDENTIFIER,
						 AccGUID				UNIQUEIDENTIFIER,
						 CurrencyGUID	     	UNIQUEIDENTIFIER,
						 Balance				FLOAT DEFAULT 0,		--«·—’Ìœ »⁄„·… «·Õ”«» 
						 EqBalance				FLOAT DEFAULT 0, 		--«·ﬁÿ⁄ «·„ﬂ«›∆ »⁄„· Â 
						 EqDiffCurrBalance		FLOAT DEFAULT 0,		--ﬁÿ⁄ «·Õ”«» »€Ì— ⁄„· Â 
						 AccCurrencyVal			FLOAT DEFAULT 0,		--«· ⁄«œ· «·Ê”ÿÌ 
						 Evlval					FLOAT DEFAULT 0,		--«· ⁄«œ· «· ﬁÌÌ„ 
						 EvlEqBalance			FLOAT DEFAULT 0,		--ﬁÿ⁄ «· ﬁÌÌ„
						 Notes					NVARCHAR(255) DEFAULT ''
                     ) 
--«·Õ”«» „ Õ—ﬂ »€Ì— ⁄„· Â                     
CREATE TABLE #OtherCurrencyResult(
						 AccGUID				UNIQUEIDENTIFIER,
						 EqDiffCurrBalance		FLOAT				--ﬁÿ⁄ —’Ìœ «·Õ”«» »€Ì— ⁄„· Â
                     ) 
--Fill #Result                     
INSERT INTO #Result([Guid], AccGUID, CurrencyGUID, Balance, EqBalance, Evlval, Notes) 
                    
SELECT @Guid,
	   @AccGUID, 
	   @CurrencyGUID,
	   ISNULL(sum([e].[debit]/[e].[currencyval]) - sum([e].[credit]/[e].[currencyval]),0), 
       ISNULL(sum([e].[debit]) - sum([e].[credit]),0),   
       @EvlVal,
       ''  
FROM [en000] [e]  
INNER JOIN [ce000] [c]  on [e].[parentGuid] = [c].[guid] 
WHERE [c].[isPosted] <> 0 
AND   [e].[accountGuid] = @AccGUID 
AND   [e].currencyGUID  = @CurrencyGUID 
AND   [c].date <= @EndDate 

--Fill #OtherCurrencyResult
INSERT INTO #OtherCurrencyResult 
SELECT @AccGUID, 
       ISNULL(sum([e].[debit]) - sum([e].[credit]),0) 
FROM [en000] [e] INNER JOIN [ce000] [c] on [e].[parentGuid] = [c].[guid] 
WHERE [c].[isPosted] <> 0 
AND   [e].[accountGuid] = @AccGUID 
AND   [e].currencyGUID <> @CurrencyGUID 
AND   [c].date <= @EndDate 

--Update 1 to calc AccCurrencyVal, EvlEqBalance
UPDATE #Result 
SET AccCurrencyVal = EqBalance / Balance,
	EvlEqBalance = Balance * Evlval
WHERE Balance <> 0

--Update 2 to adjust note, EqDiffCurrBalance
UPDATE Res
SET Res.EqDiffCurrBalance = InDiffCurrency.EqDiffCurrBalance,
	Res.Notes = '«·Õ”«» „ Õ—ﬂ »€Ì— ⁄„· Â'   
FROM #Result AS Res
INNER JOIN #OtherCurrencyResult AS InDiffCurrency ON Res.AccGUID = InDiffCurrency.AccGUID
WHERE InDiffCurrency.EqDiffCurrBalance <> 0

 
DECLARE @TestVal FLOAT
SET @TestVal = (SELECT AccCurrencyVal FROM #Result)	 

IF (ABS(@TestVal) > 10000)--So There is too Small Balance.... 
    UPDATE #Result 
    SET AccCurrencyVal = 0 
--Filter records that can be evaluated
DELETE FROM #Result WHERE EqBalance = 0

SELECT * FROM #Result
####################################################
CREATE PROCEDURE Prc_Periodic_Evaluation
(
	@AccountCode			NVARCHAR(100),
	@PositiveEvlDiff		NVARCHAR(100),
	@NegativeEvlDiff		NVARCHAR(100),
	@bFromTransferBulletin	BIT = 1
)

/*
Procedures for  periodic evaluation :
2-Prc_Periodic_Evaluation
*/

AS
	SET NOCOUNT ON
	DECLARE @Admin				NVARCHAR(100),
			@AccGUID			UNIQUEIDENTIFIER,
			@EvlNumber			INT,
			@Branch				UNIQUEIDENTIFIER,
			@MasterGUID			UNIQUEIDENTIFIER,
			@Date				DateTime,
			@PositiveEvlDiffAcc UNIQUEIDENTIFIER,
			@NegativeEvlDiffAcc UNIQUEIDENTIFIER
	SET @Admin		= (SELECT Top 1 LoginName FROM US000 WHERE bAdmin = 1)
	SET @AccGUID	= (SELECT [GUID] FROM AC000 WHERE CODE LIKE @AccountCode)
	SET @EvlNumber  = (SELECT ISNULL(MAX(NUMBER), 0) + 1 FROM TrnAccountsEvl000 )
	SET @Branch		= (SELECT [GUID] FROM br000 WHERE NUMBER = 1)
	SET @MasterGUID  = NewID()
	SET @Date		= GetDate()
	--Adjust Time
	SET @date = DateAdd("dd", -1, @date)
	Set @date = CAST (
					CAST(DatePart("yy", @date) AS NVARCHAR(4)) + '-' +
					CAST(DatePart("mm", @date) AS NVARCHAR(2)) + '-' +
					CAST(DatePart("dd", @date) AS NVARCHAR(2)) + ' 23:59:00'
					AS DATETIME
					  )
	--
	SET @PositiveEvlDiffAcc = (SELECT [GUID] FROM AC000 WHERE CODE LIKE @PositiveEvlDiff)
	SET @NegativeEvlDiffAcc = (SELECT [GUID] FROM AC000 WHERE CODE LIKE @NegativeEvlDiff)
	
	--1. Fill #Accounts table
	EXEC prcConnections_Add2 @Admin
	SELECT Ac.[GUID]
	INTO #Accounts
	FROM AC000 AS Ac
	INNER JOIN fnGetAccountsList(@AccGUID, 1) AS fnAc ON Ac.[GUID] = fnAc.[GUID]
	WHERE Ac.NSons = 0
	
	--2. Fill #DetailEvl Table
	CREATE TABLE #DetailEvl
	(
		 Number					INT IDENTITY(0,1),
		 [Guid]					UNIQUEIDENTIFIER,
		 AccGUID				UNIQUEIDENTIFIER,
		 CurrencyGUID	     	UNIQUEIDENTIFIER,
		 Balance				FLOAT DEFAULT 0,		--«·—’Ìœ »⁄„·… «·Õ”«» 
		 EqBalance				FLOAT DEFAULT 0, 		--«·ﬁÿ⁄ «·„ﬂ«›∆ »⁄„· Â 
		 EqDiffCurrBalance		FLOAT DEFAULT 0,		--ﬁÿ⁄ «·Õ”«» »€Ì— ⁄„· Â 
		 AccCurrencyVal			FLOAT DEFAULT 0,		--«· ⁄«œ· «·Ê”ÿÌ 
		 Evlval					FLOAT DEFAULT 0,		--«· ⁄«œ· «· ﬁÌÌ„ 
		 EvlEqBalance			FLOAT DEFAULT 0,		--ﬁÿ⁄ «· ﬁÌÌ„
		 Notes					NVARCHAR(255) DEFAULT ''
     )
	DECLARE DetailEvlCursor CURSOR FORWARD_ONLY FOR 
	SELECT [GUID] FROM #Accounts
	
	OPEN DetailEvlCursor
	FETCH NEXT FROM DetailEvlCursor INTO
	@AccGUID
	
	WHILE @@FETCH_STATUS = 0  
	BEGIN
		INSERT INTO #DetailEvl
		EXEC Prc_Periodic_TrnAccountsEvaluation @AccGUID, @Date, @bFromTransferBulletin
		
		FETCH NEXT FROM DetailEvlCursor INTO
		@AccGUID
	END
	CLOSE DetailEvlCursor
	DEALLOCATE DetailEvlCursor
	
	--3. Fill Master Evaluation (TrnAccountsEvl000)
	INSERT INTO TrnAccountsEvl000 (NUMBER, [GUID], BranchGuid, [Date], Note) VALUES
	(@EvlNumber, @MasterGUID, @Branch, @Date, 'Periodic Evaluation')
	
	--4. Fill Detail Evaluation (TrnAccountsEvlDetail000)
	INSERT INTO TrnAccountsEvlDetail000 
	SELECT [GUID], @MasterGUID, Number, AccGUID, CurrencyGUID, Balance, EqBalance, AccCurrencyVal, EqDiffCurrBalance, Notes, Evlval, EvlEqBalance
	FROM #DetailEvl
	
	--5. Generate Evl Entries
	CREATE TABLE #EntryRes
	(
		EntryGUID UNIQUEIDENTIFIER,
		EntryNum  INT
	)
	
	INSERT INTO #EntryRes
	EXEC prctrnAccEvlGenEntries @MasterGUID, @PositiveEvlDiffAcc, @NegativeEvlDiffAcc
####################################################
#END