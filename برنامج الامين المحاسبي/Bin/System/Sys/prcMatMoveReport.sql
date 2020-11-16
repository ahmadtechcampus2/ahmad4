#########################################################################
CREATE PROCEDURE prcMatMoveReport
-- PARAMETERS
            @Mat          UNIQUEIDENTIFIER = 0x0,   -- «·„«œ…
            @Grp          UNIQUEIDENTIFIER = 0x0,   -- «·„Ã„Ê⁄…
            @Cust         UNIQUEIDENTIFIER = 0x0,   -- «·⁄„Ì·       
            @Src          UNIQUEIDENTIFIER = 0x0,   -- „’«œ— «· ﬁ—Ì—
            @StartDate    DATETIME = '1/1/1980',    -- „‰  «—ÌŒ
            @EndDate      DATETIME = '12/30/2980',  -- ≈·Ï  «—ÌŒ
            @OrderField   INT = -1

AS

            SET NOCOUNT ON

            DECLARE @SMat BIT                                         -- ›—“ Õ”» «·„«œ…
            DECLARE @SDate BIT                                        -- ›—“ Õ”» «· «—ÌŒ
            DECLARE @SCust BIT                                        -- ›—“ Õ”» «·“»Ê‰
            SET @SMat = 0
            SET @SDate = 0
            SET @SCust = 0
            IF(@OrderField = 1) 
                        SET @SMat = 1
            IF(@OrderField = 2) 
                        SET @SDate = 1
            IF(@OrderField = 3) 
                        SET @SCust = 1

            
            ---------------------    #BtTbl   ------------------------
            -- ÃœÊ· »„’«œ— «· ﬁ—Ì—
            CREATE TABLE #BtTbl (
                        Type        UNIQUEIDENTIFIER,
                        Sec         INT,              
                        ReadPrice   INT,              
                        UnPostedSec INT)              

            INSERT INTO #BtTbl EXEC prcGetBillsTypesList2 @Src
            -------------------------------------------------------------------         

            -------------------------   #CustTbl   ---------------------------
            -- ÃœÊ· «·“»«∆‰
            CREATE TABLE #CustTbl (
            CustGuid UNIQUEIDENTIFIER, 
                        Security INT)

            INSERT INTO #CustTbl EXEC prcGetCustsList @Cust, NULL, NULL
            IF ISNULL(@Cust, 0x0) = 0x0
                        INSERT INTO #CustTbl VALUES(0x0, 1)
            -------------------------------------------------------------------

            -------------------------------------------------------------------
            --  ÃœÊ· «·„Ê«œ
            CREATE TABLE #MatTbl (
            MatGuid  UNIQUEIDENTIFIER, 
                        Security INT)           

            INSERT INTO #MatTbl EXEC prcGetMatsList  @Mat, @Grp, -1, NULL              
            -------------------------------------------------------------------
            SELECT 
                        bi.buType                                                AS BtGuid,
                        bi.btName                                               AS BtName,
                        bi.buGuid                                                 AS BuGuid,      
                        bi.buNumber                                            AS BuNumber,
                        bi.buFormatedNumber                  AS BuName,
                        bi.biMatPtr                                               AS MatGuid,
                        bi.mtName                                              AS MatName,
                        bi.mtGroup                                              AS GroupGuid,
                        gr.Name                                                              AS GroupName,
                        bi.buCustPtr                                 AS CustGuid,
                        bi.buCust_Name                           AS CustName,
                        bi.buDate                                                AS BuDate,
                        bi.biQty                                       AS Qty,
                        bi.mtUnity                                               AS Unity,
                        bi.biUnitPrice            AS UnitPrice,
                        (bi.biUnitPrice*bi.biQty) AS Total
            INTO ##Tmp
            FROM
                                   vwExtended_bi AS  bi
                        INNER JOIN #BtTbl        AS  bt ON bt.Type     = bi.buType
                        INNER JOIN #MatTbl       AS  mt ON mt.MatGuid  = bi.biMatPtr
                        INNER JOIN #CustTbl      AS  cu ON cu.CustGuid = bi.buCustPtr
                        INNER JOIN gr000         AS  gr ON gr.Guid     = bi.mtGroup                      
            WHERE
                        bi.buDate BETWEEN @StartDate AND @EndDate

            DECLARE @SelectStr AS NVARCHAR(1000)
            SET @SelectStr = ' SELECT MatName, GroupName,CustName, BuDate, Qty,Unity , UnitPrice, Total, BuName FROM ##Tmp '
            
            DECLARE @OrderByStr AS NVARCHAR(10)
            SET @OrderByStr = ' ORDER BY '

            DECLARE @OrderBySet AS BIT
            SET @OrderBySet = 0

            IF (@SMat = 1)
            BEGIN
                        SET @SelectStr = @SelectStr + @OrderByStr + ' MatName '
                        SET @OrderBySet = 1
            END
            
            IF (@SDate = 1)
            BEGIN
                        IF (@OrderBySet = 1)
                                    SET @SelectStr = @SelectStr + ', BuDate'
                        ELSE
                        BEGIN
                                    SET @SelectStr = @SelectStr + @OrderByStr + ' BuDate '
                                    SET @OrderBySet = 1
                        END
            END

            IF (@SCust = 1)
            BEGIN
                        IF (@OrderBySet = 1)
                                    SET @SelectStr = @SelectStr + ', CustName '
                        ELSE
                        BEGIN
                                    SET @SelectStr = @SelectStr + @OrderByStr + ' CustName '
                                    SET @OrderBySet = 1
                        END
            END

            EXEC (@SelectStr)
            DROP TABLE ##Tmp
#########################################################################
#END