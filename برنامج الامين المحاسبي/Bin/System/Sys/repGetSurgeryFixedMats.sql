########################################################################
CREATE PROCEDURE repGetSurgeryFixedMats
	@ParentGUID		[UNIQUEIDENTIFIER]
AS
SET NOCOUNT ON 
	DECLARE @Cnt INT
			
	SELECT @Cnt = COUNT(*) FROM [dbo].[vwHosSurgeryUsedMats] 
	WHERE ( [Type] = 1 AND [ParentGUID] = @ParentGUID )
	
	IF @Cnt > 0 
	BEGIN
	 	SELECT 
			*
		FROM 
			[dbo].[vwHosSurgeryUsedMats]
		WHERE 
			( [Type] = 1 AND [ParentGUID] = @ParentGUID )
		ORDER BY 
			[Number]
		RETURN
	END
	ELSE
	BEGIN
		SELECT @Cnt = COUNT(*) FROM [dbo].[vwHosSurgeryUsedMats]
		WHERE ( [Type] = 0 AND [ParentGUID] = @ParentGUID )
		
		IF @Cnt > 0
		BEGIN
		 	SELECT 	*
				FROM [dbo].[vwHosSurgeryUsedMats]
			WHERE ( [Type] = 0 AND [ParentGUID] = @ParentGUID )
			ORDER BY [Number]
	
			RETURN
		END
		/*
		ELSE
		BEGIN
		 	SELECT * FROM [dbo].[vwHosSurgeryUsedMats]
			WHERE [Type] = 3
			ORDER BY [Number]
		END
		*/
	END


/*
EXEC repGetSurgeryFixedMats 'e8a8898b-92a2-4239-99da-01fd3e904bf9'
SELECT * FROM [dbo].[vwHosSurgeryUsedMats]


*/


########################################################################
#END