######################################################################################
CREATE PROCEDURE trnGetExchangeCurClasses
		@CurrencyGuid	[UNIQUEIDENTIFIER],  
		@ParentGUID	[UNIQUEIDENTIFIER],
		@Type		[INT] ,
		@ExTypeGUID   [UNIQUEIDENTIFIER] 
AS  
	SET NOCOUNT ON   

	CREATE TABLE [#Result](
				Number INT ,
				[GUID] [UNIQUEIDENTIFIER],   
				[ClASsGUID] [UNIQUEIDENTIFIER],   
				[ClASsName] [NVARCHAR]( 255) COLLATE ARABIC_CI_AI,  
				[ClASsVal] Float, 
				[Value] INT,
				PayValue INT, 
				[Balance] INT) 

	CREATE INDEX resultIdx ON #Result(ClASsGUID)			

	INSERT INTO [#Result]  
	SELECT Number, 0x0, [GUID], [ClASsName], [ClASsVal], 0, 0 ,0
	FROM [TrnCurrencyClASs000] 
	WHERE [CurrencyGUID] = @CurrencyGuid 
	


	UPDATE r SET Guid = ex.guid , value = ex.value , PayValue = ex.PayValue
	FROM  #Result AS r INNER JOIN TrnExchangeCurrClASs000 AS ex ON r.clASsguid = ex.clASsguid
	WHERE ex.parentguid =  @ParentGUID 

	CREATE TABLE #ClASsBalance ( ClASsGuid UNIQUEIDENTIFIER , balance FLOAT(53) )	
	CREATE INDEX ClASsBalanceIdx ON	#ClASsBalance(ClASsGUID)

	INSERT INTO #ClASsBalance 
	SELECT c.guid , Sum(Value)
	From TrnCurrencyClASs000 AS c INNER JOIN 
	     TrnExchangeCurrClASs000 AS cex ON cex.clASsguid = c.guid 
	     INNER JOIN TrnExchange000 AS ex ON ex.Guid = cex.Parentguid
	WHERE  ex.typeguid = @ExTypeGUID 
	GROUP BY c.guid 

	UPDATE #Result SET balance = c.balance 
	FROM #Result AS r INNER JOIN #ClASsBalance AS c ON r.clASsguid = c.clASsguid

	SELECT GUID,ClASsGUID,ClASsName,ClASsVal,Value,PayValue ,Balance
	FROM [#Result]
	ORDER By Number 
##########################################################################
CREATE  PROCEDURE trnGetMaxNumberCurClasses 
AS 
	SELECT MAX(Number) AS Max_Num FROM [TrnCurrencyClass000]

#########################################################################
CREATE PROCEDURE trnGetCloseCurClasses
		@ParentGUID	[UNIQUEIDENTIFIER]
AS  
	SET NOCOUNT ON   
	CREATE TABLE [#Result](
				Number INT ,
				[GUID] [UNIQUEIDENTIFIER],   
				[ClASsGUID] [UNIQUEIDENTIFIER],   
				[ClASsName] [NVARCHAR]( 255) COLLATE ARABIC_CI_AI,  
				[ClASsVal] Float, 
				[Value] INT)

	CREATE INDEX resultIdx ON #Result(ClASsGUID)			
	Declare @CurrencyGuid UNIQUEIDENTIFIER
	select @CurrencyGuid = CurrencyGuid From TrnCloseCashier000
	where Guid = @ParentGUID
	
	INSERT INTO [#Result]  
	SELECT Number, 0x0, [GUID], [ClASsName], [ClASsVal], 0
	FROM [TrnCurrencyClASs000] 
	WHERE [CurrencyGUID] = @CurrencyGuid 
	
	UPDATE r SET Guid = ex.guid, value = ex.value
	FROM  #Result AS r INNER JOIN TrnExchangeCurrClASs000 AS ex ON r.classguid = ex.classguid
	WHERE ex.parentguid =  @ParentGUID 


	SELECT GUID,ClASsGUID,ClASsName,ClASsVal,Value
	FROM [#Result]
	ORDER By Number 
 
######################################################################################
#END