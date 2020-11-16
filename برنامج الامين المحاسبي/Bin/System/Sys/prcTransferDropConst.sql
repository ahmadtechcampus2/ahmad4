#####################################################################
CREATE PROCEDURE prcTransferDropConst
AS
	SET NOCOUNT ON
	DECLARE @S NVARCHAR(1000)
	DECLARE @C NVARCHAR(255)
	select @C = Name FROM sysobjects where 
	left(name, 16) = 'PK__TrnGenerator'
	SET @S = ' alter table TrnGenerator000 drop constraint ' + @C 
	EXECUTE (@S)
#####################################################################
#END