####################################################
CREATE FUNCTION fnGetLastCurVal(@CurGuid [UNIQUEIDENTIFIER])
RETURNS [FLOAT]
AS
  BEGIN
      DECLARE @CurrencyValue FLOAT

      SET @CurrencyValue = (SELECT TOP 1 CurrencyVal
                            FROM   mh000
                            WHERE  CurrencyGUID = @CurGuid
                            ORDER  BY [Date] DESC)

      IF @CurrencyValue IS NULL
        SET @CurrencyValue = (SELECT CurrencyVal
                              FROM   my000
                              WHERE  GUID = @CurGuid)

      RETURN ISNULL(@CurrencyValue, 1)
  END 
####################################################
CREATE PROCEDURE repOrdersCashFlow @StartDate            DATETIME,
                                   @EndDate              DATETIME,
                                   @AccountGUID          UNIQUEIDENTIFIER = 0x0,
                                   @CostGUID             UNIQUEIDENTIFIER = 0x0,
                                   @SourcesGuid          UNIQUEIDENTIFIER,
                                   @IsSelectedCurrency   BIT = 0,
                                   @SelectedCurrnecyGuid UNIQUEIDENTIFIER = 0x0,
                                   @IsEquCurrency        BIT = 0,
                                   @EquCurrencyGuid      UNIQUEIDENTIFIER = 0x0,
                                   @IsCurrencyList       BIT = 0
AS
    --Ì „ ›Ì Â–Â «·≈Ã—«∆Ì… Ã·» «·œ›⁄«  «·Œ«’… »«·ÿ·»Ì«  Ê«· Ì ·„ Ì „  ”œÌÂ« ≈·Ï «·Êﬁ  «·Õ«·Ì
    SET NOCOUNT ON;
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	-------------------------------------------------------------------          
    -------------------------   #CustTbl   ---------------------------        
    -- ÃœÊ· «·“»«∆‰ «· Ì  Õﬁﬁ «·‘—Êÿ     
    CREATE TABLE #CustTbl
      (
         CustGuid UNIQUEIDENTIFIER,
         Security INT
      )
    INSERT INTO #CustTbl
    EXEC prcGetCustsList
      0x0,
      @AccountGUID
    IF ( ISNULL(@AccountGUID, 0x0) = 0x00 )
      INSERT INTO #CustTbl
      VALUES     (0x0,
                  1)
    ------------------------------------------------------------------- 
    ------------------------------------------------------------------- 
    -- ÃœÊ· „—«ﬂ“ «·ﬂ·›…        
    CREATE TABLE #CostTbl
      (
         CostGuid UNIQUEIDENTIFIER
      )
    INSERT INTO #CostTbl
    SELECT Guid
    FROM   fnGetCostsList(@CostGUID)
    IF ISNULL(@CostGUID, 0x0) = 0x0
      INSERT INTO #CostTbl
      VALUES     (0x0)
    ------------------------------------------------------------------- 
    ------------------------------------------------------------------- 
    -- ÃœÊ· √‰Ê«⁄ «·ÿ·»Ì«  «· Ì  „ «Œ Ì«—Â« ›Ì ﬁ«∆„… √‰Ê«⁄ «·ÿ·»«         
    CREATE TABLE #OrderTypesTbl
      (
         Type        UNIQUEIDENTIFIER,
         Sec         INT,
         ReadPrice   INT,
         UnPostedSec INT
      )
    INSERT INTO #OrderTypesTbl
    EXEC prcGetBillsTypesList2
      @SourcesGuid
    ------------------------------------------------------------------- 
    SELECT ( Pay.[UpdatedValueWithCurrency] - (SELECT ISNULL(Sum(Val), 0)
                                               FROM   bp000
                                               WHERE  DebtGUID = PAY.PaymentGuid) ) AS [Total],
           PAY.[PaymentType],
           PAY.[PaymentNumber],
          (CASE @Lang WHEN 0 THEN bu.btName ELSE (CASE bu.btLatinName WHEN N'' THEN bu.btName ELSE bu.btLatinName END) END )+ ' '
           + Cast(bu.buNumber AS NVARCHAR(36))                                      AS [Name],
           PAY.[BillGuid],
           PAY.[PaymentDate]
    INTO   #Payments
    FROM   vworderpayments AS PAY
           LEFT JOIN vwBu AS BU
                  ON bu.buGUID = PAY.BillGuid
	WHERE dbo.fnGetPaymentState(bu.buGUID) != 2

    SELECT bu.buGUID                                      AS [OrderGUID],
           info.[PaymentDate]                             AS [Date],
           bu.[buType]                                    AS [TypeGuid],
           bu.[buNumber]                                  AS [Number],
           info.[Name]                                    AS [TypeName],
           bu.[buCust_Name]                               AS [CustomerName],
           bu.[buCurrencyPtr]                             AS [CurrencyGuid],
           my.[Code]                                      AS [CurrencyName],
           bu.[buCurrencyVal]                             AS [CurrencyValue],
           [Total] * bu.[btIsOutput] / bu.[buCurrencyVal] AS [Debit],
           [Total] * bu.[btIsInput] / bu.[buCurrencyVal]  AS [Credit],
           info.[PaymentType],
           info.[PaymentNumber],
           bu.[btIsOutput],
		   ( CASE @IsEquCurrency
               WHEN 1 THEN ( CASE
                               WHEN @EquCurrencyGuid =  bu.[buCurrencyPtr]  THEN 1
                               ELSE ( CASE @IsCurrencyList
                                        WHEN 1 THEN  bu.[buCurrencyVal]  / dbo.fnGetLastCurVal(@EquCurrencyGuid)
                                        ELSE [dbo].[fnGetCurVal]( bu.[buCurrencyPtr] , [Date]) / [dbo].[fnGetCurVal](@EquCurrencyGuid, [Date])
                                      END )
                             END )
               ELSE 0
             END ) AS [EquCurrencyValue]
    INTO   #Result
    FROM   vwBu AS Bu
           INNER JOIN #CustTbl AS Custs
                   ON bu.[buCustPtr] = Custs.CustGuid
           INNER JOIN #CostTbl AS Costs
                   ON bu.[buCostPtr] = Costs.CostGuid
           INNER JOIN #OrderTypesTbl AS OTypes
                   ON OTypes.[Type] = bu.[buType]
           INNER JOIN my000 AS my
                   ON my.[GUID] = bu.[buCurrencyPtr]
           INNER JOIN #Payments AS info
                   ON info.[BillGuid] = bu.[buGuid]
           INNER JOIN OrAddInfo000 AS orinfo
                   ON orinfo.[ParentGUID] = bu.[buGUID]
    WHERE  info.[PaymentDate] BETWEEN @StartDate AND @EndDate
           AND info.[Total] <> 0
           AND bu.[buCurrencyPtr] = CASE
                                      WHEN @IsSelectedCurrency <> 0 THEN @SelectedCurrnecyGuid
                                      ELSE bu.[buCurrencyPtr]
                                    END
           AND orinfo.Add1 <> 1
    ORDER  BY info.[PaymentDate]
	--------------------------------------------------------------------------------------------------
    SELECT *
    FROM   #Result
	--------------------------------------------------------------------------------------------------
    SELECT [CurrencyName],
           Sum(CASE [btIsOutput]
                 WHEN 0 THEN 0
                 ELSE Debit
               END) AS [DebitTotal],
           Sum(CASE [btIsOutput]
                 WHEN 0 THEN Credit
                 ELSE 0
               END) AS [CreditTotal],
		
		Sum(CASE [btIsOutput]
                 WHEN 0 THEN 0
                 ELSE Debit * EquCurrencyValue
               END) AS [EquDebitTotal],
           Sum(CASE [btIsOutput]
                 WHEN 0 THEN Credit * CurrencyValue
                 ELSE 0
               END) AS [EquCreditTotal]

    FROM   #Result
    GROUP  BY [CurrencyGuid],
              [CurrencyName]
#################################################### 
#END 