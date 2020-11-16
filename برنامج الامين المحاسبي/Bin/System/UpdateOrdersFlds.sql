CREATE PROCEDURE prcUpgradeOrdersFlds
AS
	IF (NOT EXISTS(SELECT * FROM op000
		WHERE Name = 'AmnCfg_UPDATEORDERPAYMENTSANDPOST'))
	BEGIN
		EXEC prcExecuteSQL 'UPDATE OrderPayments000 SET UpdatedValue = Value'
		EXEC prcExecuteSQL 'SELECT * into	#tempPaymentGuid from vwOrderPayments

		SELECT * from #tempPaymentGuid
						INSERT INTO OrderPayments000 (GUID , BillGuid, Number, PayDate, Value, Percentage, UpdatedValue) 
								SELECT 
								NEWID(),
								[o].[ParentGuid],
								1,
								CASE o.PTType
									WHEN 1 THEN DATEADD(DAY, o.[PTDaysCount], dbo.fnGetOrderDate(o.GUID, o.PTOrderDate))
									WHEN 2 THEN o.PTDate
									ELSE [dbo].fnGetOrderDate(o.GUID, o.PTOrderDate)
								END ,
								buTotal,
								100,
								buTotal
							FROM 
								vwbu bu 
								INNER JOIN vwbt bt ON [bt].[btGuid] = [bu].[buType]
								INNER JOIN orAddInfo000 [o] ON [o].[ParentGuid] = [bu].[buGuid] 
							WHERE 
								bu.[buPayType] = 1 AND o.PTType <> 3
								AND [o].[ParentGuid] NOT IN (SELECT BillGuid FROM OrderPayments000)
					
					EXECUTE sp_refreshview ''vwOrderPayments''

					select * from vwOrderPayments
					SELECT orp.paymentGuid as Guid,orp2.PaymentGuid as guid2
					 INTO #GUIDs FROM vwOrderPayments orp2 INNER JOIN #tempPaymentGuid  orp
					  ON orp.BillGuid=orp2.BillGuid AND orp2.DueDate=orp.DueDate 
					  AND orp2.OrderGuid=orp.OrderGuid
					  AND orp2.PaymentDate=orp.paymentDate AND orp.PaymentValue= orp2.PaymentValue AND orp.PaymentDate= orp2.PaymentDate

					  begin transaction

						select * from #GUIDs
  						UPDATE b
						SET b.[DebtGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[DebtGUID] = orp.Guid

						UPDATE b
						SET b.[PayGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[PayGUID] = orp.Guid
						Commit
						'
		EXEC prcExecuteSQL '

		SELECT * into	#tempPaymentGuid from vwOrderPayments
			CREATE TABLE #Result(
				OrderGuid UNIQUEIDENTIFIER,
				PaymentGUID UNIQUEIDENTIFIER,
				[Date] DATE,
				Total FLOAT,
				Dif FLOAT,
				Finished INT);
		
			;WITH TotalPosted AS
			(
				SELECT
					ori.oriPOGUID AS OrderGuid,
					SUM(bi.biBillQty * bi.biPrice) AS TotalPosted
				FROM
					vwExtended_bi bi
					INNER JOIN vwORI ori ON bi.buGUID = ori.oriBuGUID
					INNER JOIN oit000 oit ON ori.oriTypeGuid = oit.[Guid]
				WHERE
					oit.QtyStageCompleted = 1 AND ori.oriQty > 0 AND ori.oriType = 0
				GROUP BY
					ori.oriPOGUID
			),
			TotalPayment AS 
			(
				SELECT
					p.BillGuid AS OrderGuid,
					SUM(p.UpdatedValue) AS TotalPayment
				FROM
					OrderPayments000 p
				GROUP BY
					P.BillGuid
			)
			INSERT INTO #Result
			SELECT  
				bu.buGUID,
				PAY.[Guid], 
				PAY.[PayDate],
				Pay.[UpdatedValue] / bu.[buCurrencyVal],
				(Payment.TotalPayment -  Posted.TotalPosted)/ bu.[buCurrencyVal],
				orinfo.finished
			FROM  
				vwBu AS Bu 
				JOIN TotalPosted Posted ON bu.buGUID = Posted.OrderGuid
				JOIN TotalPayment Payment ON bu.buGUID = Payment.OrderGuid
				INNER JOIN OrderPayments000 AS PAY ON PAY.BillGuid = Bu.buGUID 
				INNER JOIN OrAddInfo000 AS orinfo ON orinfo.[ParentGUID] = bu.[buGUID]
			WHERE  
				Pay.[UpdatedValue] <> 0
				AND orinfo.Add1 <> 1 
			ORDER BY 
				PAY.[PayDate] DESC
			
			DECLARE @OrderGUID uniqueidentifier,
					@PaymentGUID uniqueidentifier,
					@Date Date,
					@Total Float,
					@Dif Float,
					@Finished INT
			
					DECLARE i CURSOR FOR SELECT OrderGuid,PaymentGUID, Date, Total, Dif, Finished FROM #Result   
					OPEN i  
						FETCH NEXT FROM i INTO @OrderGUID,@PaymentGUID, @Date, @Total, @Dif, @Finished 
						DECLARE @OldGuid uniqueidentifier = 0x0
						DECLARE @DifValue Float
			
						WHILE @@FETCH_STATUS = 0  
						BEGIN  
						IF (@OldGuid <> @OrderGUID)
							Begin
								SET @OldGuid = @OrderGUID
								SET @DifValue = @Dif
							End 
							IF (@DifValue < 0)
							BEGIN
								SET @DifValue = ABS(@Dif) 
								UPDATE OrderPayments000 SET UpdatedValue = UpdatedValue + @DifValue WHERE Guid = @PaymentGUID
								SET @DifValue = 0
							END
							ELSE IF (@DifValue <> 0) AND (@DifValue >= @Total AND @Total <> 0)AND(@Finished <> 0)
							Begin
								SET @DifValue -= @Total	
								IF EXISTS (SELECT * FROM bp000 WHERE DebtGUID = @PaymentGUID)
								BEGIN
									DELETE FROM bp000 WHERE DebtGUID = @PaymentGUID
								END			
								UPDATE OrderPayments000 SET Updatedvalue = 0 WHERE Guid = @PaymentGUID
							END
							ELSE IF (@DifValue <> 0) AND (@DifValue < @Total AND @Total <> 0)AND(@Finished <> 0)
							BEGIN
								SET @Total -= @DifValue
								SET @DifValue = 0
								IF EXISTS (SELECT * FROM bp000 WHERE DebtGUID = @PaymentGUID)
								BEGIN
									DELETE FROM bp000 WHERE DebtGUID = @PaymentGUID
								END	
								UPDATE OrderPayments000 SET UpdatedValue = @Total WHERE Guid = @PaymentGUID
							END 
							FETCH NEXT FROM i INTO  @OrderGuid,@PaymentGUID, @Date, @Total, @Dif, @Finished
						END  
					CLOSE i  
					DEALLOCATE i 

					EXECUTE sp_refreshview ''vwOrderPayments''

					select * from vwOrderPayments
					SELECT orp.paymentGuid as Guid,orp2.PaymentGuid as guid2
					 INTO #GUIDs FROM vwOrderPayments orp2 INNER JOIN #tempPaymentGuid  orp
					  ON orp.BillGuid=orp2.BillGuid AND orp2.DueDate=orp.DueDate 
					  AND orp2.OrderGuid=orp.OrderGuid
					  AND orp2.PaymentDate=orp.paymentDate AND orp.PaymentValue= orp2.PaymentValue AND orp.PaymentDate= orp2.PaymentDate

					  select * from #GUIDs
  						UPDATE b
						SET b.[DebtGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[DebtGUID] = orp.Guid

						UPDATE b
						SET b.[PayGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[PayGUID] = orp.Guid
					
					'

	  EXEC prcExecuteSQL '
	  SELECT * into	#tempPaymentGuid from vwOrderPayments
	  CREATE TABLE #Result(
				Number1 INT,
				Number2 INT,
				Guid1 UNIQUEIDENTIFIER,
				Guid2 UNIQUEIDENTIFIER,
				OrderGuid UNIQUEIDENTIFIER,
				POIGUID UNIQUEIDENTIFIER,
				PostDate DATE,
				FromStateGuid UNIQUEIDENTIFIER,
				ToStateGuid UNIQUEIDENTIFIER,
				BuGuid UNIQUEIDENTIFIER,
				Qty1 float,
				Qty2 float,
				Operation INT,
			);
		
			INSERT INTO #Result
			SELECT DISTINCT
				o.oriNumber,
				previousState.Number,
				o.oriGUID,
				previousState.GUID,
				o.oriPOGUID,
				o.oriPOIGuid,
				o.oriDATE,
				previousState.TypeGuid,
				o.oriTypeGuid,
				CASE oit1.operation WHEN 3 THEN 0x0 ELSE o.oriBuGuid END,
				o.oriQty,
				previousState.Qty,
				oit1.operation
			FROM
				vwOri o
				INNER JOIN ori000 previousState ON previousState.POIGUID = [o].oriPOIGuid AND previousState.Number = [o].oriNumber - 1
				LEFT JOIN oit000 oit1 ON oit1.[GUID] = o.oriTypeGuid
				LEFT JOIN vwBu bu ON bu.buGUID = o.oriBuGUID
			WHERE
				[o].[oriTypeGuid] <> [previousState].[TypeGuid] AND ABS(o.oriQty) = ABS(previousState.Qty)
			order by
				o.oriPOGUID,
				o.oriDATE DESC,
				o.oriNumber,
				CASE oit1.operation WHEN 3 THEN 0x0 ELSE o.oriBuGuid END,
				previousState.TypeGuid,
				o.oriTypeGuid

			DECLARE @Number INT,
					@GUID uniqueidentifier,
					@OrderGUID uniqueidentifier,
					@PostDate DATETIME,
					@FromStateGUID uniqueidentifier,
					@ToStateGUID uniqueidentifier,
					@BuGUID uniqueidentifier
					
					DECLARE i CURSOR FOR SELECT Number1, GUID1, OrderGuid, PostDate, FromStateGuid, ToStateGuid, BuGuid FROM #Result   
					OPEN i  
						FETCH NEXT FROM i INTO @Number, @GUID, @OrderGUID, @PostDate, @FromStateGUID, @ToStateGUID, @BuGUID 
						DECLARE @OldOrderGuid uniqueidentifier = 0x0,
								@OldPostDate DATETIME,
								@OldFromStateGUID uniqueidentifier = 0x0,
								@OldToStateGUID uniqueidentifier = 0x0,
								@OldBuGUID uniqueidentifier = 0x0,
								@PostGUID uniqueidentifier = 0x0,
								@PostNumber INT = 0
			
						WHILE @@FETCH_STATUS = 0  
						BEGIN  
						IF (@OldOrderGuid <> @OrderGUID OR @OldPostDate <> @PostDate OR @OldFromStateGUID <> @FromStateGUID
						 OR @OldToStateGUID <> @ToStateGUID OR @OldBuGUID <> @BuGUID)
							Begin
							IF(@OldOrderGuid <> @OrderGUID)
								SET @PostNumber = 0
								
							IF(((@OldBuGUID <> @BuGUID) AND (@OldBuGUID <> 0x0 OR @BuGUID <> 0x0)) 
							   OR (@OldPostDate <> @PostDate) OR (@OldBuGUID = 0x0 AND @BuGUID = 0x0 AND (@OldFromStateGUID <> @FromStateGUID OR @OldToStateGUID <> @ToStateGUID)))
							BEGIN
								SET @PostNumber += 1
								SET @PostGUID = NEWID()
								IF(@BuGUID <> 0x0)
								BEGIN
									UPDATE ori000 SET PostGuid = @PostGUID, PostNumber = @PostNumber 
									WHERE 
										POGUID = @OrderGuid AND Date = @PostDate AND BuGuid = @BuGUID
								END
								ELSE IF(@BuGUID = 0x0)
								BEGIN
									UPDATE ori000 SET PostGuid = @PostGUID, PostNumber = @PostNumber 
									WHERE 
										POGUID = @OrderGuid 
										AND (GUID IN (SELECT Guid1 FROM #Result 
											 WHERE 
											  OrderGuid = @OrderGuid AND PostDate = @PostDate
											   AND FromStateGuid = @FromStateGUID AND ToStateGuid = @ToStateGUID)
											   OR
											 GUID IN (SELECT Guid2 FROM #Result 
											 WHERE 
											  OrderGuid = @OrderGuid AND PostDate = @PostDate
											   AND FromStateGuid = @FromStateGUID AND ToStateGuid = @ToStateGUID
											   ))
							  END 
							END
						
							SET @OldOrderGuid = @OrderGUID
							SET @OldPostDate = @PostDate
							SET @OldFromStateGUID = @FromStateGUID
							SET @OldToStateGUID = @ToStateGUID
							SET @OldBuGUID = @BuGUID
							End 
							
							FETCH NEXT FROM i INTO  @Number, @GUID, @OrderGUID, @PostDate,  @FromStateGuid, @ToStateGuid, @BuGUID
						END  
					CLOSE i  
					DEALLOCATE i
					
					EXECUTE sp_refreshview ''vwOrderPayments''

					select * from vwOrderPayments
					SELECT orp.paymentGuid as Guid,orp2.PaymentGuid as guid2
					 INTO #GUIDs FROM vwOrderPayments orp2 INNER JOIN #tempPaymentGuid  orp
					  ON orp.BillGuid=orp2.BillGuid AND orp2.DueDate=orp.DueDate 
					  AND orp2.OrderGuid=orp.OrderGuid
					  AND orp2.PaymentDate=orp.paymentDate AND orp.PaymentValue= orp2.PaymentValue AND orp.PaymentDate= orp2.PaymentDate

					  select * from #GUIDs
  					UPDATE b
						SET b.[DebtGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[DebtGUID] = orp.Guid

						UPDATE b
						SET b.[PayGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[PayGUID] = orp.Guid
					'

					insert Into op000 values (NEWID(),'AmnCfg_UPDATEORDERPAYMENTSANDPOST',0, 0, '' ,NULL, 0, 0x0, 0x0 )
			END

			IF (NOT EXISTS(SELECT * FROM op000 WHERE Name = 'AmnCfg_UPDATEORITABLE'))
			BEGIN
				EXEC prcExecuteSQL '
				
				SELECT * into	#tempPaymentGuid from vwOrderPayments
				CREATE TABLE #Bills1(
					GUID UNIQUEIDENTIFIER,
					POIGUID UNIQUEIDENTIFIER,
					OrderGuid UNIQUEIDENTIFIER,
					BuGuid UNIQUEIDENTIFIER,
					Note NVARCHAR(255)
					);
				CREATE TABLE #Bills2(
							GUID UNIQUEIDENTIFIER,
							POIGUID UNIQUEIDENTIFIER,
							OrderGuid UNIQUEIDENTIFIER,
							BuGuid UNIQUEIDENTIFIER
							);
			  -----جدول أقلام الترحيل التي تحوي فواتير تحوي مواد مكررة------			
				INSERT INTo #Bills1 
				SELECT 
					ori.GUID, 
					POIGUID, 
					POGUID, 
					ori.BuGuid,
					bt.Abbrev + '':'' + CAST(bu.Number AS NVARCHAR(10)) + '':'' + CAST(bi.Number + 1 AS NVARCHAR(10))
				from 
					ori000 ori
					INNER JOIN bu000 bu ON bu.GUID = ori.POGUID
					INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
					INNER JOIN bi000 bi ON bi.GUID = ori.POIGUID
					INNER JOIN bu000 bu2 ON bu2.GUID = ori.BuGuid
				WHERE
					ori.BuGuid <> 0x0 AND
					((SELECT COUNT(*) FROM vwExtended_bi bi WHERE bi.buGuid = bu2.Guid) > (SELECT COUNT(*) FROM (SELECT DISTINCT biMatPtr FROM vwExtended_bi bi WHERE bi.buGuid = Bu2.Guid) AS bi))
			  ---------جدول أقلام الترحيل التي تحوي فواتير لا تحوي مواد مكررة-------------------
				INSERT INTo #Bills2
				SELECT 
					ori.GUID, 
					POIGUID, 
					POGUID, 
					ori.BuGuid
				from 
					ori000 ori
					INNER JOIN bu000 bu ON bu.GUID = ori.BuGuid
				WHERE
					ori.BuGuid <> 0x0 AND
					((SELECT COUNT(*) FROM vwExtended_bi bi WHERE bi.buGuid = bu.GUID) <= (SELECT COUNT(*) FROM (SELECT DISTINCT biMatPtr FROM vwExtended_bi bi WHERE bi.buGuid = bu.GUID) AS bi))
			  ------------إعطاء قيمة للعمود الجديد في حال كان سطر الترحيل غير مرتبط بفاتورة----------------------
			  UPDATE ori000 SET BiGuid = 0x0 WHERE BuGuid = 0x0
			  ------------إعطاء قيمة للعمود الجديد في جدول الترحيل عندما تكون الفاتورة تحوي مواد مكررة------------ 
				 UPDATE ori000 SET BiGuid = bi.GUID
				 FROM 
				 bi000 bi2 
				 INNER JOIN ori000 ori ON bi2.GUID = ori.POIGUID
				 INNER JOIN #Bills1 bill ON bill.GUID = ori.GUID
				 INNER JOIN bu000 bu on bu.GUID = ori.BuGuid
				 INNER JOIN bi000 bi ON bi.ParentGUID = ori.BuGuid AND bi.Notes Like bill.Note COLLATE DATABASE_DEFAULT
				------------إعطاء قيمة للعمود الجديد في جدول الترحيل عندما تكون الفاتورة لا تحوي مواد مكررة------------ 
				 UPDATE ori000 SET BiGuid = bi.GUID
				 FROM 
				 bi000 bi2 
				 INNER JOIN ori000 ori ON bi2.GUID = ori.POIGUID
				 INNER JOIN #Bills2 bill ON bill.GUID = ori.GUID
				 INNER JOIN bu000 bu on bu.GUID = ori.BuGuid
				 INNER JOIN bi000 bi ON bi.ParentGUID = ori.BuGuid AND bi.MatGUID = bi2.MatGUID
				 
				 EXECUTE sp_refreshview ''vwOrderPayments''

					select * from vwOrderPayments
					SELECT orp.paymentGuid as Guid,orp2.PaymentGuid as guid2
					 INTO #GUIDs FROM vwOrderPayments orp2 INNER JOIN #tempPaymentGuid  orp
					  ON orp.BillGuid=orp2.BillGuid AND orp2.DueDate=orp.DueDate 
					  AND orp2.OrderGuid=orp.OrderGuid
					  AND orp2.PaymentDate=orp.paymentDate AND orp.PaymentValue= orp2.PaymentValue AND orp.PaymentDate= orp2.PaymentDate

					  select * from #GUIDs
  					UPDATE b
						SET b.[DebtGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[DebtGUID] = orp.Guid

						UPDATE b
						SET b.[PayGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[PayGUID] = orp.Guid
				 '
				
					insert Into op000 values (NEWID(),'AmnCfg_UPDATEORITABLE',0, 0, '' ,NULL, 0, 0x0, 0x0 )
			END
