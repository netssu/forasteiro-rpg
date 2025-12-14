export const ATTRIBUTE_DESCRIPTIONS = {
  prc: "Habilidade de mirar, atirar, duelar e usar armas à distância.",
  vit: "Força física, resistência ao dano, capacidade de tomar e aguentar pancada.",
  ast: "Reflexos, furtividade, percepção, blefe e sobrevivência sobrenatural."
};

export const CLASSES_DATA: Record<string, { label: string; description: string; bonuses: string[]; limits: { prc: number; vit: number; ast: number } }> = {
  humano: {
    label: "Humano",
    description: "Apenas um Forasteiro que vaga por essas bandas...",
    bonuses: [
      "+1 em limite de PRC (Máx 5)",
      "Interação Pacífica: A primeira interação com NPCs humanos é sempre pacífica."
    ],
    limits: { prc: 5, vit: 4, ast: 4 }
  },
  vagante: {
    label: "Vagante",
    description: "O Diabo me trouxe aqui, por um motivo... e eu vou cumpri-lo.",
    bonuses: [
      "+2 em testes de medo",
      "Sua alma pela minha: você não morre ao zerar o hp, porém necessita ter uma vida a pagar para retornar."
    ],
    limits: { prc: 4, vit: 4, ast: 4 }
  },
  indigena: {
    label: "Indígena",
    description: "Minhas terras serão novamente minhas...",
    bonuses: [
      "+2 no limite de Vitalidade (Máx 6)",
      "Rituais: Você desbloqueia a capacidade de usar magias e rituais antigos."
    ],
    limits: { prc: 4, vit: 6, ast: 4 }
  }
};

export const RULES_TEXT = {
  combat: [
    { title: "Rodada", text: "Atirar, Correr, Recarregar ou Ação Especial." },
    { title: "Ataque", text: "2d6 + PRC" },
    { title: "Dano", text: "Base + Bônus. Crítico (12 natural) dobra o dano." }
  ],
  duel: [
    { step: "1. Olhar Mortal", text: "2d6 + AST vs AST do oponente. Vencedor ganha Iniciativa e Vantagem." },
    { step: "2. Mão no Coldre", text: "2d6 + PRC (CD 7). Falha perde Vantagem mas ainda atira." },
    { step: "3. Tiro Final", text: "Metade da Vida em um tiro = cai no chão." }
  ]
};