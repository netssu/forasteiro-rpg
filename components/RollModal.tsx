import React from 'react';
import { RollResult, Difficulty } from '../types';

interface RollModalProps {
  result: RollResult | null;
  onClose: () => void;
}

const RollModal: React.FC<RollModalProps> = ({ result, onClose }) => {
  if (!result) return null;

  const getSuccessLevel = (total: number) => {
    if (total >= Difficulty.EXTREME) return { text: "Sucesso Extremo!", color: "text-purple-700" };
    if (total >= Difficulty.HARD) return { text: "Sucesso Difícil!", color: "text-blue-700" };
    if (total >= Difficulty.NORMAL) return { text: "Sucesso Normal", color: "text-green-700" };
    return { text: "Falha", color: "text-blood" };
  };

  const status = getSuccessLevel(result.total);

  return (
    <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
      <div className="bg-paper max-w-sm w-full rounded-lg shadow-2xl border-4 border-ink p-6 relative flex flex-col items-center gap-4">
        
        <button 
          onClick={onClose}
          className="absolute top-2 right-2 text-ink hover:text-blood font-bold text-xl"
        >
          &times;
        </button>

        <h2 className="font-western text-2xl text-ink uppercase tracking-widest border-b-2 border-leather w-full text-center pb-2">
          Teste de {result.label}
        </h2>

        <div className="flex gap-4 items-center justify-center my-4">
            {/* Dice 1 */}
            <div className="w-16 h-16 bg-white border-2 border-ink rounded-lg flex items-center justify-center text-3xl font-bold shadow-[4px_4px_0px_0px_rgba(44,36,27,1)]">
                {result.dice[0]}
            </div>
            <span className="text-2xl font-western text-ink">+</span>
            {/* Dice 2 */}
            <div className="w-16 h-16 bg-white border-2 border-ink rounded-lg flex items-center justify-center text-3xl font-bold shadow-[4px_4px_0px_0px_rgba(44,36,27,1)]">
                {result.dice[1]}
            </div>
            {/* Modifier */}
            <div className="flex flex-col items-center">
                <span className="text-xs uppercase font-bold text-gray-500">Bônus</span>
                <span className="text-xl font-bold text-ink">+{result.modifier}</span>
            </div>
        </div>

        <div className="text-center">
            <div className="text-sm text-gray-600 uppercase tracking-widest mb-1">Resultado Total</div>
            <div className={`text-6xl font-western ${result.isCrit ? 'text-blood animate-pulse' : 'text-ink'}`}>
                {result.total}
            </div>
            {result.isCrit && <div className="text-blood font-bold uppercase text-sm mt-1">Crítico Natural!</div>}
        </div>

        <div className={`text-xl font-bold ${status.color} border-t border-gray-300 w-full text-center pt-3`}>
            {status.text}
        </div>

        <div className="text-xs text-gray-500 mt-2 text-center w-full bg-parchment p-2 rounded">
            <p>CD 7 (Normal) • CD 9 (Difícil) • CD 12 (Extremo)</p>
            <p className="mt-1">Falha? Gaste 1 Determinação para rerolar 1 dado.</p>
        </div>

        <button 
          onClick={onClose}
          className="mt-2 w-full bg-ink text-paper font-western py-3 rounded hover:bg-leather transition-colors"
        >
          CONTINUAR
        </button>
      </div>
    </div>
  );
};

export default RollModal;