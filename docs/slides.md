---
marp: true
theme: default
paginate: true
size: 16:9
title: Aplicação de Lógica Fuzzy na Classificação de Anomalias em APIs REST
description: Slides do trabalho final de Inteligência Artificial
style: |
  section {
    font-family: "Segoe UI", Arial, sans-serif;
    background: #f7f8fb;
    color: #18202a;
    padding: 46px 64px;
  }
  h1 {
    color: #14213d;
    font-size: 40px;
    letter-spacing: 0;
  }
  h2 {
    color: #14213d;
    font-size: 31px;
    letter-spacing: 0;
  }
  p, li {
    font-size: 23px;
    line-height: 1.22;
  }
  strong {
    color: #005f73;
  }
  table {
    font-size: 20px;
  }
  th {
    background: #14213d;
    color: #ffffff;
  }
  td, th {
    padding: 7px 10px;
  }
  code {
    background: #e8edf4;
    color: #14213d;
  }
  section.title {
    background: #14213d;
    color: #ffffff;
  }
  section.title h1,
  section.title h2,
  section.title strong {
    color: #ffffff;
  }
  section.title p {
    color: #dbe7f3;
  }
  .cols {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 26px;
    align-items: start;
  }
  .metric {
    font-size: 43px;
    font-weight: 700;
    color: #005f73;
  }
  .small {
    font-size: 18px;
  }
---

<!-- _class: title -->

# Lógica Fuzzy na Classificação de Anomalias em APIs REST

**Fuzzing guiado por contrato + Sistema de Inferência Fuzzy**

Levi Gomes - Luiz Garcia - Natã Cezer Bordignon - Renan Balestrin Bez

---

## Contexto e problema

APIs REST são base de microsserviços, apps móveis e integrações B2B. Para testar robustez, o fuzzer usa o contrato OpenAPI e envia entradas mutantes.

O desafio é o **oráculo de teste**: decidir se uma resposta inesperada é uma falha real ou um comportamento aceitável sob estresse.

Abordagens binárias tratam achados muito diferentes como iguais:

- `400` não documentado
- `200` aceitando payload inválido
- `500` por exceção interna

---

## Pergunta e objetivo

**Pergunta de pesquisa:** um Sistema de Inferência Fuzzy consegue classificar anomalias de APIs REST com mais granularidade que uma abordagem booleana?

O sistema combina três sinais:

- desvio do status code
- tempo de resposta
- razão do tamanho do payload

E gera um **score de criticidade entre 0.0 e 1.0**, depois convertido em `LOW`, `MEDIUM` ou `HIGH`.

---

## Por que Lógica Fuzzy?

A lógica booleana trabalha com fronteiras rígidas: verdadeiro ou falso.

A **Lógica Fuzzy** permite graus de pertinência:

- uma resposta pode ser parcialmente "normal" e parcialmente "lenta"
- um payload pode estar entre "esperado" e "grande"
- um desvio pode ser baixo, médio ou alto

Isso combina com testes de rede, onde latência, tamanho de resposta e comportamento sob estresse não possuem limites perfeitamente fixos.

---

## Variáveis e fluxo do FIS

<div class="cols">
<div>

| Variável | Conjuntos |
|---|---|
| `status_deviation` | low, medium, high |
| `response_time` | normal, slow, timeout |
| `payload_ratio` | expected, large, empty |
| `anomaly_score` | low, medium, high |

</div>
<div>

```text
OpenAPI
  -> payloads mutantes
  -> resposta da API
  -> tipo da anomalia
  -> score fuzzy
  -> severidade
```

O FIS atua como a **camada de inteligência** depois da coleta dos resultados.

</div>
</div>

---

## Regras de inferência

As regras traduzem conhecimento heurístico em decisões automatizadas:

- SE desvio de status é alto OU tempo é timeout, ENTÃO criticidade é alta
- SE desvio é médio E tempo é lento, ENTÃO criticidade é média
- SE desvio é baixo E payload é grande, ENTÃO criticidade é média
- SE desvio é baixo E tempo é normal E payload é esperado, ENTÃO criticidade é baixa

Depois da inferência, o resultado é desfuzzificado pelo método do **centroide**.

---

## Metodologia: status e mutações

<div class="cols">
<div>

**Desvio de status**

| Situação | Desvio |
|---|---:|
| Status documentado | `0.0` |
| Sem referência clara | `0.5` |
| `4xx` não documentado | `0.6` |
| `5xx` ou sem resposta | `1.0` |

</div>
<div>

**Mutações**

- string vazia
- string muito longa
- tipo incorreto
- campo removido
- valor numérico fora do limite
- combinações simples

</div>
</div>

---

## Metodologia: auth, classificação e ambiente

<div class="cols">
<div>

O sistema também testa endpoints protegidos:

- descoberta de registro e login
- extração de JWT
- probes sem token e com token inválido

Tipos técnicos: `SERVER_ERROR`, `UNEXPECTED_SUCCESS`, `UNEXPECTED_ERROR_STATUS`, `ERROR_CONTRADICTION`.

</div>
<div>

| Item | Configuração |
|---|---|
| Linguagem | Python 3.13 |
| Biblioteca | scikit-fuzzy |
| API alvo | crAPI |
| Endpoints | cerca de 60 |
| Fuzzing | Level 1 |
| Limite | até 10 mutações por endpoint |

</div>
</div>


---

## Resultado geral

<div class="cols">
<div>

<div class="metric">207</div>

anomalias identificadas

<div class="metric">42</div>

classificadas como alta severidade

</div>
<div>

| Severidade | Quantidade |
|---|---:|
| HIGH | 42 |
| MEDIUM | 120 |
| LOW | 45 |

Somente **20,3%** dos achados foram priorizados como críticos.

</div>
</div>


---

## Tipos de anomalia encontrados

| Classificação | Quantidade | Percentual |
|---|---:|---:|
| `UNEXPECTED_ERROR_STATUS` | 103 | 49,8% |
| `SERVER_ERROR` | 42 | 20,3% |
| `UNEXPECTED_SUCCESS` | 28 | 13,5% |
| `ERROR_CONTRADICTION` | 22 | 10,6% |
| `EXPECTED_FAILURE` | 10 | 4,8% |
| `SUCCESS_CONTRADICTION` | 2 | 1,0% |

A maioria foi documentação incompleta de erros `400`; os casos mais graves foram erros `500` e `503`.

---

## Casos representativos

| Caso | Exemplo | Score | Severidade |
|---|---|---:|---|
| Erro de servidor | `/verify-email-token` retornou `500` | 0.84 | HIGH |
| Erro não documentado | login retornou `400` fora do contrato | 0.60 | MEDIUM |
| Sucesso inesperado | `/reset-password` aceitou payload inválido | 0.50 | MEDIUM |
| Rejeição correta | erro `400` documentado | 0.31 | LOW |

O FIS diferencia falhas graves, drift de contrato e casos de baixa prioridade.

---

## Discussão

**Pontos fortes**

- priorização clara das falhas críticas
- score contínuo em vez de rótulo binário
- combinação de contrato, desempenho e payload
- potencial para execução em CI/CD

**Limitações**

- muitos `400` ficaram em severidade média
- thresholds podem ser ajustados
- regras ainda são estáticas, sem feedback adaptativo

---

## Conclusão e próximos passos

A Lógica Fuzzy mostrou-se adequada para tratar a incerteza nos testes de robustez de APIs REST.

Comparada a um oráculo binário, a abordagem reduziu a prioridade imediata de **207 achados** para **42 anomalias HIGH**.

Próximos passos:

- ajustar funções de pertinência e thresholds
- adicionar feedback do desenvolvedor
- detectar stack traces no corpo da resposta
- integrar o score fuzzy a pipelines de CI/CD