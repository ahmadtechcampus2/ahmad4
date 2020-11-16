###########################################################################
CREATE PROC prcGetHijriDateShift
AS 
SET NOCOUNT ON
IF NOT EXISTS( SELECT [name], [type]
	  FROM 	 [AmnConfig]..[sysobjects] 
	  WHERE  [name] = 'HDateMap' 
	  AND 	 [type] = 'U')
CREATE TABLE 
	[AmnConfig]..[HDateMap]( 
							[GUID] [UNIQUEIDENTIFIER] NOT NULL DEFAULT (newid()),
							[HMonth] [INT] NOT NULL ,
							[Hyear] [INT] NOT NULL ,
							[shift] [INT] NOT NULL DEFAULT (0),
						) 
SELECT 
	[HMonth],
	[Hyear],
	[shift]
	FROM [AmnConfig]..[HDateMap]
###########################################################################
Create PROCEDURE prcAddHijriDateMap
	@Year [INT], 
	@Month [INT], 
	@Shift [INT]
AS 
SET NOCOUNT ON
DELETE [AmnConfig]..[HDateMap] WHERE [HYear] = @Year And [HMonth] = @Month 
if @Shift <> 0
	INSERT INTO [AmnConfig]..[HDateMap]( [HYear], [HMonth], [Shift]) VALUES( @Year, @Month, @Shift)
###########################################################################
#END

