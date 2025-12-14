import React, { useState, useEffect, useCallback } from 'react';
import { Character, Attributes, RollResult } from './types';
import AttributeControl from './components/AttributeControl';
import RollModal from './components/RollModal';
import { ATTRIBUTE_DESCRIPTIONS, RULES_TEXT, CLASSES_DATA } from './constants';

const MAX_POINTS = 6;
const DEFAULT_MAX_HP_BASE = 10;
const DEFAULT_DETERMINATION = 3;

const INITIAL_CHARACTER: Character = {
  name: '',
  age: '',
  vocation: '',
  classType: 'humano',
  attributes: {
    prc: 0,
    vit: 0,
    ast: 0
  },
  currentHp: 10,
  currentDetermination: 3,
  notes: ''
};

export default function App() {
  // State
  const [character, setCharacter] = useState<Character>(INITIAL_CHARACTER);
  const [rollResult, setRollResult] = useState<RollResult | null>(null);
  const [activeTab, setActiveTab] = useState<'sheet' | 'rules'>('sheet');
  const [loaded, setLoaded] = useState(false);

  // Derived Values
  const usedPoints = (Object.values(character.attributes) as number[]).reduce((a, b) => a + b, 0);
  const pointsRemaining = MAX_POINTS - usedPoints;
  const maxHp = DEFAULT_MAX_HP_BASE + character.attributes.vit;
  
  // Class Data Helper
  const currentClassData = CLASSES_DATA[character.classType] || CLASSES_DATA['humano'];
  const limits = currentClassData.limits;

  // Load from LocalStorage
  useEffect(() => {
    const saved = localStorage.getItem('gunslinger_sheet');
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        // Ensure legacy saves merge with new structure if needed
        const merged = { ...INITIAL_CHARACTER, ...parsed };
        
        // Handle migration if needed: if classType is empty or not in keys, default to humano
        if (!CLASSES_DATA[merged.classType]) {
            merged.classType = 'humano';
        }
        
        setCharacter(merged);
      } catch (e) {
        console.error("Failed to parse saved character", e);
      }
    }
    setLoaded(true);
  }, []);

  // Save to LocalStorage
  useEffect(() => {
    if (loaded) {
      localStorage.setItem('gunslinger_sheet', JSON.stringify(character));
    }
  }, [character, loaded]);

  // Handlers
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setCharacter(prev => ({ ...prev, [name]: value }));
  };

  const updateAttribute = (attr: keyof Attributes, delta: number) => {
    setCharacter(prev => {
      const currentVal = prev.attributes[attr];
      const newVal = currentVal + delta;
      
      const attrLimit = limits[attr];

      // Safety Checks
      if (newVal < 0 || newVal > attrLimit) return prev;
      if (delta > 0 && pointsRemaining <= 0) return prev;

      let newCurrentHp = prev.currentHp;
      if (attr === 'vit') {
         const newMaxHp = DEFAULT_MAX_HP_BASE + newVal;
         if (newCurrentHp > newMaxHp) newCurrentHp = newMaxHp;
      }

      return {
        ...prev,
        attributes: {
          ...prev.attributes,
          [attr]: newVal
        },
        currentHp: newCurrentHp
      };
    });
  };

  const handleStatChange = (stat: 'currentHp' | 'currentDetermination', delta: number) => {
    setCharacter(prev => {
        let newVal = prev[stat] + delta;
        
        if (stat === 'currentDetermination') {
            if (newVal < 0) newVal = 0;
            if (newVal > DEFAULT_DETERMINATION) newVal = DEFAULT_DETERMINATION; 
        }

        if (stat === 'currentHp') {
            const currentMax = DEFAULT_MAX_HP_BASE + prev.attributes.vit;
            if (newVal > currentMax) newVal = currentMax;
            // Allow going below 0 for RPG drama (dying state)
        }

        return { ...prev, [stat]: newVal };
    });
  };

  const rollDice = (modifier: number, label: string) => {
    const d1 = Math.floor(Math.random() * 6) + 1;
    const d2 = Math.floor(Math.random() * 6) + 1;
    const total = d1 + d2 + modifier;
    const isCrit = (d1 + d2) === 12;

    setRollResult({
      total,
      dice: [d1, d2],
      modifier,
      isCrit,
      label
    });
  };

  const rollFear = () => {
    let mod = character.attributes.ast;
    // Vagante bonus logic
    if (character.classType === 'vagante') {
        mod += 2;
    }
    rollDice(mod, 'Medo (AST' + (character.classType === 'vagante' ? ' +2 Vagante' : '') + ')');
  };

  const resetCharacter = () => {
      if (confirm("Tem certeza que deseja apagar a ficha e começar de novo?")) {
          setCharacter(INITIAL_CHARACTER);
      }
  };

  if (!loaded) return <div className="min-h-screen bg-paper flex items-center justify-center text-ink font-western">Carregando munição...</div>;

  return (
    <div className="min-h-screen font-body text-ink pb-12 selection:bg-leather selection:text-white flex flex-col items-center">
      
      {/* Header */}
      <header className="w-full bg-ink text-paper p-4 shadow-lg border-b-4 border-leather mb-6">
        <div className="max-w-4xl mx-auto flex justify-between items-center">
            <div>
                <h1 className="font-western text-2xl md:text-4xl tracking-widest text-parchment">O PISTOLEIRO</h1>
                <p className="text-xs md:text-sm text-gray-400 opacity-80 uppercase tracking-widest">Ficha de Personagem</p>
            </div>
            <div className="flex gap-2">
                <button 
                    onClick={() => setActiveTab('sheet')} 
                    className={`px-4 py-2 rounded font-bold transition-colors ${activeTab === 'sheet' ? 'bg-leather text-white' : 'text-gray-400 hover:text-white'}`}
                >
                    FICHA
                </button>
                <button 
                    onClick={() => setActiveTab('rules')} 
                    className={`px-4 py-2 rounded font-bold transition-colors ${activeTab === 'rules' ? 'bg-leather text-white' : 'text-gray-400 hover:text-white'}`}
                >
                    REGRAS
                </button>
            </div>
        </div>
      </header>

      <main className="max-w-4xl w-full px-4 flex flex-col gap-8">
        
        {/* TAB: SHEET */}
        {activeTab === 'sheet' && (
            <>
            {/* 1. Basic Info */}
            <section className="bg-paper border border-ink/20 p-6 rounded shadow-sm relative">
                <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-leather to-transparent opacity-50"></div>
                <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div className="md:col-span-2">
                        <label className="block text-xs uppercase font-bold text-gray-500 mb-1">Nome</label>
                        <input 
                            type="text" 
                            name="name" 
                            value={character.name} 
                            onChange={handleInputChange}
                            className="w-full bg-transparent border-b-2 border-gray-400 focus:border-ink outline-none text-xl font-western text-ink placeholder-gray-300 transition-colors"
                            placeholder="Desconhecido"
                        />
                    </div>
                    <div>
                        <label className="block text-xs uppercase font-bold text-gray-500 mb-1">Idade</label>
                        <input 
                            type="text" 
                            name="age" 
                            value={character.age} 
                            onChange={handleInputChange}
                            className="w-full bg-transparent border-b-2 border-gray-400 focus:border-ink outline-none text-xl font-western text-ink"
                        />
                    </div>
                    <div>
                        <label className="block text-xs uppercase font-bold text-gray-500 mb-1">Vocação</label>
                        <input 
                            type="text" 
                            name="vocation" 
                            value={character.vocation} 
                            onChange={handleInputChange}
                            className="w-full bg-transparent border-b-2 border-gray-400 focus:border-ink outline-none text-xl font-western text-ink"
                        />
                    </div>
                     <div className="md:col-span-4 bg-parchment p-3 rounded border border-leather/20 mt-2">
                        <label className="block text-xs uppercase font-bold text-gray-500 mb-1">Classe</label>
                        <select 
                            name="classType" 
                            value={character.classType} 
                            onChange={handleInputChange}
                            className="w-full bg-paper border-b-2 border-gray-400 focus:border-ink outline-none text-xl font-western text-ink p-2 mb-2"
                        >
                            {Object.entries(CLASSES_DATA).map(([key, data]) => (
                                <option key={key} value={key}>{data.label}</option>
                            ))}
                        </select>
                        <div className="text-sm text-ink/80 px-2">
                            <p className="italic mb-2">"{currentClassData.description}"</p>
                            <ul className="list-disc list-inside space-y-1">
                                {currentClassData.bonuses.map((bonus, i) => (
                                    <li key={i} className="text-leather font-bold">{bonus}</li>
                                ))}
                            </ul>
                        </div>
                    </div>
                </div>
            </section>

            {/* 2. Attributes */}
            <section>
                <div className="flex justify-between items-center mb-4 border-b border-ink/20 pb-2 bg-orange-700 text-paper p-2 rounded shadow">
                    <h2 className="text-2xl font-western">Atributos</h2>
                    <div className={`font-bold bg-black/20 px-2 rounded`}>
                        Pontos: <span className="text-xl">{pointsRemaining}</span> / 6
                    </div>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <AttributeControl 
                        label="Precisão"
                        shortLabel="PRC"
                        value={character.attributes.prc}
                        description={ATTRIBUTE_DESCRIPTIONS.prc}
                        pointsRemaining={pointsRemaining}
                        maxValue={limits.prc}
                        onIncrement={() => updateAttribute('prc', 1)}
                        onDecrement={() => updateAttribute('prc', -1)}
                        onRoll={() => rollDice(character.attributes.prc, 'Precisão')}
                    />
                    <AttributeControl 
                        label="Vitalidade"
                        shortLabel="VIT"
                        value={character.attributes.vit}
                        description={ATTRIBUTE_DESCRIPTIONS.vit}
                        pointsRemaining={pointsRemaining}
                        maxValue={limits.vit}
                        onIncrement={() => updateAttribute('vit', 1)}
                        onDecrement={() => updateAttribute('vit', -1)}
                        onRoll={() => rollDice(character.attributes.vit, 'Vitalidade')}
                    />
                    <AttributeControl 
                        label="Astúcia"
                        shortLabel="AST"
                        value={character.attributes.ast}
                        description={ATTRIBUTE_DESCRIPTIONS.ast}
                        pointsRemaining={pointsRemaining}
                        maxValue={limits.ast}
                        onIncrement={() => updateAttribute('ast', 1)}
                        onDecrement={() => updateAttribute('ast', -1)}
                        onRoll={() => rollDice(character.attributes.ast, 'Astúcia')}
                    />
                </div>
            </section>

            {/* 3. Status Trackers */}
            <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
                
                {/* Health */}
                <div className="bg-paper p-6 rounded border-2 border-blood/30 flex flex-col items-center relative overflow-hidden">
                    <div className="absolute top-2 left-2 font-western text-blood text-opacity-20 text-6xl pointer-events-none">HP</div>
                    <h3 className="font-western text-2xl text-blood mb-4 flex items-center gap-2">
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M19 14c1.49-1.28 3.6-2.34 4.53-3.26a6.5 6.5 0 0 0 0-9.27A6.33 6.33 0 0 0 14.5 5a6.33 6.33 0 0 0-9 3.47A6.5 6.5 0 0 0 9.86 14c.93.92 3.04 1.98 4.53 3.26 1.51 1.29 2 2 4.6 4.74 2.6-2.74 3.09-3.45 4.6-4.74z"/></svg>
                        VIDA <span className="text-sm text-ink font-body">(Máx: {maxHp})</span>
                    </h3>
                    <div className="flex items-center gap-6">
                        <button onClick={() => handleStatChange('currentHp', -1)} className="w-12 h-12 bg-blood text-white rounded text-2xl font-bold hover:brightness-110 active:scale-95 shadow">-</button>
                        <div className="text-5xl font-western text-blood w-24 text-center">{character.currentHp}</div>
                        <button onClick={() => handleStatChange('currentHp', 1)} className="w-12 h-12 bg-green-700 text-white rounded text-2xl font-bold hover:brightness-110 active:scale-95 shadow">+</button>
                    </div>
                </div>

                {/* Determination */}
                <div className="bg-paper p-6 rounded border-2 border-indigo-900/30 flex flex-col items-center relative overflow-hidden">
                     <div className="absolute top-2 left-2 font-western text-indigo-900 text-opacity-10 text-6xl pointer-events-none">DT</div>
                    <h3 className="font-western text-2xl text-indigo-900 mb-4 flex items-center gap-2">
                         <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="currentColor" stroke="none"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                        DETERMINAÇÃO <span className="text-sm text-ink font-body">(Máx: 3)</span>
                    </h3>
                    <div className="flex items-center gap-6">
                        <button onClick={() => handleStatChange('currentDetermination', -1)} className="w-12 h-12 bg-indigo-900 text-white rounded text-2xl font-bold hover:brightness-110 active:scale-95 shadow">-</button>
                        <div className="text-5xl font-western text-indigo-900 w-24 text-center">{character.currentDetermination}</div>
                        <button onClick={() => handleStatChange('currentDetermination', 1)} className="w-12 h-12 bg-indigo-500 text-white rounded text-2xl font-bold hover:brightness-110 active:scale-95 shadow">+</button>
                    </div>
                </div>

            </section>
            
            {/* Medo / Quick Actions */}
            <section className="bg-parchment border-2 border-ink p-4 rounded shadow-md relative overflow-hidden">
                <div className="flex justify-between items-center mb-3 border-b border-ink/20 pb-2">
                    <h3 className="font-western text-xl text-ink">Teste de Medo</h3>
                    <span className="text-sm text-ink/70 italic font-bold">Criaturas Espectrais</span>
                </div>
                <div className="flex flex-col sm:flex-row justify-between items-center gap-4">
                    <div className="text-lg text-ink leading-snug">
                        Role <span className="font-bold bg-white/50 px-1 rounded">2d6 + AST {character.classType === 'vagante' ? ' + 2 (Vagante)' : ''}</span>. CD <span className="font-bold">7</span>. 
                        Falhar causa <span className="font-bold text-blood border-b-2 border-blood/20">Desvantagem</span> na primeira rodada.
                    </div>
                    <button 
                        onClick={rollFear}
                        className="bg-ink text-paper px-6 py-3 font-western uppercase tracking-wider hover:bg-leather transition-colors shadow-lg whitespace-nowrap rounded"
                    >
                        Rolar Medo
                    </button>
                </div>
            </section>
            
            <div className="flex justify-center mt-8">
                <button onClick={resetCharacter} className="text-xs text-red-500 underline opacity-60 hover:opacity-100">
                    Resetar Personagem
                </button>
            </div>
            </>
        )}

        {/* TAB: RULES */}
        {activeTab === 'rules' && (
            <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-300">
                
                {/* Combat Rules */}
                <div className="bg-paper p-6 rounded shadow-md border-l-4 border-blood">
                    <h2 className="font-western text-3xl text-blood mb-4 flex items-center gap-2">
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m2 4 3 12h14l3-12-6 7-4-7-4 7-6-7zm3 16h14"/></svg>
                        Combate
                    </h2>
                    <ul className="space-y-4">
                        {RULES_TEXT.combat.map((rule, idx) => (
                            <li key={idx} className="border-b border-gray-300 pb-2 last:border-0">
                                <span className="font-bold text-lg text-ink block">{rule.title}</span>
                                <span className="text-gray-700">{rule.text}</span>
                            </li>
                        ))}
                    </ul>
                </div>

                {/* Duel Rules */}
                 <div className="bg-paper p-6 rounded shadow-md border-l-4 border-ink">
                    <h2 className="font-western text-3xl text-ink mb-4 flex items-center gap-2">
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg>
                        Duelo de Pistoleiros
                    </h2>
                    <div className="space-y-4">
                        {RULES_TEXT.duel.map((rule, idx) => (
                            <div key={idx} className="bg-parchment p-3 rounded">
                                <h4 className="font-western text-lg mb-1">{rule.step}</h4>
                                <p className="text-sm">{rule.text}</p>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Difficulty Reference */}
                <div className="bg-paper p-6 rounded shadow-md border-l-4 border-green-800">
                    <h2 className="font-western text-2xl text-green-800 mb-2">Dificuldades</h2>
                    <div className="grid grid-cols-3 gap-2 text-center">
                        <div className="bg-green-100 p-2 rounded border border-green-200">
                            <div className="font-bold text-xl">7</div>
                            <div className="text-xs uppercase">Normal</div>
                        </div>
                        <div className="bg-yellow-100 p-2 rounded border border-yellow-200">
                            <div className="font-bold text-xl">9</div>
                            <div className="text-xs uppercase">Difícil</div>
                        </div>
                        <div className="bg-red-100 p-2 rounded border border-red-200">
                            <div className="font-bold text-xl">12</div>
                            <div className="text-xs uppercase">Extremo</div>
                        </div>
                    </div>
                </div>
            </div>
        )}

      </main>

      {/* Footer / Notes Area */}
      {activeTab === 'sheet' && (
        <footer className="max-w-4xl w-full px-4 mt-8">
            <label className="block text-lg font-western text-paper bg-orange-700 p-2 rounded shadow mb-2">Anotações & Inventário</label>
            <textarea 
                className="w-full min-h-[150px] bg-paper border border-ink/20 p-4 rounded shadow-inner font-body text-lg focus:border-ink outline-none resize-y"
                placeholder="Escreva seu inventário, munição ou notas da campanha aqui..."
                value={character.notes}
                onChange={handleInputChange}
                name="notes"
            ></textarea>
        </footer>
      )}

      {/* Roll Modal */}
      <RollModal result={rollResult} onClose={() => setRollResult(null)} />

    </div>
  );
}