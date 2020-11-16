######################################################### 
CREATE PROC prcCheckDB_my
	@Correct [INT] = 0
AS
	IF @Correct <> 1 AND NOT EXISTS(select * from [my000])
		INSERT INTO [ErrorLog] ([Type])
			SELECT 0xC01

	IF @Correct <> 1 AND (select count(*) from [my000] where [currencyVal] = 1) != 1
		INSERT INTO [ErrorLog] ([Type])
			SELECT 0xC02

######################################################### 