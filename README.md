# 📘 Trabalho Prático — Pipeline RISC-V

## 🎯 Objetivo

Este projeto tem como objetivo permitir a simulação e análise de um processador RISC-V simplificado com pipeline, baseado no modelo apresentado no livro do Patterson.

O foco **não é síntese em hardware**, mas sim a compreensão dos seguintes conceitos fundamentais:

- Pipeline de instruções
- Hazards de dados (RAW)
- Forwarding (bypass)
- Stalls (bolhas)
- Hazards de controle (branch)
- Flush de pipeline
- Impacto no desempenho (CPI)

---

## 📦 Estrutura do Projeto

```
trabalho_pipeline/
├── src/
│   ├── RISCVCPU.v
│   ├── ForwardingUnit.v
│   ├── HazardDetectionUnit.v
│   ├── BranchUnit.v
│   └── PipelineStats.v
│
├── tb/
│   └── tb_RISCVCPU.v
│
└── README.md
```
---
# 🛠️ Ferramentas
---

## 🐧 Instalação no Ubuntu / Linux

```bash
sudo apt update
sudo apt install iverilog gtkwave
```

Verificar:

```bash
iverilog -V
gtkwave --version
```

---

## ▶️ Compilar e Executar

```bash
iverilog -o simv src/*.v tb/tb_RISCVCPU.v
vvp simv
```

Waveform:

```bash
gtkwave wave.vcd
```

---

## 🪟 Windows

### ✔️ Opção recomendada: WSL

```powershell
wsl --install
```

Depois:

```bash
sudo apt update
sudo apt install iverilog gtkwave
```

---

### ✔️ Opção nativa

- Icarus Verilog: http://bleyer.org/icarus/
- GTKWave: https://gtkwave.sourceforge.net/

---

## 📊 Métricas

- Ciclos
- Instruções
- Stalls
- Bypasses
- Branches
- Flushes

---

## 🧠 Conceitos

### Hazard RAW
Dependência de dados entre instruções.

### Forwarding
Evita stalls usando resultados antecipados.

### Stall
Inserção de bolhas no pipeline.

### Branch Hazard
Desvios alteram fluxo de execução.

### Flush
Descarta instruções inválidas após branch.

---

## 🐞 Debug

Verifique sinais:

- stall
- forwardA / forwardB
- branch_taken
- flush

---

## ⚠️ Observação

Projeto didático. Não sintetizável.

## 🛠️ RISC-V Assembler

Use este [montador](https://riscvasm.lucasteske.dev/#) de assembly do risc-v online para simplificar os testes!


## 📌 Licença

Uso acadêmico.
