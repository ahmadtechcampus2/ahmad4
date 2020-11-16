################################################################################
create PROCEDURE prcAddAllocationEntry
	@AllocationGuid UNIQUEIDENTIFIER,
	@CeGuid UNIQUEIDENTIFIER,
	@Account UNIQUEIDENTIFIER,
	@CounterAccount UNIQUEIDENTIFIER,
	@Customer UNIQUEIDENTIFIER,
	@CounterCustomer UNIQUEIDENTIFIER,
	@MonthPortion FLOAT,
	@dateParam DATETIME,
	@BranchGuidParam UNIQUEIDENTIFIER ,
	@CurrencyVal FLOAT,
	@CurrencyGuid UNIQUEIDENTIFIER,
	@EnAcountNote NVARCHAR(250),
	@EnCounterAcountNote NVARCHAR(250),
	@WesternUsed			INT,
	@CostCreditGuid	UNIQUEIDENTIFIER,
	@CostDebitGuid	UNIQUEIDENTIFIER,
	@TempStr NVARCHAR(50)
AS


	SET NOCOUNT ON
	
	DECLARE 
		@number INT,
		@endingDate DATE 
	SET @number = 0

	IF EXISTS(SELECT * FROM en000 WHERE ParentGuid = @CeGuid)
	BEGIN
		SET @number = (SELECT ISNULL(MAX(Number),0)+1 FROM en000 WHERE ParentGuid = @CeGuid)
	END

	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() 
	DECLARE @OP NVARCHAR(30) = 'DBINFO\MONTHS' 
	IF @WesternUsed = 0
		SET @OP = @OP +'\'
	ELSE
		SET @OP = @OP +'W\'
	DECLARE @MonthName NVARCHAR(50) = [dbo].[fnStrings_get](@OP+ CAST(DATEPART (mm,@dateParam) AS NVARCHAR(2)), @language) 
	SET @MonthName = @TempStr + @MonthName
	
	INSERT INTO en000
	 ([Number]
           ,[Date]
           ,[Debit]
           ,[Credit]
           ,[Notes]
           ,[CurrencyVal]
           ,[Class]
           ,[Num1]
           ,[Num2]
           ,[Vendor]
           ,[SalesMan]
           ,[GUID]
           ,[ParentGUID]
           ,[AccountGUID]
		   ,[CustomerGUID]
           ,[CurrencyGUID]
           ,[CostGUID]
           ,[ContraAccGUID]
           ,[AddedValue]
           ,[ParentVATGuid]
           ,[BiGUID])
	VALUES(
		@number,
		@dateParam,
		0,
		@MonthPortion * @CurrencyVal ,
		@EnAcountNote + @MonthName,
		@CurrencyVal,
		'',
		0,
		0,
		0,
		1,
		NEWID(),
		@CeGuid,
		@Account,
		@Customer,
		@CurrencyGuid,
		--0x0,
		CASE @Account WHEN 0x0 THEN 0x0 ELSE @CostDebitGuid END, 	 
		@CounterAccount,
		0,
		0x0,
		0x0)
		
	SET @number = @number + 1
	
	INSERT INTO en000
	 ([Number]
           ,[Date]
           ,[Debit]
           ,[Credit]
           ,[Notes]
           ,[CurrencyVal]
           ,[Class]
           ,[Num1]
           ,[Num2]
           ,[Vendor]
           ,[SalesMan]
           ,[GUID]
           ,[ParentGUID]
           ,[AccountGUID]
		   ,[CustomerGUID]
           ,[CurrencyGUID]
           ,[CostGUID]
           ,[ContraAccGUID]
           ,[AddedValue]
           ,[ParentVATGuid]
           ,[BiGUID])
	VALUES(
		@number,
		@dateParam,
		@MonthPortion * @CurrencyVal,
		0,
		--'',
		@EnCounterAcountNote + @MonthName,
		@CurrencyVal,
		'',
		0,
		0,
		0,
		1,
		NEWID(),
		@CeGuid,
		@CounterAccount,
		@CounterCustomer,
		@CurrencyGuid,
		--0x0,-- costGuid 
		CASE @Account WHEN 0x0 THEN 0x0 ELSE @CostCreditGuid END, 	 
		@Account,
		0,
		0x0,
		0x0)

DECLARE
			@startDate	DATETIME,
			@endDate	DATETIME
		SET @startDate = CAST(MONTH(@dateParam) AS NVARCHAR) + '/1/' + CAST(YEAR(@dateParam) AS NVARCHAR)
		SET @endDate = DATEADD(DAY, -1, DATEADD(MONTH, 1, @startDate))


	INSERT INTO	AllocationEntries000
	VALUES(
		NEWID(),
		@CeGuid,
		@AllocationGuid,
		@Account,
		@CounterAccount,
		@dateParam,
		@BranchGuidParam,
		@MonthPortion,
		0
		)
################################################################################
CREATE PROCEDURE prcCalcVals
	@AllotmentGuid			UNIQUEIDENTIFIER,
	@AllocationGuid			UNIQUEIDENTIFIER,
	@yearStartParam			DATETIME,
	@yearEndParam			DATETIME,
	@monthDate				DATETIME,
	@generateType			INT
	
AS
	SET NOCOUNT ON
	
	DECLARE @FincanceYearEndParam DATETIME, @StartDate DATETIME , @fromMonth DATETIME,@toMonth  DATETIME 
	DECLARE @PaymentsCount INT 
	
	SELECT @FincanceYearEndParam = (SELECT TOP 1 CAST([Value] AS DATE) FROM op000 WHERE [Name] ='AmnCfg_EPDate')
	
	 if (@generateType = 1 )
	 BEGIN
	 SET	@fromMonth  = (SELECT CASE WHEN @yearStartParam > MIN(FromMonth) THEN @yearStartParam ELSE MIN(FromMonth) END
								FROM Allocations000 
							WHERE AllotmentGuid = @AllotmentGuid
							AND guid = @AllocationGuid 
						 )
						
	 SET	@toMonth	= (SELECT  CASE WHEN @yearEndParam	< MAX(toMonth)	 THEN @FincanceYearEndParam	  ELSE MAX(toMonth) END
							FROM  Allocations000 
							WHERE  AllotmentGuid = @AllotmentGuid
								AND guid = @AllocationGuid 
						)

	UPDATE Allocations000 
		SET DistPayNum = ( SELECT COUNT(DISTINCT BondGuid) 
						FROM AllocationEntries000 ae 
						WHERE
							ae.AllocationGuid = @AllocationGuid
							AND ae.Date BETWEEN @fromMonth AND @toMonth
							AND EXISTS(SELECT * FROM ce000 WHERE GUID = ae.BondGuid)
						)
					WHERE Allocations000.AllotmentGuid = @AllotmentGuid
						AND Allocations000.Guid = @AllocationGuid

	UPDATE Allocations000  
		SET CirclePayNum =  ISNULL((
								SELECT DATEDIFF(month, DATEADD(m, 1, @FincanceYearEndParam),al.ToMonth)
									FROM
										Allocations000  al
									WHERE
										 al.GUID = @AllocationGuid
										AND al.ToMonth > @FincanceYearEndParam
									) + 1, 0)
					WHERE
						 Allocations000.AllotmentGuid = @AllotmentGuid
					 AND
						 Allocations000.Guid = @AllocationGuid
						 				
    if ( @toMonth <=   @FincanceYearEndParam)
		BEGIN
		 UPDATE Allocations000
		 SET RestPayNum = ( SELECT distinct(abs(IsNull(al.PaymentsCount,0) - IsNull(al.DistPayNum,0) - IsNull(al.CirclePayNum,0)))
							FROM
								Allocations000  al
							
							WHERE
								al.GUID = @AllocationGuid
							
							)
							WHERE Allocations000.AllotmentGuid = @AllotmentGuid
								AND Allocations000.Guid = @AllocationGuid
		END 
	ELSE 
		BEGIN 
		  
		    UPDATE Allocations000
			SET RestPayNum = ( SELECT distinct( abs(DATEDIFF(month,al.FromMonth ,@FincanceYearEndParam)  - IsNull(al.DistPayNum,0)))
						FROM
							Allocations000  al
						
						WHERE
							al.GUID = @AllocationGuid
							
						)
						WHERE Allocations000.AllotmentGuid = @AllotmentGuid
							AND Allocations000.Guid = @AllocationGuid 
		END 
	END 
	ELSE 
	BEGIN
		SET @fromMonth = CAST(MONTH(@monthDate) AS NVARCHAR) + '/1/' + CAST(YEAR(@monthDate) AS NVARCHAR)
		SET @toMonth = DATEADD(DAY, -1, DATEADD(MONTH, 1, @fromMonth))
		UPDATE Allocations000 
		SET DistPayNum = ( SELECT COUNT(DISTINCT BondGuid) 
						FROM AllocationEntries000 ae 
							INNER JOIN Allocations000 alloc ON alloc.GUID = ae.AllocationGuid 
						WHERE
							ae.AllocationGuid = @AllocationGuid
							AND ae.Date BETWEEN alloc.FromMonth AND alloc.ToMonth
							AND EXISTS(SELECT * FROM ce000 WHERE GUID = ae.BondGuid)
						)
						WHERE Allocations000.AllotmentGuid = @AllotmentGuid
							AND Allocations000.Guid = @AllocationGuid
			
	UPDATE Allocations000  
		SET CirclePayNum =  ISNULL((SELECT DATEDIFF(month, DATEADD(m, 1, @FincanceYearEndParam), al.ToMonth)
							FROM
								Allocations000  al
							WHERE
									al.GUID = @AllocationGuid
								AND al.ToMonth > @FincanceYearEndParam
							), 0)
						WHERE
							 Allocations000.AllotmentGuid = @AllotmentGuid
						 AND
							 Allocations000.Guid = @AllocationGuid
						 				
    if ( @toMonth <=   @FincanceYearEndParam)
		BEGIN
		 UPDATE Allocations000
			SET RestPayNum = ( SELECT distinct(abs(IsNull(al.PaymentsCount,0) - IsNull(al.DistPayNum,0) - IsNull(al.CirclePayNum,0)))
							FROM
								Allocations000  al
							
							WHERE
								al.GUID = @AllocationGuid
							
							)
							WHERE Allocations000.AllotmentGuid = @AllotmentGuid
								AND Allocations000.Guid = @AllocationGuid
			END
	ELSE 
		BEGIN 
		UPDATE Allocations000
			SET RestPayNum = ( SELECT distinct( abs(DATEDIFF(month,al.FromMonth ,@FincanceYearEndParam)  - IsNull(al.DistPayNum,0)))
						FROM
							Allocations000  al
						
						WHERE
							al.GUID = @AllocationGuid
							
						)
						WHERE Allocations000.AllotmentGuid = @AllotmentGuid
							AND Allocations000.Guid = @AllocationGuid 
		END 
	END
################################################################################
CREATE PROCEDURE prcRecalcVals

AS

	SET NOCOUNT ON
	
	DECLARE @FincanceYearEndParam DATETIME, @toMonth DATETIME ,@FincanceYearStartParam DATETIME
	
	SELECT @FincanceYearEndParam   = convert(datetime, Value, 105) from op000 where Name='AmnCfg_EPDate'
	SELECT @FincanceYearStartParam = convert(datetime, Value, 105) from op000 where Name='AmnCfg_SPDate'

	DECLARE
			@alocCursor			CURSOR,
			@allotmentGuid		UNIQUEIDENTIFIER,
			@alocGuid			UNIQUEIDENTIFIER,
			@alocDistPayement	FLOAT,
			@alocRestPayement	FLOAT,
			@alocCirclePayement FLOAT,
			@paymentCount		FLOAT
			
			DECLARE alotmentCursor CURSOR FAST_FORWARD
			FOR	SELECT  Guid
				   FROM Allotment000 
  	
		OPEN alotmentCursor
		FETCH NEXT FROM alotmentCursor INTO @allotmentGuid
		

	WHILE @@FETCH_STATUS = 0
	BEGIN   

		SET @alocCursor = CURSOR FAST_FORWARD FOR
			SELECT
				aloc.GUID,
				aloc.DistPayNum,
				aloc.RestPayNum,
				aloc.CirclePayNum,
				aloc.PaymentsCount
			FROM
				Allocations000 aloc
				INNER JOIN Allotment000 alm ON alm.GUID = aloc.AllotmentGUID
			WHERE
				alm.GUID = @allotmentGuid
		 OPEN @alocCursor
		 FETCH NEXT FROM @alocCursor INTO @alocGuid,@alocDistPayement, @alocRestPayement, @alocCirclePayement, @paymentCount
		  
			
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			SET @toMonth = (SELECT ToMonth FROM Allocations000 WHERE Guid = @alocGuid AND AllotmentGuid = @AllotmentGuid)			
			if (@ToMonth <=  @FincanceYearEndParam )
			BEGIN 
				 UPDATE Allocations000
				 SET RestPayNum = ( SELECT distinct( IsNull(al.RestPayNum,0) + ISNULL(al.CirclePayNum, 0) )
						FROM  Allocations000  al
							WHERE
									 al.GUID =  @alocGuid
								)
							WHERE Allocations000.AllotmentGuid = @allotmentGuid
									AND Allocations000.Guid = @alocGuid
						 
						
					UPDATE Allocations000
					SET CirclePayNum = 0
									WHERE Allocations000.AllotmentGuid = @allotmentGuid
										AND Allocations000.Guid = @alocGuid
			END

			ELSE if (@ToMonth >  @FincanceYearEndParam ) 
			BEGIN 
					DECLARE @oldCirclePayment INT , @CirclePayNum INT 
					SET @oldCirclePayment  = (SELECT CirclePayNum FROm Allocations000 WHERE Guid = @alocGuid AND AllotmentGuid = @AllotmentGuid)
					UPDATE Allocations000  
					SET @CirclePayNum =  (SELECT DATEDIFF(month, DATEADD(m, 1, @FincanceYearEndParam),al.ToMonth)
											FROM
												Allocations000  al
											WHERE
												al.GUID = @alocGuid
												AND al.ToMonth > @FincanceYearEndParam
											)
											WHERE Allocations000.AllotmentGuid = @allotmentGuid
												AND Allocations000.Guid = @alocGuid
					SET @CirclePayNum = @CirclePayNum + 1

					UPDATE Allocations000
					SET RestPayNum = ( SELECT abs(DATEDIFF(month,@FincanceYearEndParam , al.FromMonth )) - IsNull(al.DistPayNum,0) +1 
											 FROM Allocations000 al 
												WHERE
													al.GUID =  @alocGuid
											)
										WHERE Allocations000.AllotmentGuid = @allotmentGuid
										AND Allocations000.Guid = @alocGuid
							
				UPDATE Allocations000  
				SET CirclePayNum =  @CirclePayNum
								 WHERE
									 Allocations000.AllotmentGuid = @AllotmentGuid
								 AND
									 Allocations000.Guid = @alocGuid
     
			
			END 
	
			FETCH NEXT FROM @alocCursor INTO @alocGuid,@alocDistPayement, @alocRestPayement, @alocCirclePayement, @paymentCount
	    END 
	    
  		CLOSE @alocCursor
		DEALLOCATE @alocCursor
	

	FETCH NEXT FROM alotmentCursor 
	    INTO @allotmentGuid
	END
   
		CLOSE alotmentCursor
		DEALLOCATE alotmentCursor
################################################################################
CREATE PROCEDURE prcRecalcValsTansfer
	@StartDate DATETIME  =  '1-1-1980'
	,@DataBase NVARCHAR (MAX)
AS

	SET NOCOUNT ON
	
	DECLARE @FincanceYearEndParam DATETIME
	SET @FincanceYearEndParam = (DATEADD(month,11, @StartDate ) )
	
	DECLARE
			@alocCursor			CURSOR,
			@allotmentGuid		UNIQUEIDENTIFIER,
			@alocGuid			UNIQUEIDENTIFIER,
			@alocDistPayement	FLOAT,
			@alocRestPayement	FLOAT,
			@alocCirclePayement FLOAT,
			@paymentCount		FLOAT
			
			DECLARE alotmentCursor CURSOR FAST_FORWARD
			FOR	SELECT  Guid
				   FROM Allotment000 
  	
		OPEN alotmentCursor
		FETCH NEXT FROM alotmentCursor INTO @allotmentGuid
		

	WHILE @@FETCH_STATUS = 0
	BEGIN   

		SET @alocCursor = CURSOR FAST_FORWARD FOR
			SELECT
				aloc.GUID,
				aloc.DistPayNum,
				aloc.RestPayNum,
				aloc.CirclePayNum,
				aloc.PaymentsCount
			FROM
				Allocations000 aloc
				INNER JOIN Allotment000 alm ON alm.GUID = aloc.AllotmentGUID
			WHERE
				alm.GUID = @allotmentGuid
		 OPEN @alocCursor
		 FETCH NEXT FROM @alocCursor INTO @alocGuid,@alocDistPayement, @alocRestPayement, @alocCirclePayement, @paymentCount
		  
			
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			BEGIN 
			
			 DECLARE @sql NVARCHAR (MAX) 
			 SET @sql = 'UPDATE '+@DataBase+'..Allocations000
				SET RestPayNum = ( SELECT  (DATEDIFF(month,'''+Cast(@StartDate as NVARCHAR(MAX))+
				''' , (CASE WHEN al.ToMonth < '''+CAST (@FincanceYearEndParam as NVARCHAR(MAX) ) +''' THEN al.ToMonth 
				ELSE '''+CAST (@FincanceYearEndParam as NVARCHAR(MAX) )+''' END)) + 1 )
									 FROM Allocations000 al 
										WHERE
											al.GUID =  '''+CAST (@alocGuid as NVARCHAR(MAX) )+
									''')
								WHERE Allocations000.AllotmentGuid = '''+CAST (@allotmentGuid as NVARCHAR(MAX) )+
								''' AND Allocations000.Guid =''' +CAST (@alocGuid as NVARCHAR(MAX) )+''''

						exec(@sql)
			 SET @sql = 'UPDATE '+@DataBase+'..Allocations000
						SET DistPayNum  = 0 
				 		WHERE Allocations000.AllotmentGuid = '''+CAST (@allotmentGuid as NVARCHAR(MAX) )+
								'''AND Allocations000.Guid ='''+ CAST (@alocGuid as NVARCHAR(MAX) )+''''
						exec(@sql)

		SET @sql = 'UPDATE '+@DataBase+'..Allocations000
				SET CirclePayNum = (SELECT   case  when (DATEDIFF(month,'''+CAST (@FincanceYearEndParam as NVARCHAR(MAX) )+''', al.ToMonth )) <= 0 then  0 
				else (DATEDIFF(month,'''+CAST(@FincanceYearEndParam as NVARCHAR(MAX) )+''', al.ToMonth )) end 
									 FROM Allocations000 al 
										WHERE 
											al.GUID = '''+CAST (@alocGuid as NVARCHAR(MAX) )+
									''')
								WHERE Allocations000.AllotmentGuid ='''+CAST(@allotmentGuid as NVARCHAR(MAX) )+
								'''AND Allocations000.Guid ='''+CAST( @alocGuid as NVARCHAR(MAX) )+''''
								
		exec(@sql)
	END 
			FETCH NEXT FROM @alocCursor INTO @alocGuid,@alocDistPayement, @alocRestPayement, @alocCirclePayement, @paymentCount
	    END 
	    
  		CLOSE @alocCursor
		DEALLOCATE @alocCursor
	

	FETCH NEXT FROM alotmentCursor 
	    INTO @allotmentGuid
	END
   
		CLOSE alotmentCursor
		DEALLOCATE alotmentCursor
################################################################################
#END
