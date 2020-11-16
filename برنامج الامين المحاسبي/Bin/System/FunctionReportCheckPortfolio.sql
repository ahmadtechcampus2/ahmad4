###########################################################################################
CREATE FUNCTION RemainingReceivedOrPaidPartly(@chequeguid UNIQUEIDENTIFIER, @type INT, @date datetime)
RETURNS INT
AS 
BEGIN
	DECLARE  @value INT;
	IF  NOT EXISTS (SELECT * FROM chequehistory000  WHERE date >= @date and [EventNumber] = 3 and state =0 and chequeguid= @chequeguid) 
	BEGIN
		if NOT EXISTS (SELECT *	FROM vwer e
						INNER JOIN vwce  c ON e.erEntryGUID=c.ceGUID 
						INNER JOIN vwen en ON c.ceGUID = en.enParent
						
						WHERE  e.erParentGUID =@chequeguid and e.erparentType=@type)
		SET @value= (SELECT chval FROM vwch WHERE chguid=@chequeguid)
		ELSE
		SET @value=	(
			SELECT (SELECT chval FROM vwch WHERE chguid=@chequeguid) - (SELECT SUM([col].[Val]) FROM [ColCh000] [col] WHERE [ChGUID] = @chequeguid)
						
					)
	END
	ELSE
	BEGIN
		set @value = (SELECT chval FROM vwch WHERE chguid = @chequeguid) 				
	END
	RETURN @value; 
END
############################################################
CREATE PROCEDURE CheckPortfolioReport
@date datetime
,@flag int =1
AS
	SET NOCOUNT ON

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])  
	CREATE TABLE #temp
	(
		flag int,
		stateflag int,
		SumCheques float,
		Num int,
		Port int,
		PortValue float,
		result float 
	);

	DECLARE @PortValue FLOAT
    
	CREATE TABLE #Value(val float)
	INSERT INTO #value 
		EXEC AccountPortfolioCheque 1, @date,@Flag
		
	SET @PortValue =(SELECT val FROM #value)

	DECLARE @UserGUID [UNIQUEIDENTIFIER];

	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()   ;

	CREATE TABLE #result (
		   value float,
		   [Guid] UNIQUEIDENTIFIER,
		   [Security] int,
		   UserSecurity INT,
		   dir int,
		   state int,
		   EventNumber int
		   )

    INSERT INTO #result
	 SELECT * FROM GetCheques(@date,@UserGUID)
	 IF @flag = 1
		 EXEC [prcCheckSecurity] @UserGUID

	

	 INSERT INTO #temp
		 SELECT 1 AS flag, 1 AS stateflag,ISNULL(SumCheques,0) AS SumCheques ,Num,1 AS Port, ISNULL(@PortValue,0) AS PortValue,
		CASE WHEN ABS(ISNULL(SumCheques,0) - ISNULL(@PortValue,0)) <= [dbo].[fnGetZeroValuePrice]()
			THEN 0
			ELSE ISNULL(SumCheques,0) - ISNULL(@PortValue,0)
		END
		 
		 
		 FROM 
		 (SELECT sum(ISNULL(value,0)) AS SumCheques ,count(guid) AS Num FROM #result
			WHERE state in (0,2,4) AND Dir=1 AND value > 0
			OR EXISTS (SELECT * FROM chequehistory000 WHERE date > @date AND [EventNumber] in (24,22,9,8,15,20) AND chequeguid= guid) )AS res
	 
	 DELETE FROM #value

	 INSERT INTO #value 
		EXEC AccountPortfolioCheque  5,@date,@Flag

	SET @Portvalue = (SELECT val FROM #value)

	INSERT INTO #temp
		 SELECT 3 AS flag,5 AS stateflag,ISNULL(SumCheques,0) AS SumCheques,Num,5 AS Port, ISNULL(@PortValue,0) AS PortValue ,
		CASE WHEN ABS(ISNULL(SumCheques,0) - ISNULL(@PortValue,0)) <= [dbo].[fnGetZeroValuePrice]()
			THEN 0
			ELSE ISNULL(SumCheques,0) - ISNULL(@PortValue,0)
		END
		 FROM
		 (SELECT sum(ISNULL(value,0)) AS SumCheques ,count(guid) AS Num FROM #result
			WHERE state = 7 AND dir=1
				AND NOT EXISTS (SELECT * FROM chequehistory000 WHERE date > @date AND [EventNumber] in 
			(24,22,9,8,15,20) AND chequeguid= guid) )AS res
	
	delete FROM #value

	INSERT INTO #value 
		EXEC AccountPortfolioCheque  6,@date,@Flag

	SET @Portvalue = (SELECT val FROM #value)

	INSERT INTO #temp
	SELECT 4 AS flag,6 AS stateflag,-1*ISNULL(SumCheques,0) AS SumCheques,Num,6 AS Port, -1*ISNULL(@PortValue,0) AS PortValue ,
	CASE WHEN ABS((-1*ISNULL(SumCheques,0)) - (-1*ISNULL(@PortValue,0))) <= [dbo].[fnGetZeroValuePrice]()
		THEN 0
		ELSE (-1*ISNULL(SumCheques,0)) - (-1*ISNULL(@PortValue,0))
	END
	FROM
	(SELECT sum(ISNULL(value,0)) AS SumCheques ,count(guid) AS Num FROM #result
	 WHERE state = 4 AND dir =1
		AND NOT EXISTS (SELECT * FROM chequehistory000 WHERE date > @date AND [EventNumber] in 
		(24,22,9,8,15,20) AND chequeguid= guid) )AS res

	delete FROM #value
	
	INSERT INTO #value 
		EXEC AccountPortfolioCheque 4,@date,@Flag

	SET @Portvalue = (SELECT val FROM #value)

	INSERT INTO #temp
	 SELECT 6 AS flag,4 AS stateflag,-1*ISNULL(SumCheques,0) AS SumCheques,Num,4 AS Port, -1*ISNULL(@PortValue,0) AS PortValue ,
	CASE WHEN ABS((-1*ISNULL(SumCheques,0)) - (-1*ISNULL(@PortValue,0))) <= [dbo].[fnGetZeroValuePrice]()
		THEN 0
		ELSE (-1*ISNULL(SumCheques,0)) - (-1*ISNULL(@PortValue,0))
	END
	 FROM
	 (SELECT sum(ISNULL(value,0)) AS SumCheques ,count(guid) AS Num FROM #result
			WHERE state = 11 AND dir=1
			AND NOT EXISTS (SELECT * FROM chequehistory000 WHERE date > @date AND [EventNumber] in 
			(24,22,9,8,15,20) AND chequeguid= guid) )AS res

	delete FROM #value
	
	INSERT INTO #value 
		EXEC AccountPortfolioCheque  3,@date,@Flag

	SET @Portvalue = (SELECT val FROM #value)
	INSERT INTO #temp
	 SELECT 
		5 AS flag,
		3 AS stateflag,ISNULL(res.SumCheques,0)+abs(t.SumCheques) AS SumCheques
		 ,res.Num+t.Num as Num,3 AS Port, ISNULL(@PortValue,0) AS PortValue ,
		CASE WHEN ABS((ISNULL(res.SumCheques,0)+abs(t.SumCheques)) - ISNULL(@PortValue,0)) <= [dbo].[fnGetZeroValuePrice]()
			THEN 0
			ELSE (ISNULL(res.SumCheques,0)+abs(t.SumCheques)) - ISNULL(@PortValue,0)
		END
		 FROM #temp as t,
		 (SELECT sum(ISNULL(value,0)) AS SumCheques ,count(guid) AS Num FROM #result
			WHERE state = 10 AND dir=1 
			AND NOT EXISTS (SELECT * FROM chequehistory000 WHERE date > @date AND [EventNumber] in 
			(24,22,9,8,15,20) AND chequeguid= guid)  )AS res
		WHERE t.flag=6 AND t.stateflag=4

	INSERT INTO #temp
	 SELECT 10,0,ISNULL(SUM(SumCheques),0),SUM(CASE stateflag WHEN 6 THEN 0 WHEN  4 THEN  0 ELSE Num END ),0,sum(PortValue),sum(result) FROM #temp

	DELETE FROM #value
	INSERT INTO #value 
		EXEC AccountPortfolioCheque  2,@date,@Flag

	SET @Portvalue = (SELECT val FROM #value)

	INSERT INTO #temp
	 SELECT 
		2 AS flag,
		2 AS stateflag,
		ISNULL(SumCheques,0) AS SumCheques,
		Num,
		2 AS Port,
		ISNULL(@PortValue,0) AS PortValue,
		-- ISNULL(SumCheques,0) - ISNULL(@PortValue,0)
		CASE WHEN ABS(ISNULL(SumCheques,0) - ISNULL(@PortValue,0)) <= [dbo].[fnGetZeroValuePrice]()
			THEN 0
			ELSE ISNULL(SumCheques,0) - ISNULL(@PortValue,0)
		END
	 FROM 
	 (SELECT sum(ISNULL(value,0)) AS SumCheques ,count(guid) AS Num FROM #result
		WHERE state in (0,2) AND Dir=2
	 ) as res

	INSERT INTO #temp
	SELECT 11 AS flag,
			2 AS stateflag,
			ISNULL(SumCheques,0) AS SumCheques,
			Num,
			2 AS Port,
			ISNULL(@PortValue,0) AS PortValue,
			-- ISNULL(SumCheques,0) - ISNULL(@PortValue,0)
			CASE WHEN ABS(ISNULL(SumCheques,0) - ISNULL(@PortValue,0)) <= [dbo].[fnGetZeroValuePrice]()
				THEN 0
				ELSE ISNULL(SumCheques,0) - ISNULL(@PortValue,0)
			END
	 FROM 
	 (SELECT sum(ISNULL(value,0)) AS SumCheques ,count(guid) AS Num FROM #result
		WHERE state in (0,2) AND Dir=2
	 ) as res
	
	
	 SELECT * FROM #temp

	 SELECT SUM(result) AS res FROM #temp
	 WHERE  flag=10 or flag=11
###################################################################################
CREATE FUNCTION GetCheques
(@date datetime,@UserGUID [UNIQUEIDENTIFIER])
RETURNS TABLE
AS
RETURN
(select CASE state when 2 then (SELECT dbo.RemainingReceivedOrPaidPartly(chequeguid,12,@date) ) else chval end AS chval,chequeguid,sec,usersec,chDir,state,[EventNumber] from (SELECT
			ch.[ChequeGUID]
			,ch.[Date]
			,CASE eventnumber  when 2 then 2 else ch.state end AS state
			,ch.[EventNumber]
			,h.chval
			, [h].[chSecurity] as sec
			,chDir
		,dbo.[fnGetUserNoteSec_Browse](@UserGUID, nt.ntGuid) as userSec
		,RANK() OVER (PARTITION BY ch.chequeguid ORDER BY ch.number DESC) AS Rank 
		FROM chequehistory000 ch 
		inner join vwch h ON h.chGUID =ch.ChequeGUID
		inner join vwnt  nt ON nt.ntguid = h.chtype
		
		WHERE   nt.ntbAutoentry =1 AND ch.date <= @date and nt.bTransfer = 1)AS r where Rank=1);
#########################################################################################
CREATE PROCEDURE AccountPortfolioCheque 
@Type int,@date datetime,@flag INT =1
as
	SET NOCOUNT ON
	declare @UserGUID [UNIQUEIDENTIFIER];
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()   ;
	CREATE TABLE [#SecViol2]( [Type] [INT], [Cnt] [INT])  
	create Table #result2 (
       [CeGuid] UNIQUEIDENTIFIER,
       [CeSecurity] int,
	   CeDebit float,
	   CeCredit float
      )
	IF( @type = 1) 
	BEGIN
		insert into #result2 
		SELECT ceGUID,ceSecurity,enDebit,en.enCredit FROM vReceiveAcc  r 
		INNER JOIN vwen en ON r.GUID =  en.enAccount
		inner join vwce c ON c.ceguid = en.enParent
		WHERE c.ceDate < = @date
	END
	ELSE IF (@type = 2 )
	BEGIN
		insert into #result2 
		SELECT ceGUID,ceSecurity,enDebit,en.enCredit FROM vPayAcc  r 
		INNER JOIN vwen en ON r.GUID =  en.enAccount
		inner join vwce c ON c.ceguid = en.enParent
		WHERE c.ceDate < = @date
	END
	ELSE IF (@type = 3)
	BEGIN
		insert into #result2 
		SELECT ceGUID,ceSecurity,enDebit,en.enCredit FROM vUnderDiscountingAcc  r 
		INNER JOIN vwen en ON r.GUID =  en.enAccount
		inner join vwce c ON c.ceguid = en.enParent
		WHERE c.ceDate < = @date
	END
	ELSE IF(@type = 4)
	BEGIN
		insert into #result2 
		SELECT ceGUID,ceSecurity,enDebit,en.enCredit FROM vDiscountingAcc  r 
		INNER JOIN vwen en ON r.GUID =  en.enAccount
		inner join vwce c ON c.ceguid = en.enParent
		WHERE c.ceDate < = @date
	END
	ELSE IF(@type = 5)
	BEGIN
		insert into #result2 
		SELECT ceGUID,ceSecurity,enDebit,en.enCredit FROM vCollectiONAcc  r 
		INNER JOIN vwen en ON r.GUID =  en.enAccount
		inner join vwce c ON c.ceguid = en.enParent
		WHERE c.ceDate < = @date
	END
	ELSE IF(@type = 6)
	BEGIN
		insert into #result2 
		SELECT ceGUID,ceSecurity,enDebit,en.enCredit FROM vEndorsementAcc  r 
		INNER JOIN vwen en ON r.GUID =  en.enAccount
		inner join vwce c ON c.ceguid = en.enParent
		WHERE c.ceDate < = @date
	END
	IF @Flag= 1
		EXEC [prcCheckSecurity] @UserGUID = @UserGUID, @result = '#Result2', @secViol = '#secViol2'
	declare @value float
	set @value=(select Abs(Sum(CeDebit) - Sum(CeCredit)) from #result2)
	select @value
##############################################################################
#END
