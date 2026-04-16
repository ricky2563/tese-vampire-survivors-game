import pandas as pd
import plotly.graph_objects as go

# ==========================================
# 1. CARREGAR OS DADOS
# ==========================================
ficheiro_csv = 'grafico_vida_player.csv' 

try:
    df = pd.read_csv(ficheiro_csv)
except FileNotFoundError:
    print(f"ERRO: Não encontrei o ficheiro '{ficheiro_csv}'. Verifica o caminho!")
    exit()

# ==========================================
# 2. CRIAR O GRÁFICO INTERATIVO
# ==========================================
fig = go.Figure()

# --- A) Linha da Vida (Verde) ---
fig.add_trace(go.Scatter(
    x=df['Tempo(s)'],
    y=df['Vida'],
    mode='lines',
    name='Vida do Jogador',
    line=dict(color='#2ca02c', width=3),
    hoverinfo='skip' # Ignora o rato na linha verde para não chatear
))

# --- B) Os Impactos (Pontos Vermelhos) ---
# Filtra tudo o que NÃO é normal nem é o aviso da Fase 2
danos = df[(df['Evento'] != 'Normal') & (df['Evento'] != 'BOSS: INÍCIO FASE 2')]

# A MAGIA DO HOVER: Define o texto que aparece na caixa flutuante
hover_texto = "<b>" + danos['Evento'].str.replace("Dano: ", "") + "</b><br>" + \
              "Vida Restante: " + danos['Vida'].astype(str) + " HP<br>" + \
              "Tempo: " + danos['Tempo(s)'].astype(str) + "s"

fig.add_trace(go.Scatter(
    x=danos['Tempo(s)'],
    y=danos['Vida'],
    mode='markers',
    name='Impactos / Dano',
    marker=dict(color='red', size=10, symbol='circle', line=dict(width=1, color='darkred')),
    text=hover_texto,
    hovertemplate="%{text}<extra></extra>" # <extra></extra> remove caixas de lixo extra do plotly
))

# --- C) Destacar a Fase 2 (Linha Laranja) ---
fase2 = df[df['Evento'] == 'BOSS: INÍCIO FASE 2']
if not fase2.empty:
    tempo_fase2 = fase2['Tempo(s)'].values[0]
    fig.add_vline(
        x=tempo_fase2, 
        line_width=2, 
        line_dash="dash", 
        line_color="orange",
        annotation_text="🔥 INÍCIO DA FASE 2", 
        annotation_position="top right",
        annotation_font=dict(color="orange", size=14, weight="bold")
    )

# ==========================================
# 3. DETALHES ESTÉTICOS
# ==========================================
fig.update_layout(
    title=dict(text='Análise de Sobrevivência e DDA - Confronto Final', font=dict(size=24)),
    xaxis_title='Tempo da Partida (Segundos)',
    yaxis_title='Pontos de Vida',
    yaxis=dict(range=[0, df['Vida'].max() * 1.05]), # Fixa o chão no 0
    hovermode="closest", # Facilita clicar com o rato
    template="plotly_white", # Fundo limpo, ótimo para teses
    legend=dict(yanchor="top", y=0.99, xanchor="left", x=0.01) # Põe a legenda dentro do gráfico no topo esquerdo
)

# ==========================================
# 4. GUARDAR E MOSTRAR
# ==========================================
nome_ficheiro = 'grafico_tese_interativo.html'

# Grava como uma página web que podes abrir em qualquer lugar
fig.write_html(nome_ficheiro)
print(f"Sucesso! Gráfico interativo gravado como '{nome_ficheiro}'")

# Abre automaticamente no teu browser padrão (Chrome, Edge, etc)
fig.show()