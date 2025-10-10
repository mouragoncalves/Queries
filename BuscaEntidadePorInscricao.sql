DECLARE @Entities TABLE (
    Entity VARCHAR(20)
)
101122
112122
113122
101225
106122
101223
102122
104122
107122
103122
105122
INSERT INTO @Entities VALUES ('101122'),('101223'),('101225'),('101226'),('102122'),('103122'),('104122'),('105122'),('106122'),('107122'),('112122'),('113122');

WITH TData AS (
    SELECT
    *,
        -- EntityCode, BusinessKey, Label,
        COUNT(*) OVER (PARTITION BY EntityCode, BusinessKey ORDER BY (SELECT NULL)) AS QtdRegistrosCPF
    FROM Event e 
    WHERE e.EntityCode IN (SELECT Entity FROM @Entities)
        AND e.EventTypeEnum = 1 
        AND e.EventStatusEnum = 6
)

SELECT 
    d.*, w.* 
FROM WorkerCredit w
JOIN TData d ON d.BusinessKey = w.NumeroInscricaoEstabelecimento
WHERE MainEntityCode = '101122' AND [Year] = 2025 AND [Month] = 10


