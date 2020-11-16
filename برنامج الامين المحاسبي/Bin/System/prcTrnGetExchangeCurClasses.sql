######################################################################################
CREATE  PROCEDURE trnGetExchangeCurClasses
		@ParentGUID	[UNIQUEIDENTIFIER], 
		@Type		[INT]	= 0 
AS 
	SET NOCOUNT ON  
	 
	CREATE TABLE [#Result](  
					[GUID] [UNIQUEIDENTIFIER],  
					[ClassGUID] [UNIQUEIDENTIFIER],  
					[ClassName] [NVARCHAR]( 255) COLLATE ARABIC_CI_AI, 
					[Value] [FLOAT],
					[ClassVal] [FLOAT])

	INSERT INTO [#Result] 
		SELECT [ECC].[GUID], [ECC].[ClassGUID], [CC].[ClassName], [ECC].[Value], [CC].[ClassVal]  
		FROM [TrnExchangeCurrClass000]  AS [ECC]
			INNER JOIN [TrnCurrencyClass000] AS [CC] ON [ECC].[ClassGUID] = [CC].[GUID]
		WHERE [ECC].[ParentGUID] = @ParentGUID AND
		      [ECC].[Type] = @Type

	SELECT * FROM [#Result] 
#########################################################################
#END