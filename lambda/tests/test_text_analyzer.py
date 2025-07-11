"""
Testes mínimos para TextAnalyzer.
Validar análise básica de texto.
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.text_analyzer import TextAnalyzer


def test_text_analyzer_basic():
    """Teste básico: análise de texto simples."""
    analyzer = TextAnalyzer()
    
    # Texto de teste
    text = "Olá mundo! Este é um teste simples. Vamos contar palavras."
    
    # Executar análise
    result = analyzer.analyze_text(text)
    
    # Validações básicas
    assert result['word_count'] == 10
    assert result['char_count'] == len(text)
    assert result['sentence_count'] == 3
    assert result['processing_time'] >= 0
    assert isinstance(result['most_common_words'], list)
    
    print("✅ TextAnalyzer - Teste básico passou!")


def test_text_analyzer_empty():
    """Teste edge case: texto vazio."""
    analyzer = TextAnalyzer()
    
    # Texto vazio
    text = ""
    
    # Executar análise
    result = analyzer.analyze_text(text)
    
    # Validações
    assert result['word_count'] == 0
    assert result['char_count'] == 0
    assert result['sentence_count'] == 0
    assert result['processing_time'] >= 0
    
    print("✅ TextAnalyzer - Teste texto vazio passou!")


def test_text_analyzer_structure():
    """Teste estrutura: verificar se retorna campos esperados."""
    analyzer = TextAnalyzer()
    
    text = "Teste de estrutura."
    result = analyzer.analyze_text(text)
    
    # Campos obrigatórios
    required_fields = [
        'word_count', 'char_count', 'line_count', 'sentence_count',
        'most_common_words', 'processing_time', 'text_stats'
    ]
    
    for field in required_fields:
        assert field in result, f"Campo '{field}' não encontrado no resultado"
    
    print("✅ TextAnalyzer - Teste estrutura passou!")


if __name__ == "__main__":
    test_text_analyzer_basic()
    test_text_analyzer_empty()
    test_text_analyzer_structure()
    print("\n🎉 Todos os testes do TextAnalyzer passaram!")