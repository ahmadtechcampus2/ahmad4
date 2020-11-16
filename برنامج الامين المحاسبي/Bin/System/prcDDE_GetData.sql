##################################################################3
CREATE PROCEDURE prcDDE_GetData
	@TblName		[NVARCHAR](256),	--	OR ProcName
	@RetFldName		[NVARCHAR](256),	-- 
	@CondStr		[NVARCHAR](2000) 	-- condStr or ParamStr
AS
	DECLARE @s [NVARCHAR](2000)
	SET @s = ' SELECT ' + @RetFldName + ' FROM ' + @TblName
	SET @s = @s + ' WHERE ' + @CondStr
	EXEC( @s)	

/*

prcDDE_GetData 'cu000', 'CustDebt', 'CustomerName = ''ÓÚíÏ''' 


*/
#######################################################################
#END