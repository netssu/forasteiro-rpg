import React from 'react';

interface AttributeControlProps {
  label: string;
  shortLabel: string;
  value: number;
  description: string;
  pointsRemaining: number;
  maxValue?: number;
  onIncrement: () => void;
  onDecrement: () => void;
  onRoll: () => void;
}

const AttributeControl: React.FC<AttributeControlProps> = ({
  label,
  shortLabel,
  value,
  description,
  pointsRemaining,
  maxValue = 4,
  onIncrement,
  onDecrement,
  onRoll
}) => {
  const canIncrement = pointsRemaining > 0 && value < maxValue;
  const canDecrement = value > 0;

  return (
    <div className="bg-parchment/50 border-2 border-leather rounded p-4 flex flex-col gap-2 shadow-sm relative overflow-hidden group">
      <div className="flex justifying-between items-center w-full">
        <h3 className="font-western text-xl text-ink uppercase tracking-wider">{label} <span className="text-sm opacity-60 font-body">({shortLabel})</span></h3>
        <button
          onClick={onRoll}
          className="bg-ink text-paper px-3 py-1 rounded-full text-xs font-bold hover:bg-leather transition-colors flex items-center gap-1 shadow-md active:translate-y-0.5"
          title="Rolar Dados"
        >
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect width="18" height="18" x="3" y="3" rx="2" ry="2"/><path d="m16 8-8 8"/><path d="M16 16h.01"/><path d="M8 8h.01"/></svg>
          ROLAR
        </button>
      </div>
      
      <p className="text-sm text-ink/80 italic min-h-[40px] leading-tight">{description}</p>
      
      <div className="flex items-center justify-center gap-4 mt-2">
        <button 
          onClick={onDecrement}
          disabled={!canDecrement}
          className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-xl border-2 transition-all
            ${canDecrement ? 'border-blood text-blood hover:bg-blood hover:text-white cursor-pointer' : 'border-gray-400 text-gray-400 opacity-50 cursor-not-allowed'}
          `}
        >
          -
        </button>
        
        <div className="text-4xl font-western text-ink w-12 text-center relative">
          {value}
          <span className="text-[10px] absolute -top-2 -right-4 text-gray-400">/{maxValue}</span>
        </div>

        <button 
          onClick={onIncrement}
          disabled={!canIncrement}
          className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-xl border-2 transition-all
            ${canIncrement ? 'border-green-800 text-green-800 hover:bg-green-800 hover:text-white cursor-pointer' : 'border-gray-400 text-gray-400 opacity-50 cursor-not-allowed'}
          `}
        >
          +
        </button>
      </div>
    </div>
  );
};

export default AttributeControl;