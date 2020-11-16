################################################################################
CREATE PROCEDURE prcOrderUpdateTransPostedBillInfo
	@DbName NVARCHAR(250),
	@IsTrnToExistingDb BIT
AS
	SET @DbName = N'[' + @DbName + N']'
	DECLARE	@SQL AS NVARCHAR(Max)

	CREATE table #TransInfo
	(
		TransferOriBuGuid uniqueidentifier,
		OriBuGuid uniqueidentifier,
		ReTransferOriBuGuid uniqueidentifier
	)

	SET @SQL ='INSERT INTO #TransInfo (TransferOriBuGuid, OriBuGuid)
			   SELECT TransferOriBuGuid, OriBuGuid 
			   FROM '+ @DbName+'..TransferedOrderBillsInfo000'
	EXEC (@SQL)

	SET @SQL ='DELETE FROM '+ @DbName+'..TransferedOrderBillsInfo000'
	EXEC (@SQL)

	SET @SQL ='SELECT CAST(asc2 as uniqueidentifier) AS TransferedBillGuid, CAST(Asc3 as uniqueidentifier) AS BillGuid
			   INTO #BillsGuids FROM '+ @DbName+'..mc000 where type = 40'

	SET @SQL = @SQL + 'INSERT INTO '+@DbName+ '..TransferedOrderBillsInfo000
				(	
					LcGuid,
					LcName,
					LcNumber,
					LcLatinName,
					OriBuGuid,
					TransferOriBuGuid,
					OriGuid,
					LcState
				)			
				SELECT 
					   lc.GUID,
				       lc.Name,
					   lc.Number,
					   lc.LatinName,
					   v.orderPostedBillGuid,
					   TransferedBillGuid,
					   v.orderGuid,
					   lc.State
				FROM vwOrderBuPosted v INNER JOIN bu000 bu ON bu.GUID = v.orderPostedBillGuid
				INNER JOIN LC000 lc ON lc.GUID = bu.LCGUID
				LEFT JOIN #BillsGuids BillsGuids on bu.GUID = BillsGuids.BillGuid
				LEFT JOIN '+ @DbName+'.dbo.bu000 TRansbu ON TRansbu.Guid = BillsGuids.TransferedBillGuid'
	EXEC (@SQL)

	SET @SQL ='UPDATE reTransInfo
			   SET reTransInfo.ReTransferOriBuGuid = transInfo.TransferOriBuGuid 
			   FROM #TransInfo reTransInfo INNER JOIN '+ @DbName+'..TransferedOrderBillsInfo000 transInfo 
			   ON reTransInfo.OriBuGuid = transInfo.OriBuGuid'
	EXEC (@SQL)


	SET @SQL = 'UPDATE ori 
				SET ori.BuGuid = bu.GUID
				FROM '+ @DbName +'..ori000 ori INNER JOIN '+ @DbName +'.dbo.TransferedOrderBillsInfo000 transInfo ON ori.BuGuid = transInfo.OriBuGuid 
				INNER JOIN '+ @DbName +'.dbo.bu000 bu ON bu.GUID = transInfo.TransferOriBuGuid'
	EXEC (@SQL)
		
	IF(@IsTrnToExistingDb = 1)
		BEGIN
			SET @SQL = 'UPDATE ori 
						SET ori.BuGuid = reTransInfo.ReTransferOriBuGuid
						FROM '+ @DbName +'..ori000 ori INNER JOIN #TransInfo reTransInfo ON ori.BuGuid = reTransInfo.TransferOriBuGuid'
			EXEC (@SQL)
		END

	SET @SQL = 'UPDATE ori 
				SET ori.bIsRecycled = 1 
				FROM '+ @DbName+'..ori000 ori INNER JOIN vwExtended_bi bill ON bill.buGUID = ori.POGUID
				LEFT JOIN LC000 lc ON lc.GUID = bill.buLCGUID AND lc.state = 0'
	EXEC (@SQL)	
	-------------- TrnOrdBu000---------
	DECLARE @TableName AS NVARCHAR(100)
	set @TableName = @DbName + '..TrnOrdBu000'

	SET @SQL = 'INSERT INTO ' + @TableName 
			  +' SELECT OrderGuid , '+ '(SELECT DISTINCT
											    bill.buGUID,
												bill.biGUID,
												bill.buNotes,
												bill.buType,
												bill.buVat,
												bill.buCurrencyPtr,
												bill.buCurrencyVal,
												bill.btAbbrev,
												bill.buNumber,
												bill.buCostPtr,
												bill.buDate,
												bill.buStorePtr,
												bill.buCustAcc,
												bill.buTotal,
												bill.buTotalExtra,
												bill.buTotalDisc,
												bill.buBonusDisc,
												bill.biGUID,
												bill.biStorePtr,
												bill.biCostPtr,
												bill.biUnity,
												bill.biMatPtr,
												bill.biQty,
												bill.biBillQty,
												bill.biPrice,
												bill.biUnitPrice,
												bill.biClassPtr,
												bill.biBonusDisc,
												bill.biVAT,
												bill.biUnitDiscount,
												bill.biUnitExtra,
												bill.biBonusDisc,
												bill.biVAT,
												bill.biUnitDiscount,
												bill.biUnitExtra,
												bill.biCurrencyVal,
												bill.biExpireDate,
												lc.GUID AS buLcGuid,
												lc.Number AS buLcNumber,
												lc.Name AS buLcName, 
												lc.state AS buLcState			      
					FROM '+ @DbName+'..ori000 ori INNER JOIN vwExtended_bi bill ON bill.buGUID = ori.BuGuid
					LEFT JOIN LC000 lc ON lc.GUID = bill.buLCGUID
					FOR XML PATH (''OrderBills''))' +' FROM vwOrderBuPosted AS orders Group BY OrderGuid'
					Execute (@SQL)
################################################################################
#END
