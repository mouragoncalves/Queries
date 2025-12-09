SELECT 
    [Month], FORMAT(SUM(ValorParcela), '#,##0.00', 'pt-BR') AS ValorTotalParcela
FROM WorkerCredit 
WHERE [Month] >= 7 AND [Month] <= 10
GROUP BY [Month]
ORDER BY [Month]