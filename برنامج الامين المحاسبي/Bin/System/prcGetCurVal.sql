#######################################################
CREATE PROCEDURE prcGetCurVal
	@CurGuid	[UNIQUEIDENTIFIER],
	@Date		[DATETIME]
AS
	SET NOCOUNT ON
	SELECT [dbo].[fnGetCurVal]( @CurGuid, @Date) AS [CurVal]
	

/*
EXEC prcGetCurVal '28267303-4745-43CE-97EE-A0C0ABB2215A', '12/21/2003'
*/
####################################################
#END