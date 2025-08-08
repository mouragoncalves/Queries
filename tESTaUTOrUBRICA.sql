WITH RubricaPorContrato AS (
    SELECT 
        * , -- MIN(Id)
        ROW_NUMBER() OVER (PARTITION BY Cpf, IfConcessoraCodigo, Contrato, Rubrica ORDER BY Id DESC) AS Primeiro
    FROM WorkerCredit WHERE Cpf = '27115091846'
    -- GROUP BY Cpf, IfConcessoraCodigo, Contrato, Rubrica
) SELECT * FROM RubricaPorContrato
WHERE Primeiro = 1

SELECT * FROM WorkerCredit WHERE Cpf = '27115091846'