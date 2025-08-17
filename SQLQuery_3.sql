SELECT 
    COUNT(*) OVER (PARTITION BY CPF, Matricula, year, month ORDER BY (SELECT NULL)) AS Qtd,
    ROW_NUMBER() OVER (PARTITION BY CPF, Matricula, year, month ORDER BY (SELECT NULL)) Seq,
    *
FROM WorkerCredit WHERE Matricula = 'UNA-SP-COL01022013R0149' OR Cpf = '776817540'
EXEC sp_ProcessarEventosXML @EventIds = '18342378'
SELECT * FROM XMLContent WHERE ReferenceId = 18476693
SELECT * FROM Event WHERE Id = 18346901

-- WHERE -- ([Year] = 2025 AND [Month] = 7) OR 
--     Matricula = 'APL-EDUC17012025R171908'

;WITH BaseWorkerCredit AS (
    SELECT 
        COUNT(*) OVER (PARTITION BY CPF, Matricula, year, month ORDER BY (SELECT NULL)) AS Qtd,
        ROW_NUMBER() OVER (PARTITION BY CPF, Matricula, year, month ORDER BY (SELECT NULL)) Seq,
        Id,
        Rubrica
    FROM WorkerCredit
) UPDATE wc SET Rubrica = null
FROM WorkerCredit wc
JOIN BaseWorkerCredit bw ON bw.Id = wc.Id
WHERE --wc.Rubrica IS NULL
    --AND 
    bw.Qtd > 1

;WITH BaseWorkerCredit AS (
    SELECT 
        COUNT(*) OVER (PARTITION BY CPF, Matricula, year, month ORDER BY (SELECT NULL)) AS Qtd,
        ROW_NUMBER() OVER (PARTITION BY CPF, Matricula, year, month ORDER BY (SELECT NULL)) Seq,
        Id,
        Rubrica
    FROM WorkerCredit
) --UPDATE wc SET Rubrica = '16965'
SELECT *
FROM WorkerCredit wc
JOIN BaseWorkerCredit bw ON bw.Id = wc.Id
    AND bw.Qtd = 1
    AND wc.Rubrica = '16965'

UPDATE w SET Rubrica = '16966'
FROM WorkerCredit w
WHERE Matricula IN ('ADRA-MG14122022R851519','ADRA-MG13032024R645026','ADRA-MG20092021R111456') AND [Month] IN (7,8)

