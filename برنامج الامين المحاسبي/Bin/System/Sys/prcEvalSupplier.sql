####################################################################################################
CREATE PROCEDURE prcEvalSupplier @Supplier  UNIQUEIDENTIFIER,-- 1 «·„Ê—œ
                                 @POType    UNIQUEIDENTIFIER = 0x0,-- 2 ‰Ê⁄ ÿ·» «·‘—«¡
                                 @PONumber  INT = 0,-- 3 —ﬁ„ ÿ·» «·‘—«¡
                                 @StartDate DATETIME = '1/1/1980',-- 4 „‰  «—ÌŒ
                                 @EndDate   DATETIME = '12/30/1980',-- 5 ≈·Ï  «—ÌŒ
                                 @LastEvals INT = 0 -- 6 ¬Œ— (⁄œœ) „‰ «· ﬁÌÌ„«     
AS
    SET NOCOUNT ON

	 IF [dbo].[fnObjectExists]('TmpResult') = 1
      DROP TABLE TmpResult

	CREATE TABLE TmpResult
    (
        guid UNIQUEIDENTIFIER
    )
    INSERT INTO TmpResult
    SELECT 
		Guid
    FROM 
		evs000 AS E
		JOIN vwBu AS BU ON E.OrderGuid = Bu.buGUID
    WHERE  
		BU.buCustPtr = @Supplier
		AND (Date BETWEEN @StartDate AND @EndDate)
        AND 
		( 
			POTypeGuid = (CASE @POType
							WHEN 0x THEN POTypeGuid
                            ELSE @POType
                          END ) 
		)
        AND 
		( 
			Bu.buNumber = 
				(CASE @PONumber
					WHEN 0 THEN Bu.buNumber
                    ELSE @PONumber
                 END
				 ) 
		)
        
    ORDER BY 
		Number
		
    DECLARE @top AS NVARCHAR(10)
    SET @top = CASE @LastEvals
                 WHEN 0 THEN ''
                 ELSE ' TOP ' + Cast(@LastEvals AS NVARCHAR(10))
               END
    DECLARE @q AS NVARCHAR(255)
    SET @q = ' SELECT ' + @top
             + ' e.Number, e.Guid, BU.buCustPtr, e.SupplierName, e.POTypeGuid, e.POTypeName, BU.buDate, Bu.buNumber, e.Date, e.Remarks, e.OrderGuid '
             + ' FROM evs000 e INNER JOIN TmpResult t ON e.Guid = t.Guid JOIN vwBu AS BU ON E.OrderGuid = Bu.buGUID'
    CREATE TABLE #evals
      (
         Number       INT,
         GUID         UNIQUEIDENTIFIER,
         SupplierGuid UNIQUEIDENTIFIER,
         SupplierName NVARCHAR(250),
         POTypeGuid   UNIQUEIDENTIFIER,
         POTypeName   NVARCHAR(250),
		 PODate		  DATETIME,
         PONumber     INT,
         Date         DATETIME,
         Remarks      NVARCHAR(1000),
		 OrderGuid    UNIQUEIDENTIFIER
      )
    INSERT INTO #evals
    EXEC(@q)

	 IF [dbo].[fnObjectExists]('TmpResult') = 1
    DROP TABLE TmpResult

	SELECT *
    FROM   evc000

    SELECT *
    FROM   #evals
################################################################
CREATE PROCEDURE prcEvalMatReport @Supplier   AS UNIQUEIDENTIFIER = 0x0,
                                  @Mat        AS UNIQUEIDENTIFIER = 0x0,
                                  @Dept       AS NVARCHAR(255) = '',
                                  @SampleType AS NVARCHAR(255) = '',
                                  @TestType   AS NVARCHAR(255) = '',
                                  @Cmp1       AS NVARCHAR(5) = '=',
                                  @Cmp2       AS NVARCHAR(5) = '',
                                  @CmpVal1    AS NVARCHAR(255) = '',
                                  @CmpVal2    AS NVARCHAR(255) = '',
                                  @StartDate  AS DATETIME = '01/01/2009',
                                  @EndDate    AS DATETIME = '06/20/2009'
AS
    SET NOCOUNT ON

    -- ·Õ–› «·⁄„·Ì«  «· Ì  „ Õ–› ›Ê« Ì—Â« ÊÂÌ »„À«»… ⁄„·Ì… ’Ì«‰… ·√”»«»  ﬁ‰Ì… /////////////  
    DELETE FROM ori000
    WHERE  buGuid != 0x00
           AND buGuid NOT IN(SELECT Guid
                             FROM   bu000)

    --///////////////////////////////////////////////////////////////////////////////   
    IF [dbo].[fnObjectExists]('TmpResult') = 1
      DROP TABLE TmpResult

    CREATE TABLE TmpResult
      (
         Number         int,
         GUID           uniqueidentifier,
         SupplierGuid   uniqueidentifier,
         SupplierName   NVARCHAR(255),
         MatGuid        uniqueidentifier,
         MatName        NVARCHAR(255),
         SampleType     NVARCHAR(255),
         OrderDept      NVARCHAR(255),
         DileverDate    datetime,
         EvalSampleDate datetime,
         EvmGuid        uniqueidentifier,
         SampleNumber   NVARCHAR(255),
         TestType       NVARCHAR(255),
         TestResult     NVARCHAR(255),
         AcceptedState  NVARCHAR(255),
         Remarks        NVARCHAR(255)
      )

    INSERT INTO TmpResult
    SELECT evm.Number,
           evm.GUID,
           evm.SupplierGuid,
           evm.SupplierName,
           evm.MatGuid,
           evm.MatName,
           evm.SampleType,
           evm.OrderDept,
           evm.DileverDate,
           evm.EvalSampleDate,
           evmi.EvmGuid,
           evmi.SampleNumber,
           evmi.TestType,
           evmi.TestResult,
           evmi.AcceptedState,
           evmi.Remarks
    FROM   evm000 AS evm
           INNER JOIN evmi000 AS evmi
                   ON evm.Guid = evmi.EvmGuid
    WHERE  ( SupplierGuid = CASE ISNULL(@Supplier, 0x0)
                              WHEN 0x0 THEN SupplierGuid
                              ELSE @Supplier
                            END )
           AND ( MatGuid = CASE ISNULL(@Mat, 0x0)
                             WHEN 0x0 THEN MatGuid
                             ELSE @Mat
                           END )
           AND ( OrderDept = CASE @Dept
                               WHEN '' THEN OrderDept
                               ELSE @Dept
                             END )
           AND ( SampleType = CASE @SampleType
                                WHEN '' THEN SampleType
                                ELSE @SampleType
                              END )
           AND ( TestType = CASE @TestType
                              WHEN '' THEN TestType
                              ELSE @TestType
                            END )
           AND ( EvalSampleDate BETWEEN @StartDate AND @EndDate )

    DECLARE @SELECT AS NVARCHAR(1000)

    SET @SELECT = 'SELECT *, ABS(DATEDIFF(d, DileverDate, EvalSampleDate)) AS Days FROM TmpResult WHERE 1=1 '

    IF ( @Cmp1 <> '' )
      SET @SELECT = @SELECT + 'AND TestResult ' + @Cmp1 + ' '''
                    + @CmpVal1 + ''''

    IF ( @Cmp2 <> '' )
      SET @SELECT = @SELECT + 'AND TestResult ' + @Cmp2 + ' '''
                    + @CmpVal2 + ''''

    PRINT ( @SELECT )

    EXEC(@SELECT)

    IF [dbo].[fnObjectExists]('TmpResult') = 1
      DROP TABLE TmpResult 
################################################################
#END	
