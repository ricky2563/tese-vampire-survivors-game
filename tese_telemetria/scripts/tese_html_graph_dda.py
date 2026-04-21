import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots

ficheiro_csv = 'grafico_dda_audio.csv'

try:
    df = pd.read_csv(ficheiro_csv, encoding='utf-8')
except FileNotFoundError:
    print(f"ERRO: Não encontrei o ficheiro '{ficheiro_csv}'. Verifica o caminho!")
    exit()

df['Evento'] = df['Evento'].fillna("")
df['Detalhes'] = df['Detalhes'].fillna("")

estilos_eventos = {
    'Ajuda (Realçado)':       {'cor': '#2ca02c', 'simbolo': 'triangle-up', 'tamanho': 16},
    'Desafio (Abafado)':      {'cor': '#d62728', 'simbolo': 'triangle-down', 'tamanho': 16},
    'Ducking Ativado':        {'cor': '#1f77b4', 'simbolo': 'star', 'tamanho': 18},
    'Dano Sofrido':           {'cor': '#000000', 'simbolo': 'x', 'tamanho': 12},
    'Normal (Sem Filtros)':   {'cor': '#7f7f7f', 'simbolo': 'circle', 'tamanho': 8}
}

# ========================================================
# 1. CRIAR GRÁFICO COM DOIS EIXOS Y (Esquerda=dB, Direita=EQ)
# ========================================================
fig = make_subplots(specs=[[{"secondary_y": True}]])

# ==========================================
# 2. AMBIENTE (Usa o Eixo Esquerdo de Decibéis)
# ==========================================
# Horda
fig.add_trace(go.Scatter(
    x=df['Tempo(s)'], y=df['Horda(dB)'],
    mode='lines', name='Vol: Horda',
    line=dict(color='#ff7f0e', width=3, shape='spline'),
    hovertemplate="Tempo: %{x}s<br>Horda: %{y} dB<extra></extra>"
), secondary_y=False)

# Música
fig.add_trace(go.Scatter(
    x=df['Tempo(s)'], y=df['Musica(dB)'],
    mode='lines', name='Vol: Música',
    line=dict(color='#9467bd', width=2, dash='dot', shape='spline'),
    hovertemplate="Tempo: %{x}s<br>Música: %{y} dB<extra></extra>"
), secondary_y=False)

# ==========================================
# 3. ATAQUES DO BOSS (Usa o Eixo Direito de Filtros - Degraus)
# ==========================================
# Mão de Fogo
fig.add_trace(go.Scatter(
    x=df['Tempo(s)'], y=df['Mao(Estado)'],
    mode='lines', name='Filtro: Mão',
    line=dict(color='#d62728', width=2, shape='hv'), # 'hv' cria o efeito de degrau
    hovertemplate="Tempo: %{x}s<br>Mão (EQ): %{y}<extra></extra>"
), secondary_y=True)

# Meteoro
fig.add_trace(go.Scatter(
    x=df['Tempo(s)'], y=df['Meteoro(Estado)'],
    mode='lines', name='Filtro: Meteoro',
    line=dict(color='#ff9896', width=2, dash='dash', shape='hv'),
    hovertemplate="Tempo: %{x}s<br>Meteoro (EQ): %{y}<extra></extra>"
), secondary_y=True)

# Anel de Fogo
fig.add_trace(go.Scatter(
    x=df['Tempo(s)'], y=df['Anel(Estado)'],
    mode='lines', name='Filtro: Anel',
    line=dict(color='#e377c2', width=2, dash='dot', shape='hv'),
    hovertemplate="Tempo: %{x}s<br>Anel (EQ): %{y}<extra></extra>"
), secondary_y=True)

# Stop Curse
fig.add_trace(go.Scatter(
    x=df['Tempo(s)'], y=df['Stop(Estado)'],
    mode='lines', name='Filtro: Stop',
    line=dict(color='#8c564b', width=2, dash='dashdot', shape='hv'),
    hovertemplate="Tempo: %{x}s<br>Stop (EQ): %{y}<extra></extra>"
), secondary_y=True)

# ==========================================
# 4. EVENTOS (Marcadores no Topo)
# ==========================================
eventos_reais = df[df['Evento'] != ""]

for evento_chave, estilo in estilos_eventos.items():
    subset = eventos_reais[eventos_reais['Evento'] == evento_chave]
    if not subset.empty:
        # Colocamos os eventos ancorados aos 8dB do eixo esquerdo
        y_vals = [8] * len(subset) 
        
        hover_texto = "<b>" + subset['Evento'] + "</b><br>" + \
                      "Alvo: " + subset['Detalhes'].astype(str) + "<br>" + \
                      "Tempo: " + subset['Tempo(s)'].astype(str) + "s"
        
        fig.add_trace(go.Scatter(
            x=subset['Tempo(s)'], y=y_vals,
            mode='markers', name=evento_chave,
            marker=dict(color=estilo['cor'], size=estilo['tamanho'], symbol=estilo['simbolo'], line=dict(width=1, color='black')),
            text=hover_texto,
            hovertemplate="%{text}<extra></extra>"
        ), secondary_y=False)

# ==========================================
# 5. DETALHES ESTÉTICOS E LAYOUT
# ==========================================
fig.update_layout(
    title=dict(text='Telemetria de Áudio: Volumes da Mistura vs Estado dos Filtros (EQ)', font=dict(size=24)),
    xaxis_title='Tempo da Partida (Segundos)',
    hovermode="x unified", # Mostra todos os dados dessa coluna temporal ao mesmo tempo
    template="plotly_white",
    legend=dict(yanchor="top", y=0.99, xanchor="left", x=0.01, bgcolor="rgba(255,255,255,0.8)", bordercolor="black", borderwidth=1)
)

# Configurar Eixo Y Esquerdo (Decibéis)
fig.update_yaxes(
    title_text="Volume Sonoro (Decibéis - dB)", 
    range=[-15, 10], 
    gridcolor='lightgrey', 
    zeroline=True, 
    zerolinecolor='black',
    secondary_y=False
)

# Configurar Eixo Y Direito (Filtros EQ)
fig.update_yaxes(
    title_text="Ação do Filtro (EQ)", 
    tickvals=[-1, 0, 1], 
    ticktext=["Desafio (-1)", "Normal (0)", "Ajuda (+1)"], 
    range=[-2.5, 2.5], # Intervalo largo para os degraus não sobreporem o topo/fundo do gráfico
    showgrid=False, # Esconder grelha para não confundir com a dos decibéis
    secondary_y=True
)

nome_ficheiro = 'tese_graph_dda.html'
fig.write_html(nome_ficheiro)
print(f"✅ Sucesso! Gráfico com eixos duplos gerado em '{nome_ficheiro}'.")
fig.show()