###################################
CREATE PROCEDURE prcGetPatientBal
	@CostPtr 	AS UNIQUEIDENTIFIER,	--—ﬁ„ „—ﬂ“ «·ﬂ·›…
	@StartDate 	AS DATETIME,			-- «—ÌŒ  «·œŒÊ·
	@EndDate 	AS DATETIME,			-- «—ÌŒ «·Œ—ÊÃ
	@CurGUID 	AS UNIQUEIDENTIFIER,	-- «·⁄„·…
	@CurVal 	AS FLOAT				-- «· ⁄«œ·
AS
SET NOCOUNT ON 
	DECLARE @UserGUID UNIQUEIDENTIFIER, @UserEnSec INT
	SET @UserGUID = dbo.fnGetCurrentUserGUID()
	SET @UserEnSec = dbo.fnGetUserEntrySec_Browse(@UserGUID, DEFAULT)
	CREATE TABLE #SecViol( Type INT, Cnt INT)
	CREATE TABLE #CostTbl( Number UNIQUEIDENTIFIER, Security INT)

	INSERT INTO #CostTbl EXEC prcGetCostsList @CostPtr
	INSERT INTO #Result
	( 
		RecType,
		costSecurity,
		AccSecurity, 
		AccGuid,
		ceGuid,
		ceNumber, 
		Date, 	
		Debit, 
		Credit, 
		Notes, 	
		Security, 
		UserSecurity
	)
	SELECT    
		0, -- RecType
		ISNULL( co.coSecurity, 0),  
		ac.acSecurity,  
		--Ce.ceType,    
		ce.enAccount,
		Ce.ceGuid,
		ce.ceNumber,
		Ce.enDate,
		Ce.FixedEnDebit,
		Ce.FixedEnCredit,
		Ce.enNotes,
		Ce.ceSecurity,
		@UserEnSec  
	FROM    
		dbo.fnExtended_En_Fixed( @CurGUID) As Ce   
		INNER JOIN vwAc AS Ac ON ce.enAccount = Ac.acGUID  
		LEFT JOIN vwCo AS Co On ce.enCostPoint = Co.coGUID 
	WHERE
		( @CostPtr = 0x0 OR  EXISTS( SELECT Number FROM #CostTbl WHERE enCostPoint  = Number))AND
		enDate BETWEEN @StartDate AND @EndDate
	ORDER BY
			enDate,co.coCode,ac.acCode  
	
	select * from #Result order by ceguid
	INSERT INTO #Result2
	( 
		RecType,
		costSecurity,
		AccSecurity, 
		AccGuid,
		ceGuid,
		ceNumber, 
		Date, 	
		Debit, 
		Credit, 
		Notes, 	
		Security, 
		UserSecurity
	)
	SELECT
		1, -- RecType
		ISNULL( co.coSecurity, 0),  
		ac.acSecurity,  
		ce.enAccount,
		Ce.ceGuid,
		ce.ceNumber,
		Ce.enDate,
		Ce.FixedEnDebit,
		Ce.FixedEnCredit,
		Ce.enNotes,
		Ce.ceSecurity,
		@UserEnSec
	FROM
		dbo.fnExtended_En_Fixed( @CurGUID) As Ce
		INNER JOIN vwAc AS Ac ON ce.enAccount = Ac.acGUID
		LEFT JOIN vwCo AS Co On ce.enCostPoint = Co.coGUID 
	WHERE
		( @CostPtr = 0x0 OR  EXISTS( SELECT Number FROM #CostTbl WHERE enCostPoint  = Number))AND  
		enDate BETWEEN @StartDate AND @EndDate
		AND ceGuid IN( SELECT Distinct ceGuid FRom #Result)
	ORDER BY
			enDate,co.coCode,ac.acCode  	

	select * from #Result2 order by ceguid
	EXEC prcCheckSecurity @UserGuid  
	EXEC prcCheckSecurity @UserGuid , 0, 0, '#result2' 
	
		SELECT
			ISNULL( SUM(Debit), 0) AS Debit,
			ISNULL( SUM(Credit) , 0) AS Credit
		FROM #Result

	SELECT *, 1 AS flag FROM #SecViol

/*	CREATE TABLE  #Result
	(
		RecType			INT,
		Id 				INT IDENTITY(1,1),
		CostSecurity	INT,
		AccSecurity		INT,
		ceGuid 			UNIQUEIDENTIFIER,
		ceNumber 		INT,
		Date			DATETIME,
		Debit			FLOAT,
		Credit			FLOAT,
		Notes			VARCHAR(255) COLLATE ARABIC_CI_AI,
		Security		INT,
		UserSecurity	INT
	)
	CREATE TABLE  #Result2
	(   
		RecType			INT,
		Id 				INT IDENTITY(1,1),
		CostSecurity	INT,
		AccSecurity		INT,

		ceGuid 			UNIQUEIDENTIFIER,
		ceNumber 		INT,
		Date			DATETIME,
		Debit			FLOAT,
		Credit			FLOAT,
		Notes			VARCHAR(255) COLLATE ARABIC_CI_AI,
		Security		INT,
		UserSecurity	INT
	)

EXEC prcGetPatientBal
'5DB9E725-F4FC-4171-8993-AD616E763A5E',			--@CostPtr 	AS UNIQUEIDENTIFIER,--—ﬁ„ „—ﬂ“ «·ﬂ·›…
'1/27/2005',		--@StartDate 	AS DATETIME,-- «—ÌŒ  «·œŒÊ·
'1/27/2005',		--@EndDate 	AS DATETIME,-- «—ÌŒ «·Œ—ÊÃ
'95EC83B3-3EF4-4DB8-A547-E8EC58F4C3AB',			--@CurGUID 	AS UNIQUEIDENTIFIER,-- «·⁄„·…
1				--@CurVal 	AS FLOAT-- «· ⁄«œ·
*/
############################################
#END