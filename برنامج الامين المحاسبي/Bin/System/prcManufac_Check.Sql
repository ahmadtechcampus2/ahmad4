#########################################################
##	prcManufac_check
##	return a recordset with the:
##				ManPtr
##				BillPtr means the formptr or the billPtr depends on the errortype
##				BillType
##				ErrorType meand the error type ( 0, 32)
CREATE PROCEDURE prcManufac_check 
	@InBillType [UNIQUEIDENTIFIER],  
	@OutBillType [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	DECLARE 
		@Result TABLE (
			[ManGUID] [UNIQUEIDENTIFIER],
			[BillGUID] [UNIQUEIDENTIFIER],
			[BillTypeGUID] [UNIQUEIDENTIFIER],
			[ErrorType] [INT])  

	DECLARE @outSemiBillTypeGuid [UNIQUEIDENTIFIER]
	SELECT @outSemiBillTypeGuid =cast((SELECT [VALUE] FROM op000 WHERE [NAME] ='man_semiconduct_outbilltype')as uniqueidentifier)

	DECLARE @SemiManGroup UNIQUEIDENTIFIER   
	SET @SemiManGroup = (SELECT [Value] FROM op000 WHERE [Name] ='man_semiconductGroup')   

	-- ›Ê« Ì— «· ’‰Ì⁄ «·€Ì— „— »ÿ… »√Ì ⁄„·Ì…  ’‰Ì⁄  
	INSERT INTO @Result
		SELECT  
			0x0, 
			[bu].[buGUID],  
			[bu].[buType], 
			0 
		FROM  
			[vwbu] AS [bu]  
			LEFT OUTER JOIN [MB000] AS [mb]
			ON [bu].[buGUID] = [mb].[BillGUID]  --- SELECT * FROM MB000
		WHERE  
			[mb].[BillGUID] IS NULL AND ([bu].[buType] = @InBillType OR [bu].[buType] = @OutBillType)

	-- ›Ê« Ì— ≈œŒ«· «·„Ê«œ «·Ã«Â“… «·„ﬂ——… ›Ì √ﬂÀ— „‰ ⁄„·Ì…  
	UNION ALL
		SELECT   
				0x00,
				[mb].[BillGUID],
				@InBillType,
				1  
		From   
			[MB000] As [mb]  
		GROUP by
			[mb].[BillGUID]
		HAVING
			COUNT(*) > 1

	--»ÿ«ﬁ«   ’‰Ì⁄  ÕÊÌ √Œÿ«¡   
	UNION ALL

	-- Œÿ√ ›Ì —ﬁ„ ⁄„·Ì… «· ’‰Ì⁄  
		SELECT [mnGUID], 0x0, 0x0, 2 FROM [vwMn] WHERE [mnType] = 1 AND ([mnNumber] = 0 OR [mnNumber] IS NULL)

	UNION ALL
	-- Œÿ√ ›Ì —ﬁ„ ›« Ê—… «·≈œŒ«· ÷„‰ ⁄„·Ì… «· ’‰Ì⁄  
		SELECT [mnGUID], 0x0, 0x0, 3 FROM [vwMn] AS [mn]	INNER JOIN [MB000] AS [mb] ON [mn].[mnGUID] = [mb].[ManGUID]
													INNER JOIN [vwBu] AS [bu] On [mb].[BillGUID] = [bu].[buGUID]
		WHERE ([bu].[buNumber] = 0 OR [bu].[buNumber] IS NULL)  AND [mn].[mnType] = 1

	UNION ALL
	-- Œÿ√ ›Ì —ﬁ„ »ÿ«ﬁ… «·‰„Ê–Ã «·„” Œœ„ ›Ì ⁄„·Ì… «· ’‰Ì⁄  
		SELECT [mnGUID], 0x0, 0x0, 5 FROM [vwMn] WHERE [mnFormGUID] = 0x0 OR [mnFormGUID] IS NULL  

	UNION ALL
	-- Œÿ√ ›Ì ”Ì«”… «· ”⁄Ì— «·„” Œœ„… ÷„‰ ⁄„·Ì… «· ’‰Ì⁄  
		SELECT [mnGUID], 0x0, 0x0, 6 FROM [vwMn] WHERE ([mnType] = 1) AND ([mnPriceType] < 0 OR [mnPriceType] > 3 OR [mnPriceType] IS NULL)

	UNION ALL
	-- Œÿ√ ›Ì «·ﬁÌ„… «·≈Ã„«·Ì… ·⁄„·Ì… «· ’‰Ì⁄  
		SELECT [mnGUID], 0x0, 0x0, 7 FROM [vwMn] WHERE ([mnType] = 1 AND [mnTotalPrice] = 0) OR [mnTotalPrice] IS NULL

	UNION ALL
	-- Œÿ√ ›Ì «·⁄„·… Ê«· ⁄«œ· «·„” Œœ„ ÷„‰ ⁄„·Ì… «· ’‰Ì⁄  
		SELECT [mnGUID], 0x0, 0x0, 8 FROM [vwMn] WHERE [mnCurrencyGUID] = 0x0 OR [mnCurrencyGUID] IS NULL   
											OR [mnCurrencyVal] = 0 OR [mnCurrencyVal] IS NULL  

	UNION ALL
	-- Œÿ√ ›Ì Õ”«» «·≈œŒ«· «·Ê”Ìÿ «·„” Œœ„ ÷„‰ ⁄„·Ì… «· ’‰Ì⁄  
		SELECT [mnGUID], 0x0, 0x0, 9 FROM [vwMn] WHERE [mnType] = 1 AND ([mnInTempAcc] = 0x0	OR [mnInTempAcc] IS NULL)

	UNION ALL
	-- Œÿ√ ›Ì Õ”«» «·≈Œ—«Ã «·Ê”Ìÿ «·„” Œœ„ ÷„‰ ⁄„·Ì… «· ’‰Ì⁄  
		SELECT [mnGUID], 0x0, 0x0, 10 FROM [vwMn] WHERE [mnType] = 1 AND ([mnOutTempAcc] = 0x0	OR [mnOutTempAcc] IS NULL)

	UNION ALL
	-- ⁄„·Ì«  «· ’‰Ì⁄  ÕÊÌ √—ﬁ«„ ›Ê« Ì— €Ì— „ÊÃÊœ…
		SELECT   
			[mn].[mnGUID],  
			[mb].[BillGUID],  
			@InBillType,  
			11  
		FROM   
			[vwMn] AS [mn]  INNER JOIN [MB000] AS [mb] ON [mn].[mnGUID] = [mb].[ManGUID]
		WHERE   
			(    
			[mb].[BillGUID] NOT IN ( SELECT [buGUID] FROM [vwBu] WHERE [buType] = @InBillType OR buType = @OutBillType)   
			AND [mb].[Type] <> 2
		)
			OR ( 
			[mb].[BillGUID] NOT IN ( SELECT [buGUID] FROM [vwBu] WHERE buType = @outSemiBillTypeGuid)   
			AND [mb].[Type] = 2 AND ISNULL(@SemiManGroup, 0x0) <> 0x0 AND [mn].[mnGUID] IN ( 
															SELECT Mn.Guid  
															FROM Mn000 Mn 
															INNER JOIN Mi000 Mi ON Mi.ParentGuid = Mn.Guid 
															INNER JOIN Mt000 Mt ON Mi.MatGuid = Mt.Guid 
															WHERE Mn.Type = 1 AND Mi.Type = 1 AND Mt.GroupGuid IN (SELECT Guid FROM fnGetGroupsList(@SemiManGroup)) 
														) 
				)
	UNION ALL
	--»ÿ«ﬁ«  «· ’‰Ì⁄  ÕÊÌ √—ﬁ«„ ‰„«–Ã €Ì— „ÊÃÊœ…  
		SELECT   
			[mn].[mnGUID],  
			[mn].[mnFormGUID],  
			0x0,  
			12  
		FROM   
			[vwMn] AS [mn]
		WHERE   
			[mn].[mnFormGUID] NOT IN ( SELECT [fmGUID] FROM [vwFm] )  

	UNION ALL
	-- »ÿ«ﬁ«  «·‰„«–Ã  ÕÊÌ √Œÿ«¡  
	-- Œÿ√ ›Ì «·⁄„·… Ê«· ⁄«œ·  
		select
				[fmGUID] AS [ManGUID],
				0x0 AS [BillNumber],  
				0x0 AS [BillType],   
				13 AS [ErrorCode]  
		from [vwFm] AS [fm]
		WHERE   
			[fm].[fmCurrencyGUID] = 0x0 OR [fm].[fmCurrencyGUID] IS NULL OR [fm].[fmCurrencyVal] = 0 OR [fm].[fmCurrencyVal] IS NULL  

	UNION ALL
	-- Œÿ√ ›Ì  «—ÌŒ «·‰„Ê–Ã  
		select 	  
				[mn].[mnGUID] AS [ManGUID],  
				0x0 AS [BillNumber],  
				0x0 AS [BillType],   
				14 AS [ErrorCode]  
		from [vwMn]  AS [mn]
		WHERE   
			[mn].[mnDate] IS NULL  

	UNION ALL
	-- Œÿ√ ›Ì «”„ «·‰„Ê–Ã  
		select 	  
				[fmGUID] AS [ManGUID],
				0x0 AS [BillNumber],
				0x0 AS [BillType],
				15 AS [ErrorCode]
		from [vwfm]
		WHERE   
			[fmName] IS NULL OR [fmName] = ''

	UNION ALL
	-- Œÿ√ ›Ì —„“ «·‰„Ê–Ã  
		select 	  
				[fmGUID] AS [FormGUID],
				0x0 AS [BillNumber],
				0x0 AS [BillType],
				15 AS [ErrorCode]
		from [vwfm] 
		WHERE   
			[fmCode] IS NULL OR [fmCode] = ''

	UNION ALL
	-- Œÿ√ ›Ì „” Êœ⁄ «·≈œŒ«· √Ê «·≈Œ—«Ã  
		select 	  
				[mnGUID] AS [ManGUID],  
				0x0 AS [BillNumber],  
				0x0 AS [BillType],   
				17 AS [ErrorCode]  
		from [vwMn]  
		WHERE   
			[mnInStore] = 0x0 OR [mnInStore] IS NULL OR [mnOutStore] = 0x0 OR [mnOutStore] IS NULL

	/*
	UNION ALL
	-- Œÿ√ ›Ì —ﬁ„ «·‰„Ê–Ã  
		SELECT 	  
				0 AS ManNumber,  
				0 AS BillNumber,  
				0 AS BillType,   
				18 AS ErrorCode  
		FROM vwFm  
		WHERE   
			fmNumber = 0 OR fmNumber IS NULL  
	UNION ALL
	-- Œÿ√ ›Ì ﬂ„Ì… «·„«œ…  
		SELECT   
				fm.fmNumber AS ManNumber,  
				mi.miNumber AS BillNumber,  
				mi.miItemType AS BillType,  
				19 AS ErrorCode  
		FROM  
			vwFm AS fm  
			INNER JOIN vwMi AS mi  
			ON mi.miParent = fm.fmNumber  
		WHERE  
			mi.miType = 1  
			AND mi.miItemType IN (1,2)  
			AND (mi.miQty <= 0 OR mi.miQty IS NULL)  
	UNION ALL
	-- Œÿ√ ›Ì «·ÊÕœ…  
		SELECT   
				fm.fmNumber AS ManNumber,  
				mi.miNumber AS BillNumber,  
				mi.miItemType AS BillType,  
				20 AS ErrorCode  
		FROM  
			vwFm AS fm  
			INNER JOIN vwMi AS mi  
			ON mi.miParent = fm.fmNumber  
		WHERE  
			mi.miType = 1  
			AND mi.miItemType IN (1,2)  
			AND (mi.miUnity < 1 OR mi.miUnity > 3 OR mi.miUnity IS NULL)  
	UNION ALL
	-- Œÿ√ ›Ì „Ã„Ê⁄ ⁄«„· «· ﬁ”Ì„ ··„Ê«œ «·„’‰⁄…  
		SELECT   
				fm.fmNumber AS ManNumber,  
				0 AS BillNumber,  
				0 AS BillType,  
				21 AS ErrorCode  
		FROM  
			vwFm AS fm  
			INNER JOIN vwMi AS mi  
			ON mi.miParent = fm.fmNumber  
		WHERE  
			mi.miType = 1  
			AND mi.miItemType = 1  
			AND (	SELECT   
						SUM( mi1.miPrice) AS UnitFAct   
					FROM   
						vwFm AS fm1   
						INNER JOIN vwMi AS mi1   
						ON  mi1.miParent = fm1.fmNumber   
					WHERE   
						mi1.miType = 1 AND mi1.miItemType = 1  
						AND fm1.fmNumber = fm.fmNumber  
					GROUP BY   
						fm1.fmNumber) <> 100  
		GROUP BY   
			fm.fmNumber  

	-- Œÿ√ ›Ì ⁄«„·  ﬁ”Ì„ «·„Ê«œ «·„’‰⁄…  
	UNION ALL
		SELECT   
				fm.fmNumber,  
				mi.miNumber,  
				mi.miMatPtr AS BillType,  
				22 AS ErrorCode  
		FROM  
			vwFm AS fm  
			INNER JOIN vwMi AS mi  
			ON mi.miParent = fm.fmNumber  
		WHERE  
			mi.miType = 1  
			AND mi.miItemType = 1  
			AND ( mi.miPrice = 0 OR mi.miPrice IS NULL)  
		GROUP BY   
			fm.fmNumber,  
			mi.miNumber,  
			mi.miMatPtr  

	UNION ALL
	-- »ÿ«ﬁ«  ⁄„·Ì«  «· ’‰Ì⁄ ÌÕÊÌ √Œÿ«¡  
	-- Œÿ√ ›Ì «·⁄„·… Ê«· ⁄«œ·  
		select 	  
				mnNumber,  
				mnForm,  
				0,   
				23  
		from vwMn  
		WHERE   
			mnCurrencyVal = 0 OR   
			mnCurrencyVal IS NULL OR   
			mnCurrencyPtr = 0 OR   
			mnCurrencyPtr IS NULL  
	UNION ALL
	-- Œÿ√ ›Ì  «—ÌŒ «·⁄„·Ì…  
		select 	  
				mnNumber,  
				mnForm,  
				0,   
				24  
		from vwMn  
		WHERE   
			mnDate IS NULL OR   
			mnInDate IS NULL OR  
			mnOutDate IS NULL  
	UNION ALL
	-- Œÿ√ ›Ì „” Êœ⁄ «·≈œŒ«· √Ê «·≈Œ—«Ã  
		select 	  
				mnNumber,  
				mnForm,  
				0,   
				25  
		from vwMn  
		WHERE   
			mnStorePtr = 0 OR   
			mnStorePtr IS NULL OR   
			mnRawStore = 0 OR   
			mnRawStore IS NULL   
	UNION ALL
	-- Œÿ√ ›Ì ﬂ„Ì… «·„«œ…  
		SELECT   
				mn.mnNumber,  
				mi.miNumber,  
				mi.miItemType,  
				26  
		FROM  
			vwMn AS mn  
			INNER JOIN vwMi AS mi  
			ON mi.miParent = mn.mnNumber  
		WHERE  
			mi.miType = 2  
			AND mi.miItemType IN (1,2)  
			AND (mi.miQty <= 0 OR mi.miQty IS NULL)  
	UNION ALL
	-- Œÿ√ ›Ì «·ÊÕœ…  
		SELECT   
				mn.mnNumber,  
				mi.miNumber,  
				mi.miItemType,  
				27  
		FROM  
			vwMn AS mn  
			INNER JOIN vwMi AS mi  

			ON mi.miParent = mn.mnNumber  
		WHERE  
			mi.miType = 2  
			AND mi.miItemType IN (1,2)  
			AND (mi.miUnity < 1 OR mi.miUnity > 3 OR mi.miUnity IS NULL)  
	UNION ALL
	-- Œÿ√ ›Ì „Ã„Ê⁄ ⁄«„· «· ﬁ”Ì„ ··„Ê«œ «·„’‰⁄…  
		SELECT   
				mn.mnNumber,  
				mn.mnForm,  
				0,  
				28  
		FROM  
			vwMn AS mn  
			INNER JOIN vwMi AS mi  
			ON mi.miParent = mn.mnNumber  
		WHERE  
			mi.miType = 2  
			AND mi.miItemType = 1  
			AND (	SELECT   
						SUM( mi1.miPrice) AS UnitFAct   
					FROM   
						vwMn AS mn1   
						INNER JOIN vwMi AS mi1   
						ON  mi1.miParent = mn1.mnNumber   
					WHERE   
						mi1.miType = 2 AND mi1.miItemType = 1  
						AND mn1.mnNumber = mn.mnNumber  
					GROUP BY   
						mn1.mnNumber) <> 100  
		GROUP BY   
				mn.mnNumber,  
				mn.mnForm  
	UNION ALL
	-- Œÿ√ ›Ì ⁄«„·  ﬁ”Ì„ «·„Ê«œ «·„’‰⁄…  
		SELECT   
				mn.mnNumber,  
				mn.mnForm,  
				0,  
				29  
		FROM  
			vwMn AS mn  
			INNER JOIN vwMi AS mi  
			ON mi.miParent = mn.mnNumber  
		WHERE  
			mi.miType = 2  
			AND mi.miItemType = 1  
			AND ( mi.miPrice = 0 OR mi.miPrice IS NULL)  
		GROUP BY  
				mn.mnNumber,  
				mn.mnForm  
	UNION ALL
	-- Œÿ√ ›Ì ⁄œœ «·‰„«–Ã ÷„‰ ⁄„·Ì… «· ’‰Ì⁄  
		SELECT   
				mnNumber,  
				mnForm,  
				0,  
				30  
		FROM   
			vwMn  
		WHERE   
			mnQty <= 0	  
	UNION ALL
	-- Õ”«» «·«Œ—«Ã «·Ê”Ìÿ ·Ì” ›—⁄Ì  
		SELECT   
				mn.mnNumber,  
				ac.acNumber,  
				0,  
				31  
		FROM  
			vwMn AS mn  
			INNER JOIN  
			vwAc AS ac  
			ON ac.acNumber = mn.mnOutTmpAcc  
		WHERE  
			ac.acNSons <> 0 OR ac.acNSons IS NULL  
	UNION ALL
	-- Õ”«» «·«œŒ«· «·Ê”Ìÿ ·Ì” ›—⁄Ì  
		SELECT   
				mn.mnNumber,  
				ac.acNumber,  
				0,  
				32  
		FROM  
			vwMn AS mn  
			INNER JOIN  
			vwAc AS ac  
			ON ac.acNumber = mn.mnInTmpAcc  
		WHERE  
			ac.acNSons <> 0 OR ac.acNSons IS NULL  
	*/
	-- to fix Errors
	-- 1 
	UPDATE [Mn000]
	SET
		[CurrencyGUID] = (SELECT TOP 1 [GUID] FROM [My000]),
		[CurrencyVal] = (SELECT TOP 1 [CurrencyVal] FROM [My000])
	WHERE
		[CurrencyGUID] = 0x0 OR [CurrencyGUID] IS NULL   
	-- 2 
	UPDATE [Mi000]
	SET
		[CurrencyGUID] = (SELECT TOP 1 [GUID] FROM [My000]),
		[CurrencyVal] = (SELECT TOP 1 [CurrencyVal] FROM [My000])
	WHERE
		[CurrencyGUID] = 0x0 OR [CurrencyGUID] IS NULL   

	UPDATE [Mn000] SET [InAccountGUID] = 0x0 WHERE [InAccountGUID] IS NULL   
	UPDATE [Mn000] SET [OutAccountGUID] = 0x0 WHERE [OutAccountGUID] IS NULL   
	UPDATE [Mn000] SET [InTempAccGUID] = 0x0 WHERE [InTempAccGUID] IS NULL   
	UPDATE [Mn000] SET [OutTempAccGUID] = 0x0 WHERE [OutTempAccGUID] IS NULL   
	UPDATE [Mn000] SET [InCostGUID] = 0x0 WHERE [InCostGUID] IS NULL   
	UPDATE [Mn000] SET [OutCostGUID] = 0x0 WHERE [OutCostGUID] IS NULL   
	UPDATE [Mn000] SET [InStoreGUID] = 0x0 WHERE [InStoreGUID] IS NULL   
	UPDATE [Mn000] SET [OutStoreGUID] = 0x0 WHERE [OutStoreGUID] IS NULL   
	
	SELECT * FROM @Result

#########################################################
#END