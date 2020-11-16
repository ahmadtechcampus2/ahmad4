#########################################################
CREATE PROCEDURE prcGetOptionsValue
	@opNames [NVARCHAR](max),
	@opType [INT] = 0
AS 
	SET NOCOUNT ON 

	DECLARE @OptionsValue TABLE( [opName] [NVARCHAR](250) COLLATE ARABIC_CI_AI, [opValue] [NVARCHAR](2000) COLLATE ARABIC_CI_AI)
	DECLARE 
		@c_OpName CURSOR,
		@opName [NVARCHAR](250), 
		@opValue [NVARCHAR](250)

	SET @c_OpName = CURSOR FAST_FORWARD FOR SELECT [SubStr] FROM [dbo].[fnString_Split]( @opNames, ',')
	OPEN @c_OpName FETCH NEXT FROM @c_OpName INTO @opName
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		SET @opValue = [dbo].[fnOption_GetValue]( @opName, @opType)
		IF( ISNULL( @opValue, '') != '')
		BEGIN 

			INSERT INTO @OptionsValue
			SELECT 
				@opName, 
				@opValue
		END 

		FETCH NEXT FROM @c_OpName INTO @opName
	END 
	CLOSE @c_OpName DEALLOCATE @c_OpName
	
	SELECT [opName], [opValue] FROM @OptionsValue
#########################################################
#END
