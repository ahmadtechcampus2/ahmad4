############################################################## 
CREATE PROCEDURE repOrderPayments
	@OrderGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	DECLARE @result TABLE(
		[Guid] UNIQUEIDENTIFIER,
		TypeName NVARCHAR(250),
		Number INT,
		IsPayment BIT,
		ParentGuid UNIQUEIDENTIFIER,
		[Date] DATETIME,
		Value FLOAT,
		CurrencyGuid UNIQUEIDENTIFIER,
		CurrencyDescription NVARCHAR(250),
		CurrencyValue FLOAT,
		Notes NVARCHAR(250),
		Paid FLOAT,
		Remainder FLOAT,
		trn int,
		rowGuid int);

	-- get order currency GUID and Value
	DECLARE @OrderCurrencyGUID AS UNIQUEIDENTIFIER
	DECLARE @OrderCurrencyValue AS INT
	SELECT @OrderCurrencyGUID = buCurrencyPtr, @OrderCurrencyValue = (CASE WHEN buCurrencyVal <> 0 THEN buCurrencyVal ELSE 1 END) 
	FROM vwBu WHERE [buGuid] = @OrderGUID

	-- fill order payment info from orAddInfo000
	INSERT INTO @result
	SELECT 
		o.PaymentGuid,
		bt.Name +': ' + CAST(bu.Number AS NVARCHAR),  -- TypeName
		o.PaymentNumber,  -- Number
		0, -- IsPayment
		o.BillGuid,
		o.PaymentDate,
		o.UpdatedValueWithCurrency / (CASE WHEN bu.CurrencyVal <> 0 THEN bu.CurrencyVal ELSE 1 END) AS PaymentValue, -- Value

		bu.CurrencyGUID, -- CurrencyGuid
		'', -- CurrencyDescription
		bu.CurrencyVal,  -- CurrencyValue
		'',  -- Notes
		0,  -- Paid
		0,  -- Remainder
		0,
		0
	FROM
		vwOrderPayments o
		INNER JOIN bu000 bu ON o.BillGuid = bu.Guid
		INNER JOIN bt000 bt ON bu.TypeGuid = bt.Guid
	WHERE
		o.BillGuid = @OrderGuid AND o.UpdatedValueWithCurrency <> 0
	
	INSERT INTO @result
	SELECT 
		ISNULL(en.[Guid], bu.buGuid),
		ISNULL((et.Abbrev + ': ' + CAST(py.Number AS NVARCHAR)), bt.Abbrev+ ': ' + CAST(bu.buNumber AS NVARCHAR)),
		o.PaymentNumber,
		1,
		o.PaymentGuid, -- ParentGuid
		ISNULL(en.[Date], bu.buDate),
		(CASE WHEN bp.CurrencyGUID <> @OrderCurrencyGUID THEN (CASE WHEN bp.CurrencyVal = 1 THEN bp.Val / @OrderCurrencyValue ELSE bp.Val END) ELSE bp.Val / @OrderCurrencyValue END),
		bp.CurrencyGUID,
		my.Code + ' ' + my.Name,
		bp.CurrencyVal,
		'',
		0,
		0,
		0,
		0
	FROM 
		bp000 bp
		INNER JOIN vwOrderPayments o ON (bp.DebtGUID = o.PaymentGuid OR  bp.PayGUID = o.PaymentGuid) AND o.BillGuid = @OrderGuid
		LEFT JOIN vwOrderPayments oPay ON (bp.DebtGUID = oPay.PaymentGuid OR  bp.PayGUID = oPay.PaymentGuid) AND oPay.BillGuid <> @OrderGuid
		LEFT JOIN en000 en ON bp.DebtGUID = en.[Guid] OR bp.PayGUID = en.[Guid]
		LEFT JOIN ce000 ce ON en.ParentGUID = ce.[GUID]
		LEFT JOIN er000 er ON er.EntryGUID = ce.[GUID]
		LEFT JOIN py000 py ON py.[GUID] = er.ParentGUID
		LEFT JOIN et000 et ON et.[Guid] = ce.TypeGUID
		LEFT JOIN my000 my ON my.[GUID] = bp.CurrencyGUID
		-- LEFT JOIN vwExtended_bi bi ON bi.buGuid = bp.DebtGUID OR bi.buGUID = bp.PayGUID;
		LEFT JOIN vwBu bu ON bu.buGuid = bp.DebtGUID OR bu.buGUID = bp.PayGUID
		LEFT JOIN bt000 bt ON bt.GUID = bu.buType;
	WITH payments AS
	(
		SELECT
			Sum(Value) AS Value,
			ParentGuid
		FROM 
			@result
		WHERE 
			IsPayment = 1
		GROUP BY 
			ParentGuid
	)
	UPDATE r
	SET
		r.Paid = ISNULL(p.Value, 0),
		r.Remainder = r.Value - ISNULL(p.Value, 0)
	FROM 
		@result r 
		LEFT JOIN payments p ON p.ParentGuid = r.Guid
	WHERE 
		r.IsPayment = 0;

	IF(Exists(select * from @result where ISNULL(TypeName,'') = '' ))
	BEGIN
		;WITH UpRowGuid AS
		(
		  SELECT *
			, new_row_id=ROW_NUMBER() OVER (PARTITION BY ParentGuid ORDER BY ParentGuid )
		  FROM @result
	
		)
		UPDATE UpRowGuid
		SET rowGuid = new_row_id

		;WITH C AS
		(
			SELECT 
				ROW_NUMBER() OVER(PARTITION BY PaymentParentGuid ORDER BY PaymentParentGuid) AS Num,
				PaymentParentGuid,
				TrnTypeName,
				DatePayment 
			FROM TrnOrdPayment000 
			WHERE  PaymentParentGuid in (SELECT DISTINCT ParentGuid FROM @result)
		
		)
		UPDATE  r
			set R.TypeName = C.TrnTypeName,
				[Date] = C.DatePayment,
				trn=1
			from 
				@result r
			JOIN C ON R.ParentGuid = C.PaymentParentGuid  and num =r.rowGuid
	END
	SELECT * FROM @result ORDER BY [Date], Number;
##############################################################  
CREATE PROCEDURE prcUpdateOrderPayments @OrderGuid        UNIQUEIDENTIFIER,
	@FinishedRollBack BIT
AS
    SET nocount ON

	DECLARE @OrderPaymentUpdated BIT = 0;

    IF @FinishedRollBack = 0 ---IF order state changed from active to finised
	BEGIN
		DECLARE @OrderValue FLOAT
		DECLARE @TotalPosted FLOAT
		DECLARE @TotalPayment FLOAT
		DECLARE @Finished BIT

		CREATE TABLE #Temp(
			DebitGuid UNIQUEIDENTIFIER,
			PayGuid UNIQUEIDENTIFIER)
		--------------------Õ«·… «·ÿ·»Ì… -------------------------------
          SELECT @Finished = orinfo.finished
          FROM   OrAddInfo000 AS orinfo
          WHERE  orinfo.ParentGuid = @OrderGuid

		-------------------- ≈Ã„«·Ì «·ÿ·»Ì… -------------------------------
          SELECT @OrderValue = ( ( bi.buTotal + bi.buTotalExtra + bi.buVat ) -
                                                      ( bi.buTotalDisc +
                               bi.buBonusDisc ) )
          FROM (SELECT DISTINCT bi.buGuid,
				bi.buTotal,
				bi.buTotalExtra,
				bi.buTotalDisc,
				bi.buBonusDisc,
				bi.buVat
                  FROM   vwExtended_bi bi
                  WHERE  bi.buGuid = @OrderGuid
                  GROUP  BY bi.buGuid,
                            bi.buTotal,
				bi.buTotalExtra,
				bi.buTotalDisc,
				bi.buBonusDisc,
                bi.buVat) AS bi

		---------------------«·„Ã„Ê⁄ «·„Õﬁﬁ ··ÿ·»Ì… -----------------
		 SELECT @TotalPosted = [dbo].[fnGetPostedBillValue](@OrderGuid)
	
		-----------------------------------------------------------------
		--------------«·„Ã„Ê⁄ «·ﬂ·Ì ·œ›⁄«  «·ÿ·»Ì… ------------
          SELECT @TotalPayment = Sum(Pay.UpdatedValueWithCurrency)
          FROM   vworderpayments AS Pay
          WHERE  Pay.billGuid = @OrderGuid
          GROUP  BY Pay.BillGuid

	   ----------------------------------------------------------------------------
          CREATE TABLE #result
            (
			   PaymentGUID UNIQUEIDENTIFIER,
               Date        DATE,
               Total       FLOAT,
               Dif         FLOAT
            )

			CREATE TABLE #bp
			(
				 DebtGuid UNIQUEIDENTIFIER,
				 PayGuid  UNIQUEIDENTIFIER,
				 enDate	  DATE
			)

		INSERT INTO #Result
		SELECT  
			PAY.[PaymentGuid] AS [PaymentGUID], 
			PAY.[PaymentDate] AS [Date],
			Pay.[UpdatedValueWithCurrency] / bu.[buCurrencyVal] AS [Total],
			(@TotalPayment - @TotalPosted)/ bu.[buCurrencyVal] AS Dif
		FROM  
			vwBu AS Bu 
			INNER JOIN vworderpayments AS PAY ON PAY.BillGuid = Bu.buGUID 
			INNER JOIN OrAddInfo000 AS orinfo ON orinfo.[ParentGUID] = bu.[buGUID]
		WHERE  
			PAY.[BillGuid] = @OrderGuid AND Pay.[UpdatedValueWithCurrency] <> 0
			AND orinfo.Add1 <> 1 
          ORDER  BY PAY.[PaymentDate] DESC
	
		-------------------------------------------------------------------------------
		------- ⁄œÌ· ﬁÌ„ «·œ›⁄«  ›Ì Õ«· ﬂ«‰ «·ÿ·» „”·„ √Ê „”·„ Ã“∆Ì« ÊÌÊÃœ ›—ﬁ »Ì‰ ﬁÌ„… «·ÿ·»Ì… ÊﬁÌ„… «·„Ê«œ «·„”·„… ··“»Ê‰	
        IF ( @TotalPayment <> @TotalPosted )
		BEGIN
		DECLARE @PaymentGUID UNIQUEIDENTIFIER,
				@DebtGuid UNIQUEIDENTIFIER,
				@bp_Cursor Cursor,
				@PayGuid UNIQUEIDENTIFIER,
				@Date Date,
				@Total Float,
				@Dif Float
			-------------- ⁄œÌ· ﬁÌ„… «·œ›⁄«  ›Ì Õ«· ﬂ«‰ „Ã„Ê⁄ «· —ÕÌ· √ﬂ»— „‰ ﬁÌ„… œ›⁄«  «·ÿ·»Ì…-----------
			IF (@TotalPayment < @TotalPosted)
			BEGIN
				SELECT TOP 1 @PaymentGUID = PaymentGUID, @Dif = ABS(Dif) from #Result ORDER BY Date DESC
			
				UPDATE OrderPayments000 SET UpdatedValue = UpdatedValue + @Dif WHERE Guid = @PaymentGUID
			END
			 -------------- ⁄œÌ· ﬁÌ„… «·œ›⁄«  ›Ì Õ«· ﬂ«‰ „Ã„Ê⁄ «· —ÕÌ· √’€— „‰ ﬁÌ„… œ›⁄«  «·ÿ·»Ì…-----------
			ELSE
			BEGIN
			IF (@Finished = 1 OR @TotalPayment > @OrderValue)
			BEGIN
				DECLARE i CURSOR FOR SELECT PaymentGUID, Date, Total, Dif FROM #Result ORDER BY Date DESC 
				OPEN i  
					FETCH NEXT FROM i INTO @PaymentGUID, @Date, @Total, @Dif 
					DECLARE @DifValue Float
					SET @DifValue = @Dif
			       -----------------›Ì Õ«·  „ ≈·€«¡  —ÕÌ· „‰ «· —ÕÌ·«  Êﬂ«‰  ﬁÌ„… «·–„… √ﬂ»— „‰ ﬁÌ„… «·ÿ·»Ì…--------------
				    IF(@Finished = 0 AND (@TotalPayment - @Dif) < @OrderValue)
					BEGIN
					SET @DifValue = @TotalPayment - @OrderValue
					END

					WHILE @@FETCH_STATUS = 0  
					BEGIN  
						IF (@DifValue <> 0) AND (@DifValue >= @Total AND @Total <> 0) 
								Begin
									SET @DifValue -= @Total	
									IF EXISTS (SELECT * FROM bp000 WHERE DebtGUID = @PaymentGUID OR PayGUID = @PaymentGUID)
									BEGIN
										DELETE FROM bp000 WHERE DebtGUID = @PaymentGUID OR PayGUID = @PaymentGUID
										SET @OrderPaymentUpdated = 1
									 END			
									UPDATE OrderPayments000 SET Updatedvalue = 0 WHERE Guid = @PaymentGUID
								END

						ELSE IF (@DifValue <> 0) AND (@DifValue < @Total AND @Total <> 0)
							BEGIN
								SET @Total -= @DifValue
								SET @DifValue = 0

								UPDATE OrderPayments000 SET UpdatedValue = @Total WHERE  Guid = @PaymentGUID

								IF EXISTS (SELECT * FROM   bp000 WHERE DebtGUID = @PaymentGUID OR PayGUID = @PaymentGUID)
								BEGIN
									INSERT INTO #bp 
									SELECT 
										DebtGUID, PayGUID, ISNULL(en.enDate, bu.Date)
									FROM  
										bp000 bp 
										LEFT JOIN [vwEn] en
												ON bp.DebtGUID = en.[enGuid]
													OR bp.PayGUID = en.[enGuid]
										LEFT JOIN ce000 ce
												ON en.enParent = ce.[GUID]
										LEFT JOIN er000 er
												ON er.EntryGUID = ce.[GUID]
										LEFT JOIN py000 py
												ON py.[GUID] = er.ParentGUID
										LEFT JOIN bu000 bu
												ON bu.[GUID] = bp.DebtGUID
												    OR bu.[Guid] = bp.PayGUID
									WHERE 
										DebtGUID = @PaymentGUID OR PayGUID = @PaymentGUID
									
									DELETE FROM bp000 WHERE DebtGUID = @PaymentGUID OR PayGUID = @PaymentGUID
			
									SET @bp_Cursor = CURSOR FAST_FORWARD FOR SELECT DebtGUID, PayGUID FROM #bp ORDER BY enDate
									OPEN @bp_Cursor  
									FETCH NEXT FROM @bp_Cursor INTO @DebtGuid, @PayGuid
									WHILE @@FETCH_STATUS = 0  
									BEGIN
										INSERT INTO #Temp 
										EXEC [dbo].[prcEntry_ConnectDebtPay]
										@DebtGuid,
										@PayGuid

									  FETCH NEXT FROM @bp_Cursor INTO @DebtGuid, @PayGuid
									END
								CLOSE @bp_Cursor
								DEALLOCATE @bp_Cursor
								SET @OrderPaymentUpdated = 1
								DELETE FROM #bp
								END	
							END 
						FETCH NEXT FROM i INTO  @PaymentGUID, @Date, @Total, @Dif
					END  

				CLOSE i  
				DEALLOCATE i 
			END
			END
		END 
	END  ----- END IF @FinishedRollBack = 0
	ELSE IF @FinishedRollBack = 1  -----IF order state changed from finished to active
	BEGIN
	 UPDATE 
		 OrderPayments000 SET UpdatedValue = Value
	 FROM
		 vwBu Bu
		 INNER JOIN OrderPayments000 p ON p.BillGuid = Bu.[buGuid]
	 WHERE
		 UpdatedValue < Value AND BillGuid = @OrderGuid
	END

	SELECT @OrderPaymentUpdated AS PaymentUpdated
############################################################## 
CREATE PROCEDURE prcOrder_ReconnectPayments @OrderGuid      UNIQUEIDENTIFIER,
                                            @DeletePayments Bit = 0
AS
    SET NOCount ON

    IF @DeletePayments = 0
      BEGIN
          DECLARE @c_Debt           CURSOR,
                  @c_Pay            CURSOR,
                  @d_enGUID         [UNIQUEIDENTIFIER],
                  @d_enCurrencyGUID [UNIQUEIDENTIFIER],
                  @d_enCurrencyVal  [FLOAT],
                  @d_Debt           [FLOAT],
                  @p_enGUID         [UNIQUEIDENTIFIER],
                  @p_enCurrencyGUID [UNIQUEIDENTIFIER],
                  @p_enCurrencyVal  [FLOAT],
                  @d_parentGUID     [UNIQUEIDENTIFIER],
                  @p_parentGUID     [UNIQUEIDENTIFIER],
                  @p_Pay            [FLOAT],
                  @Zero             [FLOAT],
                  @DebitType        [INT],
                  @PaymentType      [INT],
                  @DefCurr          [UNIQUEIDENTIFIER],
                  @d_CostGuid       [UNIQUEIDENTIFIER],
                  @p_CostGuid       [UNIQUEIDENTIFIER]

          SET @DefCurr = dbo.fnGetDefaultCurr()
          SET @Zero = dbo.fnGetZeroValuePrice()

          CREATE TABLE #DebitTbl
            (
               DebitGUID     UNIQUEIDENTIFIER,
               CurrencyGuid  UNIQUEIDENTIFIER,
               CurrencyValue FLOAT,
               Value         FLOAT,
               DebitType     INT,
               ParentGUID    UNIQUEIDENTIFIER,
               CostGuid      UNIQUEIDENTIFIER,
			   DebitDate	Date
            )

          CREATE TABLE #PaymentsTbl
            (
               PaymentGUID   UNIQUEIDENTIFIER,
               CurrencyGuid  UNIQUEIDENTIFIER,
               CurrencyValue FLOAT,
               Value         FLOAT,
               PaymentType   INT,
               ParentGUID    UNIQUEIDENTIFIER,
               CostGuid      UNIQUEIDENTIFIER,
			   PaymentDate	 Date
            )

		  EXEC prcUpdateOrderPayments @OrderGuid, 0
          -------«·œ›⁄«  «·ÃœÌœ… ··ÿ·»Ì… «·„⁄œ·…-------
          INSERT INTO #DebitTbl
          SELECT [orp].[PaymentGUID],
                 [ac].[CurrencyGUID],
                 CASE
                   WHEN [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN
                   [bu].[buCurrencyVal]
                   ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate])
                 END,
                 orp.UpdatedValueWithCurrency / ( CASE
                 WHEN
                 [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN
                 [bu].[buCurrencyVal]
                                                    ELSE
                 [dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate])
                                                  END ),
                 1,
                 [bu].[buGuid],
                 bu.buCostPtr,
				 CONVERT(date, [orp].[PaymentDate])
          FROM   [vwOrderPayments] AS [orp]
                 INNER JOIN [vwbu] [bu]
                         ON [bu].[buGuid] = [orp].[BillGuid]
                 INNER JOIN [ac000] AS [ac]
                         ON [bu].[buCustAcc] = [ac].[GUID]
          WHERE  [orp].[BillGuid] = @OrderGuid
          ORDER  BY CONVERT(date, [orp].[PaymentDate]) ASC

          -----------------«· ”œÌœ«  «·Œ«’… »«·ÿ·»Ì… ---------------
          INSERT INTO #PaymentsTbl
          SELECT ISNULL([en].[enGuid], [bi].[buGuid]),
                 ISNULL([enAc].[CurrencyGUID], [buAc].[CurrencyGUID]),
                 CASE ISNULL(bi.buGUID, 0x0) WHEN 0x0 THEN
					 CASE
                       WHEN [en].[enCurrencyPtr] = [enAc].[CurrencyGUID] THEN
                       [en].[enCurrencyVal]
                       ELSE [dbo].fnGetCurVal([enAc].[CurrencyGUID], [en].[enDate])
                     END
				  ELSE
				     CASE
						WHEN [bi].[buCurrencyPtr] = [buAc].[CurrencyGUID] THEN
						[bi].[buCurrencyVal]
						ELSE [dbo].fnGetCurVal([buAc].[CurrencyGUID], [bi].[buDate])
                     END
				  END,
                 SUM(CASE
                       WHEN bp.CurrencyGUID <> bu.CurrencyGUID THEN ( CASE
                       WHEN bp.CurrencyVal = 1 THEN bp.Val / bu.CurrencyVal
                       ELSE bp.Val
                                                                      END )
                       ELSE bp.Val / bu.CurrencyVal
                     END),
                 0,
                 0x0,
                 ISNULL(en.enCostPoint, bi.buCostPtr),
				 ISNULL([en].[enDate], [bi].[buDate])
          FROM   bp000 bp
                 INNER JOIN bu000 bu
                         ON bu.GUID = bp.ParentDebitGUID
                             OR bu.GUID = bp.ParentPayGUID
                 LEFT JOIN [vwEn] en
                        ON bp.DebtGUID = en.[enGuid]
                            OR bp.PayGUID = en.[enGuid]
                 LEFT JOIN ce000 ce
                        ON en.enParent = ce.[GUID]
                 LEFT JOIN er000 er
                        ON er.EntryGUID = ce.[GUID]
                 LEFT JOIN py000 py
                        ON py.[GUID] = er.ParentGUID
                 LEFT JOIN et000 et
                        ON et.[Guid] = ce.TypeGUID
                 LEFT JOIN [ac000] AS [enAc]
                         ON [en].[enAccount] = [enAc].[GUID]
				 LEFT JOIN vwExtended_bi AS bi 
				         ON bi.buGuid = bp.DebtGUID OR bi.buGUID = bp.PayGUID
				 LEFT JOIN [ac000] AS [buAc]
                         ON [bi].[buCustAcc] = [buAc].[GUID]
          WHERE  
			     bu.GUID = @OrderGuid
          GROUP  BY 
		         ISNULL([en].[enGuid], [bi].[buGuid]),
                 ISNULL([enAc].[CurrencyGUID], [buAc].[CurrencyGUID]),
                 CASE ISNULL(bi.buGUID, 0x0) WHEN 0x0 THEN
					 CASE
                       WHEN [en].[enCurrencyPtr] = [enAc].[CurrencyGUID] THEN
                       [en].[enCurrencyVal]
                       ELSE [dbo].fnGetCurVal([enAc].[CurrencyGUID], [en].[enDate])
                     END
				  ELSE
				     CASE
						WHEN [bi].[buCurrencyPtr] = [buAc].[CurrencyGUID] THEN
						[bi].[buCurrencyVal]
						ELSE [dbo].fnGetCurVal([buAc].[CurrencyGUID], [bi].[buDate])
                     END
				  END,
                 ISNULL(en.enCostPoint, bi.buCostPtr),
				 ISNULL([en].[enDate], [bi].[buDate]),
                 ISNULL([py].[Number], [bi].[buNumber])
          ORDER  BY 
				 CONVERT(Date,  ISNULL([en].[enDate], [bi].[buDate])),
                 ISNULL([py].[Number], [bi].buNumber)

          --------Õ–› «·«— »«ÿ«  «·ﬁœÌ„…------------
          DELETE FROM bp000
          WHERE  ParentDebitGUID = @OrderGuid
                  OR ParentPayGUID = @OrderGuid

          ---------≈œŒ«· «·«— »«ÿ«  «·ÃœÌœ… ------------
          CREATE TABLE #bp_result
            (
               [DebtGUID] UNIQUEIDENTIFIER,
               [PayGUID]  UNIQUEIDENTIFIER
            )

          SELECT @d_enGUID = DebitGUID,
                 @d_enCurrencyGUID = CurrencyGuid,
                 @d_enCurrencyVal = CurrencyValue,
                 @d_Debt = Value,
                 @DebitType = DebitType,
                 @d_parentGUID = ParentGUID,
                 @d_CostGuid = CostGuid
          FROM   #DebitTbl

          SELECT @p_enGUID = PaymentGUID,
                 @p_enCurrencyGUID = CurrencyGuid,
                 @p_enCurrencyVal = CurrencyValue,
                 @p_Pay = Value,
                 @PaymentType = PaymentType,
                 @p_parentGUID = ParentGUID,
                 @p_CostGuid = CostGuid
          FROM   #PaymentsTbl

          SET @c_Debt = CURSOR FAST_FORWARD
          FOR SELECT DebitGUID,
                     CurrencyGuid,
                     CurrencyValue,
                     Value,
                     DebitType,
                     ParentGUID
              FROM   #DebitTbl
			  ORDER BY DebitDate ASC
          SET @c_Pay = CURSOR FAST_FORWARD
          FOR SELECT PaymentGUID,
                     CurrencyGuid,
                     CurrencyValue,
                     Value,
                     PaymentType,
                     ParentGUID
              FROM   #PaymentsTbl

          OPEN @c_Debt

          OPEN @c_Pay

          FETCH FROM @c_Debt INTO @d_enGUID, @d_enCurrencyGUID, @d_enCurrencyVal
          ,
          @d_Debt, @DebitType, @d_parentGUID

          IF @@FETCH_STATUS <> 0
            GOTO NextAccount

          FETCH FROM @c_Pay INTO @p_enGUID, @p_enCurrencyGUID, @p_enCurrencyVal,
          @p_Pay, @PaymentType, @p_parentGUID

          IF @@FETCH_STATUS <> 0
            GOTO NextAccount

          WHILE 1 = 1
            BEGIN
                IF @d_Debt < @p_Pay
                  BEGIN
                      SET @p_Pay = @p_Pay - @d_Debt

                      INSERT INTO [bp000]
                                  ([DebtGUID],
                                   [PayGUID],
                                   [PayType],
                                   [Val],
                                   [CurrencyGUID],
                                   [CurrencyVal],
                                   [RecType],
                                   [DebitType],
                                   ParentDebitGUID,
                                   ParentPayGUID,
                                   [PayVal],
                                   [PayCurVal])
                      VALUES     ( @d_enGUID,
                                   @p_enGUID,
                                   @PaymentType,
                                   @d_Debt * @d_enCurrencyVal,
                                   @d_enCurrencyGUID,
                                   @d_enCurrencyVal,
                                   0,
                                   @DebitType,
                                   @d_parentGUID,
                                   @p_parentGUID,
                                   @d_Debt * @p_enCurrencyVal,
                                   @p_enCurrencyVal)

                      FETCH FROM @c_Debt INTO @d_enGUID, @d_enCurrencyGUID,
                      @d_enCurrencyVal
                      ,
                      @d_Debt, @DebitType, @d_parentGUID

                      IF @@FETCH_STATUS <> 0
                        BREAK
                  END
                ELSE IF @d_Debt > @p_Pay
                  BEGIN
                      SET @d_Debt = @d_Debt - @p_Pay

                      INSERT INTO [bp000]
                                  ([DebtGUID],
                                   [PayGUID],
                                   [PayType],
                                   [Val],
                                   [CurrencyGUID],
                                   [CurrencyVal],
                                   [RecType],
                                   [DebitType],
                                   ParentDebitGUID,
                                   ParentPayGUID,
                                   [PayVal],
                                   [PayCurVal])
                      VALUES     ( @d_enGUID,
                                   @p_enGUID,
                                   @PaymentType,
                                   @p_Pay * @d_enCurrencyVal,
                                   @p_enCurrencyGUID,
                                   @d_enCurrencyVal,
                                   0,
                                   @DebitType,
                                   @d_parentGUID,
                                   @p_parentGUID,
                                   @p_Pay * @p_enCurrencyVal,
                                   @p_enCurrencyVal)

                      FETCH FROM @c_Pay INTO @p_enGUID, @p_enCurrencyGUID,
                      @p_enCurrencyVal,
                      @p_Pay, @PaymentType, @p_parentGUID

                      IF @@FETCH_STATUS <> 0
                        BREAK
                  END
                ELSE -- @d_Debt = @p_Pay 
                  BEGIN
                      INSERT INTO [bp000]
                                  ([DebtGUID],
                                   [PayGUID],
                                   [PayType],
                                   [Val],
                                   [CurrencyGUID],
                                   [CurrencyVal],
                                   [RecType],
                                   [DebitType],
                                   ParentDebitGUID,
                                   ParentPayGUID,
                                   [PayVal],
                                   [PayCurVal])
                      VALUES     ( @d_enGUID,
                                   @p_enGUID,
                                   @PaymentType,
                                   @p_Pay * @d_enCurrencyVal,
                                   @p_enCurrencyGUID,
                                   @d_enCurrencyVal,
                                   0,
                                   @DebitType,
                                   @d_parentGUID,
                                   @p_parentGUID,
                                   @p_Pay * @p_enCurrencyVal,
                                   @p_enCurrencyVal)

                      FETCH FROM @c_Debt INTO @d_enGUID, @d_enCurrencyGUID,
                      @d_enCurrencyVal
                      ,
                      @d_Debt, @DebitType, @d_parentGUID

                      IF @@FETCH_STATUS <> 0
                        BREAK

                      FETCH FROM @c_Pay INTO @p_enGUID, @p_enCurrencyGUID,
                      @p_enCurrencyVal,
                      @p_Pay, @PaymentType, @p_parentGUID

                      IF @@FETCH_STATUS <> 0
                        BREAK
                  END
            END

          NEXTACCOUNT:

          CLOSE @c_Debt

          CLOSE @c_Pay

		  DEALLOCATE @c_Debt
		  DEALLOCATE @c_Pay
      END
    ELSE
      BEGIN
          DELETE FROM bp000
          WHERE  ParentDebitGUID = @OrderGuid
                  OR ParentPayGUID = @OrderGuid
      END 
##############################################################
#END     
