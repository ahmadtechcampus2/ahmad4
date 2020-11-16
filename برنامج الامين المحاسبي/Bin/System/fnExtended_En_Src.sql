################################################################################
CREATE FUNCTION fnExtended_En_Src( @SrcGUID [UNIQUEIDENTIFIER])    
	RETURNS TABLE 
		 /* 
			TYPE = 1 -> ENTRY   
			TYPE = 2 -> Bill   
			TYPE = 4 -> Pay   
			TYPE = 5 -> Check   
			TYPE = 6 -> CheckCol   
		*/   
AS    
	RETURN ( 
		SELECT    
			[en].[ceGUID],    
			[en].[ceType],    
			[en].[ceNumber],    
			[en].[ceDate],
			[en].[cePostDate],
			[en].[ceDebit],    
			[en].[ceCredit],    
			[en].[ceNotes],    
			[en].[ceCurrencyVal],    
			[en].[ceCurrencyPtr],    
			[en].[ceIsPosted],    
			[en].[ceState],    
			[en].[ceSecurity],    
			4 AS [UserSecurity], 
			[en].[ceBranch],    
			[en].[enGUID],    
			[en].[enNumber],    
			[en].[enAccount],    
			[en].[enDate],    
			[en].[enDebit],    
			[en].[enCredit],    
			[en].[enNotes],    
			[en].[enCurrencyPtr],    
			[en].[enCurrencyVal],    
			[en].[enCostPoint],    
			[en].[enClass],    
			[en].[enNum1],    
			[en].[enNum2],    
			[en].[enVendor],    
			[en].[enSalesMan],    
			[en].[enContraAcc],   
			[en].[acNumber],    
			[en].[acName],    
			[en].[acLatinName],   
			[en].[acCode],    
			[en].[acParent],    
			[en].[acFinal],    
			[en].[acSecurity],    
			[en].[acNSons],    
			[en].[acType],    
			[en].[acMaxDebit],    
			[en].[acWarn],    
			[en].[acNotes],    
			[en].[acUseFlag],    
			[en].[acCurrencyPtr],    
			[en].[acCurrencyVal],    
			[en].[acDebitOrCredit],   
			[en].[acGUID],
			ISNULL([er].[erParentType],0) [erParentType],
			ISNULL( [er].[erParentGuid], 0x0) AS [ParentGUID],
			[en].[ceTypeGUID] AS [ParentTypeGUID],
			ISNULL( [er].[erParentType], 0x0) AS [ceRecType], 
			ISNULL( [er].[erParentNumber], 0x0) AS [ceParentNumber], 
			ISNULL( [bt].[btName], ISNULL( [et].[etName], ISNULL( [nt].[ntName], ''))) AS [ceTypeName], 
			ISNULL( [bt].[btLatinName], ISNULL( [et].[etLatinName], ISNULL( [nt].[ntLatinName], ''))) AS [ceTypeLatinName], 
			ISNULL( [bt].[btAbbrev], ISNULL( [et].[etAbbrev], ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, ''))) AS [ceTypeAbbrev], 
			ISNULL( [bt].[btLatinAbbrev], ISNULL( [et].[etLatinAbbrev], ISNULL( CASE [nt].[ntLatinAbbrev] WHEN '' THEN [nt].[ntLatinName] ELSE [nt].[ntLatinAbbrev] END, ''))) AS [ceTypeLatinAbbrev],
			[en].[enBiGUID],
			[en].[enCustomerGUID]
		FROM 	
			[vwExtended_en] AS [en]   
			INNER JOIN (select distinct [guid] from [dbo].[fnGetSourcesType]( @SrcGUID)) AS [t]      
			ON ISNULL( [en].[ceTypeGUID], 0x0) = [t].[GUID] 
			LEFT JOIN [vwEr] AS [er] ON [en].[ceGuid] = [er].[erEntryGuid] 
			LEFT JOIN [vwBt] AS [bt] ON [en].[ceTypeGUID] = [bt].[btGuid]
			LEFT JOIN [vwEt] AS [et] ON [en].[ceTypeGUID] = [et].[etGuid]
			LEFT JOIN [vwNt] AS [nt] ON [en].[ceTypeGUID] = [nt].[ntGuid]
	)
################################################################################
#END
