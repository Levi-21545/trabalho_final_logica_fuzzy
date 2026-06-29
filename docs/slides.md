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
  .pipeline {
    text-align: center;
    font-size: 18px;
    line-height: 1.5;
  }
  .pipeline .arrow {
    font-size: 28px;
    color: #005f73;
    display: block;
  }
  .tag {
    display: inline-block;
    background: #005f73;
    color: #fff;
    padding: 2px 10px;
    border-radius: 4px;
    font-size: 16px;
    font-weight: 600;
  }
  .boxed {
    background: #e8edf4;
    padding: 10px 16px;
    border-radius: 6px;
    margin: 4px 0;
  }
  .highlight {
    font-size: 38px;
    font-weight: 700;
    color: #c0392b;
  }
---

<!-- _class: title -->

# Lógica Fuzzy na Classificação de Anomalias em APIs REST

**Fuzzing guiado por contrato + Sistema de Inferência Fuzzy (Mamdani)**

Levi Gomes - Luiz Garcia - Natã Cezer Bordignon - Renan Balestrin Bez

---

## Contexto e problema

APIs REST são base de microsserviços, apps móveis e integrações B2B. Para testar robustez, o fuzzer usa o contrato OpenAPI e envia entradas mutantes.

O desafio é o **oráculo de teste**: decidir se uma resposta inesperada é uma falha real ou um comportamento aceitável sob estresse.

Abordagens binárias tratam achados muito diferentes como iguais:

- `400` não documentado
- `200` aceitando payload inválido
- `500` por exceção interna

<div class="cols" style="margin-top: 16px;">
<div class="boxed" style="text-align: center;">

**Oráculo booleano:** falha / passa

</div>
<div class="boxed" style="text-align: center;">

**Lógica Fuzzy:** score contínuo **[0, 1]**

</div>
</div>

---

## Pergunta e objetivo

**Pergunta de pesquisa:** um Sistema de Inferência Fuzzy (FIS) consegue classificar anomalias de APIs REST com mais granularidade que uma abordagem booleana?

O FIS combina três variáveis de entrada:

- `status_deviation`  — desvio do código HTTP
- `response_time`     — latência da resposta
- `payload_ratio`     — tamanho relativo do payload

Gera um **score contínuo entre 0.0 e 1.0**, convertido em `LOW`, `MEDIUM` ou `HIGH`.

<span class="tag">Score contínuo — não binário</span>

---

## Por que Lógica Fuzzy?

<div class="cols">
<div class="boxed">

**Lógica Booleana**

Fronteiras rígidas

- resposta é "normal" **ou** "lenta"
- payload é "esperado" **ou** "grande"
- desvio é "presente" **ou** "ausente"

</div>
<div class="boxed">

**Lógica Fuzzy**

**Graus de pertinência** \([0, 1]\)

- resposta: 30% normal + 70% lenta
- payload: 60% esperado + 40% grande
- desvio: baixo, médio ou alto

</div>
</div>

As **funções de pertinência triangulares e trapezoidais** mapeiam cada valor observado para o intervalo \([0, 1]\), capturando a incerteza natural de métricas de rede como latência e tamanho de resposta.

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
<div class="pipeline">

<span class="boxed" style="display:inline-block;">
`status_deviation`<br>`response_time`<br>`payload_ratio`
</span>

<span class="arrow">↓</span>

<span class="boxed" style="display:inline-block;">
<b>Fuzzificação</b><br><span class="small">funções triang./trap.</span>
</span>

<span class="arrow">↓</span>

<span class="boxed" style="display:inline-block;">
<b>Inferência</b><br><span class="small">Mamdani — 9 regras</span>
</span>

<span class="arrow">↓</span>

<span class="boxed" style="display:inline-block;">
<b>Desfuzzificação</b><br><span class="small">centroide</span>
</span>

<span class="arrow">↓</span>

<span class="boxed" style="display:inline-block;">
<b>anomaly_score</b><br><span class="small">[0.0 — 1.0]</span>
</span>

</div>
</div>

<span class="tag" style="margin-top: 8px;">LOW [0, 0.33) · MEDIUM [0.33, 0.66) · HIGH [0.66, 1.0]</span>

---

## Regras de inferência

As regras traduzem **conhecimento heurístico** em decisões automatizadas. **9 regras** no total — interpretáveis e ajustáveis:

```
SE desvio é alto OU tempo é timeout              → criticidade ALTA
SE desvio é alto                                  → criticidade ALTA
SE desvio é médio E tempo é lento                  → criticidade MÉDIA
SE desvio é baixo E payload é grande               → criticidade MÉDIA
SE desvio é baixo E tempo é normal E payload ok    → criticidade BAIXA
```

<span class="tag">Inferência Mamdani</span> <span class="tag">Desfuzzificação por centroide</span> <span class="tag">Regras interpretáveis</span>

---

## Metodologia: status e mutações

<div class="cols">
<div>

**Desvio de status**

| Situação | Desvio |
|---:|---:|
| Status documentado | `0.0` |
| Sem referência clara | `0.5` |
| `4xx` não documentado | `0.6` |
| `5xx` ou sem resposta | `1.0` |

</div>
<div>

**Mutações (entrada do FIS)**

| Nível | Descrição |
|---|---|
| Level 0 | Baseline válido |
| Level 1 | 1 violação por vez (tipo, vazio, overflow) |
| Level 2 | 2 violações simultâneas |

</div>
</div>

O valor de `status_deviation` alimenta o FIS com um **grau de desvio** — quanto maior, maior o impacto nas regras de inferência.

---

## Metodologia: auth, classificação e ambiente

<div class="cols">
<div>

O sistema testa endpoints protegidos com auto-auth e probes de autenticação.

**Pipeline da análise:**

```
Resposta bruta
  → classificador binário (tipo da anomalia)
  → FIS (score contínuo)
  → severidade (LOW/MEDIUM/HIGH)
```

Tipos: `SERVER_ERROR`, `UNEXPECTED_SUCCESS`, `UNEXPECTED_ERROR_STATUS`, `ERROR_CONTRADICTION`.

</div>
<div>

| Item | Configuração |
|---|---|
| Linguagem | Python 3.13 |
| Biblioteca | scikit-fuzzy |
| API alvo | crAPI |
| Endpoints | cerca de 60 |
| Fuzzing | Level 1 |
| Limite | até 10 mutações / endpoint |

</div>
</div>

---

## Resultado geral

<div class="cols">
<div>

<div class="metric">207</div>

anomalias identificadas

<div class="highlight">42</div>

classificadas como <b>HIGH</b> (≥ 0.66)

<span class="small">**20,3%** dos achados priorizados como críticos</span>

</div>
<div>

| Severidade | Intervalo | Quantidade |
|---|---|---|
| **HIGH** | ≥ 0.66 | **42** |
| MEDIUM | [0.33, 0.66) | 120 |
| LOW | < 0.33 | 45 |

O score contínuo do FIS permitiu reduzir a prioridade imediata de **207** para **42** anomalias.

</div>
</div>

---

## Tipos de anomalia encontrados

| Classificação | Quantidade | Percentual |
|---|---|---|
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
|---|---|---|---|
| Erro de servidor | `/verify-email-token` retornou `500` | 0.84 | HIGH |
| Erro não documentado | login retornou `400` fora do contrato | 0.60 | MEDIUM |
| Sucesso inesperado | `/reset-password` aceitou payload inválido | 0.50 | MEDIUM |
| Rejeição correta | erro `400` documentado | 0.31 | LOW |

O FIS diferencia falhas graves, drift de contrato e casos de baixa prioridade.

---

## Discussão

**Pontos fortes**

- priorização clara das falhas críticas
- **score contínuo** em vez de rótulo binário
- combinação de contrato, desempenho e payload
- regras interpretáveis e ajustáveis
- potencial para execução em CI/CD

**Limitações**

- muitos `400` ficaram em severidade média
- thresholds podem ser ajustados
- regras ainda são estáticas, sem feedback adaptativo

---

## Conclusão e próximos passos

A Lógica Fuzzy mostrou-se adequada para tratar a **incerteza** nos testes de robustez de APIs REST, substituindo a decisão binária por um **score contínuo** baseado em graus de pertinência e regras interpretáveis.

Comparada a um oráculo booleano, a abordagem reduziu a prioridade imediata de **207 achados** para **42 anomalias HIGH**.

Próximos passos:

- ajustar funções de pertinência e thresholds
- adicionar feedback do desenvolvedor
- detectar stack traces no corpo da resposta
- integrar o score fuzzy a pipelines de CI/CD
