SELECT Id, Code, [Description] FROM Entity --WHERE EndDate IS NULL AND Deleted = 0
SELECT Id, UserName FROM Users --WHERE EndDate IS NULL

SELECT 
    e.Code, e.[Description], u.UserName 
FROM UserEntity ue
JOIN Users u ON ue.UserId = u.Id
JOIN Entity e ON ue.EntityId = e.Id
WHERE u.UserName = 'jadson.oliveira' AND e.Code LIKE '%|%'

-- DELETE ue
-- FROM UserEntity ue
-- JOIN Users u ON ue.UserId = u.Id
-- JOIN Entity e ON ue.EntityId = e.Id
-- WHERE u.UserName = 'jadson.oliveira' AND e.Code LIKE '%|%'