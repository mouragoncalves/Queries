declare @mat_esocial nvarchar(100) = 'USB09031998R0002';
 
 
select
    ee.matricula,
	ve.id_enrollment,
	ve.enrollment_code,
	ve.name_first,
	case
		when tp.object = 'CONTRA_CHEQUE'
		or tp.object = 'CONTRA_CHEQUE_RETROATIVO'
		or tp.object = 'CONTRA_CHEQUE_INTERMITENTE' 
		or tp.object = 'AUXILIO_MANUTENCAO_RELIGIOSO' then 'Salário Mensal'
		when tp.object = 'FERIAS' 
		or tp.object = 'DESCANSO_ANUAL_RELIGIOSO' then 'Férias'
		when tp.object = 'RESCISAO' 
		or tp.object = 'AJUSTE_FINAL_RELIGIOSO' then 'Rescisão'
		when tp.object = 'DECIMO_TERCEIRO' then 'Décimo Terceiro'
		when tp.object = 'ADIANTAMENTO' then 'Ajuda de Custo'
		when tp.object = 'RPA' then 'RPS'
		when tp.object = 'ADIANTAMENTO_SALARIO' then 'Adiantamento Salário'
		when tp.object = 'Reembolso_Despesa_Viagem' then 'Reembolso viagem'
		when tp.object = 'MOBILIDADE' then 'Mobilidade'
	end tipo_pagamento,
	concat(a.code,'-',a.name) verba,
	case
		when ao.type = 0 then 'Exclusão' else 'Inclusão' 
	end inc_exc,
	ao.money_1 referencia,
	ao.money_2 value,
	ao.datetime_1 data_reajuste,
	ao.char_1 fixado_por
from 
	Allowance_Object ao
	inner join Allowance a on a.id_allowance=ao.id_allowance
	inner join v_employee ve on ve.id_enrollment=ao.pk
	inner join Enrollment_Employee ee on ee.id_enrollment=ve.id_enrollment
	inner join v_type_payment tp on tp.id_type_payment=ao.id_type_payment
where
 ao.datetime_1 >= '2025-09-01'
-- 	ee.matricula = @mat_esocial 