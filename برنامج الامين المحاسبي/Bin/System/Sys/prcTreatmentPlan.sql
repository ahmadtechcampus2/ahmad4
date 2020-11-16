##########################
CREATE    PROC PrcHosTreatmentPlanDetails
	@FileGuid UNIQUEIDENTIFIER = 0x0, 
	@FromDate DATETIME = '1/1/2000' 	, 
	@ToDate DATETIME = '1/1/2050' 	, 
	@HideFinished  BIT = 0, 
	@HideCanceled  BIT = 0, 

	@Sort INT = 1 
AS 
SET NOCOUNT ON 
DECLARE @strSQL NVARCHAR(max) 
SET @strSQL = 'SELECT	* FROM vwhosTreatmentPlanDetails '+ 
						 ' WHERE  ' + 
						 ' (FileGuid = '''+ CAST(@FileGuid AS NVARCHAR(100)) + ''' OR 	'''+ CAST(@FileGuid AS NVARCHAR(100)) + ''' = ''00000000-0000-0000-0000-000000000000'' )' + 
						 ' AND ' + 
						 ' (DoseTime >=  '''+CAST(@FromDate AS NVARCHAR)+''' AND DoseTime <= '''+CAST(@ToDate AS NVARCHAR(20) )+''')' + 
						 ' AND  '+ 
						 ' (	'+ CAST(@HideFinished AS NVARCHAR(20))+ '  = 0 OR WorkerGuid = ''00000000-0000-0000-0000-000000000000'' ) '+ 
						 ' AND  '+ 
						 ' (	'+ CAST(@HideCanceled AS NVARCHAR(20))+ '  = 0 OR Status = 0 ) '+ 

						 '	ORDER BY '  
IF  		 @Sort = 0   SET @strSQL = @strSQL + ' DoseTime ' 
else if  @Sort = 1 SET @strSQL = @strSQL + ' [FileName], DoseTime' 
else if  @Sort = 2 SET @strSQL = @strSQL + ' WorkerName , DoseTime' 
else if  @Sort = 3 SET @strSQL = @strSQL + ' MatName , DoseTime'  
else  SET @strSQL = @strSQL + ' Code , DoseTime' 
print @strSQL 
EXEC(@strSQL)

##########################
CREATE  PROC PrcHosTreatmentPlanGenerateBills
	@FileGuid UNIQUEIDENTIFIER = 0x0, 
	@FromDate DATETIME = '12/20/2006', 
	@ToDate DATETIME = '12/26/2006'
AS 
SET NOCOUNT ON 
	DECLARE @PlanGuid UNIQUEIDENTIFIER
	DECLARE @BillTypeGuid UNIQUEIDENTIFIER -- 
	DECLARE @DefStoreGuid UNIQUEIDENTIFIER --
	DECLARE @StoreGuid UNIQUEIDENTIFIER --
	DECLARE @FileAccGuid UNIQUEIDENTIFIER --
	DECLARE @CostGuid  UNIQUEIDENTIFIER --
	DECLARE @BillGuid  UNIQUEIDENTIFIER --
	DECLARE @PlanCode  NVARCHAR(250) --
	
	DECLARE @NOTES  NVARCHAR(250)  --
	DECLARE @BillNumber BIGINT	 -- —ﬁ„ «·›« Ê—…
	DECLARE @BillDate DATETIME	 -- —ﬁ„ «·›« Ê—…
	DECLARE @CurrencyGuid  UNIQUEIDENTIFIER -- «·⁄„·… 
	DECLARE @CustomerGuid  UNIQUEIDENTIFIER --  «·“»Ê‰
	DECLARE @CurrencyVal  INT  --
	SELECT  @CurrencyGuid = CAST ( [Value] AS  UNIQUEIDENTIFIER) FROM op000 WHERE Name = 'AmnCfg_DefaultCurrency'
	SET 		@CurrencyVal  = 1 --  ⁄«œ· «·⁄„·…
  SELECT  @BillTypeGuid = CAST ( [Value] AS  UNIQUEIDENTIFIER) FROM op000 WHERE Name = 'HosCfg_Surgery_BillType'
	SELECT  @DefStoreGuid = DefStoreGuid  --, 					@DefBillAccGuid = DefBillAccGuid -- Õ”«» «·„Ê«œ
	FROM  bt000 WHERE Guid = @BillTypeGuid

		DECLARE PlansCursor CURSOR   FOR 
	----
		SELECT	DISTINCT ParentGuid FROM vwhosTreatmentPlanDetails
		WHERE  
				(FileGuid = @FileGuid OR @FileGuid =0x0)
		AND (DoseTime >=  @FromDate AND DoseTime <=@ToDate)

		UPDATE hosTreatmentPlan000 SET BillGuid = 0x0 WHERE Guid In(  SELECT	DISTINCT ParentGuid FROM vwhosTreatmentPlanDetails
																																	WHERE  
																																			(FileGuid = @FileGuid OR @FileGuid =0x0)
																																	AND (DoseTime >=  @FromDate AND DoseTime <=@ToDate)
																																)
	-----
		OPEN PlansCursor
		FETCH NEXT FROM PlansCursor INTO @PlanGuid
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT top 1 @BillGuid = BillGuid  -- «·›« Ê—…
			FROM vwhosTreatmentPlanDetails WHERE ParentGUID = @PlanGuid
			if (@BillGuid IS NOT Null) 
			BEGIN
				EXEC	prcBill_delete  @BillGuid
				EXEC	prcBill_Delete_Entry @BillGuid
			END
			FETCH NEXT FROM PlansCursor INTO @PlanGuid
		END
		CLOSE PlansCursor
   	--DEALLOCATE PlansCursor

	---
		OPEN PlansCursor
		FETCH NEXT FROM PlansCursor INTO @PlanGuid
		WHILE @@FETCH_STATUS = 0
		BEGIN
		-- insert into  Bu 
			IF NOT EXISTS (SELECT 1 FROM vwhosTreatmentPlanDetails 	WHERE ParentGUID = @PlanGuid AND WorkerGuid <> 0x0)	
			BEGIN
					FETCH NEXT FROM PlansCursor INTO @PlanGuid
					CONTINUE
			END
			SELECT top 1 @CostGuid = CostGuid,  -- „—ﬂ“ «·ﬂ·›… 
									 @StoreGuid = StoreGuid,  -- «·„” Êœ⁄
									 @PlanCode = Code,  -- —„“ «·Œÿ…
									 @BillGuid = BillGuid,  -- «·›« Ê—…
									 @BillDate = DoseTime,
									 @FileAccGuid = AccGuid, 
									 @CustomerGuid = CustomerGuid, -- «·⁄„Ì·
									 @Notes = '„Ê·œ… ⁄‰ «·Œÿ… «·⁄·«ÃÌ… —ﬁ„:' + Code + '  «·„—Ì÷: '+ [FileName]
			FROM vwhosTreatmentPlanDetails WHERE ParentGUID = @PlanGuid
			if (@StoreGuid IS NULL ) SET @StoreGuid = @DefStoreGuid
			SELECT @BillNumber =  ISNULL(MAX(Number), 0 ) + 1 from bu000 where  TypeGuid = @BillTypeGuid 			print @BillNumber
			DECLARE @NewBillGuid   UNIQUEIDENTIFIER
			SET @NewBillGuid = NEWID()
			INSERT INTO Bu000 (Guid,  number, [Date], CurrencyVal, Notes, PayType, TypeGuid, CustGuid, CurrencyGuid, CustAccGuid , StoreGuid)
			VALUES (@NewBillGuid, @BillNumber, @BillDate, @CurrencyVal, @Notes, 1, @BillTypeGuid, @CustomerGuid, @CurrencyGuid, @FileAccGuid, @StoreGuid )


			INSERT  INTO Bi000 
				( Qty, 
					Unity, 
					Price, 
					CurrencyGuid, 
					CurrencyVal, 
					Notes, 
					StoreGuid, 
					ParentGuid, 
					CostGuid, 
					MatGuid
				)
			SELECT  		

					Dose* CASE DetailsUnity WHEN 0 THEN 1 WHEN 1 THEN Unit2Fact WHEN 2 THEN Unit3Fact END,
					DetailsUnity+1, 
					CASE DetailsUnity WHEN 0 THEN mt.EndUser WHEN 1 THEN mt.EndUser2 WHEN 2 THEN mt.EndUser3 END, 
					@CurrencyGuid, 
					@CurrencyVal, 
				 	@Notes + ' «· «—ÌŒ: '+ Cast(DoseTime AS NVARCHAR(250)), 
					@StoreGuid, 
					@NewBillGuid, 
					@CostGuid, 
					MatGuid 
			FROM vwhosTreatmentPlanDetails td INNER JOIN mt000 mt on mt.Guid = td.MatGuid
			WHERE ParentGUID = @PlanGuid AND WorkerGuid <> 0x0
			ORDER BY DoseTime
			exec prcBill_post @NewBillGuid, 1
			exec  prcBill_genEntry @NewBillGuid
			UPDATE HosTreatmentPlan000 SET BillGuid = @NewBillGuid WHERE Guid = @PlanGuid 

			FETCH NEXT FROM PlansCursor INTO @PlanGuid
		END
	 CLOSE PlansCursor
   DEALLOCATE PlansCursor
/*
prcBill_post
prcBill_genEntry

select * from SysObjects where name like '%Entry%'
	SELECT * FROM Ac000 where Name = '‰“·«¡'
	SELECT * FROM cu000 where Name = '‰“·«¡'
select Name , Guid from Ac000 where code  = '31'
FA648A2A-41E3-40A3-AFF5-609AA6A0305E


	SELECT StoreGuid FROM Bu000
	SELECT unity  FROM Bi000
	SELECT	* FROM vwHosFile
	
	SELECT	* FROM vwhosTreatmentPlanDetails
WHERE  
		(FileGuid = @FileGuid OR @FileGuid =0x0)
AND (DoseTime >=  @FromDate AND DoseTime <=@ToDate)
AND (@HideFinished = 0 OR WorkerGuid = 0x0)
AND (	@HideCanceled = 0 OR Status = 0 )
ORDER BY ParentGuid

*/
-- exec PrcHosTreatmentPlanToSave
/*
select * from bi000
	alter table bu000 enable trigger all 

	select * from bu000

	delete  from bi000 where parentGuid in (select Guid from bu000 where Number  >= 3)
	delete  from bu000 where Number  >= 3
	select * from vwHosTreatmentPlanDetails
	delete  from ce000  where Notes like '%Œÿ…%'
	select * from mt000

*/
##########################
#END