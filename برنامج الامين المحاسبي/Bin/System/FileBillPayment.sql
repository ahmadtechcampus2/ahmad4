######################################################################################
CREATE FUNCTION fnGetBillTotalForUpgrade(
	@buGuid [uniqueidentifier],
	@CurGUID [uniqueidentifier] = 0x0)
RETURNS FLOAT 
AS
BEGIN

	/*
		DONT UPDATE this function it's only used for update from ameen 8 to 9
	*/
	DECLARE 
		@total [float],
		@AccGuid [uniqueidentifier]
	IF ISNULL(@CurGUID, 0x0) = 0x0
		SET @CurGUID = (SELECT TOP 1 GUID FROM MY000 WHERE CurrencyVal = 1 ORDER BY Number)

	SET @AccGuid = (SELECT CustAccGUID FROM bu000 WHERE Guid = @buGuid)
	SET @total = (SELECT ABS(SUM(en.FixedEnCredit) - SUM(en.FixedEnDebit)) 
				FROM 
					er000 er 
					INNER JOIN [dbo].[fnExtended_En_Fixed](@CurGUID) [en]  ON en.ceGUID = er.EntryGUID AND en.enAccount = @AccGuid
				WHERE 
					 er.ParentGUID = @buGuid
					 AND en.enGUID NOT IN (
											SELECT 
												en.GUID 
											FROM 
												en000 en 
												INNER JOIN ce000 ce ON ce.Guid = en.ParentGUID
												INNER JOIN er000 er ON er.EntryGUID = ce.GUID
												INNER JOIN bu000 bu ON bu.GUID = er.ParentGUID
												INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
											WHERE
												er.ParentType = 2 AND bu.GUID = @buGuid
												AND ((bt.bIsInput = 1 AND en.Credit = 0) OR (bt.bIsOutput = 1 AND en.Debit = 0))
												AND (en.ContraAccGUID = bu.FPayAccGUID AND en.ContraAccGUID <> 0x00)
												AND (en.AccountGUID = bu.CustAccGUID))
				  GROUP BY en.ceGUID )
	RETURN @total
END
#########################################################################################################
CREATE PROC PrcGetErrorBillPaymentConnect 
AS 
    SET NOCOUNT ON 
	
	SELECT * INTO #bp FROM bp000

	EXECUTE	[prcAddGUIDFld] '#bp', 'ParentDebitGUID'

	IF [dbo].[fnObjectExists]('#bp.ParentPayGUID') =  0
	BEGIN	
		EXECUTE	[prcAddGUIDFld] '#bp', 'ParentPayGUID'
		EXEC ('
			UPDATE #bp 
			SET ParentDebitGUID = bu.GUID  
			FROM 
				#bp bp 
				INNER JOIN en000 en ON en.GUID = bp.DebtGUID 
				INNER JOIN ce000 ce ON ce.GUID =  en.ParentGUID 
				INNER JOIN er000 er ON ce.GUID =  er.EntryGUID 
				INNER JOIN bu000 bu ON bu.GUID =  er.ParentGUID')

		EXEC ('
			UPDATE #bp 
			SET ParentPayGUID = bu.GUID  
			FROM 
				#bp bp 
				INNER JOIN en000 en ON en.GUID = bp.PayGUID 
				INNER JOIN ce000 ce ON ce.GUID =  en.ParentGUID 
				INNER JOIN er000 er ON ce.GUID =  er.EntryGUID 
				INNER JOIN bu000 bu ON bu.GUID =  er.ParentGUID')
	END

	DECLARE @sql NVARCHAR(MAX);
	  SET @sql = ' CREATE TABLE #result 
		  ( 
			 billnametype nvarchar(max), 
			 billnumber   int, 
			 val          float, 
			 buguid       UNIQUEIDENTIFIER,
			 type		  INT
		 
		  ) 

		INSERT INTO #result
		SELECT bt.abbrev, 
			   bu.number, 
			   bp.val, 
			   CASE 
				 WHEN ParentDebitGUID = bu.guid THEN ParentPayGUID 
				 ELSE ParentDebitGUID 
			   END AS buguid2 
			   ,1
		FROM   #bp bp 
			   INNER JOIN en000 en 
					   ON en.GUID = bp.PayGUID 
			   INNER JOIN ce000 ce 
					   ON ce.Guid = en.ParentGUID 
			   INNER JOIN er000 er 
					   ON er.EntryGUID = ce.GUID 
			   INNER JOIN bu000 bu 
					   ON bu.GUID = er.ParentGUID 
			   INNER JOIN bt000 bt 
					   ON bt.GUID = bu.TypeGUID 
		WHERE  er.ParentType = 2 
			   AND ( ( bt.bIsInput = 1 
					   AND en.Credit = 0 ) 
					  OR ( bt.bIsOutput = 1 
						   AND en.Debit = 0 ) ) 
			   AND ( en.ContraAccGUID = bu.FPayAccGUID ) 
			   AND ( en.AccountGUID = bu.CustAccGUID ) 
			   AND ( ParentDebitGUID <> bu.GUID 
					  OR ParentPayGUID <> bu.GUID ) ';
	
		IF [dbo].[fnObjectExists]('ch000') =  1
			BEGIN
				SET @sql = @sql + 'INSERT INTO #result 
				SELECT bt.abbrev, 
					   bu.Number, 
					   bp.Val, 
					   CASE 
						 WHEN ISNULL(ParentDebitGUID, 0x0) = 0x0 THEN ParentPayGUID 
						 ELSE ParentDebitGUID 
					   END AS buguid2 ,
					   2
				FROM   #bp bp 
					   INNER JOIN en000 en 
							   ON ( en.GUID = bp.PayGUID 
									 OR en.guid = bp.DebtGuid ) 
					   INNER JOIN ce000 ce 
							   ON ce.GUID = en.ParentGUID 
					   INNER JOIN er000 er 
							   ON er.EntryGUID = ce.GUID 
					   INNER JOIN ch000 ch 
							   ON ch.Guid = er.ParentGUID 
					   INNER JOIN bu000 bu 
							   ON bu.GUID = ch.ParentGUID 
					   INNER JOIN bt000 bt 
							   ON bt.GUID = bu.TypeGUID 
				WHERE  er.ParentType = 5 
					   AND ( ParentDebitGUID <> bu.GUID 
							 AND ParentPayGUID <> bu.GUID ) ';
		END

		SET @sql = @sql + 'INSERT INTO #result
		SELECT bt.abbrev, 
			   bu.Number, 
			   bp.Val, 
			   CASE 
				 WHEN ISNULL(ParentDebitGUID, 0x0) = 0x0 THEN ParentPayGUID 
				 ELSE ParentDebitGUID 
			   END AS buguid2 ,
			   3
		FROM   #bp bp 
					   INNER JOIN en000 en
							   ON en.GUID = bp.PayGUID
					   INNER JOIN ce000 ce
							   ON ce.Guid = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = er.ParentGUID
					   INNER JOIN bt000 bt
							   ON bt.GUID = bu.TypeGUID
				WHERE  er.ParentType = 2
					   AND ( ( bt.bIsInput = 1
							   AND en.Credit = 0 )
							  OR ( bt.bIsOutput = 1
								   AND en.Debit = 0 ) )
					   AND ( en.ContraAccGUID <> bu.FPayAccGUID )
					   AND ( en.AccountGUID = bu.CustAccGUID )
					   AND ( bp.ParentDebitGUID <> bp.ParentPayGUID )
				    

		SELECT cast(bu.Number as NVARCHAR(MAX)) +'':''+ bt.abbrev as bill,
			   dbo.fnGetBillTotalForUpgrade(bu.Guid,DEFAULT) as total,
			   bu.Date as budate,
			   val, 
			   cast(billnumber as NVARCHAR(MAX)) +'':''+ billnametype as billOriginal, 
			   res.type as type
		FROM   #result res
			   INNER JOIN bu000 bu 
					   ON bu.GUID = buguid 
			   INNER JOIN bt000 bt 
					   ON bt.GUID = bu.TypeGUID 
		ORDER BY  bt.NAME +'':''+cast(bu.Number as NVARCHAR(MAX))'
	EXEC (@sql);
	
######################################################################################
#END