export interface Attributes {
  prc: number; // Precisão
  vit: number; // Vitalidade
  ast: number; // Astúcia
}

export interface Character {
  name: string;
  age: string;
  vocation: string;
  classType: string;
  attributes: Attributes;
  currentHp: number;
  currentDetermination: number;
  notes: string;
}

export interface RollResult {
  total: number;
  dice: number[];
  modifier: number;
  isCrit: boolean;
  label: string;
}

export enum Difficulty {
  NORMAL = 7,
  HARD = 9,
  EXTREME = 12
}