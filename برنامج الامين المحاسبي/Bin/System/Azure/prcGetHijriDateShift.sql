###########################################################################
CREATE PROC prcGetHijriDateShift
AS 
	SET NOCOUNT ON
	IF [dbo].[fnTblExists]('HDateMap') = 0
		CREATE TABLE [HDateMap]
		( 
			[GUID] [UNIQUEIDENTIFIER] NOT NULL DEFAULT (newid()),
			[HMonth] [INT] NOT NULL ,
			[Hyear] [INT] NOT NULL ,
			[shift] [INT] NOT NULL DEFAULT (0),
		) 
	SELECT 
		[HMonth],
		[Hyear],
		[shift]
		FROM [HDateMap]
###########################################################################
Create PROCEDURE prcAddHijriDateMap
	@Year [INT], 
	@Month [INT], 
	@Shift [INT]
AS 
	SET NOCOUNT ON
	DELETE [HDateMap] WHERE [HYear] = @Year And [HMonth] = @Month 
	if @Shift <> 0
		INSERT INTO [HDateMap]( [HYear], [HMonth], [Shift]) VALUES( @Year, @Month, @Shift)
###########################################################################
#END

