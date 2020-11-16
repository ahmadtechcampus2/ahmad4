###########################################################
## create by mohammad 2005/12/24
##########################################################

CREATE  PROC prcGetPrintStyleSections
	@StyleGuid UNIQUEIDENTIFIER 
AS 
	SELECT
		[prh].*,
		[fn].* 
	/*
		[prh].[GUID], 
		[prh].[ParentGUID], 
		[prh].[SectionID], 
		[prh].[FontGUID], 
		[prh].[Color], 
		[prh].[Just], 
		[prh].[Pat], 
		[prh].[LeftBorder], 
		[prh].[TopBorder], 
		[prh].[RightBorder], 
		[prh].[BottomBorder], 
		[prh].[Flags], 
		[prh].[ExtFlags], 
		[prh].[BackColor], 
		[prh].[FrontColor], 
		[prh].[Height],
		[fn].*,
		[prh].[HdrContents]
		*/
	FROM  
		[prh000] AS [prh] 
			INNER JOIN [vwfn] AS [fn]
			ON [prh].[FontGUID] = [fn].[fnGUID]
		WHERE  
			[prh].[ParentGUID] = @StyleGuid 

###########################################################
#end
