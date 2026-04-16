import pandas as pd
import matplotlib.pyplot as plt

# ==========================================
# 1. CARREGAR OS DADOS
# ==========================================
# Substitui o caminho se o ficheiro estiver noutra pasta
ficheiro_csv = 'grafico_vida_player.csv' 

try:
    df = pd.read_csv(ficheiro_csv)
except FileNotFoundError:
    print(f"ERRO: Não encontrei o ficheiro '{ficheiro_csv}'. Verifica o caminho!")
    exit()

# ==========================================
# 2. CONFIGURAR O GRÁFICO
# ==========================================
plt.figure(figsize=(14, 7)) # Tamanho da imagem (Largo x Altura)

# Desenha a linha contínua da Vida (Verde)
plt.plot(df['Tempo(s)'], df['Vida'], label='Vida do Jogador', color='#2ca02c', linewidth=2.5)

# ==========================================
# 3. DESTACAR A FASE 2
# ==========================================

fase2 = df[df['Evento'] == 'BOSS: INÍCIO FASE 2']

if not fase2.empty:
    tempo_fase2 = fase2['Tempo(s)'].values[0]
    # Desenha uma linha vertical amarela
    plt.axvline(x=tempo_fase2, color='orange', linestyle='--', linewidth=2, label='Início Fase 2')
    
    # Adiciona um texto no topo da linha
    plt.text(tempo_fase2, plt.ylim()[1]*0.9, ' FASE 2', color='orange', fontweight='bold')

# ==========================================
# 4. DESTACAR OS IMPACTOS DE DANO
# ==========================================
# Filtra apenas os momentos em que o evento NÃO foi a regeneração normal
danos = df[df['Evento'] != 'Normal']

# Coloca um ponto vermelho em cada impacto
plt.scatter(danos['Tempo(s)'], danos['Vida'], color='red', s=50, zorder=5, label='Impacto sofrido')

# Opcional: Escreve o nome de quem te deu dano (ex: "Boss: Meteoro") por cima do ponto.
# Se o gráfico ficar demasiado confuso cheio de texto, basta apagares este "for loop"
for i, row in danos.iterrows():
    plt.annotate(row['Evento'].replace("Dano: ", ""), # Tira a palavra "Dano: " para poupar espaço
                 (row['Tempo(s)'], row['Vida']),
                 textcoords="offset points",
                 xytext=(0, 12),
                 ha='center',
                 fontsize=8,
                 rotation=45,
                 alpha=0.7)

# ==========================================
# 5. DETALHES ESTÉTICOS
# ==========================================
plt.title('Análise de Sobrevivência e DDA', fontsize=16, fontweight='bold', pad=20)
plt.xlabel('Tempo da Partida (Segundos)', fontsize=12)
plt.ylabel('Pontos de Vida', fontsize=12)

# Define os limites do eixo Y (começa no 0, vai até ao teu máximo de vida + um bocado de margem)
plt.ylim(0, df['Vida'].max() * 1.1) 

plt.grid(True, linestyle='--', alpha=0.5)
plt.legend(loc='lower left')
plt.tight_layout()

# ==========================================
# 6. GUARDAR E MOSTRAR
# ==========================================
nome_imagem = 'grafico_tese_bossfight.png'
plt.savefig(nome_imagem, dpi=300) # Salva em Alta Resolução (300 DPI é o padrão académico)

print(f"Sucesso! O gráfico foi guardado como '{nome_imagem}'")
plt.show() # Abre a janela para veres o gráfico logo na hora