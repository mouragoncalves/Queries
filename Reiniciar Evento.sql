DECLARE @EventId INT = 0

DELETE XMLContent WHERE ReferenceId = @EventId AND ContentReferenceEnum <> 0
UPDATE Event SET EventStatusEnum = 0 WHERE Id = @EventId