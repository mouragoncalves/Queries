-- SELECT * FROM WorkerCredit WHERE MainEntityCode = '141221';

WITH DadosBase AS (
    SELECT 
        MainEntityCode,
        Competencia,
        Cpf,
        Matricula,
        Contrato,
        ValorLiberado,
        ValorParcela,
        TotalParcelas,
        COUNT(*) OVER (PARTITION BY MainEntityCode, Cpf, Year, Month) AS QtdRegistrosCPF,
        ROW_NUMBER() OVER (PARTITION BY MainEntityCode, Cpf, Year, Month, Contrato ORDER BY Id) as RN_Contrato
    FROM [dbo].[WorkerCredit]
    -- WHERE Competencia IN ('2025-06', '2025-07', '2025-08')
    --   AND Month IN (6, 7, 8) 
    --   AND Year = 2025
), DadosUnicos AS (
    SELECT 
        MainEntityCode,
        Competencia,
        Cpf,
        Matricula,
        Contrato,
        ValorLiberado,
        ValorParcela,
        TotalParcelas,
        QtdRegistrosCPF
    FROM DadosBase
    WHERE RN_Contrato = 1  -- Pega apenas um registro por contrato
), EmprestimosPorCPF AS (
    SELECT 
        MainEntityCode,
        Competencia,
        Cpf,
        COUNT(DISTINCT Contrato) as QtdEmprestimosPorCPF,
        SUM(ValorLiberado) as ValorTotalEmprestimosCPF,
        MIN(ValorLiberado) MinTotalEmprestimosLiberado,
        MAX(ValorLiberado) MaxTotalEmprestimosLiberado,
        SUM(ValorParcela) as ValorTotalParcelasCPF,
        MIN(ValorParcela) MinValorParcela,
        MAX(ValorParcela) MaxValorParcela,
        SUM(TotalParcelas) as TotalParcelasCPF
    FROM DadosUnicos
    GROUP BY MainEntityCode, Competencia, Cpf
),

ResumoConsolidado AS (
    SELECT 
        MainEntityCode,
        Competencia,
        SUM(CASE WHEN QtdEmprestimosPorCPF = 1 THEN 1 ELSE 0 END) as Empregados_1_Emprestimo,
        SUM(CASE WHEN QtdEmprestimosPorCPF = 2 THEN 1 ELSE 0 END) as Empregados_2_Emprestimos,
        SUM(CASE WHEN QtdEmprestimosPorCPF >= 3 THEN 1 ELSE 0 END) as Empregados_3_ou_Mais_Emprestimos,
        SUM(QtdEmprestimosPorCPF) as Total_Emprestimos,
        SUM(ValorTotalEmprestimosCPF) as Valor_Total_Emprestimos,
        MIN(MinTotalEmprestimosLiberado) MinTotalEmprestimosLiberado,
        MAX(MaxTotalEmprestimosLiberado) MaxTotalEmprestimosLiberado,
        SUM(ValorTotalParcelasCPF) as Valor_Total_Parcelas,
        MIN(MinValorParcela) MinValorParcela,
        MAX(MaxValorParcela) MaxValorParcela,
        SUM(TotalParcelasCPF) as Total_Parcelas_Geral,
        COUNT(DISTINCT Cpf) as Total_Empregados
        
    FROM EmprestimosPorCPF
    GROUP BY MainEntityCode, Competencia
)

SELECT 
    MainEntityCode as Entidade_Matriz,
    Competencia as Mes_Ano,
    
    -- Quantidades de empregados por número de empréstimos (formatados)
    FORMAT(Empregados_1_Emprestimo, 'N0', 'pt-BR') as Empregados_1_Emprestimo,
    FORMAT(Empregados_2_Emprestimos, 'N0', 'pt-BR') as Empregados_2_Emprestimos,
    FORMAT(Empregados_3_ou_Mais_Emprestimos, 'N0', 'pt-BR') as Empregados_3_ou_Mais_Emprestimos,
    FORMAT(Total_Empregados, 'N0', 'pt-BR') as Total_Empregados,
    
    -- Total de empréstimos (formatado)
    FORMAT(Total_Emprestimos, 'N0', 'pt-BR') as Total_Emprestimos,
    
    -- Valores monetários formatados (sem R$)
    FORMAT(Valor_Total_Emprestimos, 'N2', 'pt-BR') as Valor_Total_Emprestimos,
    FORMAT(MinTotalEmprestimosLiberado, 'N2', 'pt-BR') MinTotalEmprestimosLiberado,
    FORMAT(MaxTotalEmprestimosLiberado, 'N2', 'pt-BR') MaxTotalEmprestimosLiberado,
    FORMAT(Valor_Total_Parcelas, 'N2', 'pt-BR') as Valor_Total_Parcelas,
    FORMAT(MinValorParcela, 'N2', 'pt-BR') MinValorParcela,
    FORMAT(MaxValorParcela, 'N2', 'pt-BR') MaxValorParcela,
    
    -- 7. Média da quantidade de parcelas por empréstimo (formatado)
    FORMAT(
        CASE 
            WHEN Total_Emprestimos > 0 THEN 
                ROUND(CAST(Total_Parcelas_Geral AS DECIMAL(10,2)) / Total_Emprestimos, 2)
            ELSE 0 
        END, 'N2', 'pt-BR'
    ) as Media_Parcelas_Por_Emprestimo,
    
    -- 8. Média do valor da parcela por empregado (formatado sem R$)
    FORMAT(
        CASE 
            WHEN Total_Empregados > 0 THEN 
                Valor_Total_Parcelas / Total_Empregados
            ELSE 0
        END, 'N2', 'pt-BR'
    ) as Media_Valor_Parcela_Por_Empregado

FROM ResumoConsolidado

-- Ordenação: Entidade, ano e depois por mês
ORDER BY MainEntityCode, Competencia;

-- Query adicional para visualizar a evolução consolidada (totais gerais por mês)
/*
SELECT 
    Month as Mes,
    Year as Ano,
    Competencia as Mes_Ano,
    SUM(Empregados_1_Emprestimo) as Total_Empregados_1_Emprestimo,
    SUM(Empregados_2_Emprestimos) as Total_Empregados_2_Emprestimos,
    SUM(Empregados_3_ou_Mais_Emprestimos) as Total_Empregados_3_ou_Mais,
    SUM(Total_Empregados) as Total_Geral_Empregados,
    SUM(Total_Emprestimos) as Total_Geral_Emprestimos,
    FORMAT(SUM(Valor_Total_Emprestimos), 'C', 'pt-BR') as Valor_Total_Geral,
    ROUND(
        CASE 
            WHEN SUM(Total_Emprestimos) > 0 THEN 
                CAST(SUM(Total_Parcelas_Geral) AS DECIMAL(10,2)) / SUM(Total_Emprestimos)
            ELSE 0 
        END, 2
    ) as Media_Geral_Parcelas_Por_Emprestimo
FROM ResumoConsolidado
GROUP BY Month, Year, Competencia
ORDER BY Year, Month;
*/