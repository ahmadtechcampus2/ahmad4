###############################################################################
CREATE PROC repCustomersList
	@AccGuid			UNIQUEIDENTIFIER=0x0,
	@CostGuid			UNIQUEIDENTIFIER=0x0,
	@CondGuid			UNIQUEIDENTIFIER=0x0,
	@CurGuid			UNIQUEIDENTIFIER=0x0,
	@CurVal				INT=1,
	@ShowCustCost		BIT=1,
	@CustGuid			UNIQUEIDENTIFIER=0x0
AS
	SET NOCOUNT ON;
	EXEC prcEntry_Repost
	DECLARE @cu TABLE(Guid UNIQUEIDENTIFIER, Security INT);
	INSERT INTO @cu EXEC prcGetCustsList @CustGuid, @AccGuid, @CondGuid;
	CREATE TABLE #SecViol (Type INT, Cnt INT);
	CREATE TABLE #Result
	(
		acGuid		UNIQUEIDENTIFIER,
		cuGuid		UNIQUEIDENTIFIER,
		cuDebit		FLOAT,
		cuCredit	FLOAT,
		acSecurity	INT,
		cuSecurity	INT
	);
	
	INSERT INTO #Result (acGuid, cuGuid, acSecurity, cuSecurity)
	SELECT A.GUID, C.GUID, A.Security, C.Security
	  FROM @cu U JOIN cu000 C ON C.GUID = U.Guid JOIN ac000 A ON A.GUID = C.AccountGUID
	 WHERE @CostGuid = 0x OR C.CostGUID = @CostGuid;

   UPDATE R SET cuDebit = sumDebit, cuCredit = sumCredit
     FROM #Result R 
		  INNER JOIN (SELECT CustomerGUID, AccountGUID, SUM(en.Debit) AS sumDebit, SUM(en.Credit) AS sumCredit 
						FROM en000 en INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID
					   WHERE ce.IsPosted = 1
					   GROUP BY CustomerGUID, AccountGUID) C ON C.CustomerGUID = R.cuGuid AND C.AccountGUID = R.acGuid

	EXEC prcCheckSecurity;
	DECLARE @Sql NVARCHAR(MAX) = 'SELECT C.GUID CustPtr, C.CustomerName CuName',
			@Lang INT = dbo.fnConnections_GetLanguage();
			
	SET @Sql += ', A.Guid AS AccPtr';
	--IF @ShowAccName = 1 SET @Sql += ', CASE @Lang WHEN 0 THEN A.Name ELSE (CASE A.LatinName WHEN '''' THEN A.Name ELSE A.LatinName END) END AS AccountName';
	IF @lang=0
	 SET @Sql += ', (R.cuDebit - R.cuCredit)/A.CurrencyVal AS AccountBalance,a.CurrencyGUID,m.Name mName ';
	ELSE 
	 SET @Sql += ', (R.cuDebit - R.cuCredit)/A.CurrencyVal AS AccountBalance,a.CurrencyGUID,m.LatinName mName ';
	SET @Sql += ', C.DefPrice AS CustomerPrice';
	IF @ShowCustCost = 1 SET @Sql += ', CASE @Lang WHEN 0 THEN T.Name ELSE (CASE T.LatinName WHEN '''' THEN T.Name ELSE T.LatinName END) END AS CostCenter';
	
	SET @Sql += ' FROM #Result R JOIN cu000 C ON R.cuGuid = C.GUID JOIN vwExtended_AC A ON A.GUID = C.AccountGUID INNER JOIN my000 m on m.GUID = A.CurrencyGUID';
	IF @ShowCustCost = 1 SET @Sql += ' Left JOIN co000 T ON T.GUID = C.CostGUID';	
	IF @CurGuid <> 0x SET @Sql += ' WHERE A.CurrencyGUID = ''' + CAST(@CurGuid AS NVARCHAR(90)) + '''';
	
	SET @Sql += ' ORDER BY ' + 
		'C.CustomerName'
	
	EXEC sp_executesql @sql, N'@Lang AS INT', @Lang = @Lang; 	
	SELECT * FROM #SecViol
#################################################################
#END