#################################################################
CREATE PROC repStockAccountsCheck
	@FilterMatGuid		UNIQUEIDENTIFIER, 
	@FilterGroupGuid	UNIQUEIDENTIFIER, 
	@AccountGuid		UNIQUEIDENTIFIER,
	@PriceType			INT,
	@EndDate			DATE,
	@IgnoredVarianceValue FLOAT,
	@FromDate	DATE = NULL
AS
	SET NOCOUNT ON;
	
	CREATE TABLE #SecViol (Type INT, Cnt INT);
	CREATE TABLE #MatTbl (MatGuid UNIQUEIDENTIFIER, mtSecurity INT); 
	INSERT INTO  #MatTbl EXEC prcGetMatsList @FilterMatGuid, @FilterGroupGuid; 
	
	CREATE TABLE #Accounts
	(
		acGUID		UNIQUEIDENTIFIER,
		ParentGuid	UNIQUEIDENTIFIER,
		acSecurity	INT ,  
		Level	INT , 
		Date datetime , 
		Value FLOAT
	);
	
	INSERT INTO #Accounts(acGUID, ParentGuid, acSecurity , Level)
	SELECT ac.Guid, ParentGuid, Security , Level
	FROM fnGetAccountsList(@AccountGuid,0) t  
	INNER JOIN ac000 ac ON ac.GUID = t.GUID 

	EXEC prcCheckSecurity @result = '#MatTbl';
	EXEC prcCheckSecurity @result = '#Accounts';

	CREATE TABLE #EndResult ([Date]  Date , Invent FLOAT , AccBalance FLOAT , Diff FLOAT)
	IF @PriceType = 0x2
		EXEC repStockAccountsCheckByCost	@EndDate,  @IgnoredVarianceValue, @FromDate;
	ELSE
		EXEC repStockAccountsCheckByOap		@EndDate,  @IgnoredVarianceValue;

	SELECT * FROM #EndResult
	SELECT * FROM #SecViol
#################################################################
#END