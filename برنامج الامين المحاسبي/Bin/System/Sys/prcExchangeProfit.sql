#####################################################
CREATE PROCEDURE prcExchangeProfit
	@CurrencyGuid  UNIQUEIDENTIFIER , 
	@AccGuid UNIQUEIDENTIFIER = 0x00, 
	@StartDate DATETIME, 
	@EndDate DATETIME, 
	@SourceRepGuid UNIQUEIDENTIFIER, 
	@Strategy INT , 
	@CustomerType INT = 3 
AS 
	SET NOCOUNT ON	 
	SET QUOTED_IDENTIFIER ON	 
	DECLARE @IsArabicLang INT  
	Select @IsArabicLang = [dbo].fnConnections_GetLanguage() 
 		  
	DECLARE @Result Table(	Squence INT IDENTITY(1,1), 
				MoveType INT , 
				MoveDesc NVARCHAR(255) COLLATE ARABIC_CI_AI , 
				Amount FLOAT(53), 
				CurrencyVal FLOAT(53), 
				Balance FLOAT(53), 
				Average FLOAT(53), 
				Profit FLOAT(53), 
				EntryGuid UNIQUEIDENTIFIER , 
				AccName NVARCHAR(255) COLLATE ARABIC_CI_AI ,-- 
				AccountGuid UNIQUEIDENTIFIER, 
				EntryDate DATETIME, 
				ExNumber INT,	
				ExDate DATETIME, 
				ExGuid UNIQUEIDENTIFIER, 
				ContrAccName NVARCHAR(255) COLLATE ARABIC_CI_AI,-- 
				ContraAccGuid UNIQUEIDENTIFIER ,-- 
				EntryNumber FLOAT(53), 
				CurGuid UNIQUEIDENTIFIER, 
				CurName NVARCHAR(255) COLLATE ARABIC_CI_AI, 
				CustomerType INT  
        		) 
	 
  
	-- MoveType 0 Sell , 1 Purchase  
	/*INSERT INTO @Result(MoveType  , Amount ,MoveDesc , CurrencyVal ,Balance , 
			Average , Profit , EntryGuid, AccName ,AccountGuid 
			,EntryDate ,ExDate,ExGuid , ContrAccName , ContraAccGuid , EntryNumber , CurGuid , CurName , CustomerType) 
	*/
	SELECT CASE  en.Debit WHEN 0 THEN 0 ELSE 1 END as MoveType, 
		   CASE en.Debit WHEN 0 THEN en.Credit ELSE en.Debit END as Amount , 
		   CASE @IsArabicLang 
			WHEN 0 Then Abbrev + ': ' + Cast(Ex.Number as NVARCHAR(10))
			ELSE LatinAbbrev + ': ' +Cast(Ex.Number as NVARCHAR(10)) 
		    END as MoveDesc , 
			en.CurrencyVal, 
			0.0 as Balance, 
			0.0 as Average, 
			0.0 as Profit, 
			ce.guid as EntryGuid , 
			CASE @IsArabicLang WHEN 0 THEN ac.Name ELSE ac.LatinName END as AccName, 
			en.AccountGuid  as AccountGuid, 
			ce.Date as EntryDate,
			Ex.Number As ExNumber, 
			Ex.Date as ExDate, 
			Ex.Guid as ExGuid , 
			' ' as ContrAccName , 
			en.ContraAccGuid, 
			ce.Number as EntryNumber, 
			en.CurrencyGuid, 
			' ' as CurName, 
			CustomerType  
	into #temp
	FROM ce000 AS ce INNER JOIN en000 AS en ON en.parentguid = ce.guid 
		INNER JOIN TrnExchange000 as Ex on Ex.EntryGuid = Ce.Guid 
		INNER JOIN RepSrcs as ExType on ExType.IdType = Ex.typeGuid  
		INNER JOIN TrnExchangeTypes000 as T ON T.Guid = ExType.IdType 
		INNER JOIN Ac000 as ac on ac.guid = en.accountguid    
	WHERE 	en.Date BETWEEN @StartDate AND @EndDate   
			And (@CurrencyGuid = 0x00 OR en.CurrencyGuid = @CurrencyGuid ) 
			And (en.AccountGuid = @AccGuid OR @AccGuid = 0x00 ) 
			And ExType.IdTbl = @SourceRepGuid 
			And en.AccountGuid != T.RoundAccGuid -- temp Solution  
			And (@CustomerType = 3 OR CustomerType = @CustomerType ) 
  	--ORDER BY Ex.Date, en.Date , Ex.Number   

	INSERT INTO @Result(MoveType  , Amount ,MoveDesc , CurrencyVal ,Balance, 
		Average, Profit, EntryGuid, AccName ,AccountGuid, 
		EntryDate, ExNumber, ExDate,ExGuid , ContrAccName,
		ContraAccGuid, EntryNumber, CurGuid, CurName, CustomerType) 
	select * from #temp
	order by ExDate, EntryDate, ExNumber, MoveType	desc
		
	UPDATE r Set ContrAccName = CASE @IsArabicLang WHEN 0 THEN ac.Name ELSE ac.LatinName END  
	FROM @Result as r INNER JOIN Ac000 as Ac on r.ContraAccGuid = ac.Guid  
	 
	UPDATE r Set CurName = CASE @IsArabicLang WHEN 0 THEN my.Name ELSE my.LatinName END  
	FROM @Result as r INNER JOIN my000 as my on r.CurGuid = my.guid  
	DECLARE exchangeCursor CURSOR FORWARD_ONLY FOR  
	SELECT  squence ,MoveType  , Amount , CurrencyVal ,Balance , 
		Average , Profit , EntryGuid , AccountGuid 
	FROM  @Result 
	ORDER BY squence 
	 
	DECLARE @squence INT, @MoveType INT, @Amount FLOAT, @CurrencyVal FLOAT, 
			@Balance FLOAT, @Average FLOAT, @Profit FLOAT, 
			@EntryGuid UNIQUEIDENTIFIER, @AccountGuid UNIQUEIDENTIFIER 
	OPEN exchangeCursor 
	FETCH NEXT FROM exchangeCursor INTO 
			@squence , @MoveType , @Amount , @CurrencyVal , @Balance, @Average  
			, @Profit , @EntryGuid , @AccountGuid 
	DECLARE @TotalBalance FLOAT  
	SET @TotalBalance = 0 
	WHILE @@FETCH_STATUS = 0 
	BEGIN  
		IF @MoveType = 1 -- purchase  
			SET @TotalBalance = @TotalBalance +  (@Amount/ @CurrencyVal) 
		ELSE  
			SET @TotalBalance = @TotalBalance -  (@Amount/ @CurrencyVal) 
		 
		 
		SET @Balance = @TotalBalance 
		UPDATE @Result SET balance = @Balance WHERE squence = @squence			 
		FETCH NEXT FROM exchangeCursor INTO 
			@squence , @MoveType , @Amount , 
			@CurrencyVal , @Balance, @Average , 
			@Profit , @EntryGuid , @AccountGuid 
	END  
	CLOSE exchangeCursor 
	DEALLOCATE exchangeCursor 
	/******************************************* 
	Note : Continuos Average And FIFO are fully generated in c++  
	********************************************/ 
	IF	@Strategy = 1	-- Dialy Average 
	BEGIN 
	 
	-- back up EntryDate Column From #Result Table Into #DateBackUp Table  
	DECLARE @DateBackup TABLE(squence INT ,EntryDate DATETIME) 
	INSERT INTO @DateBackup 
	SELECT squence , EntryDate  
	FROM @Result 
		--  ›Ì Õ«· ﬂ«‰  √Ê· ⁄„·Ì… ÂÌ ⁄„·Ì… »Ì⁄ Ì „ Õ”«» «·Ê”ÿÌ Ê «·—’Ìœ «·”«»ﬁ ÊÌ⁄ »— √”«” ·√Ê· »Ì⁄  
		IF EXISTS (SELECT  * FROM @Result WHERE squence = 1 and MoveType = 0 )  
		BEGIN 
			DECLARE @PrevAverage FLOAT(53), @PrevBalance FLOAT(53) 
			SELECT @PrevAverage = ISNULL(SUM(CashAmount/CashCurrencyVal) / SUM(CashAmount),0) 
					, @PrevBalance = ISNULL(SUM(CashAmount/CashCurrencyVal),0) 
			FROM TrnExchange000  
			WHERE CashCurrency = @CurrencyGuid   
			And [Date] < @StartDate 
 		 
			IF @PrevAverage = 0 
				SELECT TOP 1 @PrevBalance = Balance  , @PrevAverage = Average 
				FROM @Result 
				WHERE movetype = 1  
				ORDER BY squence 
		END 
				 
		-- Õ”«» «·Ê”ÿÌ «·ÌÊ„Ì  
		UPDATE r SET Average = re.Average 
		FROM @Result AS r INNER JOIN 
		( 
			SELECT SUM(Amount * CurrencyVal) / SUM(Amount) AS Average, EntryDate 
			FROM @Result 
			WHERE MoveType = 1  
			GROUP BY EntryDate  
		)  AS re ON r.EntryDate = re.EntryDate 
		-- calculate profit from exchange operation  
		UPDATE @Result SET  profit =  (CurrencyVal-Average) * (Amount/CurrencyVal) 
		WHERE MoveType = 0 	 
		-- roll back previous chenges on #Result Table On DateTime Column  
		UPDATE r SET  r.EntryDate = d.EntryDate 
		FROM @Result AS r INNER JOIN @DateBackup AS d ON r.squence = d.squence 
		 
	END	 
	/******************************************* 
	********************************************/ 
	-- Balance Calculated in C++ 
	SELECT MoveType , Amount , MoveDesc , CurrencyVal , Balance , Average, Profit , EntryGuid ,AccountGuid, EntryDate , ExDate ,ExGuid ,AccName , ContrAccName , ContraAccGuid , EntryNumber ,CurGuid , CurName , CustomerType 
	FROM @Result 
	ORDER BY squence,EntryDate 
########################################
#END	