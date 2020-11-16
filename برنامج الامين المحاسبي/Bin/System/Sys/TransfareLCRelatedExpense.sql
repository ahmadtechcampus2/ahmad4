##############################################
CREATE PROCEDURE TransfareLCRelatedExpense
	@DbName NVARCHAR(250)
AS
	IF LEFT(@DbName, 1) <> N'['
	BEGIN
		SET @DbName = N'[' + @DbName + N']';
	END

	EXEC('DECLARE @LCGUID UNIQUEIDENTIFIER;
	DECLARE cur CURSOR FOR SELECT [GUID] FROM LC000 WHERE [State] = 1
	OPEN cur
		FETCH NEXT FROM cur INTO @LCGUID
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		INSERT INTO ' + @DbName + '..LCRelatedExpense000
			SELECT 
				NEWID()
				,expense.LCGuid
				,expense.SourceType
				,expense.TypeGUID
				,expense.ItemNumber
				,expense.ItemGUID
				,expense.ExpenseGUID
				,1
				,expense.TypeName
				,expense.AccountGUID
				,expense.[Date]
				,expense.NetValue
				,expense.CurrencyGUID
				,expense.CurrencyVal
				,expense.Notes
				 FROM fnGetLCExpenses(@LCGUID) AS expense
		FETCH NEXT FROM cur INTO @LCGUID
	END
	CLOSE cur;
	DEALLOCATE cur;')
#####################################################################################################################
#END