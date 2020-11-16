#########################################################
CREATE PROCEDURE prcPalm_GetMatsList
		@CondId 	AS 	[INT] = 0,
		@CondGUID	AS 	[UNIQUEIDENTIFIER] = 0x0
AS
/*
	DELETE [MC000]
	WHERE
		[Type] = 17 AND
		[Number] = -@@spid

	if @CondID > 0
		INSERT INTO [MC000]
			SELECT [Type], -@@spid, [Item], [ParentType], [ParentNumber], [Asc1], [Asc2], [Asc3], [Asc4], [Asc5], [Num1], [Num2], [Num3], [Num4], [Num5], [Num6], [Num7], [Num8], [Date1], [Date2], [Date3]
			FROM
				[MC000] 
			WHERE
				[Type] = 17 AND
				[Number] = @CondID
	
	EXEC [prcGetMatsList] 			
*/

	EXEC [prcGetMatsList] 0x0, 0x0, -1, @CondGUID

#########################################################
#END