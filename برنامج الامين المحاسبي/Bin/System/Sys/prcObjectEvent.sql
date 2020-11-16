#################################################################################
CREATE PROCEDURE NSPrcObjectEvent
    @objectGuid      AS UNIQUEIDENTIFIER,
	@objectID	AS int,
	@eventID as int
AS
BEGIN
    SET NOCOUNT ON;

	IF NOT EXISTS (SELECT * FROM sys.services WHERE name like 'BillEventService')
	BEGIN
		RETURN
	END

    DECLARE @EventMessage AS XML

    SET @EventMessage = (SELECT
							@objectGuid AS objectGuid, @objectID as objectID, @eventID  AS eventID
							FOR XML PATH(''), ROOT('objectEvent'), ELEMENTS)

    DECLARE @handle    AS UNIQUEIDENTIFIER

    BEGIN DIALOG CONVERSATION @handle  
        FROM
            SERVICE BillEventService
        TO
            SERVICE 'BillCheckEventConditionsService'
        WITH
            ENCRYPTION = OFF;

    SEND
        ON CONVERSATION @handle (@EventMessage)

		DECLARE @Log NVARCHAR(MAX)
		SET @Log = N'Service_Broker:objectEventprc' + CAST(@EventMessage AS NVARCHAR(MAX))
		EXEC prcLog @Log

	END CONVERSATION @handle

END
#################################################################################
CREATE PROCEDURE NSPrcSchedulevent
	@objectID	AS int,
	@eventID AS INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EventMessage AS XML

    SET @EventMessage = (SELECT
							@objectID as objectID, @eventID  AS eventID
							FOR XML PATH(''), ROOT('scheduleEvent'), ELEMENTS)

    DECLARE @handle    AS UNIQUEIDENTIFIER

    BEGIN DIALOG CONVERSATION @handle  
        FROM
            SERVICE BillEventService
        TO
            SERVICE 'ScheduleEventConditionsService'
        WITH
            ENCRYPTION = OFF;

    SEND
        ON CONVERSATION @handle (@EventMessage)

		DECLARE @Log NVARCHAR(MAX)
		SET @Log = N'Service_Broker:ScheduleEventprc' + CAST(@EventMessage AS NVARCHAR(MAX))
	--	EXEC prcLog @Log

	END CONVERSATION @handle

END
#################################################################################
CREATE PROCEDURE NSPrcManualevent
	@objectGuid AS UNIQUEIDENTIFIER,
	@message AS XML
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EventMessage AS XML

    SET @EventMessage = (SELECT @objectGuid AS objectGuid, @message AS [Message]
							FOR XML PATH(''), ROOT('manualEvent'), ELEMENTS)

    DECLARE @handle    AS UNIQUEIDENTIFIER

    BEGIN DIALOG CONVERSATION @handle  
        FROM
            SERVICE BillEventService
        TO
            SERVICE 'ManualEventConditionsService'
        WITH
            ENCRYPTION = OFF;

    SEND ON CONVERSATION @handle (@EventMessage)
	END CONVERSATION @handle
END
#################################################################################
CREATE PROCEDURE NSPrcConnectionsAddAdmin
AS
BEGIN
    SET NOCOUNT ON;

	IF [dbo].[fnGetCurrentUserGuid]() = 0X0
	BEGIN
		DECLARE @UsGuid [UNIQUEIDENTIFIER] 
		SELECT top 1 @UsGuid = [GUID] FROM [us000] WHERE [bAdmin] = 1
		Execute [prcConnections_add] @UsGuid
	END
END
#################################################################################
#END