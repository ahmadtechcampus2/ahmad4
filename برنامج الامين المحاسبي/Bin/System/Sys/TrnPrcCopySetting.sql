####################################################
CREATE PROCEDURE TrnPrcCopySettings
	@FromComputer NVARCHAR(100),
	@ToComputer NVARCHAR(100),
	@UserId UNIQUEIDENTIFIER
	
AS
	SET NOCOUNT ON
	DECLARE @CurrentCenter  NVARCHAR(100),
			@OldCenter		NVARCHAR(100)

	SELECT 
		@CurrentCenter  = VALUE
	FROM OP000 
	WHERE NAME = 'TrnCfg_CurrentCenter' AND Computer = @FromComputer
	
	SELECT @CurrentCenter = ISNULL(@CurrentCenter, '')

	
	IF ((SELECT COUNT(*) FROM OP000 WHERE NAME = 'TrnCfg_CurrentCenter' AND COMPUTER = @ToComputer) <> 0)
		UPDATE OP000 
			SET PrevValue = VALUE,
			VALUE = @CurrentCenter 
		WHERE NAME = 'TrnCfg_CurrentCenter' AND COMPUTER = @ToComputer
	
	ELSE
		INSERT INTO OP000 ([Name], VALUE, Computer, [Time],Type)
			VALUES('TrnCfg_CurrentCenter', @CurrentCenter, @ToComputer, GetDate(), 2)
####################################################
#END