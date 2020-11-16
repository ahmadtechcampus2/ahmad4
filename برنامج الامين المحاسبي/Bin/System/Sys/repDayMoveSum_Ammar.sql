
-- exec repDayMoveSummary '1/1/2003','3/15/2003','','',0x0,'35AD554C-CC20-4612-914B-7151CDCD1AC7',0x0, 1,1

CREATE   PROCEDURE dbo.repDayMoveSum_Ammar
	@StartDate 		DATETIME, 
	@EndDate 		DATETIME, 
	@NotesContain 		NVARCHAR(256),-- NULL or Contain Text 
	@NotesNotContain	NVARCHAR(256), -- NULL or Not Contain 
	@StoreGuid 		UNIQUEIDENTIFIER, --0 all stores so don't check store or list of stores 
	@CurrencyGuid 		UNIQUEIDENTIFIER, 
	--@CurrencyVal 		FLOAT, 
	@SrcTypesguid		UNIQUEIDENTIFIER,
	@TimeLimit		INT,  -- 1 for dayly, 2 for weekly, 3 for monthly
	@ViewType		INT  -- 0 for Minimal, 1 for expanded

--- select * from repSrcs
AS
SET NOCOUNT ON
	
-- Creating temporary tables 
CREATE TABLE #SecViol( Type INT, Cnt INTEGER)
CREATE TABLE #StoreTbl(	StoreGuid UNIQUEIDENTIFIER, Security INT)
CREATE TABLE #BillsTypesTbl( TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER)
	
--Filling temporary tables
INSERT INTO #StoreTbl		EXEC prcGetStoresList 		@StoreGuid
INSERT INTO #BillsTypesTbl	EXEC prcGetBillsTypesList 	@SrcTypesguid--, @UserGuid

DECLARE	@strNotContain	NVARCHAR(250)
DECLARE	@strContain	NVARCHAR(250)

SET @strNotContain = '%'+ @NotesNotContain + '%'  
SET @strContain = '%'+ @NotesContain + '%'

CREATE TABLE #Result (
	Period			INT,
	PeriodStart		DATETIME,
	PeriodEnd		DATETIME,
	TypeGuid 		UNIQUEIDENTIFIER,
	TypeName		NVARCHAR(250) COLLATE Arabic_CI_AI,
	BaseType		INT,	
	BillTotal		FLOAT,

	Security		INT,
	UserSecurity 		INT
)

INSERT INTO #Result 
SELECT
	p.Period,
	--CONVERT (NVARCHAR(50), p.StartDate, 1 )+ ' - ' + CONVERT (NVARCHAR(50), p.EndDate, 1),
	--p.StartDate + ' - ' + p.EndDate,
	p.StartDate,
	p.EndDate,
	rv.buType,
	rv.btName,
	rv.btBillType,
	CASE WHEN UserReadPriceSecurity >= BuSecurity THEN rv.FixedBuTotal ELSE 0 END AS FixedBuTotal,
	rv.buSecurity,
	bt.UserSecurity
	
FROM
	dbo.fnExtended_bi_Fixed(@CurrencyGUID) AS rv
	RIGHT JOIN dbo.fnGetDatePeriod( @TimeLimit, @StartDate, @EndDate) AS p 
	ON rv.buDate BETWEEN p.StartDate AND p.EndDate
	INNER JOIN #BillsTypesTbl AS bt ON rv.buType = bt.TypeGuid

WHERE
	(rv.[Budate] BETWEEN @StartDate AND @EndDate)
	AND( (@StoreGUID = 0x0) OR (rv.BiStorePtr IN( SELECT StoreGUID FROM #StoreTbl)))
	AND ( @NotesContain = '' or rv.buNotes Like @strContain) 
	AND ( @NotesNotContain = '' or rv.buNotes NOT Like @strNotContain)
	
----check sec
EXEC prcCheckSecurity

CREATE TABLE #EndResult
	(
		Period			INT,
		Type			NVARCHAR(100),
		TotalSum		FLOAT
	)

IF @ViewType = 0 
BEGIN
	INSERT INTO #EndResult 
		SELECT
			Period,
			CAST( BaseType AS NVARCHAR(100)),
			sum(BillTotal)
		FROM
			#Result
		
		GROUP BY
			CAST( BaseType AS NVARCHAR(100)),
			Period
END

IF @ViewType = 1
/*
BEGIN
	ALTER TABLE #EndResult 
		DROP COLUMN BaseTypeSum

	ALTER TABLE #EndResult
		ADD			TypeGuid UNIQUEIDENTIFIER,
					TypeName NVARCHAR(250),
					TypeGuidSum FLOAT
END
select * from #EndResult
*/
BEGIN
	INSERT INTO #EndResult 
		SELECT
			Period,
			CAST( TypeGuid AS NVARCHAR(100)),
			sum(BillTotal)
		FROM
			#Result

		GROUP BY
			CAST( TypeGuid AS NVARCHAR(100)),
			Period
END

IF @ViewType = 0
BEGIN
	SELECT r1.Period, r1.PeriodStart, r1.PeriodEnd, r1.BaseType, r2.TotalSum
	FROM 
		#Result AS r1 INNER JOIN #EndResult AS r2	
	ON
		r1.Period = r2.Period AND r1.BaseType = CAST( r2.Type AS INT)
	group by 
		 r1.Period, r1.PeriodStart, r1.PeriodEnd, r1.BaseType, r2.TotalSum		
	order by r1.Period
END
IF
@ViewType = 1
BEGIN
	SELECT r1.Period, r1.PeriodStart, r1.PeriodEnd, r1.TypeGuid, r1.TypeName, r1.BaseType, r2.TotalSum
	FROM 
		#Result AS r1 INNER JOIN #EndResult AS r2	
		ON r1.Period = r2.Period AND r1.TypeGuid = CAST( r2.Type AS UNIQUEIDENTIFIER)
	group by 
		r1.Period, r1.PeriodStart, r1.PeriodEnd, r1.TypeGuid, r1.TypeName, r1.BaseType, r2.TotalSum
	order by r1.Period

END

--SELECT * FROM #EndResult ORDER BY Period
SELECT * FROM #SecViol




GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

