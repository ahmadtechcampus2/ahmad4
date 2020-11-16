################################################################################
## 
CREATE PROCEDURE repCustBalArround
	@StartDate DATETIME,
	@EndDate DATETIME,
	@AccGUID UNIQUEIDENTIFIER,
	@CurGUID UNIQUEIDENTIFIER,
	@CurVal INT,
	@Contain AS NVARCHAR(200),
	@NotContain AS NVARCHAR(200),
	@CostGuid AS UNIQUEIDENTIFIER,
	@Branch AS UNIQUEIDENTIFIER = 0x0,
	@Type AS INT 
AS   
	DECLARE @AllAcc AS INT   
	DECLARE @DebitAcc AS INT   
	DECLARE @CreditAcc AS INT   

	CREATE TABLE #SecViol(Type INT, Cnt INT)  
	CREATE TABLE  #CustTable ( cuNumber UNIQUEIDENTIFIER, cuSec INT)   
	INSERT INTO #CustTable EXEC prcGetCustsList NULL, @AccGUID   
	DECLARE @strContain AS NVARCHAR( 1000)   
	DECLARE @strNotContain AS NVARCHAR( 1000)   
	SET @strNotContain = '%'+ @NotContain + '%'   
	SET @strContain = '%'+ @Contain + '%' 
	SET NOCOUNT ON 
	DECLARE @Cost_Tbl TABLE( GUID UNIQUEIDENTIFIER)  
	INSERT INTO @Cost_Tbl  SELECT GUID FROM dbo.fnGetCostsList( @CostGUID)   
	IF ISNULL( @CostGUID, 0x0) = 0x0    
		INSERT INTO @Cost_Tbl VALUES(0x0)   

	CREATE TABLE #Result(
		AccPtr UNIQUEIDENTIFIER,   
		Debit FLOAT,  
		Credit FLOAT,  
		AccSecurity INT,  
		CustSecurity INT)  
	CREATE TABLE #EndResult(  
		AccPtr UNIQUEIDENTIFIER,   
		Debit FLOAT,  
		Credit FLOAT,  
		Balance FLOAT)  


	DECLARE @BranchMask BIGINT 
	DECLARE @BranchGuid UNIQUEIDENTIFIER
	SET @BranchGuid = ( CASE WHEN ISNULL(@Branch, 0x0) = 0x0 THEN dbo.fnBranch_getDefaultGuid() ELSE @Branch END )
	SET @BranchMask = ( SELECT brNumber FROM vwbr WHERE brGuid = @BranchGuid )

	SET @AllAcc = 0   
	SET @DebitAcc = 1   
	SET @CreditAcc = 2   

	INSERT INTO #Result SELECT  
			ac.acGuid AS AccPtr,
			vwEx.FixedEnDebit AS Debit,
			vwEx.FixedEnCredit AS Credit,
			ac.acSecurity AS acSecurity,
			cu.cuSecurity AS cuSecurity
		FROM  
			fnExtended_en_Fixed( @CurGUID) AS vwEx  
			INNER JOIN vwAC AS ac ON vwEx.enAccount = ac.acGuid  
			INNER JOIN vwCu AS cu ON cu.cuAccount = ac.acGuid  
			INNER JOIN #CustTable AS Cust ON Cust.cuNumber = cu.cuGuid  
			INNER JOIN @Cost_Tbl AS Cost ON vwEx.enCostPoint = Cost.GUID 
		WHERE  
			( @Contain = '' or cu.cuNotes Like @strContain)   
			AND ( @NotContain = '' or cu.cuNotes NOT Like @strNotContain)   
			AND vwEx.enDate BETWEEN @StartDate AND @EndDate  
			AND vwEx.ceIsPosted = 1   
			AND ( (ac.acBranchMask = 0) OR (CAST( ac.acBranchMask AS BIGINT) &  CAST( @BranchMask AS BIGINT)) <>  0)
			AND ( vwEx.CeBranch = @BranchGuid)

	EXEC prcCheckSecurity @Check_AccBalanceSec = 1  

	INSERT INTO #EndResult
		SELECT
			Res.AccPtr,
			SUM( Res.Debit) AS Debit,  
			SUM( Res.Credit) AS Credit,  
			(CASE ac.acWarn  
				WHEN 2 THEN -( SUM( Res.Debit) - SUM( Res.Credit) )  
				ELSE  SUM( Res.Debit) - SUM( Res.Credit)  
				END)
		FROM  
			#Result As Res INNER JOIN vwAc AS ac  
			ON Res.AccPtr = ac.acGUID
		GROUP BY  
			Res.AccPtr,  
			ac.acWarn  

SELECT   
	ac.acGUID AS AccPtr, 
	ac.acCode AS AccCode,   
	ac.acName AS AccName,   
	ac.acLatinName AS AccLName,   
	cu.cuGUID AS CustPtr,   
	cu.cuNumber AS CustNum,   
	cu.cuCustomerName AS CustName ,   
	cu.cuLatinName AS CustLName ,   
	cu.cuNationality AS Nationality,   
	cu.cuAddress AS Address,   
	cu.cuPhone1 AS Phone1,   
	cu.cuPhone2 AS Phone2,   
	cu.cuFax AS Fax,   
	cu.cuTelex AS Telex,   
	cu.cuNotes AS Notes,   
	cu.cuDiscRatio AS DiscRatio,   
	cu.cuPrefix AS Prefix, 
	cu.cuSuffix AS Suffix, 
	cu.cuMobile AS Mobile, 
	cu.cuPager AS Pager, 
	cu.cuEmail AS Email, 
	cu.cuHomePage AS HomePage, 
	cu.cuCountry AS Country, 
	cu.cuCity AS City, 
	cu.cuArea AS Area, 
	cu.cuStreet AS Street, 
	cu.cuZipCode AS ZipCode, 
	cu.cuPOBox AS POBox, 
	cu.cuCertificate AS Certificate, 
	cu.cuJob AS Job, 
	cu.cuJobCategory AS JobCategory, 
	cu.cuUserFld1 AS UserFld1, 
	cu.cuUserFld2 AS UserFld2, 
	cu.cuUserFld3 AS UserFld3, 
	cu.cuUserFld4 AS UserFld4, 
	cu.cuDateOfBirth AS DateOfBirth, 
	cu.cuGender AS Gender, 
	cu.cuHobbies AS Hobbies, 
	cu.cuDefPrice AS DefPrice,  
	dbo.fnCurrency_fix( ac.acMaxDebit, ac.acCurrencyPtr, ac.acCurrencyVal, @CurGUID , @EndDate) AS AccMaxDebit, 
	ac.acWarn AS AccWarn,   
	ISNULL( Res.Balance,0) AS Balance
from   
	vwCu As cu INNER JOIN VWAC AS ac  
	ON cu.cuAccount = ac.acGuid   
	INNER JOIN #CustTable AS Cust  
	ON Cust.cuNumber = cu.cuGuid   
	INNER JOIN #EndResult AS Res   
	ON Res.AccPtr = ac.acGuid   
where   
	( @Contain = '' or cu.cuNotes Like @strContain)   
	AND( @NotContain = '' or cu.cuNotes NOT Like @strNotContain)   
	AND(   
		( @Type = @AllAcc )   
		OR ( @Type = @DebitAcc AND (Res.Debit - Res.Credit) > 0 )   
		OR ( @type = @CreditAcc AND (Res.Debit - Res.Credit) < 0 )   
	)	
SELECT * FROM #SecViol 

################################################################################
#END
