######################################################################################
CREATE PROCEDURE prcCustHide
	@AccGUID		AS [UNIQUEIDENTIFIER],
	@CustCondGUID	AS [UNIQUEIDENTIFIER],
	@HideCust		AS [INT],
	@Operation		AS [INT]     -- Operation : 1-Preview,  2-Apply
AS
	SET NOCOUNT ON

	CREATE TABLE [#CustTable]( [cuGuid] [UNIQUEIDENTIFIER], [cuSec] [INT])

	INSERT INTO [#CustTable] EXEC [prcGetCustsList] NULL, @AccGUID, @CustCondGuid

	DECLARE @hide [INT]
	SET @hide = 0
	
	IF @HideCust = 0
		SET @hide = 1
		
	IF @Operation = 1 -- Preview
			SELECT	
				[cu].[cuGUID] AS [GUID],
				[cu].[cuCustomerName] AS [Name],
				[cu].[cuLatinName] AS [LatinName]
			FROM 
				[vwCu] [cu] 
				INNER JOIN [#CustTable] [ct] ON [cu].[cuGUID] = [ct].[cuGuid]
			WHERE 
				[cu].[cuHide] = @hide
			
	IF @Operation = 2	-- Apply
	BEGIN
		UPDATE cu 
		SET 
			[cu].[bHide] = @HideCust 
		FROM 
			[cu000] [cu]
		WHERE EXISTS( SELECT cuGuid FROM [#CustTable] WHERE [cuGuid] = [cu].[GUID] AND [cu].[bHide] = @hide)

		SELECT @@ROWCOUNT AS [COUNT]
	END
######################################################################################
#END
