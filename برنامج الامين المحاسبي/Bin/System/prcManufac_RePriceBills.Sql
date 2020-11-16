#########################################################
CREATE PROCEDURE prcManufac_ReGenBillEntry
	@StartDate	DATETIME, 
	@EndDate	DATETIME                 
AS 
/*
This  Procedure Used To Regenrate Manufacture Bill Entry
*/
Declare @source uniqueidentifier = newid()
DECLARE @OutBillTypeGuid		UNIQUEIDENTIFIER 
DECLARE @InBillTypeGuid			UNIQUEIDENTIFIER 
DECLARE @OutSemiBillTypeGuid	UNIQUEIDENTIFIER 

SELECT  @InBillTypeGuid = GUID FROM BT000 WHERE Type = 2 AND SortNum = 5 
SELECT  @OutBillTypeGuid = GUID FROM BT000 WHERE Type = 2 AND SortNum = 6 
SELECT @outSemiBillTypeGuid = cast((SELECT [VALUE] FROM op000 WHERE [NAME] ='man_semiconduct_outbilltype')as uniqueidentifier)  

INSERT INTO RepSrcs(IdTbl,IdType,IdSubType) VALUES(@source,@OutBillTypeGuid ,2 )
INSERT INTO RepSrcs(IdTbl,IdType,IdSubType) VALUES(@source,@InBillTypeGuid ,2 )
IF (ISNULL(@OutSemiBillTypeGuid,0x0) <> 0x0)
INSERT INTO RepSrcs(IdTbl,IdType,IdSubType) VALUES(@source,@outSemiBillTypeGuid ,2 )

EXEC prcBill_reGenEntry @source ,@StartDate ,@EndDate
Delete From RepSrcs WHERE IdTbl = @source 
#########################################################
CREATE PROCEDURE prcManufac_RePriceBills
	@StartDate	DATETIME,
	@EndDate	DATETIME,
	@PriceType	INT = 0,
	@StageCount INT = 1	
AS
/* 
	Summery : ≈⁄«œ…  ”⁄Ì— ›Ê«Ì — «· ’‰Ì⁄ Õ”» ”Ì«”… «· ”⁄Ì— «·„„——… 
	Major Modification : ≈÷«›… Õ”«» «· ﬂ«·Ì› «·≈÷«›Ì… Ê «·≈Ã„«·Ì… ·›Ê« Ì— ⁄„·Ì«  «· ’‰Ì⁄ 
				≈·Ï ≈Ã„«·Ì «·›« Ê—… ›Ì Õ«· ﬂ«‰  «·›« Ê—… ·«  Ê·œ ﬁÌœ »«· ﬂ«·Ì› «·≈÷«›Ì… 	 
*/ 
	SET NOCOUNT ON 
	DECLARE @i AS INT 
	SET @i = 0 
	DECLARE @MnStageCount AS INT 
	SET @MnStageCount = ISNULL ((Select Max(PhaseNumber) From Mn000), 0)
	IF (@StageCount > @MnStageCount)
	SET @StageCount = @MnStageCount
	WHILE (@i < @StageCount) 
	BEGIN 
		SET @i = @i + 1 
		------  œﬁÌﬁ √—’œ… «·„Ê«œ Ê «·√”⁄«— 
		EXEC prcBill_rePost 
		EXEC prcDisableTriggers	'bi000'  
		-- ≈⁄«œ…  ”⁄Ì— ›Ê« Ì— ≈Œ—«Ã «·„Ê«œ «·√Ê·Ì… 
		DECLARE @OutTypeGUID AS UNIQUEIDENTIFIER 
		DECLARE @outSemiBillTypeGuid AS UNIQUEIDENTIFIER 
		DECLARE @isSemiMatBillReq AS INT 
		SELECT @OutTypeGUID = GUID FROM BT000 WHERE Type = 2 AND SortNum = 6 
		SELECT @outSemiBillTypeGuid =cast((SELECT [VALUE] FROM op000 WHERE [NAME] ='man_semiconduct_outbilltype')as uniqueidentifier)  
		--SELECT @isSemiMatBillReq = VALUE FROM OP000 WHERE NAME LIKE 'is_SemiManedMat_Bill_Required'     
		SET @isSemiMatBillReq = 1;
		----------------------------   
		UPDATE [bi000] SET   
				[Price] = 
				 (CASE (SELECT dbo.CanRepriceManufacturingMaterial(mt.GUID))
						WHEN 0 THEN  
								bi.UnitCostPrice
						WHEN 2 THEN 
								bi.UnitCostPrice
						WHEN 1 THEN 
								bi.Price
                  END)
		
			FROM    
				[bi000] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID]   
				INNER JOIN [bu000] AS [bu] ON [bi].[ParentGUID] = [bu].[GUID]
				INNER JOIN [MB000] [mb] ON [mb].[BillGUID] = [bu].[GUID]
				INNER JOIN [MN000] [mn] ON [mn].GUID = mb.ManGUID
			WHERE    
				[bi].[Qty] > 0  AND 
				([bu].[TypeGUID] = @OutTypeGUID OR (@isSemiMatBillReq = 0 OR [bu].[TypeGUID] = @outSemiBillTypeGuid)) AND 
				[bu].[Date] BETWEEN @StartDate AND @EndDate 

		-- ≈⁄«œ… Õ”«» „Ã«„Ì⁄ «·›Ê« Ì— 
		EXEC [prcCheckDB_bu_Sums] 1  
		 
		------ ≈⁄«œ…  ”⁄Ì— ›Ê« Ì— ≈œŒ«· «·„Ê«œ «·Ã«Â“… Õ”» ›Ê« Ì— ≈Œ—«Ã «·„Ê«œ «·√Ê·Ì…	 
		--in bill guid , out bill guid , mn guid , mn.flag	initially 0, extra cost  initially 0 
		SELECT  [BILLIN],--›« Ê—… «··≈œŒ«·  
			[OUTP].[BILLOUT] AS [BILLOUT],-- ›« Ê—… «·≈Œ—«Ã  
			[SEMIOUTP].[BILLOUT] AS [SEMIOUTP],--›« Ê—… «Œ—«Ã ‰’› „’‰⁄ 
			[INP].[ManGuid] AS [ManGuid] ,-- ⁄„·Ì… «· ’‰Ì⁄ 
			mn.flags as flag ,--  Ê·œ ﬁÌœ »«· ﬂ«·Ì› «·≈÷«›Ì… 
			0 as extra ,-- ≈Ã„«·Ì «· ﬂ«·Ì› «·≈÷«›Ì… 
			1 as totalReadyMat -- ⁄œœ «·„Ê«œ «·Ã«Â“… 
		INTO #MANBILL  
		FROM  
			(SELECT [BILLGUID] AS [BILLIN],[ManGuid] FROM [MB000] WHERE  [TYPE] = 1) AS [INP]  
		INNER JOIN	  
			(SELECT [BILLGUID] AS [BILLOUT],[ManGuid] FROM [MB000] WHERE  [TYPE] = 0) AS [OUTP]   
		ON [INP].[ManGuid] = [OUTP].[ManGuid] 
		LEFT JOIN	  
			(SELECT [BILLGUID] AS [BILLOUT],[ManGuid] FROM [MB000] WHERE  [TYPE] = 2) AS [SEMIOUTP]   
		ON [INP].[ManGuid] = [SEMIOUTP].[ManGuid] 
		INNER JOIN mn000 as mn on [INP].[ManGuid] = mn.guid      
			 
		DECLARE @inBill UNIQUEIDENTIFIER, 
			@outBill UNIQUEIDENTIFIER, 
			@manGuid UNIQUEIDENTIFIER, 
			@flag FLOAT(53), 
			@extra FLOAT(53), 
			@totalReadyMat INT  
			 
		-- Ì” Œœ„ ··œÊ—«‰ ⁄·Ï ⁄„·Ì«  «· ’‰Ì⁄ Ê›Ê« Ì— ≈œŒ«·Â« Ê ≈Œ—«ÃÂ«  
		-- Ê ⁄œÌ· «· ﬂ«·Ì› «·≈÷«›Ì… «· Ì „‰ À„  Ã„⁄ ··›« Ê—…  
		DECLARE MANBILL_CURSOR cursor FORWARD_ONLY for  
		SELECT [BILLIN], [BILLOUT], [ManGuid], flag, extra, totalReadyMat FROM #MANBILL 
		OPEN MANBILL_CURSOR 
		 
		FETCH NEXT FROM MANBILL_CURSOR INTO  
		@inBill , @outBill , @manGuid , @flag , @extra ,@totalReadyMat  
		DECLARE @mxExtra FLOAT(53),-- ﬁÌ„… «· ﬂ«·Ì›  
				@mxDiscount FLOAT(53),-- ‰”»… «· ﬂ«·Ì›  
				@mxFlag  INT , -- ‰Ê⁄ «· ﬂ«·Ì› ≈›—«œÌ… √Ê ≈Ã„«·Ì…  
				@previousExtra FLOAT(53)-- „Ã„Ê⁄ «· ﬂ«·Ì› «·≈÷«›Ì… »€÷ «·‰Ÿ— ⁄‰ ‰Ê⁄Â«  
				Set @previousExtra  = 0  
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			--SELECT @flag = flags FROM mn000 WHERE guid = @manGuid 
			IF  @flag = 0 -- ⁄„·Ì…  ’‰Ì⁄ ·«  Ê·œ ﬁÌœ »«· ﬂ«·Ì›  
			BEGIN  
				-- Ã·» «· ﬂ«·Ì› «·≈÷«›Ì… ·⁄„·Ì… «· ’‰Ì⁄ «·Õ«·Ì… 			 
				DECLARE mxCursor CURSOR FORWARD_ONLY FOR  
				SELECT extra , Discount , Flag   
				FROM mx000 
				WHERE parentguid = @manGuid 
				select @totalReadyMat = count(*) 
				from mi000 
				where type = 0 and parentguid =  @manGuid 
				 
				OPEN mxCursor 
				FETCH NEXT FROM mxCursor INTO @mxExtra, @mxDiscount, @mxFlag 
									 
				WHILE @@FETCH_STATUS = 0  
				BEGIN  
						IF @mxFlag = 0 --  ﬂ«·Ì› ≈÷«›Ì… ≈›—«œÌ…  
						BEGIN 
							IF @mxExtra = 0 -- «· ﬂ«·Ì› „Œ“‰… ﬂ‰”»…  
							BEGIN  
								-- „Ã„Ê⁄  ﬂ·›… «·„Ê«œ «·√Ê·Ì… œ«Œ· ‰„Ê–Ã «· ’‰Ì⁄ 
								DECLARE @rawMatSum FLOAT(53) 
								SELECT @rawMatSum = Sum(Bi.Price * Bi.Qty) FROM Bu000 Bu 
								INNER JOIN Mb000 Mb ON Bu.Guid = Mb.BillGuid 
								INNER JOIN Bi000 Bi ON Bi.ParentGuid = Bu.Guid 
								WHERE Mb.ManGuid = @manGuid  
										AND Mb.Type = 0 
								-- «· ﬂ«·Ì› = «·‰”»… *„Ã„Ê⁄ «·„Ê«œ «·√Ê·Ì… ⁄·Ï 100 
								SET @mxExtra = @mxDiscount * @rawMatSum / 100  
							END 
						END 
						 
						ELSE --  ﬂ«·Ì› ≈÷«›Ì… ≈Ã„«·Ì… 
						BEGIN  
								IF @mxExtra = 0 -- «· ﬂ«·Ì› „Œ“‰… ﬂ‰”»…  
								BEGIN  
									SELECT @rawMatSum = isnull(sum(price),0) 
									FROM mi000  
									WHERE type = 0  and parentguid = @manGuid 
									 
										-- «· ﬂ«·Ì› = «·‰”»… *„Ã„Ê⁄ «·„Ê«œ «·√Ê·Ì… ⁄·Ï 100 
									SET  @mxExtra = @mxDiscount * @rawMatSum / 100  
								END	 
									--  ﬁ”Ì„ «· ﬂ·›… «·≈Ã„«·Ì… ⁄·Ï ⁄œœ «·‰„«–Ã «·„’‰⁄…  
									DECLARE @qty INT    
									SELECT @qty = qty FROM mn000 WHERE guid = @manGuid 
									SET @mxExtra = @mxExtra / @Qty  
						End 
				 
				/* 
					Ã„⁄ «· ﬂ«·Ì› «·≈÷«›Ì…  Ê  «·≈›—«œÌ… „⁄ »⁄÷Â« ·‰›” ⁄„·Ì…   «· ’‰Ì⁄ Ê „—«ﬂ„ Â«  
					 ›Ì „ €Ì— Ê«Õœ Â–Â «·ﬁÌ„… ” Œ“‰ ›Ì «·ÃœÊ· ·Ì „ «” Œœ«„Â« ·«Õﬁ« √À‰«¡  ”⁄Ì— «·›« Ê—…  
					›Ì Õ«· ﬂ«‰  ⁄„·Ì… «· ’‰Ì⁄ ·«  Ê·œ ﬁÌœ »«· ﬂ«·Ì› «·≈÷«›Ì…  
				*/ 
				SET @previousExtra = @previousExtra + @mxExtra 
				 
				--  ÕœÌÀ «· ﬂ·›… «·≈÷«›Ì… Ê «·≈Ã„«·Ì… „⁄« ·⁄„·Ì… «· ’‰Ì⁄ «·Õ«·Ì…  
				--Â–Â «·ﬁÌ„… ” Ã„⁄ ≈·Ï ”⁄— «·›« Ê—… ›Ì Õ«· ﬂ«‰  ·«  Ê·œ ﬁÌœ »«· ﬂ«·Ì› «·≈÷«›Ì… 
				UPDATE #MANBILL SET flag = @flag , extra = @previousExtra , totalReadyMat=@totalReadyMat 
				WHERE  [ManGuid] = @manGuid  
				 
				FETCH NEXT FROM mxCursor  
				INTO @mxExtra, @mxDiscount, @mxFlag 
			END -- inner cousor while 
				 
				-- reset variable for next cursor iterations 
				SET @previousExtra =  0 
				CLOSE mxCursor  
				DEALLOCATE mxCursor 
				 
			END -- if flag = 0  
				 
						 
				FETCH NEXT FROM MANBILL_CURSOR INTO  
				@inBill , @outBill , @manGuid , @flag , @extra ,@totalReadyMat 
		End	-- outer cousor while  
		 
		CLOSE MANBILL_CURSOR  
		DEALLOCATE MANBILL_CURSOR 
		-- «” À‰«¡ «·„Ê«œ Ê«· ﬂ«·Ì› «·„— »ÿ… „‰ ≈Ã„«·Ì ›« Ê—… «·≈Œ—«Ã 
		SELECT  
			mn.Guid ManGuid, 
			( 
				SELECT Sum(bi.Price * bi.Qty) 
				FROM    bi000 bi 
					INNER JOIN mb000 mb ON mb.BillGuid = bi.ParentGuid 
					INNER JOIN mi000 mi ON bi.MatGUID = mi.MatGUID and bi.Number = mi.Number AND mi.ParentGuid = mn.Guid 
				WHERE (mb.Type = 0 OR mb.Type = 2) AND mb.ManGuid = mn.Guid 
					AND  mi.ReadyMatGuid <> 0x0 
				GROUP BY bi.ParentGUID 
			) ExcludedLinkedMatVal, 
			( 
				SELECT Sum(Extra) 
				FROM    mx000 mx 
				WHERE mx.ParentGUID = mn.Guid  
					AND ReadyMatGuid <> 0x0 
				GROUP BY mx.ParentGUID 
			) ExcludedLinkedCostVal 
		INTO #ExcludedValuesFromOutputBill 
		FROM mn000 mn 
		WHERE mn.Type = 1 
		--  Õ„Ì· «·„Ê«œ «·√Ê·Ì… Ê«· ﬂ«·Ì› «·≈÷«›Ì… ⁄·Ï «·„Ê«œ «·Ã«Â“… «·„— »ÿ… »Â« 
		SELECT  
			mn.Guid ManGuid, 
			mi.MatGUid, 
			( 
				SELECT Sum(bi.Price * bi.Qty) 
				FROM    bi000 bi 
					INNER JOIN mb000 mb ON mb.BillGuid = bi.ParentGuid 
					INNER JOIN mi000 Submi ON bi.MatGUID = Submi.MatGUID and bi.Number = submi.Number AND Submi.ParentGuid = mn.Guid 
				WHERE (mb.Type = 0 OR mb.Type = 2) AND mb.ManGuid = mn.Guid 
					AND  Submi.ReadyMatGuid = mi.MatGUID 
				GROUP BY Submi.ReadyMatGuid 
			) IncludedLinkedMatVal, 
			( 
				SELECT Sum(Extra) 
				FROM    mx000 mx 
				WHERE mx.ParentGUID = mn.Guid  
					AND mx.ReadyMatGuid = mi.MatGUID 
				GROUP BY mx.ReadyMatGuid 
			) IncludedLinkedCostVal 
		INTO #LinkedMatAndCostValue 
		FROM mn000 mn 
		INNER JOIN mi000 mi ON mi.ParentGUID = mn.Guid 
		WHERE mn.Type = 1 
			AND mi.Type = 0 
		--  ⁄œÌ· √”⁄«— ﬂ· «·›Ê« Ì— Ê ›Ì Õ«· ﬂ«‰  ·«  Ê·œ ﬁÌœ »«· ﬂ«·Ì› «·≈÷«›Ì… Ã„⁄  
		-- «· ﬂ«·Ì› «·„Õ”Ê»… „”»ﬁ« ≈·Ï ”⁄— «·›« Ê—…  	
		UPDATE BI000 SET Price =  
		( 
			outBu.outTotal / bi.Qty  
			*(CASE bi.Unity WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact ELSE 1 END)--„⁄«·Ã… «·ÊÕœ… 
			*(CASE outBu.percentage when 0 then 0 else outBu.percentage / 100 END)--„⁄«·Ã… ⁄«„· «· ﬁ”Ì„ 
		) 
		+ 
		ISNULL( 
			IncludedLinkedMatVal / bi.Qty 
			* (CASE bi.Unity WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact ELSE 1 END)--„⁄«·Ã… «·ÊÕœ… 
		, 0) 
		+ 
		ISNULL( 
			IncludedLinkedCostVal / bi.Qty 
			* (CASE bi.Unity WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact ELSE 1 END)--„⁄«·Ã… «·ÊÕœ… 
		, 0) 
		FROM	 
			Bi000 AS bi, 
			( 
				SELECT ( 
							(bu2.Total + ISNULL(bu3.Total, 0) + bu2.TotalExtra + (case mb.flag when 0 then mb.extra else 0 End)  
							- ISNULL(ExcludedLinkedMatVal, 0) - ISNULL(ExcludedLinkedCostVal, 0)) 
					   ) AS outTotal,  
					   lmt.IncludedLinkedMatVal, 
					   lmt.IncludedLinkedCostVal, 
					   bi.MatGUID, 
					   bi.GUID AS GUID, 
					   mi.percentage as percentage  
				FROM 
					mi000 as mi INNER JOIN   
					#MANBILL AS mb 	on mi.parentguid = mb.manguid 
					INNER JOIN bu000 AS bu1 ON [BILLIN] = bu1.GUID 
					INNER JOIN bu000 AS bu2 ON [BILLOut] = bu2.GUID	 
					LEFT JOIN bu000 AS bu3 ON [SEMIOUTP] = bu3.GUID	 
					INNER JOIN bi000 AS bi ON bi.ParentGUID = bu1.GUID and bi.MatGuid = mi.matguid and bi.storeguid = mi.storeguid 
					LEFT JOIN #ExcludedValuesFromOutputBill AS ExValues ON mb.ManGuid = ExValues.ManGuid 
					LEFT JOIN #LinkedMatAndCostValue lmt ON lmt.ManGuid = mi.parentguid AND lmt.MatGUID = mi.MatGUid 
					inner join MN000 mn on mn.GUID = mb.ManGuid
				WHERE [bu1].[Date] BETWEEN @StartDate AND @EndDate and mi.type = 0  
				      	 
			) AS outBu, 
			MT000  AS mt		 
		WHERE 
			bi.GUID = outbu.GUID AND bi.MatGUID = mt.GUID 
		DROP TABLE #MANBILL  
		DROP TABLE #ExcludedValuesFromOutputBill
		DROP Table #LinkedMatAndCostValue
		EXEC prcEnableTriggers 'bi000'  
		EXEC [prcCheckDB_bu_Sums] 1  
	END 
	-- ≈⁄«œ…  ”⁄Ì— „Ê«œ ‰„Ê–Ã ⁄„·Ì… «· ’‰Ì⁄ „‰ «·›Ê« Ì— 
	UPDATE [mi] SET [mi].[Price] = [bi].[Price] 
	FROM [bi000] bi 
		INNER JOIN [bu000] [bu] ON [bi].[ParentGUID] = [bu].[Guid] 
		INNER JOIN [MB000] [mb] ON [mb].[BillGUID] = [bu].[GUID] 
		INNER JOIN [MI000] [mi] ON [mi].[ParentGUID] = [mb].[ManGUID] AND [mi].[MatGUID] = [bi].[MatGUID] AND mi.Number = bi.Number
	WHERE [bu].[Date] BETWEEN @StartDate AND @EndDate 
--- regeneration of Entry 
--Declare @source uniqueidentifier = newid() ,@InTypeGuid uniqueidentifier
--SELECT  @InTypeGuid = GUID FROM BT000 WHERE Type = 2 AND SortNum = 5 
--INSERT INTO RepSrcs(IdTbl,IdType,IdSubType) VALUES(@source,@OutTypeGUID ,2 )
--INSERT INTO RepSrcs(IdTbl,IdType,IdSubType) VALUES(@source,@outSemiBillTypeGuid ,2 )
--INSERT INTO RepSrcs(IdTbl,IdType,IdSubType) VALUES(@source,@InTypeGuid ,2 )
--EXEC prcBill_reGenEntry @source ,@StartDate ,@EndDate
--Delete From RepSrcs WHERE IdTbl = @source
EXEC prcManufac_ReGenBillEntry @StartDate , @EndDate
#########################################################
#END