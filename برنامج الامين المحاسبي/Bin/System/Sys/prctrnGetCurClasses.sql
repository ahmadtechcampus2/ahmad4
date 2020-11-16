#######################################
CREATE  PROCEDURE prctrnGetCurClasses 
	@CurrencyGuid UNIQUEIDENTIFIER,
	@TypeGuid UNIQUEIDENTIFIER = 0x0
AS   
	SET NOCOUNT ON    
	CREATE TABLE [#Result]( 
				Number INT , 
				--[GUID] [UNIQUEIDENTIFIER],    
				[ClASsGUID] [UNIQUEIDENTIFIER],    
				[ClASsName] [NVARCHAR]( 255) COLLATE ARABIC_CI_AI,   
				[ClASsVal] Float,  
				DebitNum INT,
				CreditNum INT)
				--[Value] INT) 
	CREATE INDEX resultIdx ON #Result(ClASsGUID)

	INSERT INTO [#Result]   
	SELECT Number, Guid, [ClASsName], [ClASsVal], 0,0 
	FROM [TrnCurrencyClASs000]  
	WHERE [CurrencyGUID] = @CurrencyGuid  

	DECLARE @NUM TABLE (ClassGuid UNIQUEIDENTIFIER, type INT, Num BIGINT)

	insert into @NUM
	SELECT r.ClassGuid, clas.type ,Sum(clas.value) as Num
		FROM  #Result AS r 
		INNER JOIN TrnExchangeCurrClASs000 AS clas ON r.classguid = clas.classguid
		INNER JOIN TrnExchange000 as ex on ex.Guid = clas.parentGuid 
		where clas.CurGuid = @CurrencyGuid AND (@TypeGuid = 0x0 OR ex.TypeGuid = @TypeGuid)
		group by r.ClassGuid, clas.type

	insert into @NUM
	SELECT r.ClassGuid, clas.type ,Sum(clas.value) as Num
		FROM  #Result AS r 
		INNER JOIN TrnExchangeCurrClASs000 AS clas ON r.classguid = clas.classguid
		INNER JOIN TrnCloseCashier000 as cl on cl.Guid = clas.parentGuid 
		where clas.CurGuid = @CurrencyGuid AND (@TypeGuid = 0x0 OR Cl.ExchangeTypeGuid = @TypeGuid)
		group by r.ClassGuid, clas.type

	UPDATE r 
	SET DebitNum = Debit.Num
	FROM  #Result AS r 
	inner join @NUM as Debit on Debit.ClASsGUID = r.ClASsGUID AND Debit.type = 0

	UPDATE r 
	set CreditNum = Credit.Num
	FROM  #Result AS r 
	inner join @NUM as Credit on Credit.ClASsGUID = r.ClASsGUID AND Credit.type = 1


	SELECT Number,ClASsGUID,ClASsName,ClASsVal, DebitNum, CreditNum
	FROM [#Result] 
	ORDER By Number 
##############################################
#END