import re
import time
from typing import Dict, Any, List
from collections import Counter


class TextAnalyzer:
    """
    Analisador de texto simples para demonstração.
    Futuramente será substituído por Gemini + LangGraph.
    """
    
    def analyze_text(self, text: str) -> Dict[str, Any]:
        """
        Analisa um texto e retorna estatísticas básicas.
        
        Args:
            text: Texto a ser analisado
            
        Returns:
            Dicionário com análises do texto
        """
        start_time = time.time()
        
        # Análises básicas
        analysis = {
            'word_count': self._count_words(text),
            'char_count': len(text),
            'char_count_no_spaces': len(text.replace(' ', '')),
            'line_count': len(text.split('\n')),
            'paragraph_count': len([p for p in text.split('\n\n') if p.strip()]),
            'sentence_count': self._count_sentences(text),
            'avg_word_length': self._calculate_avg_word_length(text),
            'most_common_words': self._get_most_common_words(text, top=10),
            'text_stats': self._get_text_statistics(text),
            'processing_time': round(time.time() - start_time, 3)
        }
        
        return analysis
    
    def _count_words(self, text: str) -> int:
        """Conta palavras no texto."""
        words = re.findall(r'\b\w+\b', text.lower())
        return len(words)
    
    def _count_sentences(self, text: str) -> int:
        """Conta frases no texto."""
        sentences = re.split(r'[.!?]+', text)
        return len([s for s in sentences if s.strip()])
    
    def _calculate_avg_word_length(self, text: str) -> float:
        """Calcula comprimento médio das palavras."""
        words = re.findall(r'\b\w+\b', text.lower())
        if not words:
            return 0.0
        return round(sum(len(word) for word in words) / len(words), 2)
    
    def _get_most_common_words(self, text: str, top: int = 10) -> List[Dict[str, Any]]:
        """Retorna as palavras mais comuns."""
        words = re.findall(r'\b\w+\b', text.lower())
        
        # Filtrar palavras muito curtas e comuns
        stop_words = {'a', 'o', 'e', 'de', 'do', 'da', 'em', 'um', 'uma', 'para', 'com', 'por', 'que', 'se', 'é', 'ou', 'as', 'os', 'no', 'na', 'ao', 'à', 'te', 'me', 'tu', 'você', 'ele', 'ela', 'nós', 'eles', 'elas'}
        
        filtered_words = [word for word in words if len(word) > 2 and word not in stop_words]
        
        counter = Counter(filtered_words)
        return [
            {'word': word, 'count': count, 'frequency': round(count / len(words) * 100, 2)}
            for word, count in counter.most_common(top)
        ]
    
    def _get_text_statistics(self, text: str) -> Dict[str, Any]:
        """Retorna estatísticas gerais do texto."""
        words = re.findall(r'\b\w+\b', text.lower())
        
        return {
            'has_numbers': bool(re.search(r'\d', text)),
            'has_special_chars': bool(re.search(r'[^\w\s]', text)),
            'unique_words': len(set(words)),
            'vocabulary_richness': round(len(set(words)) / len(words) * 100, 2) if words else 0,
            'longest_word': max(words, key=len) if words else '',
            'shortest_word': min(words, key=len) if words else '',
            'avg_sentence_length': round(len(words) / self._count_sentences(text), 2) if self._count_sentences(text) > 0 else 0
        }