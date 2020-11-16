################################################################################
CREATE PROCEDURE prcInitServiceBroker
AS
BEGIN

	IF(SELECT is_broker_enabled FROM sys.databases WHERE name = db_name()) = 0
	BEGIN
		DECLARE @sql VARCHAR(100)
		set @sql='ALTER DATABASE '+ quotename(db_name()) + ' SET NEW_BROKER WITH ROLLBACK IMMEDIATE;'
		exec(@sql)
	END

	IF NOT EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'BillEventQueue')
	BEGIN
		CREATE QUEUE BillEventQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'BillCheckEventConditionsQueue')
	BEGIN
		CREATE QUEUE BillCheckEventConditionsQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'BillReadyMessageQueue')
	BEGIN
		CREATE QUEUE BillReadyMessageQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ReadySmsMessageQueue')
	BEGIN
		CREATE QUEUE ReadySmsMessageQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ScheduleEventConditionsQueue')
	BEGIN
		CREATE QUEUE ScheduleEventConditionsQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ManualEventConditionsQueue')
	BEGIN
		CREATE QUEUE ManualEventConditionsQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ScheduleEventQueue')
	BEGIN
		CREATE QUEUE ScheduleEventQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ReSendMailQueue')
	BEGIN
		CREATE QUEUE ReSendMailQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ReSendSmsQueue')
	BEGIN
		CREATE QUEUE ReSendSmsQueue
	END
	-------------------------------------
	IF NOT EXISTS (SELECT * FROM  sys.services WHERE name like 'BillEventService')
	BEGIN
		CREATE SERVICE BillEventService
			ON QUEUE BillEventQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.services WHERE name like 'BillCheckEventConditionsService')
	BEGIN
		CREATE SERVICE BillCheckEventConditionsService
			ON QUEUE BillCheckEventConditionsQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.services WHERE name like 'BillReadyMessageService')
	BEGIN
		CREATE SERVICE BillReadyMessageService
			ON QUEUE BillReadyMessageQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.services WHERE name like 'ReadySmsMessageService')
	BEGIN
		CREATE SERVICE ReadySmsMessageService
			ON QUEUE ReadySmsMessageQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.services WHERE name like 'ScheduleEventConditionsService')
	BEGIN
		CREATE SERVICE ScheduleEventConditionsService
			ON QUEUE ScheduleEventConditionsQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.services WHERE name like 'ManualEventConditionsService')
	BEGIN
		CREATE SERVICE ManualEventConditionsService
			ON QUEUE ManualEventConditionsQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.services WHERE name like 'ScheduleEventService')
	BEGIN
		CREATE SERVICE ScheduleEventService
			ON QUEUE ScheduleEventQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.services WHERE name like 'ReSendMailService')
	BEGIN
		CREATE SERVICE ReSendMailService
			ON QUEUE ReSendMailQueue
	END

	IF NOT EXISTS (SELECT * FROM  sys.services WHERE name like 'ReSendSmsService')
	BEGIN
		CREATE SERVICE ReSendSmsService
			ON QUEUE ReSendSmsQueue
	END

	-------------------------------------------------------------------------------------------
	IF NOT exists (
		SELECT * FROM sys.service_contract_usages sc 
		inner join sys.services s ON sc.service_id = s.service_id
		inner join sys.service_contracts c ON sc.service_contract_id = c.service_contract_id
		 WHERE s.name like 'BillEventService' and c.name like 'DEFAULT')
	BEGIN
		ALTER SERVICE BillEventService
		( ADD CONTRACT [DEFAULT] )
	END

	IF NOT exists (
		SELECT * FROM sys.service_contract_usages sc 
		inner join sys.services s ON sc.service_id = s.service_id
		inner join sys.service_contracts c ON sc.service_contract_id = c.service_contract_id
		 WHERE s.name like 'BillCheckEventConditionsService' and c.name like 'DEFAULT')
	BEGIN
		ALTER SERVICE BillCheckEventConditionsService
		( ADD CONTRACT [DEFAULT] )
	END

	IF NOT exists (
		SELECT * FROM sys.service_contract_usages sc 
		inner join sys.services s ON sc.service_id = s.service_id
		inner join sys.service_contracts c ON sc.service_contract_id = c.service_contract_id
		 WHERE s.name like 'ScheduleEventConditionsService' and c.name like 'DEFAULT')
	BEGIN
		ALTER SERVICE ScheduleEventConditionsService
		( ADD CONTRACT [DEFAULT] )
	END

	IF NOT exists (
		SELECT * FROM sys.service_contract_usages sc 
		inner join sys.services s ON sc.service_id = s.service_id
		inner join sys.service_contracts c ON sc.service_contract_id = c.service_contract_id
		 WHERE s.name like 'ManualEventConditionsService' and c.name like 'DEFAULT')
	BEGIN
		ALTER SERVICE ManualEventConditionsService
		( ADD CONTRACT [DEFAULT] )
	END

	IF NOT exists (
		SELECT * FROM sys.service_contract_usages sc 
		inner join sys.services s ON sc.service_id = s.service_id
		inner join sys.service_contracts c ON sc.service_contract_id = c.service_contract_id
		 WHERE s.name like 'BillReadyMessageService' and c.name like 'DEFAULT')
	BEGIN
		ALTER SERVICE BillReadyMessageService
		( ADD CONTRACT [DEFAULT] )
	END

	IF NOT exists (
		SELECT * FROM sys.service_contract_usages sc 
		inner join sys.services s ON sc.service_id = s.service_id
		inner join sys.service_contracts c ON sc.service_contract_id = c.service_contract_id
		 WHERE s.name like 'ReadySmsMessageService' and c.name like 'DEFAULT')
	BEGIN
		ALTER SERVICE ReadySmsMessageService
		( ADD CONTRACT [DEFAULT] )
	END

	IF NOT exists (
		SELECT * FROM sys.service_contract_usages sc 
		inner join sys.services s ON sc.service_id = s.service_id
		inner join sys.service_contracts c ON sc.service_contract_id = c.service_contract_id
		 WHERE s.name like 'ScheduleEventService' and c.name like 'DEFAULT')
	BEGIN
		ALTER SERVICE ScheduleEventService
		( ADD CONTRACT [DEFAULT] )
	END

	IF NOT exists (
		SELECT * FROM sys.service_contract_usages sc 
		inner join sys.services s ON sc.service_id = s.service_id
		inner join sys.service_contracts c ON sc.service_contract_id = c.service_contract_id
		 WHERE s.name like 'ReSendMailService' and c.name like 'DEFAULT')
	BEGIN
		ALTER SERVICE ReSendMailService
		( ADD CONTRACT [DEFAULT] )
	END

	IF NOT exists (
		SELECT * FROM sys.service_contract_usages sc 
		inner join sys.services s ON sc.service_id = s.service_id
		inner join sys.service_contracts c ON sc.service_contract_id = c.service_contract_id
		 WHERE s.name like 'ReSendSmsService' and c.name like 'DEFAULT')
	BEGIN
		ALTER SERVICE ReSendSmsService
		( ADD CONTRACT [DEFAULT] )
	END
	----------------------------------------
	IF  EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'BillCheckEventConditionsQueue')
	BEGIN
		ALTER QUEUE BillCheckEventConditionsQueue
		WITH ACTIVATION
		( STATUS = ON,
			PROCEDURE_NAME = NSPrcObjectCheckEventConditions,
			MAX_QUEUE_READERS = 10,
			EXECUTE AS SELF
		);
	END

	IF  EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ScheduleEventConditionsQueue')
	BEGIN
		ALTER QUEUE ScheduleEventConditionsQueue
		WITH ACTIVATION
		( STATUS = ON,
			PROCEDURE_NAME = NSPrcCheckScheduleEventConditions,
			MAX_QUEUE_READERS = 10,
			EXECUTE AS SELF
		);
	END

	IF  EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ManualEventConditionsQueue')
	BEGIN
		ALTER QUEUE ManualEventConditionsQueue
		WITH ACTIVATION
		( STATUS = ON,
			PROCEDURE_NAME = NSPrcCheckManualEventConditions,
			MAX_QUEUE_READERS = 10,
			EXECUTE AS SELF
		);
	END

	IF  EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'BillReadyMessageQueue')
	BEGIN
		ALTER QUEUE BillReadyMessageQueue
		WITH ACTIVATION
		( STATUS = ON,
			PROCEDURE_NAME = prcSendBillMessage,
			MAX_QUEUE_READERS = 10,
			EXECUTE AS SELF
		);--, POISON_MESSAGE_HANDLING (STATUS = OFF);
	END

	IF  EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ReadySmsMessageQueue')
	BEGIN
		ALTER QUEUE ReadySmsMessageQueue
		WITH ACTIVATION
		( STATUS = ON,
			PROCEDURE_NAME = prcSendSmsMessage,
			MAX_QUEUE_READERS = 10,
			EXECUTE AS SELF
		);--, POISON_MESSAGE_HANDLING (STATUS = OFF);
	END

	IF  EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ScheduleEventQueue')
	BEGIN
		ALTER QUEUE ScheduleEventQueue
		WITH ACTIVATION
		( STATUS = ON,
			PROCEDURE_NAME = NSPrcSendScheduleMessage,
			MAX_QUEUE_READERS = 10,
			EXECUTE AS SELF
		);--, POISON_MESSAGE_HANDLING (STATUS = OFF);
	END

	IF  EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ReSendMailQueue')
	BEGIN
		ALTER QUEUE ReSendMailQueue
		WITH ACTIVATION
		( STATUS = ON,
			PROCEDURE_NAME = NSPrcReSendMailMessage,
			MAX_QUEUE_READERS = 10,
			EXECUTE AS SELF
		);--, POISON_MESSAGE_HANDLING (STATUS = OFF);
	END

	IF  EXISTS (SELECT * FROM  sys.service_queues WHERE name like 'ReSendSmsQueue')
	BEGIN
		ALTER QUEUE ReSendSmsQueue
		WITH ACTIVATION
		( STATUS = ON,
			PROCEDURE_NAME = NSPrcReSendSmsMessage,
			MAX_QUEUE_READERS = 10,
			EXECUTE AS SELF
		);--, POISON_MESSAGE_HANDLING (STATUS = OFF);
	END
END
#################################################################################
#END

--ALTER QUEUE BillCheckEventConditionsQueue WITH ACTIVATION (STATUS = OFF)
--ALTER QUEUE BillReadyMessageQueue WITH ACTIVATION (STATUS = OFF)

--SELECT TOP 1000 *, casted_message_body = 
--CASE message_type_name WHEN 'X' 
--  THEN CAST(message_body AS NVARCHAR(MAX)) 
--  ELSE message_body 
--END 
--FROM [AmnDb031].[dbo].[BillReadyMessageQueue] WITH(NOLOCK)
 --select * from sys.dm_broker_activated_tasks
 --select * from sys.transmission_queue
 --select * from sys.conversation_endpoints
 --sp_who
 --kill 71 WITH StatusOnly
 --C:\Src\Amn81- AMS02\Amn80\Exe\Debug - Unicode\NSLibaray.dll